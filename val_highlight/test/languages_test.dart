import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/languages/json.dart';

import 'helpers.dart';

void main() {
  test('built-in grammars compile', () {
    for (final grammar in [dartLanguage, jsonLanguage]) {
      grammar.validate();
    }
  });

  group('dart', () {
    HighlightResult hl(String code) => highlightChecked(code, dartLanguage);

    test('keywords, literals, builtins, types and functions', () {
      final r = hl('final List<Foo> x = compute(null, this);');
      expect(scopeAt(r, 'final'), Scopes.keyword);
      expect(scopeAt(r, 'List'), Scopes.typeBuiltin);
      expect(scopeAt(r, 'Foo'), Scopes.type);
      expect(scopeAt(r, 'x '), isNull);
      expect(scopeAt(r, 'compute'), Scopes.function);
      expect(scopeAt(r, 'null'), Scopes.literal);
      expect(scopeAt(r, 'this'), Scopes.variableLanguage);
    });

    test('generic function call', () {
      final r = hl('parse<int>(s)');
      expect(scopeAt(r, 'parse'), Scopes.function);
    });

    test('comments: line, doc and nested block', () {
      final r = hl('/// doc\n// line\n/* a /* b */ c */ tail');
      expect(scopeAt(r, 'doc'), Scopes.commentDoc);
      expect(scopeAt(r, 'line'), Scopes.comment);
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, 'tail'), isNull);
    });

    test('strings with escapes and both interpolation forms', () {
      final r = hl(r'"a\n $name ${x + {1: 2}[1]} b" + 1');
      expect(scopeAt(r, r'\n'), Scopes.stringEscape);
      expect(scopeAt(r, r'$name'), Scopes.interpolation);
      expect(scopesAt(r, '1:'), [
        Scopes.string,
        Scopes.interpolation,
        Scopes.number,
      ]);
      expect(scopeAt(r, ' b'), Scopes.string);
      expect(scopeAt(r, '+ 1'), Scopes.operator);
    });

    test('raw and triple-quoted strings', () {
      final r = hl("r'\$x \\n' '''multi\nline \$y''' after");
      expect(scopeAt(r, r'$x'), Scopes.string);
      expect(scopeAt(r, 'line'), Scopes.string);
      expect(scopeAt(r, r'$y'), Scopes.interpolation);
      expect(scopeAt(r, 'after'), isNull);
    });

    test('unterminated single-line string stops at end of line', () {
      final r = hl('"open\nvar x;');
      expect(scopeAt(r, 'var'), Scopes.keyword);
    });

    test('numbers', () {
      final r = hl('0xFF 1_000 3.14 1e-9 .5 x1');
      for (final n in ['0xFF', '1_000', '3.14', '1e-9', '.5']) {
        expect(scopeAt(r, n), Scopes.number, reason: n);
      }
      expect(scopeAt(r, 'x1'), isNull);
    });

    test('annotations', () {
      final r = hl('@override\n@pragma.vm void f() {}');
      expect(scopeAt(r, '@override'), Scopes.meta);
      expect(scopeAt(r, '@pragma.vm'), Scopes.meta);
    });
  });

  group('json', () {
    test('keys, strings, numbers, literals, escapes, comments', () {
      final r = highlightChecked(
        '{"key": "va\\"l", "n": -1.5e3, "ok": true, "z": null} // c',
        jsonLanguage,
      );
      expect(scopeAt(r, '"key"'), Scopes.property);
      expect(scopeAt(r, 'va'), Scopes.string);
      expect(scopeAt(r, r'\"'), Scopes.stringEscape);
      expect(scopeAt(r, '-1.5e3'), Scopes.number);
      expect(scopeAt(r, 'true'), Scopes.literal);
      expect(scopeAt(r, 'null'), Scopes.literal);
      expect(scopeAt(r, '// c'), Scopes.comment);
      expect(scopeAt(r, '{'), Scopes.punctuation);
    });
  });
}
