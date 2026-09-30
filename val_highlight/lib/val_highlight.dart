/// Fast, light, fully customizable syntax highlighting in pure Dart.
///
/// ```dart
/// import 'package:val_highlight/val_highlight.dart';
/// import 'package:val_highlight/languages/dart.dart';
///
/// final html = const Highlighter().toHtml(code, language: dartLanguage);
/// ```
///
/// This is the shared core used by `val_highlight_flutter` (and later
/// `val_highlight_jaspr`). It has no Flutter dependency. Each language and
/// theme is its own import, so an app only ships what it uses. Grammar
/// authoring and raw engine access live in `advanced.dart`.
library;

export 'src/detect.dart' show Detection, LanguageDetector;
export 'src/engine/scope_table.dart' show ScopeTable;
export 'src/grammar/grammar.dart' show Grammar, GrammarException;
export 'src/grammar/scopes.dart' show Scopes;
export 'src/highlighter.dart' show Highlighter;
export 'src/incremental.dart' show IncrementalHighlighter;
export 'src/registry.dart' show LanguageRegistry, UnknownLanguageException;
export 'src/render/html.dart' show HtmlRenderer;
export 'src/result.dart' show HighlightResult, HighlightToken;
export 'src/theme/theme.dart' show Style, ValTheme, cssColor, scopeClass;
