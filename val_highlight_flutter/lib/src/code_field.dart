import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'code_editing.dart';
import 'code_theme.dart';
import 'editor_decorations.dart';
import 'highlight_text_controller.dart';

export 'code_editing.dart' show indentText, newlineKeepingIndent, outdentLines;

/// A code editor: a multi-line [TextField] driven by a
/// [HighlightTextController], which stays fast on large documents.
///
/// ```dart
/// CodeField(controller: HighlightTextController(language: dartLanguage))
/// ```
///
/// Typing follows [editing]: Enter keeps the indentation, brackets and
/// quotes close themselves, and the bracket at the caret is matched. Keys
/// follow [shortcuts]: Tab and Shift+Tab indent and outdent, and Ctrl+/
/// (Cmd+/ on Apple platforms) toggles comments. Each key sends an [Intent]
/// ([IndentCodeIntent], [OutdentCodeIntent], [ToggleCommentIntent]); an
/// [Actions] widget above the field can override what they do.
///
/// Set [lineNumbers] for a gutter, [highlightedLines] to mark lines, and
/// [highlightCurrentLine] to mark the caret's line. These are painted from
/// the text's own layout, so wrapped lines line up.
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
    this.editing = const CodeEditing(),
    this.shortcuts,
    this.inputFormatters,
    this.lineNumbers = false,
    this.firstLineNumber = 1,
    this.gutterStyle,
    this.highlightedLines = const {},
    this.highlightColor,
    this.highlightCurrentLine = false,
    this.currentLineColor,
    this.bracketColor,
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

  /// What typing, Enter and Backspace do beyond inserting text. Use
  /// [CodeEditing.none] for a plain text field.
  final CodeEditing editing;

  /// Keys and the intents they send. Defaults to [defaultShortcuts]; pass
  /// `const {}` for none, so Tab moves focus as in other fields.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Formatters applied after the editing behaviour, such as a length
  /// limit.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether to show line numbers in a gutter.
  final bool lineNumbers;

  /// Number shown for the first line.
  final int firstLineNumber;

  /// Style of the line numbers. Defaults to the code style in a faded
  /// text color.
  final TextStyle? gutterStyle;

  /// Line numbers, as shown in the gutter, to highlight.
  final Set<int> highlightedLines;

  /// Background of [highlightedLines].
  final Color? highlightColor;

  /// Whether to highlight the line with the caret.
  final bool highlightCurrentLine;

  /// Background of the caret's line when [highlightCurrentLine] is set.
  final Color? currentLineColor;

  /// Background of a matched bracket pair, when [CodeEditing.matchBrackets]
  /// is on.
  final Color? bracketColor;

  /// The default [shortcuts]: Tab, Shift+Tab, and Ctrl+/ (Cmd+/ on macOS
  /// and iOS).
  static Map<ShortcutActivator, Intent> get defaultShortcuts {
    final apple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return {
      const SingleActivator(LogicalKeyboardKey.tab): const IndentCodeIntent(),
      const SingleActivator(LogicalKeyboardKey.tab, shift: true):
          const OutdentCodeIntent(),
      SingleActivator(LogicalKeyboardKey.slash, meta: apple, control: !apple):
          const ToggleCommentIntent(),
    };
  }

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  ScrollController? _ownScroll;
  ScrollPosition? _outer;
  bool _scheduled = false;
  late CodeEditingFormatter _formatter = _newFormatter();
  final _outerMoved = _Notifier();
  GutterDigits? _digits;
  GutterDigits? _currentDigits;
  int _digitCount = 0;

  late final Map<Type, Action<Intent>> _actions = {
    IndentCodeIntent: Action<IndentCodeIntent>.overridable(
      defaultAction: _EditAction<IndentCodeIntent>(
        this,
        (value) => indentText(value, widget.indent),
      ),
      context: context,
    ),
    OutdentCodeIntent: Action<OutdentCodeIntent>.overridable(
      defaultAction: _EditAction<OutdentCodeIntent>(
        this,
        (value) => outdentLines(value, widget.indent),
      ),
      context: context,
    ),
    ToggleCommentIntent: Action<ToggleCommentIntent>.overridable(
      defaultAction: _EditAction<ToggleCommentIntent>(
        this,
        (value) => toggleComment(
          value,
          widget.editing.syntaxFor(widget.controller.language),
          result: widget.controller.result,
        ),
      ),
      context: context,
    ),
  };

  Listenable? _repaintListenable;
  Object? _repaintController;
  Object? _repaintScroll;

  /// Everything that moves the decorations, merged once per controller
  /// and scroll controller.
  Listenable _repaint() {
    final controller = widget.controller;
    final scroll = _scroll;
    if (!identical(controller, _repaintController) ||
        !identical(scroll, _repaintScroll)) {
      _repaintController = controller;
      _repaintScroll = scroll;
      _repaintListenable = Listenable.merge([controller, scroll, _outerMoved]);
    }
    return _repaintListenable!;
  }

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  CodeEditingFormatter _newFormatter() => CodeEditingFormatter(
    controller: widget.controller,
    editing: widget.editing,
    indent: widget.indent,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void didUpdateWidget(CodeField old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _formatter = _newFormatter();
    } else {
      _formatter
        ..editing = widget.editing
        ..indent = widget.indent;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = Scrollable.maybeOf(context)?.position;
    if (!identical(outer, _outer)) {
      _outer?.removeListener(_onOuterScroll);
      _outer = outer?..addListener(_onOuterScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    _outer?.removeListener(_onOuterScroll);
    _ownScroll?.dispose();
    _outerMoved.dispose();
    _digits?.dispose();
    _currentDigits?.dispose();
    super.dispose();
  }

  void _onChanged() {
    _schedule();
    // The gutter widens when the line count gains a digit.
    if (widget.lineNumbers && _digitsFor() != _digitCount) setState(() {});
  }

  /// A font finished loading, so the text was laid out again: lay out the
  /// digits again too, and repaint the gutter where the lines now are.
  void _onFontsChanged() {
    _digits?.dispose();
    _currentDigits?.dispose();
    _digits = null;
    _currentDigits = null;
    if (mounted) setState(() {});
  }

  void _onOuterScroll() {
    _schedule();
    _outerMoved.notify();
  }

  int _digitsFor() {
    final last = widget.firstLineNumber + widget.controller.result.lineCount;
    return math.max(2, '${math.max(last - 1, 0)}'.length);
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
    final editable = _editable();
    if (editable == null || !editable.attached || !editable.hasSize) return;

    // The visible part of the text: the editable box, clipped by any
    // enclosing scroll view.
    var visible = editable.localToGlobal(Offset.zero) & editable.size;
    final viewport = _viewport();
    if (viewport != null) visible = visible.intersect(viewport);
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

  RenderEditable? _editable() => _findEditable(context.findRenderObject());

  /// The global rectangle of the enclosing scroll view, if any.
  Rect? _viewport() {
    final box = _outer?.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
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

  /// Whether a shortcut may edit the text now.
  bool get _canEdit {
    final value = widget.controller.value;
    return !widget.readOnly &&
        value.selection.isValid &&
        !value.isComposingRangeValid;
  }

  /// Applies an edit made by a shortcut, as the user's own.
  void _apply(TextEditingValue? edited) {
    if (edited == null) return;
    final changed = edited.text != widget.controller.text;
    widget.controller.value = edited;
    if (changed) widget.onChanged?.call(edited.text);
  }

  /// Enter keeps the indentation. Typed line breaks reach the formatter
  /// instead on keyboards that do not send key events.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !widget.editing.autoIndent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    if (keys.isShiftPressed ||
        keys.isControlPressed ||
        keys.isMetaPressed ||
        keys.isAltPressed ||
        !_canEdit) {
      return KeyEventResult.ignored;
    }
    _apply(
      newlineKeepingIndent(
        widget.controller.value,
        widget.indent,
        brackets: widget.editing.syntaxFor(widget.controller.language).brackets,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _schedule(requestFrame: false);
    Widget field = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: _field(context),
    );
    field = Actions(actions: _actions, child: field);
    field = Shortcuts(
      shortcuts: widget.shortcuts ?? CodeField.defaultShortcuts,
      child: field,
    );
    final decorated =
        widget.lineNumbers ||
        widget.highlightCurrentLine ||
        widget.highlightedLines.isNotEmpty ||
        widget.editing.matchBrackets;
    if (!decorated) return field;
    return _decorate(context, field);
  }

  Widget _decorate(BuildContext context, Widget field) {
    final theme = CodeTheme.resolve(context, widget.controller.theme);
    final base = CodeTheme.textStyleOf(context, widget.style);
    final foreground = theme.root.color == null
        ? base.color ?? (theme.dark ? Colors.white : Colors.black)
        : Color(theme.root.color!);

    var gutterWidth = 0.0;
    const gap = 16.0;
    const leading = 8.0;
    GutterDigits? digits;
    GutterDigits? current;
    if (widget.lineNumbers) {
      final scaler = MediaQuery.textScalerOf(context);
      final style = base
          .copyWith(color: foreground.withValues(alpha: 0.45))
          .merge(widget.gutterStyle);
      if (_digits?.style != style ||
          _digits?.textScaler != scaler ||
          widget.highlightCurrentLine != (_currentDigits != null)) {
        _digits?.dispose();
        _currentDigits?.dispose();
        _digits = GutterDigits(style, scaler);
        _currentDigits = widget.highlightCurrentLine
            ? GutterDigits(
                style.copyWith(color: style.color?.withValues(alpha: 0.9)),
                scaler,
              )
            : null;
      }
      digits = _digits;
      current = _currentDigits;
      _digitCount = _digitsFor();
      gutterWidth = leading + digits!.maxWidth * _digitCount + gap;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: EditorDecorations(
              controller: widget.controller,
              repaint: _repaint(),
              editable: _editable,
              viewport: _viewport,
              digits: digits,
              gutterWidth: gutterWidth,
              gutterGap: gap,
              firstLineNumber: widget.firstLineNumber,
              highlightedLines: widget.highlightedLines,
              highlightColor:
                  widget.highlightColor ??
                  (theme.dark
                      ? const Color(0x22FFFFFF)
                      : const Color(0x14000000)),
              currentLineColor: widget.highlightCurrentLine
                  ? widget.currentLineColor ??
                        (theme.dark
                            ? const Color(0x12FFFFFF)
                            : const Color(0x0A000000))
                  : null,
              currentNumberDigits: current,
              bracketColor: widget.editing.matchBrackets
                  ? widget.bracketColor ?? foreground.withValues(alpha: 0.18)
                  : null,
              editing: widget.editing,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: gutterWidth),
          child: field,
        ),
      ],
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
        inputFormatters: [_formatter, ...?widget.inputFormatters],
      ),
    );
  }
}

/// An edit triggered by a shortcut, enabled while the field is editable.
class _EditAction<T extends Intent> extends Action<T> {
  _EditAction(this._state, this._edit);

  final _CodeFieldState _state;
  final TextEditingValue? Function(TextEditingValue value) _edit;

  @override
  bool isEnabled(T intent) => _state.mounted && _state._canEdit;

  @override
  Object? invoke(T intent) {
    _state._apply(_edit(_state.widget.controller.value));
    return null;
  }
}

class _Notifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
