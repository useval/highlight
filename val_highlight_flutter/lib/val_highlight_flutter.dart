/// Flutter widgets for `val_highlight`.
///
/// ```dart
/// import 'package:val_highlight_flutter/val_highlight_flutter.dart';
/// import 'package:val_highlight/languages/dart.dart';
///
/// CodeView(source, language: dartLanguage)
/// ```
///
/// This library re-exports `package:val_highlight/val_highlight.dart`, so
/// one import covers the core API. Languages and themes are separate
/// imports under `package:val_highlight/languages/` and `themes/`.
library;

export 'package:val_highlight/val_highlight.dart';

export 'src/code_field.dart' show CodeField;
export 'src/code_highlighter.dart' show CodeHighlighter;
export 'src/code_styles.dart' show CodeStyles, textStyleFromStyle;
export 'src/code_theme.dart' show CodeTheme;
export 'src/code_view.dart'
    show
        CodeGutterBuilder,
        CodeLineBuilder,
        CodeSpanBuilder,
        CodeToken,
        CodeView;
export 'src/highlight_text_controller.dart' show HighlightTextController;
export 'src/spans.dart' show documentSpans, exactSpans, lineSpans;
