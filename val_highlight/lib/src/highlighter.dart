import 'engine/compiler.dart';
import 'engine/scanner.dart';
import 'engine/scope_table.dart';
import 'grammar/grammar.dart';
import 'registry.dart';
import 'render/html.dart';
import 'result.dart';

/// Highlights source code.
///
/// ```dart
/// final result = const Highlighter().highlight(code, language: dartLanguage);
/// print(result.toHtml());
/// ```
///
/// A highlighter holds no mutable state, so one instance can be shared, and
/// it is safe to use from any isolate.
final class Highlighter {
  /// Creates a highlighter.
  ///
  /// [registry] enables lookup by name and resolves languages named inside
  /// the code, such as Markdown code fences.
  const Highlighter({this.registry});

  /// Languages available by name, if any.
  final LanguageRegistry? registry;

  /// Highlights [code] with [language].
  HighlightResult highlight(String code, {required Grammar language}) {
    final compiled = CompiledGrammar.of(language);
    final table = ScopeTable();
    final out = TokenBuffer(code.length ~/ 6);
    Scanner(
      code: code,
      table: table,
      out: out,
      embeds: registry,
    ).scan(ScanFrame(compiled.root, ScopeTable.root, null), 0);
    return HighlightResult.fromBuffers(
      code: code,
      language: language,
      scopes: table,
      ends: out.ends,
      stacks: out.stacks,
      tokenCount: out.count,
    );
  }

  /// Highlights [code] with the language registered as [name] or an alias,
  /// or the registry's fallback.
  ///
  /// Throws [UnknownLanguageException] if there is no such language and no
  /// fallback.
  HighlightResult highlightByName(String code, {required String name}) {
    final language = registry?.resolve(name);
    if (language == null) throw UnknownLanguageException(name);
    return highlight(code, language: language);
  }

  /// Highlights [code] with [language] and renders it as HTML.
  String toHtml(
    String code, {
    required Grammar language,
    HtmlRenderer renderer = const HtmlRenderer(),
  }) => renderer.render(highlight(code, language: language));
}
