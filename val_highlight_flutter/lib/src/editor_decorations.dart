import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:val_highlight/val_highlight.dart';

import 'code_editing.dart';
import 'highlight_text_controller.dart';

/// Pre-laid-out digits `0`–`9` in one style, so painting line numbers never
/// lays out text: a number is drawn digit by digit, right-aligned.
final class GutterDigits {
  /// Lays out the ten digits in [style].
  GutterDigits(this.style, this.textScaler)
    : _painters = List.generate(
        10,
        (digit) => TextPainter(
          text: TextSpan(text: '$digit', style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
      ) {
    for (final painter in _painters) {
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
  }

  /// The style the digits were laid out in.
  final TextStyle style;

  /// The text scaler the digits were laid out with.
  final TextScaler textScaler;

  final List<TextPainter> _painters;

  /// Width of the widest digit.
  double maxWidth = 0;

  /// Width of [number] when painted.
  double widthOf(int number) {
    var width = 0.0;
    do {
      width += _painters[number % 10].width;
      number ~/= 10;
    } while (number > 0);
    return width;
  }

  /// Paints [number] with its right edge at [right] and its top at [top].
  void paint(Canvas canvas, int number, double right, double top) {
    var x = right;
    do {
      final painter = _painters[number % 10];
      x -= painter.width;
      painter.paint(canvas, Offset(x, top));
      number ~/= 10;
    } while (number > 0);
  }

  /// Releases the laid-out digits.
  void dispose() {
    for (final painter in _painters) {
      painter.dispose();
    }
  }
}

/// Paints behind a `CodeField`'s text: highlighted and current line bands,
/// line numbers in the gutter, and the matched bracket pair.
///
/// Everything is positioned from the editable text's own layout, so wrapped
/// lines, scrolling and any decoration padding line up exactly. Only lines
/// inside the visible area are visited, so the cost per frame depends on
/// the screen, not the document.
class EditorDecorations extends LeafRenderObjectWidget {
  /// Creates the decorations.
  const EditorDecorations({
    super.key,
    required this.controller,
    required this.repaint,
    required this.editable,
    required this.viewport,
    required this.digits,
    required this.gutterWidth,
    required this.gutterGap,
    required this.firstLineNumber,
    required this.highlightedLines,
    required this.highlightColor,
    required this.currentLineColor,
    required this.currentNumberDigits,
    required this.bracketColor,
    required this.editing,
  });

  /// The text being decorated.
  final HighlightTextController controller;

  /// Fires whenever the decorations may have moved.
  final Listenable repaint;

  /// The render object of the editable text, once laid out.
  final RenderEditable? Function() editable;

  /// The global rectangle of an enclosing scroll view, if any.
  final Rect? Function() viewport;

  /// Digits for line numbers, or `null` for no gutter.
  final GutterDigits? digits;

  /// Width of the gutter, including [gutterGap].
  final double gutterWidth;

  /// Space between the numbers and the text.
  final double gutterGap;

  /// Number shown for the first line.
  final int firstLineNumber;

  /// Line numbers, as shown, to paint with [highlightColor].
  final Set<int> highlightedLines;

  /// Band color for [highlightedLines].
  final Color highlightColor;

  /// Band color for the caret's line, or `null` for none.
  final Color? currentLineColor;

  /// Digits for the caret line's number, or `null` to use [digits].
  final GutterDigits? currentNumberDigits;

  /// Fill for the matched bracket pair, or `null` for no matching.
  final Color? bracketColor;

  /// Editing behaviour, whose syntax gives the bracket pairs to match.
  final CodeEditing editing;

  @override
  RenderEditorDecorations createRenderObject(BuildContext context) =>
      RenderEditorDecorations(this);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEditorDecorations renderObject,
  ) {
    renderObject.config = this;
  }
}

/// The render object of [EditorDecorations].
class RenderEditorDecorations extends RenderBox {
  /// Creates the render object.
  RenderEditorDecorations(this._config);

  EditorDecorations _config;

  /// The current configuration.
  set config(EditorDecorations value) {
    final old = _config;
    _config = value;
    if (attached && !identical(old.repaint, value.repaint)) {
      old.repaint.removeListener(markNeedsPaint);
      value.repaint.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  // The last bracket match, reused while the text and caret stay put.
  HighlightResult? _matchResult;
  int _matchCaret = -1;
  String _matchBrackets = '';
  (int, int)? _match;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _config.repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _config.repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final editable = _config.editable();
    if (editable == null ||
        !editable.attached ||
        !editable.hasSize ||
        editable.maxLines == 1) {
      return;
    }
    final result = _config.controller.result;
    final lineCount = result.lineCount;
    final origin = MatrixUtils.transformPoint(
      editable.getTransformTo(this),
      Offset.zero,
    );

    // The visible part: the editable's viewport, clipped by our bounds and
    // by an enclosing scroll view.
    var visible = Rect.fromLTRB(
      0,
      origin.dy < 0 ? 0 : origin.dy,
      size.width,
      origin.dy + editable.size.height > size.height
          ? size.height
          : origin.dy + editable.size.height,
    );
    final viewport = _config.viewport();
    if (viewport != null) {
      final topLeft = globalToLocal(viewport.topLeft);
      visible = visible.intersect(topLeft & viewport.size);
    }
    if (visible.isEmpty || visible.height <= 0) return;

    // Caret rectangles carry a constant, platform-specific offset from the
    // top of their line. Measure it on the first line, whose top is known.
    final scroll = editable.offset.pixels;
    final skew =
        editable.getLocalRectForCaret(const TextPosition(offset: 0)).top +
        scroll;
    double lineTop(int line) =>
        editable
            .getLocalRectForCaret(TextPosition(offset: result.lineStart(line)))
            .top -
        skew +
        origin.dy;

    final selection = _config.controller.selection;
    final caretLine = selection.isValid
        ? _lineOf(result, selection.extentOffset)
        : -1;
    final firstVisible = _lineOf(
      result,
      editable
          .getPositionForPoint(
            localToGlobal(Offset(visible.left + 1, visible.top + 1)),
          )
          .offset,
    );

    final canvas = context.canvas;
    canvas
      ..save()
      ..clipRect(visible.shift(offset));
    final digits = _config.digits;
    final numberRight = _config.gutterWidth - _config.gutterGap;
    final paint = Paint();
    var line = firstVisible > 0 ? firstVisible - 1 : 0;
    var top = lineTop(line);
    while (line < lineCount && top < visible.bottom) {
      final bottom = line + 1 < lineCount
          ? lineTop(line + 1)
          : top + editable.preferredLineHeight;
      if (bottom > visible.top) {
        final number = _config.firstLineNumber + line;
        Color? band;
        if (_config.highlightedLines.contains(number)) {
          band = _config.highlightColor;
        } else if (line == caretLine) {
          band = _config.currentLineColor;
        }
        if (band != null) {
          canvas.drawRect(
            Rect.fromLTRB(0, top, size.width, bottom).shift(offset),
            paint..color = band,
          );
        }
        if (digits != null && number >= 0) {
          final style = line == caretLine
              ? _config.currentNumberDigits ?? digits
              : digits;
          style.paint(canvas, number, offset.dx + numberRight, offset.dy + top);
        }
      }
      line++;
      top = bottom;
    }

    final bracketColor = _config.bracketColor;
    if (bracketColor != null && selection.isValid && selection.isCollapsed) {
      final match = _bracketMatch(result, selection.baseOffset);
      if (match != null) {
        paint.color = bracketColor;
        for (final at in [match.$1, match.$2]) {
          for (final box in editable.getBoxesForSelection(
            TextSelection(baseOffset: at, extentOffset: at + 1),
          )) {
            final rect = box.toRect().shift(origin + offset);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                rect.inflate(1),
                const Radius.circular(2),
              ),
              paint,
            );
          }
        }
      }
    }
    canvas.restore();
  }

  /// The bracket next to [caret] and its match: the one before the caret
  /// first, as most editors do.
  (int, int)? _bracketMatch(HighlightResult result, int caret) {
    final brackets = _config.editing
        .syntaxFor(_config.controller.language)
        .brackets;
    if (identical(result, _matchResult) &&
        caret == _matchCaret &&
        brackets == _matchBrackets) {
      return _match;
    }
    _matchResult = result;
    _matchCaret = caret;
    _matchBrackets = brackets;
    _match = null;
    for (final at in [caret - 1, caret]) {
      final other = result.matchingBracket(at, brackets: brackets);
      if (other >= 0) {
        _match = at < other ? (at, other) : (other, at);
        break;
      }
    }
    return _match;
  }

  static int _lineOf(HighlightResult result, int offset) {
    var low = 0;
    var high = result.lineCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (result.lineStart(mid) <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}
