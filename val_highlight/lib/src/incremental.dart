import 'dart:typed_data';

import 'engine/compiler.dart';
import 'engine/scanner.dart';
import 'engine/scope_table.dart';
import 'grammar/grammar.dart';
import 'registry.dart';
import 'result.dart';

/// Keeps a document highlighted as it is edited, re-scanning only what an
/// edit can affect.
///
/// The scanner state is saved at every line start. After an edit, scanning
/// resumes a line before the first change and stops at the first line after
/// the change whose saved state matches, then reuses the old tokens for the
/// rest of the document. Typing inside a function re-scans a line or two;
/// opening a block comment re-scans until the comment closes.
///
/// ```dart
/// final doc = IncrementalHighlighter(language: dartLanguage, text: source);
/// final result = doc.update(editedSource);
/// ```
final class IncrementalHighlighter {
  /// Creates a highlighter for [text] in [language]. [registry] resolves
  /// languages named inside the code, such as Markdown code fences.
  IncrementalHighlighter({
    required Grammar language,
    String text = '',
    this.registry,
  }) : _language = language {
    _full(text);
  }

  /// Languages for embedded regions named in the code.
  final LanguageRegistry? registry;

  Grammar _language;
  late HighlightResult _result;
  late List<ScanFrame?> _checkpoints;
  late ScopeTable _table;

  /// Lines re-scanned by the last [update], for diagnostics.
  int lastRescannedLines = 0;

  /// The current result.
  HighlightResult get result => _result;

  /// The current language. Setting it re-highlights everything.
  Grammar get language => _language;
  set language(Grammar value) {
    if (identical(value, _language)) return;
    _language = value;
    _full(_result.code);
  }

  RegExp? get _restartLine {
    final pattern = _language.restartLine;
    if (pattern == null) return null;
    return CompiledGrammar.of(_language).regExp(pattern);
  }

  /// Updates the document to [text] and returns the new result.
  HighlightResult update(String text) {
    final old = _result;
    final oldText = old.code;
    if (text == oldText) return old;

    // The edit is the region between the common prefix and suffix.
    final maxCommon = text.length < oldText.length
        ? text.length
        : oldText.length;
    var prefix = 0;
    while (prefix < maxCommon &&
        text.codeUnitAt(prefix) == oldText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < maxCommon - prefix &&
        text.codeUnitAt(text.length - 1 - suffix) ==
            oldText.codeUnitAt(oldText.length - 1 - suffix)) {
      suffix++;
    }
    final editEndNew = text.length - suffix;
    final delta = text.length - oldText.length;

    final newStarts = _spliceLineStarts(old, text, prefix, suffix, delta);
    final oldLineCount = old.lineCount;
    final lineDelta = newStarts.length - oldLineCount;

    // Resume one line before the line holding the first change, because a
    // rule's lookahead may have read across the line break. Grammars whose
    // lookahead reaches further name the lines it never crosses.
    var line = _lineOf(old, prefix) - 1;
    if (line < 0) line = 0;
    final restart = _restartLine;
    while (line > 0 &&
        (_checkpoints[line] == null ||
            (restart != null &&
                restart.matchAsPrefix(oldText, old.lineStart(line)) == null))) {
      line--;
    }
    final resumeAt = old.lineStart(line);
    final frame =
        _checkpoints[line] ??
        ScanFrame(CompiledGrammar.of(_language).root, ScopeTable.root, null);

    final out = TokenBuffer(old.tokenCount + 16);
    final keep = old.tokenAt(resumeAt);
    out.appendShifted(old.rawEnds, old.rawStacks, 0, keep, 0);
    if (keep < old.tokenCount) out.emit(resumeAt, old.tokenStack(keep));

    final checkpoints = List<ScanFrame?>.filled(newStarts.length, null);
    for (var i = 0; i <= line; i++) {
      checkpoints[i] = _checkpoints[i];
    }

    var resumedOldLine = -1;
    final stoppedAt =
        Scanner(
          code: text,
          table: _table,
          out: out,
          embeds: registry,
          lineStarts: newStarts,
          checkpoints: checkpoints,
        ).scan(
          frame,
          resumeAt,
          firstLine: line,
          stop: (newLine, state) {
            final start = newStarts[newLine];
            if (start < editEndNew || newLine == line) return false;
            final oldLine = newLine - lineDelta;
            if (oldLine < 0 || oldLine >= oldLineCount) return false;
            if (old.lineStart(oldLine) != start - delta) return false;
            if (!state.sameAs(_checkpoints[oldLine])) return false;
            resumedOldLine = oldLine;
            return true;
          },
        );

    if (resumedOldLine >= 0) {
      // Reuse the old tokens and checkpoints after the convergence point.
      final oldAt = stoppedAt - delta;
      out.appendShifted(
        old.rawEnds,
        old.rawStacks,
        old.tokenAt(oldAt),
        old.tokenCount,
        delta,
      );
      for (var o = resumedOldLine; o < oldLineCount; o++) {
        checkpoints[o + lineDelta] = _checkpoints[o];
      }
      lastRescannedLines = resumedOldLine + lineDelta - line;
    } else {
      lastRescannedLines = newStarts.length - line;
    }

    _checkpoints = checkpoints;
    return _result = _resultFrom(text, out, newStarts);
  }

  void _full(String text) {
    _table = ScopeTable();
    final starts = computeLineStarts(text);
    _checkpoints = List<ScanFrame?>.filled(starts.length, null);
    final out = TokenBuffer(text.length ~/ 6);
    Scanner(
      code: text,
      table: _table,
      out: out,
      embeds: registry,
      lineStarts: starts,
      checkpoints: _checkpoints,
    ).scan(
      ScanFrame(CompiledGrammar.of(_language).root, ScopeTable.root, null),
      0,
    );
    lastRescannedLines = starts.length;
    _result = _resultFrom(text, out, starts);
  }

  HighlightResult _resultFrom(String text, TokenBuffer out, Int32List starts) {
    return HighlightResult.fromBuffers(
      code: text,
      language: _language,
      scopes: _table,
      ends: out.ends,
      stacks: out.stacks,
      tokenCount: out.count,
      lineStarts: starts,
    );
  }

  /// Line starts of [text] from those of [old]: lines before the edit are
  /// unchanged, lines after it shift by [delta], and only the edited range
  /// is scanned for line breaks.
  static Int32List _spliceLineStarts(
    HighlightResult old,
    String text,
    int prefix,
    int suffix,
    int delta,
  ) {
    final oldEditEnd = old.code.length - suffix;
    final newEditEnd = text.length - suffix;
    // Old lines starting at or before `prefix` are unchanged.
    final keep = _lineOf(old, prefix) + 1;
    // Old lines starting after the edited range survive, shifted.
    var after = keep;
    while (after < old.lineCount && old.lineStart(after) <= oldEditEnd) {
      after++;
    }
    final middle = <int>[];
    for (var i = prefix; i < newEditEnd; i++) {
      if (text.codeUnitAt(i) == 0x0A) middle.add(i + 1);
    }
    final count = keep + middle.length + (old.lineCount - after);
    final starts = Int32List(count);
    for (var i = 0; i < keep; i++) {
      starts[i] = old.lineStart(i);
    }
    var at = keep;
    for (final start in middle) {
      starts[at++] = start;
    }
    for (var i = after; i < old.lineCount; i++) {
      starts[at++] = old.lineStart(i) + delta;
    }
    return starts;
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
