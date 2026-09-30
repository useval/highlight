import 'package:flutter/painting.dart';
import 'package:val_highlight/val_highlight.dart';

import 'code_styles.dart';

/// Spans for line [line] of [result], without the line break.
List<TextSpan> lineSpans(HighlightResult result, int line, CodeStyles styles) {
  final spans = <TextSpan>[];
  final code = result.code;
  final table = result.scopes;
  result.forEachSegment(line, (start, end, stack) {
    spans.add(
      TextSpan(
        text: code.substring(start, end),
        style: stack == 0 ? null : styles.of(table, stack),
      ),
    );
  });
  return spans;
}

/// Spans for every line of [result], joined with `\n`. Carriage returns are
/// dropped so they never render.
List<TextSpan> documentSpans(HighlightResult result, CodeStyles styles) {
  final spans = <TextSpan>[];
  for (var line = 0; line < result.lineCount; line++) {
    if (line > 0) spans.add(const TextSpan(text: '\n'));
    spans.addAll(lineSpans(result, line, styles));
  }
  return spans;
}

/// Spans covering every character of [result] exactly, as a text field
/// needs. When [composing] is a valid range, that range is underlined.
///
/// Only code within [styled] (all of it by default) is coloured; the rest
/// is plain text, which keeps huge documents cheap to lay out. Adjacent
/// pieces with the same style share one span.
List<TextSpan> exactSpans(
  HighlightResult result,
  CodeStyles styles, {
  TextRange composing = TextRange.empty,
  TextRange? styled,
}) {
  final spans = <TextSpan>[];
  final code = result.code;
  final table = result.scopes;
  final hasComposing = composing.isValid && !composing.isCollapsed;
  const underline = TextStyle(decoration: TextDecoration.underline);
  final styledStart = styled?.start ?? 0;
  final styledEnd = styled?.end ?? code.length;

  var pendingStart = 0;
  var pendingEnd = 0;
  TextStyle? pendingStyle;

  void flush() {
    if (pendingEnd > pendingStart) {
      spans.add(
        TextSpan(
          text: code.substring(pendingStart, pendingEnd),
          style: pendingStyle,
        ),
      );
    }
    pendingStart = pendingEnd;
  }

  void add(int start, int end, TextStyle? style) {
    if (start >= end) return;
    if (hasComposing && start >= composing.start && end <= composing.end) {
      style = style == null ? underline : style.merge(underline);
    }
    // A line break joins the run before it. When trailing spaces end a run
    // (say, an italic comment) and the next run starts with the line
    // break, Flutter's text layout does not advance the caret over those
    // spaces while typing. A line break draws nothing, so its style never
    // shows.
    if (!identical(style, pendingStyle) &&
        start == pendingEnd &&
        pendingEnd > pendingStart &&
        code.codeUnitAt(start) == 0x0A) {
      pendingEnd = start + 1;
      start++;
      if (start >= end) return;
    }
    if (!identical(style, pendingStyle) || start != pendingEnd) {
      flush();
      pendingStart = start;
      pendingStyle = style;
    }
    pendingEnd = end;
  }

  void piece(int start, int end, int stack) {
    if (start >= end) return;
    if (!hasComposing || end <= composing.start || start >= composing.end) {
      add(start, end, stack == 0 ? null : styles.of(table, stack));
      return;
    }
    // Split at the composing range boundaries.
    final style = stack == 0 ? null : styles.of(table, stack);
    final a = composing.start.clamp(start, end);
    final b = composing.end.clamp(start, end);
    add(start, a, style);
    add(a, b, style);
    add(b, end, style);
  }

  for (var i = 0; i < result.tokenCount; i++) {
    final start = result.tokenStart(i);
    final end = result.tokenEnd(i);
    final stack = result.tokenStack(i);
    // Outside the styled range, text is plain.
    if (end <= styledStart || start >= styledEnd) {
      piece(start, end, 0);
      continue;
    }
    piece(start, styledStart.clamp(start, end), 0);
    piece(styledStart.clamp(start, end), styledEnd.clamp(start, end), stack);
    piece(styledEnd.clamp(start, end), end, 0);
  }
  flush();
  return spans;
}
