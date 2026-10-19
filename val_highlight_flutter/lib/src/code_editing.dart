import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:val_highlight/val_highlight.dart';

import 'highlight_text_controller.dart';

/// Editing behaviour for `CodeField`: what typing, Enter and Backspace do
/// beyond inserting text.
///
/// Brackets, quotes and comment markers come from the language's
/// [EditingSyntax], unless [syntax] overrides them.
///
/// ```dart
/// CodeField(
///   controller: controller,
///   editing: const CodeEditing(autoClose: false),
/// )
/// ```
///
/// Use [CodeEditing.none] to turn every behaviour off.
@immutable
class CodeEditing {
  /// Creates editing behaviour. Everything is on by default.
  const CodeEditing({
    this.autoIndent = true,
    this.autoClose = true,
    this.wrapSelection = true,
    this.matchBrackets = true,
    this.syntax,
  });

  /// Plain text editing: no auto-indent, auto-closing, wrapping or bracket
  /// matching.
  static const none = CodeEditing(
    autoIndent: false,
    autoClose: false,
    wrapSelection: false,
    matchBrackets: false,
  );

  /// Whether Enter keeps the current line's indentation, adds a level after
  /// an opening bracket or `:`, and moves a closing bracket right after the
  /// caret onto its own line.
  final bool autoIndent;

  /// Whether typing an opening bracket or quote also inserts its closing
  /// one.
  ///
  /// Brackets close when the caret is followed by whitespace, the end of
  /// the text or a closing character such as `)` or `;`. Quotes also stay
  /// single after a letter or digit and inside strings and comments.
  /// Typing a closer that was inserted automatically steps over it, and
  /// Backspace between an empty automatic pair deletes both.
  final bool autoClose;

  /// Whether typing an opening bracket or quote over a selection wraps the
  /// selection instead of replacing it.
  final bool wrapSelection;

  /// Whether the bracket at the caret and its match are outlined.
  final bool matchBrackets;

  /// Comment markers, brackets and quotes to use instead of the language's.
  final EditingSyntax? syntax;

  /// The syntax used for [language]: [syntax], or the language's own.
  EditingSyntax syntaxFor(Grammar language) =>
      syntax ?? EditingSyntax.of(language);

  /// Returns a copy with the given fields replaced.
  CodeEditing copyWith({
    bool? autoIndent,
    bool? autoClose,
    bool? wrapSelection,
    bool? matchBrackets,
    EditingSyntax? syntax,
  }) {
    return CodeEditing(
      autoIndent: autoIndent ?? this.autoIndent,
      autoClose: autoClose ?? this.autoClose,
      wrapSelection: wrapSelection ?? this.wrapSelection,
      matchBrackets: matchBrackets ?? this.matchBrackets,
      syntax: syntax ?? this.syntax,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CodeEditing &&
      other.autoIndent == autoIndent &&
      other.autoClose == autoClose &&
      other.wrapSelection == wrapSelection &&
      other.matchBrackets == matchBrackets &&
      other.syntax == syntax;

  @override
  int get hashCode =>
      Object.hash(autoIndent, autoClose, wrapSelection, matchBrackets, syntax);
}

/// Indents the selected lines, or inserts an indent at the caret. Bound to
/// Tab in `CodeField`.
class IndentCodeIntent extends Intent {
  /// Creates an indent intent.
  const IndentCodeIntent();
}

/// Removes one indent from the selected lines. Bound to Shift+Tab in
/// `CodeField`.
class OutdentCodeIntent extends Intent {
  /// Creates an outdent intent.
  const OutdentCodeIntent();
}

/// Comments or uncomments the selected lines. Bound to Ctrl+/ (Cmd+/ on
/// Apple platforms) in `CodeField`.
class ToggleCommentIntent extends Intent {
  /// Creates a toggle-comment intent.
  const ToggleCommentIntent();
}

/// Applies [CodeEditing] to text typed into a field driven by a
/// [HighlightTextController].
///
/// `CodeField` installs one automatically. Add one to a plain [TextField]'s
/// `inputFormatters` to get the same behaviour there:
///
/// ```dart
/// TextField(
///   controller: controller,
///   maxLines: null,
///   inputFormatters: [CodeEditingFormatter(controller: controller)],
/// )
/// ```
///
/// It reacts to text changes rather than key presses, so it works the same
/// with hardware keyboards, on-screen keyboards and voice input. Text being
/// composed by an input method is never changed. Each change it makes is a
/// single edit, so one undo reverts it.
class CodeEditingFormatter extends TextInputFormatter {
  /// Creates a formatter for [controller].
  CodeEditingFormatter({
    required this.controller,
    this.editing = const CodeEditing(),
    this.indent = '  ',
  });

  /// The controller whose highlighting tells strings and comments apart.
  final HighlightTextController controller;

  /// The behaviour to apply.
  CodeEditing editing;

  /// One level of indentation, for Enter.
  String indent;

  // Offsets of closers inserted automatically, in increasing order. Only
  // these are stepped over or deleted with their opener.
  final List<int> _closers = [];
  String? _text;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = _format(oldValue, newValue);
    _text = value.text;
    return value;
  }

  TextEditingValue _format(TextEditingValue oldValue, TextEditingValue value) {
    // Something other than this formatter changed the text: the recorded
    // closers may no longer be where they were.
    if (!identical(oldValue.text, _text)) _closers.clear();
    final edit = _Edit.between(oldValue, value);
    if (edit == null) {
      _closers.clear();
      return value;
    }
    _forgetDistantClosers(oldValue.text, edit.start);
    // Never change text an input method is still composing.
    if (value.composing.isValid) return _shifted(value, edit);

    final text = oldValue.text;
    final inserted = edit.inserted;
    if (inserted.length == 1) {
      if (inserted == '\n') {
        if (!editing.autoIndent) return _shifted(value, edit);
        _closers.clear();
        return newlineKeepingIndent(
          oldValue,
          indent,
          brackets: _syntax.brackets,
        ).copyWith(composing: TextRange.empty);
      }
      final closer = editing.autoClose || editing.wrapSelection
          ? _syntax.closerOf(inserted)
          : null;
      if (edit.start < edit.end) {
        if (closer != null && editing.wrapSelection) {
          _closers.clear();
          return _wrap(oldValue, edit, inserted, closer);
        }
        return _shifted(value, edit);
      }
      if (editing.autoClose) {
        final at = edit.start;
        // Step over a closer this formatter inserted.
        if (at < text.length && text[at] == inserted && _closers.contains(at)) {
          _closers.remove(at);
          return oldValue.copyWith(
            selection: TextSelection.collapsed(offset: at + 1),
            composing: TextRange.empty,
          );
        }
        if (closer != null && _shouldClose(text, at, inserted, closer)) {
          _shift(at, at, 2);
          _closers
            ..add(at + 1)
            ..sort();
          return TextEditingValue(
            text: value.text.replaceRange(at + 1, at + 1, closer),
            selection: TextSelection.collapsed(offset: at + 1),
          );
        }
      }
      return _shifted(value, edit);
    }

    // Backspace between an automatic pair deletes both halves.
    if (inserted.isEmpty &&
        editing.autoClose &&
        edit.end - edit.start == 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset == edit.end &&
        _closers.contains(edit.end) &&
        edit.end < text.length &&
        _syntax.closerOf(text[edit.start]) == text[edit.end]) {
      _closers.remove(edit.end);
      _shift(edit.start, edit.end + 1, 0);
      return TextEditingValue(
        text: text.replaceRange(edit.start, edit.end + 1, ''),
        selection: TextSelection.collapsed(offset: edit.start),
      );
    }
    return _shifted(value, edit);
  }

  EditingSyntax get _syntax => editing.syntaxFor(controller.language);

  bool _shouldClose(String text, int at, String open, String close) {
    if (at < text.length && !_closesBefore(text.codeUnitAt(at))) return false;
    final quote = open == close;
    if (!quote) return true;
    if (at > 0 && _isWord(text.codeUnitAt(at - 1))) return false;
    final result = controller.result;
    if (!identical(result.code, text) && result.code != text) return true;
    return !result.isInsideStringOrComment(at, _syntax);
  }

  TextEditingValue _wrap(
    TextEditingValue value,
    _Edit edit,
    String open,
    String close,
  ) {
    final text = value.text;
    final selection = value.selection;
    return TextEditingValue(
      text:
          '${text.substring(0, edit.start)}$open'
          '${text.substring(edit.start, edit.end)}$close'
          '${text.substring(edit.end)}',
      selection: TextSelection(
        baseOffset: selection.baseOffset + 1,
        extentOffset: selection.extentOffset + 1,
      ),
    );
  }

  TextEditingValue _shifted(TextEditingValue value, _Edit edit) {
    _shift(edit.start, edit.end, edit.inserted.length);
    return value;
  }

  /// Moves recorded closers for [start, end) being replaced by [length]
  /// characters. Closers inside the replaced range are forgotten.
  void _shift(int start, int end, int length) {
    if (_closers.isEmpty) return;
    final delta = length - (end - start);
    var write = 0;
    for (final offset in _closers) {
      if (offset < start) {
        _closers[write++] = offset;
      } else if (offset >= end) {
        _closers[write++] = offset + delta;
      }
    }
    _closers.length = write;
  }

  /// Forgets closers behind the caret or on another line: once the caret
  /// leaves an auto-closed pair, its closer is ordinary text.
  void _forgetDistantClosers(String text, int caret) {
    if (_closers.isEmpty) return;
    _closers.removeWhere((offset) {
      if (offset < caret || offset >= text.length || offset - caret > 512) {
        return true;
      }
      for (var i = caret; i < offset; i++) {
        if (text.codeUnitAt(i) == 0x0A) return true;
      }
      return false;
    });
  }

  static bool _closesBefore(int unit) =>
      unit == 0x20 || // space
      unit == 0x09 || // tab
      unit == 0x0A || // \n
      unit == 0x0D || // \r
      unit == 0x29 || // )
      unit == 0x5D || // ]
      unit == 0x7D || // }
      unit == 0x3E || // >
      unit == 0x3B || // ;
      unit == 0x3A || // :
      unit == 0x2C || // ,
      unit == 0x2E || // .
      unit == 0x3D; // =

  static bool _isWord(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      unit == 0x5F ||
      unit > 0x7F;
}

/// A single replacement of `[start, end)` in the old text by [inserted].
final class _Edit {
  const _Edit(this.start, this.end, this.inserted);

  final int start;
  final int end;
  final String inserted;

  /// The edit that turns [old] into [value], when it is a typed insertion,
  /// a replaced selection, Backspace or Delete. `null` for anything else,
  /// such as an input method rewriting a word.
  ///
  /// Checks run in constant time: lengths, selections and the text around
  /// the edit.
  static _Edit? between(TextEditingValue old, TextEditingValue value) {
    final selection = old.selection;
    final after = value.selection;
    if (!selection.isValid || !after.isValid || !after.isCollapsed) {
      return null;
    }
    final oldText = old.text;
    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    final inserted = text.length - oldText.length + (end - start);
    if (inserted >= 0 && after.baseOffset == start + inserted) {
      if (_same(oldText, text, start, end, start + inserted)) {
        return _Edit(start, end, text.substring(start, start + inserted));
      }
    }
    if (selection.isCollapsed && text.length == oldText.length - 1) {
      if (start > 0 && after.baseOffset == start - 1) {
        if (_same(oldText, text, start - 1, start, start - 1)) {
          return _Edit(start - 1, start, '');
        }
      } else if (start < oldText.length && after.baseOffset == start) {
        if (_same(oldText, text, start, start + 1, start)) {
          return _Edit(start, start + 1, '');
        }
      }
    }
    return null;
  }

  /// Whether [oldText] and [text] agree just before [start] and just after
  /// the edit, which ends at [oldEnd] in the old text and [newEnd] in the
  /// new one.
  static bool _same(
    String oldText,
    String text,
    int start,
    int oldEnd,
    int newEnd,
  ) {
    const window = 16;
    for (var i = start - 1; i >= 0 && i >= start - window; i--) {
      if (oldText.codeUnitAt(i) != text.codeUnitAt(i)) return false;
    }
    for (var i = 0; i < window && oldEnd + i < oldText.length; i++) {
      if (newEnd + i >= text.length ||
          oldText.codeUnitAt(oldEnd + i) != text.codeUnitAt(newEnd + i)) {
        return false;
      }
    }
    return true;
  }
}

/// Tab: inserts [indent] at the caret, or indents every selected line.
TextEditingValue indentText(TextEditingValue value, String indent) {
  final text = value.text;
  final selection = value.selection;
  if (selection.isCollapsed ||
      !text.substring(selection.start, selection.end).contains('\n')) {
    return value
        .replaced(selection, indent)
        .copyWith(
          selection: TextSelection.collapsed(
            offset: selection.start + indent.length,
          ),
        );
  }
  final first = _lineStart(text, selection.start);
  final buffer = StringBuffer(text.substring(0, first));
  var added = 0;
  var addedBeforeStart = 0;
  var position = first;
  for (final line in text.substring(first, selection.end).split('\n')) {
    if (position > first) buffer.write('\n');
    if (line.isNotEmpty) {
      buffer.write(indent);
      added += indent.length;
      if (position <= selection.start) addedBeforeStart += indent.length;
    }
    buffer.write(line);
    position += line.length + 1;
  }
  buffer.write(text.substring(selection.end));
  return TextEditingValue(
    text: buffer.toString(),
    selection: TextSelection(
      baseOffset: selection.start + addedBeforeStart,
      extentOffset: selection.end + added,
    ),
  );
}

/// Shift+Tab: removes one level of indentation from every selected line (or
/// the caret's line).
TextEditingValue outdentLines(TextEditingValue value, String indent) {
  final text = value.text;
  final selection = value.selection;
  final first = _lineStart(text, selection.start);
  final end = selection.end;
  final buffer = StringBuffer(text.substring(0, first));
  var removed = 0;
  var removedBeforeStart = 0;
  var position = first;
  final lines = text.substring(first, end).split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i > 0) buffer.write('\n');
    var cut = 0;
    if (line.startsWith(indent)) {
      cut = indent.length;
    } else {
      while (cut < indent.length && cut < line.length && line[cut] == ' ') {
        cut++;
      }
      if (cut == 0 && line.startsWith('\t')) cut = 1;
    }
    buffer.write(line.substring(cut));
    removed += cut;
    if (position < selection.start) {
      removedBeforeStart += cut.clamp(0, selection.start - position);
    }
    position += line.length + 1;
  }
  buffer.write(text.substring(end));
  return TextEditingValue(
    text: buffer.toString(),
    selection: TextSelection(
      baseOffset: selection.start - removedBeforeStart,
      extentOffset: selection.end - removed,
    ),
  );
}

/// Enter: a line break followed by the current line's indentation, plus one
/// [indent] level after an opening bracket or colon.
///
/// When the caret sits between a pair from [brackets], as in `{|}`, the
/// closing bracket moves to its own line below the caret.
TextEditingValue newlineKeepingIndent(
  TextEditingValue value,
  String indent, {
  String brackets = '',
}) {
  final text = value.text;
  final selection = value.selection;
  final lineStart = _lineStart(text, selection.start);
  var leading = lineStart;
  while (leading < selection.start &&
      (text.codeUnitAt(leading) == 0x20 || text.codeUnitAt(leading) == 0x09)) {
    leading++;
  }
  final current = text.substring(lineStart, leading);
  var insert = '\n$current';
  final before = text.substring(lineStart, selection.start).trimRight();
  final opened =
      before.endsWith('{') ||
      before.endsWith('[') ||
      before.endsWith('(') ||
      before.endsWith(':');
  if (opened) insert += indent;
  final caret = selection.start + insert.length;
  if (selection.start > 0 && selection.end < text.length) {
    final open = text[selection.start - 1];
    final close = text[selection.end];
    for (var i = 0; i + 1 < brackets.length; i += 2) {
      if (brackets[i] == open && brackets[i + 1] == close) {
        if (!opened) insert += indent;
        return value
            .replaced(selection, '$insert\n$current')
            .copyWith(
              selection: TextSelection.collapsed(
                offset: selection.start + insert.length,
              ),
            );
      }
    }
  }
  return value
      .replaced(selection, insert)
      .copyWith(selection: TextSelection.collapsed(offset: caret));
}

/// Comments or uncomments the lines touched by the selection, using
/// [syntax]'s markers. Returns `null` when the language has no comments.
///
/// With a line comment marker, the lines are uncommented when every
/// non-blank one already starts with the marker, and commented otherwise.
/// Markers are aligned at the smallest indentation, and blank lines are
/// left alone. [result], when it highlights [value]'s text, makes sure a
/// marker inside a string is not taken for a comment.
///
/// With only a block comment, as in CSS or HTML, the selection (or the
/// caret's line) is wrapped in the markers, or unwrapped if it already is.
TextEditingValue? toggleComment(
  TextEditingValue value,
  EditingSyntax syntax, {
  HighlightResult? result,
}) {
  final text = value.text;
  final selection = value.selection;
  if (!selection.isValid || selection.end > text.length) return null;
  final checked = result != null && result.code == text ? result : null;
  final line = syntax.lineComment;
  if (line != null && line.isNotEmpty) {
    return _toggleLineComments(value, line, checked);
  }
  final block = syntax.blockComment;
  if (block != null) return _toggleBlockComment(value, block, checked);
  return null;
}

TextEditingValue _toggleLineComments(
  TextEditingValue value,
  String marker,
  HighlightResult? result,
) {
  final text = value.text;
  final selection = value.selection;
  var end = selection.end;
  // A selection ending at the start of a line does not include that line.
  if (end > selection.start && text.codeUnitAt(end - 1) == 0x0A) end--;

  final starts = <int>[];
  final indents = <int>[];
  var blankOnly = true;
  var allCommented = true;
  var minIndent = -1;
  var start = _lineStart(text, selection.start);
  while (true) {
    var lineEnd = text.indexOf('\n', start);
    if (lineEnd < 0) lineEnd = text.length;
    var indent = start;
    while (indent < lineEnd &&
        (text.codeUnitAt(indent) == 0x20 || text.codeUnitAt(indent) == 0x09)) {
      indent++;
    }
    final blank =
        indent == lineEnd ||
        (indent + 1 == lineEnd && text.codeUnitAt(indent) == 0x0D);
    starts.add(start);
    indents.add(blank ? -1 : indent);
    if (!blank) {
      blankOnly = false;
      if (minIndent < 0 || indent - start < minIndent) {
        minIndent = indent - start;
      }
      if (!_commentedBy(text, indent, marker, result)) allCommented = false;
    }
    if (lineEnd >= end || lineEnd >= text.length) break;
    start = lineEnd + 1;
  }

  final edits = <_Change>[];
  if (blankOnly) {
    // Only blank lines: comment them at their own indentation.
    for (final start in starts) {
      var indent = start;
      while (indent < text.length &&
          (text.codeUnitAt(indent) == 0x20 ||
              text.codeUnitAt(indent) == 0x09)) {
        indent++;
      }
      edits.add(_Change(indent, indent, '$marker '));
    }
  } else if (allCommented) {
    for (final indent in indents) {
      if (indent < 0) continue;
      var cut = indent + marker.length;
      if (cut < text.length && text.codeUnitAt(cut) == 0x20) cut++;
      edits.add(_Change(indent, cut, ''));
    }
  } else {
    for (var i = 0; i < starts.length; i++) {
      if (indents[i] < 0) continue;
      final at = starts[i] + minIndent;
      edits.add(_Change(at, at, '$marker '));
    }
  }
  return _applyChanges(value, edits);
}

/// Whether the line whose text starts at [indent] was commented out with
/// [marker].
///
/// Doc comments (`///`, `//!`, R's `#'`) and shebangs (`#!`) start with the
/// marker too, but they are content: toggling comments them out like any
/// other line instead of breaking them.
bool _commentedBy(
  String text,
  int indent,
  String marker,
  HighlightResult? result,
) {
  if (!text.startsWith(marker, indent)) return false;
  final after = indent + marker.length;
  if (after < text.length && text.codeUnitAt(after) == 0x21) return false;
  if (result == null) {
    // Without highlighting, `///` is told apart from `//` by its repeated
    // last character.
    return after >= text.length ||
        text.codeUnitAt(after) != marker.codeUnitAt(marker.length - 1);
  }
  final stack = result.tokenStack(result.tokenAt(indent));
  if (!result.scopes.isComment(stack)) return false;
  for (final scope in result.scopes.scopesOf(stack)) {
    if (scope == Scopes.commentDoc ||
        scope.startsWith('${Scopes.commentDoc}.')) {
      return false;
    }
  }
  return true;
}

TextEditingValue _toggleBlockComment(
  TextEditingValue value,
  (String, String) block,
  HighlightResult? result,
) {
  final (open, close) = block;
  final text = value.text;
  final selection = value.selection;
  var start = selection.start;
  var end = selection.end;
  if (selection.isCollapsed) {
    start = _lineStart(text, start);
    end = text.indexOf('\n', start);
    if (end < 0) end = text.length;
  }
  // Ignore surrounding whitespace.
  while (start < end && _isSpace(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _isSpace(text.codeUnitAt(end - 1))) {
    end--;
  }
  final wrapped =
      end - start >= open.length + close.length &&
      text.startsWith(open, start) &&
      text.startsWith(close, end - close.length) &&
      (result == null || result.isCommentAt(start));
  if (wrapped) {
    var openEnd = start + open.length;
    var closeStart = end - close.length;
    if (openEnd < closeStart && text.codeUnitAt(openEnd) == 0x20) openEnd++;
    if (closeStart > openEnd && text.codeUnitAt(closeStart - 1) == 0x20) {
      closeStart--;
    }
    return _applyChanges(value, [
      _Change(start, openEnd, ''),
      _Change(closeStart, end, ''),
    ]);
  }
  return _applyChanges(value, [
    _Change(start, start, '$open '),
    _Change(end, end, ' $close'),
  ], inner: true);
}

/// Replaces `[start, end)` with [text].
final class _Change {
  const _Change(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}

/// Applies [changes], in increasing order and not overlapping, as one edit,
/// carrying the selection along.
///
/// A selection grows to take in text inserted at its edges, unless [inner],
/// when it keeps to the text it had.
TextEditingValue _applyChanges(
  TextEditingValue value,
  List<_Change> changes, {
  bool inner = false,
}) {
  final text = value.text;
  final out = StringBuffer();
  var position = 0;
  for (final change in changes) {
    out
      ..write(text.substring(position, change.start))
      ..write(change.text);
    position = change.end;
  }
  out.write(text.substring(position));

  // Maps an old offset to the new text. Text inserted exactly at the
  // offset lands after it when [after], before it otherwise.
  int map(int offset, bool after) {
    var delta = 0;
    for (final change in changes) {
      if (offset < change.start || (offset == change.start && !after)) break;
      if (offset < change.end) {
        return change.start + delta + (after ? change.text.length : 0);
      }
      delta += change.text.length - (change.end - change.start);
    }
    return offset + delta;
  }

  final selection = value.selection;
  final TextSelection mapped;
  if (selection.isCollapsed) {
    mapped = TextSelection.collapsed(offset: map(selection.baseOffset, true));
  } else {
    final forward = selection.baseOffset <= selection.extentOffset;
    final start = map(selection.start, inner);
    final end = map(selection.end, !inner);
    mapped = TextSelection(
      baseOffset: forward ? start : end,
      extentOffset: forward ? end : start,
    );
  }
  return TextEditingValue(text: out.toString(), selection: mapped);
}

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

/// Offset where the line containing [offset] starts.
int _lineStart(String text, int offset) =>
    offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
