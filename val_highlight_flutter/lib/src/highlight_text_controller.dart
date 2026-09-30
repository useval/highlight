import 'package:flutter/widgets.dart';
import 'package:val_highlight/val_highlight.dart';

import 'code_styles.dart';
import 'code_theme.dart';
import 'spans.dart';

/// A [TextEditingController] that highlights its text as you type.
///
/// ```dart
/// final controller = HighlightTextController(language: dartLanguage);
/// TextField(controller: controller, maxLines: null, style: monospace);
/// ```
///
/// Edits are highlighted incrementally: only the lines an edit can affect
/// are re-scanned, so typing stays fast in large documents.
class HighlightTextController extends TextEditingController {
  /// Creates a controller for [language].
  ///
  /// [theme] defaults to [CodeTheme] or the built-in theme for the app's
  /// brightness. [registry] resolves languages named inside the text, such
  /// as Markdown code fences.
  HighlightTextController({
    super.text,
    required Grammar language,
    ValTheme? theme,
    LanguageRegistry? registry,
  }) : _theme = theme,
       _document = IncrementalHighlighter(
         language: language,
         text: text ?? '',
         registry: registry,
       );

  final IncrementalHighlighter _document;
  ValTheme? _theme;
  CodeStyles? _styles;
  ({int first, int last})? _window;

  /// Zero-based lines to colour, or `null` for all of them.
  ///
  /// Laying out a text field with many thousands of styled runs is slow, so
  /// for large documents only the visible lines, plus a margin, need
  /// colours. `CodeField` sets this automatically as you scroll.
  ({int first, int last})? get window => _window;
  set window(({int first, int last})? value) {
    if (value == _window) return;
    _window = value;
    notifyListeners();
  }

  /// The language of the text. Setting it re-highlights everything.
  Grammar get language => _document.language;
  set language(Grammar value) {
    if (identical(value, _document.language)) return;
    _document.language = value;
    notifyListeners();
  }

  /// The theme, or `null` to follow the app.
  ValTheme? get theme => _theme;
  set theme(ValTheme? value) {
    if (identical(value, _theme)) return;
    _theme = value;
    notifyListeners();
  }

  /// The highlight result for the current text.
  HighlightResult get result => _document.update(text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final result = _document.update(text);
    final theme = CodeTheme.resolve(context, _theme);
    if (_styles?.theme != theme) _styles = CodeStyles(theme);
    final styles = _styles!;
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final window = _window;
    TextRange? styled;
    if (window != null && result.lineCount > 0) {
      final last = window.last.clamp(0, result.lineCount - 1);
      final first = window.first.clamp(0, last);
      styled = TextRange(
        start: result.lineStart(first),
        end: last + 1 < result.lineCount
            ? result.lineStart(last + 1)
            : result.code.length,
      );
    }
    return TextSpan(
      style: styles.rootStyle(style ?? const TextStyle()),
      children: exactSpans(
        result,
        styles,
        composing: composing,
        styled: styled,
      ),
    );
  }
}
