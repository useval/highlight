// Pure-Dart tour of val_highlight. Run: dart run example/main.dart
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/light.dart';

void main() {
  const code = r'''
void main() {
  final name = 'world';
  print('Hello, $name!'); // greet
}
''';

  // 1. Highlight and render HTML with CSS classes.
  const highlighter = Highlighter();
  final result = highlighter.highlight(code, language: dartLanguage);
  print(result.toHtml(const HtmlRenderer(wrap: true)));

  // 2. The stylesheet for those classes.
  print(lightTheme.toCss());

  // 3. Or inline styles, with no stylesheet needed.
  print(result.toHtml(const HtmlRenderer(theme: lightTheme)));

  // 4. Raw tokens, for any other renderer.
  for (final token in result.tokens.take(6)) {
    print(token);
  }

  // 5. Customize: extend a grammar with your own rule.
  final withTodo = dartLanguage.extend(
    rules: [const TokenRule(r'\bTODO\b', scope: 'todo')],
  );
  final todo = highlighter.highlight('// TODO: ship it', language: withTodo);
  print(todo.tokens.map((t) => '${t.scope}: ${t.text}').join(' | '));

  // 6. Detect a language.
  final detected = const LanguageDetector().detect(
    'def f(x):\n    return x * 2\n',
    allLanguages,
  );
  print('Detected: ${detected?.language.name}');

  // 7. Markdown code fences need a registry to find their language.
  final markdown = Highlighter(registry: allLanguagesRegistry()).highlight(
    '# Title\n\n```json\n{"ok": true}\n```\n',
    language: markdownLanguage,
  );
  print(markdown.toHtml());

  // 8. Incremental updates for editors.
  final document = IncrementalHighlighter(language: dartLanguage, text: code);
  document.update(code.replaceFirst('world', 'there'));
  print('Re-scanned ${document.lastRescannedLines} line(s) after an edit.');
}
