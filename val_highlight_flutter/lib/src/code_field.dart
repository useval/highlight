import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'code_theme.dart';
import 'highlight_text_controller.dart';

/// A code editor: a multi-line [TextField] driven by a
/// [HighlightTextController], which stays fast on large documents.
///
/// ```dart
/// CodeField(controller: HighlightTextController(language: dartLanguage))
/// ```
///
/// Laying out a text field is proportional to its styled runs, so for
/// documents longer than [styleAllBelow] lines only the visible lines, plus
/// [margin] lines on each side, are coloured. The window follows scrolling
/// (of the field itself or of an enclosing scroll view) and is computed from
/// the laid-out text, so wrapped lines are handled exactly.
class CodeField extends StatefulWidget {
  /// Creates a code editor.
  const CodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.decoration = const InputDecoration(
      border: InputBorder.none,
      isCollapsed: true,
    ),
    this.expands = false,
    this.minLines,
    this.maxLines,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.scrollController,
    this.textAlignVertical,
    this.styleAllBelow = 300,
    this.margin = 150,
    this.indent = '  ',
  });

  /// The text and its highlighting.
  final HighlightTextController controller;

  /// Focus node for the field.
  final FocusNode? focusNode;

  /// Text style merged over the default code style.
  final TextStyle? style;

  /// Decoration around the field. Defaults to none.
  final InputDecoration? decoration;

  /// Whether the field fills its parent's height.
  final bool expands;

  /// Minimum visible lines.
  final int? minLines;

  /// Maximum visible lines before the field scrolls; `null` to grow.
  final int? maxLines;

  /// Whether the text is read-only.
  final bool readOnly;

  /// Whether to focus the field on first build.
  final bool autofocus;

  /// Called when the user edits the text.
  final ValueChanged<String>? onChanged;

  /// Scroll controller for the field's own scrolling.
  final ScrollController? scrollController;

  /// Vertical alignment of the text.
  final TextAlignVertical? textAlignVertical;

  /// Documents with at most this many lines are coloured in full.
  final int styleAllBelow;

  /// Lines coloured beyond each edge of the visible area.
  final int margin;

  /// Text inserted by Tab and removed by Shift+Tab, such as two spaces or
  /// `'\t'`. Enter keeps the current line's indentation, adding one level
  /// after an opening `{`, `[`, `(` or `:`.
  final String indent;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  ScrollController? _ownScroll;
  ScrollPosition? _outer;
  bool _scheduled = false;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
  }

  @override
  void didUpdateWidget(CodeField old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = Scrollable.maybeOf(context)?.position;
    if (!identical(outer, _outer)) {
      _outer?.removeListener(_schedule);
      _outer = outer?..addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _outer?.removeListener(_schedule);
    _ownScroll?.dispose();
    super.dispose();
  }

  /// Updates the styled window after the next layout. [requestFrame] asks
  /// for a frame; not needed when called during a build.
  void _schedule({bool requestFrame = true}) {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _updateWindow();
    });
    if (requestFrame) WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _scrolling = false;

  void _updateWindow() {
    final settled = !_scrolling;
    final controller = widget.controller;
    final result = controller.result;
    final lines = result.lineCount;
    if (lines <= widget.styleAllBelow) {
      controller.window = null;
      return;
    }
    final editable = _findEditable(context.findRenderObject());
    if (editable == null || !editable.attached || !editable.hasSize) return;

    // The visible part of the text: the editable box, clipped by any
    // enclosing scroll view.
    var visible = editable.localToGlobal(Offset.zero) & editable.size;
    final outerBox = _outer?.context.notificationContext?.findRenderObject();
    if (outerBox is RenderBox && outerBox.hasSize) {
      visible = visible.intersect(
        outerBox.localToGlobal(Offset.zero) & outerBox.size,
      );
    }
    if (visible.isEmpty) return;
    final top = editable
        .getPositionForPoint(visible.topLeft + const Offset(1, 1))
        .offset;
    final bottom = editable
        .getPositionForPoint(visible.bottomRight - const Offset(1, 1))
        .offset;
    final firstVisible = _lineOf(result.lineStart, lines, top);
    final lastVisible = _lineOf(result.lineStart, lines, bottom);

    // Moving the window re-lays out the whole field, so keep it while the
    // visible lines stay clear of its edges; while scrolling, only move it
    // when they get close. Once scrolling stops, re-centre it.
    final current = controller.window;
    final slack = settled ? widget.margin ~/ 2 : widget.margin ~/ 5;
    if (current != null &&
        (current.first == 0 || firstVisible - current.first >= slack) &&
        (current.last >= lines - 1 || current.last - lastVisible >= slack)) {
      return;
    }
    controller.window = (
      first: math.max(0, firstVisible - widget.margin),
      last: math.min(lines - 1, lastVisible + widget.margin),
    );
  }

  static int _lineOf(int Function(int) lineStart, int lines, int offset) {
    var low = 0;
    var high = lines - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (lineStart(mid) <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  static RenderEditable? _findEditable(RenderObject? object) {
    if (object == null) return null;
    if (object is RenderEditable) return object;
    RenderEditable? found;
    object.visitChildren((child) => found ??= _findEditable(child));
    return found;
  }

  /// Tab and Shift+Tab indent and outdent; Enter keeps the indentation.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || widget.readOnly) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final value = widget.controller.value;
    if (!value.selection.isValid || value.isComposingRangeValid) {
      return KeyEventResult.ignored;
    }
    TextEditingValue? edited;
    if (key == LogicalKeyboardKey.tab) {
      edited = keys.isShiftPressed
          ? outdentLines(value, widget.indent)
          : indentText(value, widget.indent);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (keys.isShiftPressed) return KeyEventResult.ignored;
      edited = newlineKeepingIndent(value, widget.indent);
    }
    if (edited == null) return KeyEventResult.ignored;
    widget.controller.value = edited;
    widget.onChanged?.call(edited.text);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _schedule(requestFrame: false);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: _field(context),
    );
  }

  Widget _field(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) _scrolling = true;
        if (notification is ScrollEndNotification) _scrolling = false;
        _schedule();
        return false;
      },
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: _scroll,
        style: CodeTheme.textStyleOf(context, widget.style),
        decoration: widget.decoration,
        expands: widget.expands,
        minLines: widget.minLines,
        maxLines: widget.expands ? null : widget.maxLines,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        keyboardType: TextInputType.multiline,
        textAlignVertical: widget.textAlignVertical,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
      ),
    );
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
TextEditingValue newlineKeepingIndent(TextEditingValue value, String indent) {
  final text = value.text;
  final selection = value.selection;
  final lineStart = _lineStart(text, selection.start);
  var leading = lineStart;
  while (leading < selection.start &&
      (text.codeUnitAt(leading) == 0x20 || text.codeUnitAt(leading) == 0x09)) {
    leading++;
  }
  var insert = '\n${text.substring(lineStart, leading)}';
  final before = text.substring(lineStart, selection.start).trimRight();
  if (before.endsWith('{') ||
      before.endsWith('[') ||
      before.endsWith('(') ||
      before.endsWith(':')) {
    insert += indent;
  }
  return value
      .replaced(selection, insert)
      .copyWith(
        selection: TextSelection.collapsed(
          offset: selection.start + insert.length,
        ),
      );
}

/// Offset where the line containing [offset] starts.
int _lineStart(String text, int offset) =>
    offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
