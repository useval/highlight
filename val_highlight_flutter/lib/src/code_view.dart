import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show FlutterError, FlutterErrorDetails, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:val_highlight/languages/generic.dart';
import 'package:val_highlight/languages/plaintext.dart';
import 'package:val_highlight/val_highlight.dart';

import 'code_highlighter.dart';
import 'code_styles.dart';
import 'code_theme.dart';
import 'spans.dart';

/// Builds the gutter cell for [line]. Return a fixed-width widget so rows
/// stay aligned.
typedef CodeGutterBuilder =
    Widget Function(BuildContext context, CodeLineDetails line);

/// Wraps the row for [line]. [child] is the default row.
typedef CodeLineBuilder =
    Widget Function(BuildContext context, CodeLineDetails line, Widget child);

/// One line of a [CodeView], as passed to [CodeView.gutterBuilder] and
/// [CodeView.lineBuilder].
@immutable
final class CodeLineDetails {
  /// Creates the details of a line.
  const CodeLineDetails({
    required this.line,
    required this.lineNumber,
    required this.highlighted,
  });

  /// Zero-based index of the line in the code.
  final int line;

  /// Number shown in the gutter: [line] plus [CodeView.firstLineNumber].
  final int lineNumber;

  /// Whether [lineNumber] is in [CodeView.highlightedLines].
  final bool highlighted;

  @override
  bool operator ==(Object other) =>
      other is CodeLineDetails &&
      other.line == line &&
      other.lineNumber == lineNumber &&
      other.highlighted == highlighted;

  @override
  int get hashCode => Object.hash(line, lineNumber, highlighted);

  @override
  String toString() =>
      'CodeLineDetails(line: $line, lineNumber: $lineNumber, '
      'highlighted: $highlighted)';
}

/// Builds the span for one [token], replacing the default. [style] is the
/// token's themed style (`null` for plain text). Return a [TextSpan] with
/// `text: token.text` so the text stays unchanged.
typedef CodeSpanBuilder =
    InlineSpan Function(
      BuildContext context,
      CodeToken token,
      TextStyle? style,
    );

/// One piece of highlighted code, as passed to [CodeView.onTokenTap] and
/// [CodeView.spanBuilder]. Pieces never cross a line break.
@immutable
final class CodeToken {
  /// Creates a token.
  const CodeToken({
    required this.text,
    required this.start,
    required this.end,
    required this.line,
    required this.scopes,
  });

  /// The token's source text.
  final String text;

  /// Start offset in the code.
  final int start;

  /// End offset (exclusive) in the code.
  final int end;

  /// Zero-based line.
  final int line;

  /// Scopes from the outermost to the innermost; empty for plain text.
  final List<String> scopes;

  /// Innermost scope, or `null` for plain text.
  String? get scope => scopes.isEmpty ? null : scopes.last;

  @override
  String toString() => 'CodeToken(${scopes.join(' > ')}: "$text")';
}

/// Shows syntax-highlighted code.
///
/// ```dart
/// CodeView(source, language: dartLanguage)
/// ```
///
/// Everything else is optional. The theme follows the brightness (see
/// [CodeTheme] for app-wide defaults). Results are cached, and inputs above
/// [CodeHighlighter.isolateThreshold] are highlighted in a background
/// isolate while plain text is shown.
///
/// Code is always laid out left to right, even in a right-to-left app. To
/// let people select and copy it, put it — or the page around it — inside
/// a `SelectionArea`; line numbers are never selected.
///
/// Short code renders as one text block. Code with more than
/// [virtualizeAbove] lines, placed where its height is bounded, renders one
/// row per line in a lazy list, so only visible lines are laid out.
class CodeView extends StatefulWidget {
  /// Creates a code view.
  const CodeView(
    this.code, {
    super.key,
    this.language,
    this.detectLanguages = const [],
    this.fallbackLanguage = genericLanguage,
    this.theme,
    this.style,
    this.padding,
    this.lineNumbers,
    this.firstLineNumber = 1,
    this.highlightedLines = const {},
    this.highlightColor,
    this.wrap = false,
    this.highlighter,
    this.virtualizeAbove = 1000,
    this.gutterBuilder,
    this.lineBuilder,
    this.header,
    this.scrollController,
    this.onTokenTap,
    this.spanBuilder,
  });

  /// Source code to show.
  final String code;

  /// Language of [code]. When `null`, the language is detected among
  /// [detectLanguages]; if that fails, [fallbackLanguage] is used.
  final Grammar? language;

  /// Language used when [language] is `null` and detection finds nothing.
  /// Defaults to `genericLanguage`, which highlights what most languages
  /// share. Use `plainTextLanguage` for no highlighting.
  final Grammar fallbackLanguage;

  /// Candidates for detection when [language] is `null`.
  final List<Grammar> detectLanguages;

  /// Color theme. Defaults to [CodeTheme] or the built-in light/dark theme.
  final ValTheme? theme;

  /// Text style merged over the default code style
  /// ([CodeTheme.textStyleOf]).
  final TextStyle? style;

  /// Padding inside the background. Defaults to [CodeThemeData.padding],
  /// or 16 on every side.
  final EdgeInsetsGeometry? padding;

  /// Whether to show line numbers. Defaults to
  /// [CodeThemeData.lineNumbers], or `false`.
  final bool? lineNumbers;

  /// Number shown for the first line.
  final int firstLineNumber;

  /// Line numbers (as shown in the gutter) to highlight.
  final Set<int> highlightedLines;

  /// Background for [highlightedLines].
  final Color? highlightColor;

  /// Whether long lines wrap. When `false`, code scrolls horizontally.
  final bool wrap;

  /// Highlighter to use. Defaults to [CodeHighlighter.shared].
  final CodeHighlighter? highlighter;

  /// Line count above which rows are built lazily.
  final int virtualizeAbove;

  /// Custom gutter cells.
  final CodeGutterBuilder? gutterBuilder;

  /// Custom rows. Setting this always renders one row per line.
  final CodeLineBuilder? lineBuilder;

  /// A widget shown above the code, such as a title or copy button.
  final Widget? header;

  /// Vertical scroll controller for the lazy list. Only attached while the
  /// code is laid out lazily (see [virtualizeAbove]).
  final ScrollController? scrollController;

  /// Called when a token is tapped, such as an identifier to jump to.
  /// Whitespace is not tappable.
  final ValueChanged<CodeToken>? onTokenTap;

  /// Builds each token's span, for hover effects, links, tooltips or
  /// custom styling. Takes priority over [onTokenTap].
  final CodeSpanBuilder? spanBuilder;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  HighlightResult? _result;
  HighlightResult? _plain;
  Grammar? _detected;
  int _generation = 0;
  CodeStyles? _styles;

  // Memoized document spans for the block layout.
  List<TextSpan>? _spans;
  HighlightResult? _spansResult;
  CodeStyles? _spansStyles;

  // Memoized spans per line for the row layout, so lines scrolled back into
  // view are not rebuilt.
  List<List<TextSpan>?>? _lineCache;
  HighlightResult? _lineCacheResult;
  CodeStyles? _lineCacheStyles;

  List<TextSpan> _cachedLineSpans(_Layout layout, int line) {
    if (!identical(_lineCacheResult, layout.result) ||
        !identical(_lineCacheStyles, layout.styles)) {
      _lineCache = List<List<TextSpan>?>.filled(layout.result.lineCount, null);
      _lineCacheResult = layout.result;
      _lineCacheStyles = layout.styles;
    }
    return _lineCache![line] ??= lineSpans(layout.result, line, layout.styles);
  }

  @override
  void initState() {
    super.initState();
    _highlight();
  }

  @override
  void didUpdateWidget(CodeView old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code ||
        !identical(old.language, widget.language) ||
        !identical(old.fallbackLanguage, widget.fallbackLanguage) ||
        !identical(old.highlighter, widget.highlighter) ||
        !_sameList(old.detectLanguages, widget.detectLanguages)) {
      _highlight();
    }
  }

  static bool _sameList(List<Grammar> a, List<Grammar> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  void _highlight() {
    final code = widget.code;
    _plain = null;
    _detected = widget.language == null && widget.detectLanguages.isNotEmpty
        ? const LanguageDetector()
              .detect(code, widget.detectLanguages)
              ?.language
        : null;
    final language = widget.language ?? _detected ?? widget.fallbackLanguage;
    final highlighter = widget.highlighter ?? CodeHighlighter.shared;
    final generation = ++_generation;
    if (!highlighter.usesIsolate(code)) {
      _result = highlighter.highlightSync(code, language);
      return;
    }
    _result = highlighter.cached(code, language);
    if (_result != null) return;
    highlighter
        .highlight(code, language)
        .then(
          (result) {
            if (mounted && generation == _generation) {
              setState(() => _result = result);
            }
          },
          onError: (Object error, StackTrace stack) {
            // The code stays plain; report the failure like a build error.
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'val_highlight_flutter',
                context: ErrorDescription(
                  'while highlighting code for CodeView',
                ),
              ),
            );
          },
        );
  }

  HighlightResult get _current =>
      _result ??
      (_plain ??= const Highlighter().highlight(
        widget.code,
        language: plainTextLanguage,
      ));

  @override
  Widget build(BuildContext context) {
    final theme = CodeTheme.resolve(context, widget.theme);
    if (_styles?.theme != theme) _styles = CodeStyles(theme);
    final styles = _styles!;
    final codeTheme = CodeTheme.maybeOf(context);
    final base = styles.rootStyle(CodeTheme.textStyleOf(context, widget.style));
    final layout = _Layout(
      result: _current,
      styles: styles,
      base: base,
      strut: StrutStyle.fromTextStyle(base, forceStrutHeight: true),
      lineHeight:
          MediaQuery.textScalerOf(context).scale(base.fontSize ?? 14) *
          (base.height ?? 1.2),
      lineNumbers: widget.lineNumbers ?? codeTheme?.lineNumbers ?? false,
      highlightColor:
          widget.highlightColor ??
          (theme.dark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
      gutterStyle: base.copyWith(
        color: (base.color ?? const Color(0xFF888888)).withValues(alpha: 0.45),
      ),
    );

    final background = theme.root.background;
    return LayoutBuilder(
      builder: (context, outer) {
        Widget content = Padding(
          padding:
              widget.padding ?? codeTheme?.padding ?? const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) => _body(layout, constraints),
            ),
          ),
        );
        if (widget.header != null) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.header!,
              if (outer.hasBoundedHeight) Flexible(child: content) else content,
            ],
          );
        }
        return ColoredBox(
          color: Color(background ?? 0x00000000),
          child: content,
        );
      },
    );
  }

  Widget _body(_Layout layout, BoxConstraints constraints) {
    final lineCount = layout.result.lineCount;
    final virtual =
        constraints.hasBoundedHeight && lineCount > widget.virtualizeAbove;
    final rows =
        virtual ||
        widget.lineBuilder != null ||
        (widget.wrap &&
            (layout.lineNumbers || widget.highlightedLines.isNotEmpty));
    return rows
        ? _rows(layout, constraints, virtual)
        : _block(layout, constraints);
  }

  /// One text block for the whole document, with a separate gutter column.
  Widget _block(_Layout layout, BoxConstraints constraints) {
    final result = layout.result;
    Widget code;
    if (_interactive) {
      code = _CodeText(
        base: layout.base,
        strut: layout.strut,
        softWrap: widget.wrap,
        spans: (context, recognizers) => [
          for (var line = 0; line < result.lineCount; line++) ...[
            if (line > 0) const TextSpan(text: '\n'),
            ..._interactiveSpans(context, layout, line, recognizers),
          ],
        ],
      );
    } else {
      if (!identical(_spansResult, result) ||
          !identical(_spansStyles, layout.styles)) {
        _spans = documentSpans(result, layout.styles);
        _spansResult = result;
        _spansStyles = layout.styles;
      }
      code = Text.rich(
        TextSpan(style: layout.base, children: _spans),
        strutStyle: layout.strut,
        softWrap: widget.wrap,
      );
    }
    if (!widget.wrap) {
      code = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: code,
      );
    }
    if (widget.highlightedLines.isNotEmpty) {
      code = Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LineBands(
                lines: [
                  for (final number in widget.highlightedLines)
                    number - widget.firstLineNumber,
                ],
                lineHeight: layout.lineHeight,
                color: layout.highlightColor,
              ),
            ),
          ),
          code,
        ],
      );
    }
    if (!layout.lineNumbers) return code;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gutter(
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var line = 0; line < result.lineCount; line++)
                _gutterCell(layout, line),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (constraints.hasBoundedWidth) Expanded(child: code) else code,
      ],
    );
  }

  /// One row per line, lazily built when [virtual].
  Widget _rows(_Layout layout, BoxConstraints constraints, bool virtual) {
    final result = layout.result;
    final gutterWidth = layout.lineNumbers && widget.gutterBuilder == null
        ? _measure(
            '${widget.firstLineNumber + result.lineCount - 1}',
            layout.gutterStyle,
            layout.strut,
          )
        : null;

    Widget row(BuildContext context, int line) {
      final number = widget.firstLineNumber + line;
      Widget text = _interactive
          ? _CodeText(
              base: layout.base,
              strut: layout.strut,
              softWrap: widget.wrap,
              spans: (context, recognizers) =>
                  _interactiveSpans(context, layout, line, recognizers),
            )
          : Text.rich(
              TextSpan(
                style: layout.base,
                children: _cachedLineSpans(layout, line),
              ),
              strutStyle: layout.strut,
              softWrap: widget.wrap,
            );
      if (widget.wrap) text = Expanded(child: text);
      Widget child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (layout.lineNumbers) ...[
            _gutter(
              SizedBox(width: gutterWidth, child: _gutterCell(layout, line)),
            ),
            const SizedBox(width: 16),
          ],
          text,
        ],
      );
      if (widget.highlightedLines.contains(number)) {
        child = ColoredBox(color: layout.highlightColor, child: child);
      }
      final builder = widget.lineBuilder;
      return builder == null ? child : builder(context, _details(line), child);
    }

    Widget list;
    if (virtual) {
      list = ListView.builder(
        controller: widget.scrollController,
        itemCount: result.lineCount,
        itemExtent: widget.wrap ? null : layout.lineHeight,
        itemBuilder: row,
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var line = 0; line < result.lineCount; line++)
            Builder(builder: (context) => row(context, line)),
        ],
      );
    }
    if (widget.wrap) return list;

    // Without wrapping, every row gets the width of the longest line so the
    // whole list scrolls horizontally as one.
    final contentWidth =
        _longestLineWidth(layout) +
        (gutterWidth == null ? 0 : gutterWidth + 16) +
        2;
    final width = math.max(
      contentWidth,
      constraints.hasBoundedWidth ? constraints.maxWidth : 0.0,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: virtual ? constraints.maxHeight : null,
        child: list,
      ),
    );
  }

  bool get _interactive =>
      widget.onTokenTap != null || widget.spanBuilder != null;

  /// Spans for [line] through [CodeView.spanBuilder], or with tap
  /// recognizers for [CodeView.onTokenTap]. Recognizers are added to
  /// [recognizers] so their owner can dispose them.
  List<InlineSpan> _interactiveSpans(
    BuildContext context,
    _Layout layout,
    int line,
    List<GestureRecognizer> recognizers,
  ) {
    final result = layout.result;
    final code = result.code;
    final table = result.scopes;
    final spans = <InlineSpan>[];
    final builder = widget.spanBuilder;
    final onTap = widget.onTokenTap;
    result.forEachSegment(line, (start, end, stack) {
      final style = stack == 0 ? null : layout.styles.of(table, stack);
      final token = CodeToken(
        text: code.substring(start, end),
        start: start,
        end: end,
        line: line,
        scopes: table.scopesOf(stack),
      );
      if (builder != null) {
        spans.add(builder(context, token, style));
      } else if (onTap != null && token.text.trim().isNotEmpty) {
        final recognizer = TapGestureRecognizer()..onTap = () => onTap(token);
        recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: token.text,
            style: style,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
      } else {
        spans.add(TextSpan(text: token.text, style: style));
      }
    });
    return spans;
  }

  CodeLineDetails _details(int line) {
    final number = widget.firstLineNumber + line;
    return CodeLineDetails(
      line: line,
      lineNumber: number,
      highlighted: widget.highlightedLines.contains(number),
    );
  }

  /// Line numbers are not part of the code: never selected, and not read
  /// out by screen readers.
  static Widget _gutter(Widget child) =>
      SelectionContainer.disabled(child: ExcludeSemantics(child: child));

  Widget _gutterCell(_Layout layout, int line) {
    final number = widget.firstLineNumber + line;
    final builder = widget.gutterBuilder;
    if (builder != null) return builder(context, _details(line));
    // Line numbers never wrap, even if the gutter is a pixel too narrow.
    return Text(
      '$number',
      style: layout.gutterStyle,
      strutStyle: layout.strut,
      textAlign: TextAlign.right,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.visible,
    );
  }

  double _longestLineWidth(_Layout layout) {
    final result = layout.result;
    var longest = 0;
    var longestLength = -1;
    for (var line = 0; line < result.lineCount; line++) {
      final length = result.lineEnd(line) - result.lineStart(line);
      if (length > longestLength) {
        longest = line;
        longestLength = length;
      }
    }
    return _measure(
      result.code.substring(result.lineStart(longest), result.lineEnd(longest)),
      layout.base,
      layout.strut,
    );
  }

  /// Width of [text] as it will render: [style] over the ambient
  /// [DefaultTextStyle], at the ambient text scale, with the line strut.
  double _measure(String text, TextStyle style, StrutStyle strut) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      strutStyle: strut,
    )..layout();
    final width = painter.width;
    painter.dispose();
    // One extra pixel absorbs rounding between measuring and painting.
    return width.ceilToDouble() + 1;
  }
}

class _Layout {
  const _Layout({
    required this.result,
    required this.styles,
    required this.base,
    required this.strut,
    required this.lineHeight,
    required this.lineNumbers,
    required this.highlightColor,
    required this.gutterStyle,
  });

  final HighlightResult result;
  final CodeStyles styles;
  final TextStyle base;
  final StrutStyle strut;
  final double lineHeight;
  final bool lineNumbers;
  final Color highlightColor;
  final TextStyle gutterStyle;
}

/// Paints full-width bands behind highlighted lines of a text block.
class _LineBands extends CustomPainter {
  _LineBands({
    required this.lines,
    required this.lineHeight,
    required this.color,
  });

  final List<int> lines;
  final double lineHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final line in lines) {
      if (line < 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(0, line * lineHeight, size.width, lineHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LineBands old) =>
      old.lineHeight != lineHeight ||
      old.color != color ||
      !listEquals(old.lines, lines);
}

/// Rich text whose spans may carry gesture recognizers, which it owns and
/// disposes when rebuilt or removed.
class _CodeText extends StatefulWidget {
  const _CodeText({
    required this.base,
    required this.strut,
    required this.softWrap,
    required this.spans,
  });

  final TextStyle base;
  final StrutStyle strut;
  final bool softWrap;
  final List<InlineSpan> Function(
    BuildContext context,
    List<GestureRecognizer> recognizers,
  )
  spans;

  @override
  State<_CodeText> createState() => _CodeTextState();
}

class _CodeTextState extends State<_CodeText> {
  List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers = [];
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final recognizers = <GestureRecognizer>[];
    final children = widget.spans(context, recognizers);
    _recognizers = recognizers;
    return Text.rich(
      TextSpan(style: widget.base, children: children),
      strutStyle: widget.strut,
      softWrap: widget.softWrap,
    );
  }
}
