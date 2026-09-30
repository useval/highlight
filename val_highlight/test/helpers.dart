import 'package:test/test.dart';
import 'package:val_highlight/val_highlight.dart';

/// Highlights [code] and checks the invariants every result must hold.
HighlightResult highlightChecked(String code, Grammar language) {
  final result = const Highlighter().highlight(code, language: language);
  expectCoverage(result);
  return result;
}

/// Tokens cover the whole source, in order, with no gaps or empty tokens,
/// and neighbours never share a stack.
void expectCoverage(HighlightResult result) {
  var cursor = 0;
  for (var i = 0; i < result.tokenCount; i++) {
    expect(result.tokenStart(i), cursor, reason: 'gap before token $i');
    expect(result.tokenEnd(i), greaterThan(cursor), reason: 'empty token $i');
    if (i > 0) {
      expect(
        result.tokenStack(i),
        isNot(result.tokenStack(i - 1)),
        reason: 'unmerged neighbours at token $i',
      );
    }
    cursor = result.tokenEnd(i);
  }
  expect(cursor, result.code.length);
}

/// `(text, innermost scope)` for every scoped token.
List<(String, String)> scoped(HighlightResult result) => [
  for (final token in result.tokens)
    if (token.scope != null) (token.text, token.scope!),
];

/// Innermost scope of the token covering the first occurrence of [text].
String? scopeAt(HighlightResult result, String text) {
  final offset = result.code.indexOf(text);
  expect(offset, isNonNegative, reason: '"$text" not in source');
  for (final token in result.tokens) {
    if (token.start <= offset && offset < token.end) return token.scope;
  }
  return null;
}

/// Scopes, outermost first, of the token covering the first occurrence of
/// [text].
List<String> scopesAt(HighlightResult result, String text) {
  final offset = result.code.indexOf(text);
  for (final token in result.tokens) {
    if (token.start <= offset && offset < token.end) return token.scopes;
  }
  return const [];
}
