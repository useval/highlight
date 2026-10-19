import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';

HighlightResult _dart(String code) =>
    const Highlighter().highlight(code, language: dartLanguage);

void main() {
  group('EditingSyntax', () {
    test('every built-in language declares its syntax', () {
      for (final language in allLanguages) {
        expect(language.editing, isNotNull, reason: language.name);
      }
    });

    test('declared comment markers highlight as comments', () {
      for (final language in allLanguages) {
        final syntax = EditingSyntax.of(language);
        final line = syntax.lineComment;
        if (line != null) {
          final result = const Highlighter().highlight(
            '$line note\n',
            language: language,
          );
          expect(result.isCommentAt(0), isTrue, reason: language.name);
        }
        final block = syntax.blockComment;
        if (block != null) {
          final code = '${block.$1} note ${block.$2}\n';
          final result = const Highlighter().highlight(
            code,
            language: language,
          );
          expect(result.isCommentAt(0), isTrue, reason: language.name);
          expect(
            result.isCommentAt(code.length - 2),
            isTrue,
            reason: language.name,
          );
        }
      }
    });

    test('is derived from comment and string blocks', () {
      const grammar = Grammar(
        name: 'custom',
        rules: [
          LineComment('///', scope: Scopes.commentDoc),
          LineComment('--'),
          BlockComment('{-', '-}'),
          QuotedString('"'),
          QuotedString('"""'),
        ],
      );
      final syntax = EditingSyntax.of(grammar);
      expect(syntax.lineComment, '--');
      expect(syntax.blockComment, ('{-', '-}'));
      expect(syntax.quotes, '"');
      expect(syntax.brackets, '()[]{}');
      expect(identical(EditingSyntax.of(grammar), syntax), isTrue);
    });

    test('defaults to common quotes when a grammar declares none', () {
      const grammar = Grammar(name: 'bare', rules: []);
      final syntax = EditingSyntax.of(grammar);
      expect(syntax.lineComment, isNull);
      expect(syntax.blockComment, isNull);
      expect(syntax.quotes, '"\'');
    });

    test('extend keeps or replaces the syntax', () {
      expect(dartLanguage.extend().editing, EditingSyntax.cStyle);
      expect(
        dartLanguage.withKeywords(remove: ['var']).editing,
        EditingSyntax.cStyle,
      );
      const hash = EditingSyntax(lineComment: '#');
      expect(dartLanguage.extend(editing: hash).editing, hash);
    });

    test('closerOf pairs brackets and quotes', () {
      const syntax = EditingSyntax(quotes: '"`');
      expect(syntax.closerOf('('), ')');
      expect(syntax.closerOf('{'), '}');
      expect(syntax.closerOf('"'), '"');
      expect(syntax.closerOf('`'), '`');
      expect(syntax.closerOf("'"), isNull);
      expect(syntax.closerOf(')'), isNull);
    });
  });

  group('string and comment context', () {
    test('characters in strings and comments', () {
      const code = 'f("a(") // b(';
      final result = _dart(code);
      expect(result.isStringOrCommentAt(0), isFalse);
      expect(result.isStringOrCommentAt(code.indexOf('a')), isTrue);
      expect(result.isCommentAt(code.indexOf('a')), isFalse);
      expect(result.isCommentAt(code.indexOf('b')), isTrue);
      expect(result.isStringOrCommentAt(-1), isFalse);
      expect(result.isStringOrCommentAt(code.length), isFalse);
    });

    test('interpolations are code again', () {
      const code = r'"x ${f(1)} y"';
      final result = _dart(code);
      expect(result.isStringOrCommentAt(code.indexOf('x')), isTrue);
      expect(result.isStringOrCommentAt(code.indexOf('(')), isFalse);
      expect(result.isStringOrCommentAt(code.indexOf('y')), isTrue);
    });

    test('caret positions between characters', () {
      const code = 'a = "bc" + d; // e\nx = "open\n/* c */\n';
      final result = _dart(code);
      bool inside(String marker, [int shift = 0]) =>
          result.isInsideStringOrComment(code.indexOf(marker) + shift);

      expect(inside('a'), isFalse);
      expect(inside('bc'), isTrue); // just after the opening quote
      expect(inside('c"'), isTrue);
      expect(inside('" +'), isTrue); // before the closing quote
      expect(inside(' + d'), isFalse); // just after the closing quote
      expect(inside('e\n', 1), isTrue); // end of a line comment
      expect(inside('open\n', 4), isTrue); // end of an unterminated string
      expect(inside('*/\n', 2), isFalse); // after a closed block comment
      expect(result.isInsideStringOrComment(0), isFalse);
    });

    test('a block comment still open at the end of a line', () {
      const code = 'a /* b\nc */';
      final result = _dart(code);
      expect(result.isInsideStringOrComment(code.indexOf('\n')), isTrue);
    });

    test('a string closed at the end of a line', () {
      final result = const Highlighter().highlight(
        "x = 'a'\n",
        language: pythonLanguage,
      );
      expect(result.isInsideStringOrComment(7), isFalse);
      expect(result.isInsideStringOrComment(6), isTrue);
    });
  });

  group('matchingBracket', () {
    test('matches forwards and backwards', () {
      const code = 'f(a[1], {b: (c)})';
      final result = _dart(code);
      expect(result.matchingBracket(1), code.length - 1);
      expect(result.matchingBracket(code.length - 1), 1);
      expect(result.matchingBracket(3), code.indexOf(']'));
      expect(result.matchingBracket(code.indexOf(']')), 3);
      expect(result.matchingBracket(code.indexOf('{')), code.indexOf('}'));
      expect(result.matchingBracket(code.indexOf('(c')), code.indexOf(')}'));
    });

    test('skips brackets in strings and comments', () {
      const code = 'f(")", // )\n  x)';
      final result = _dart(code);
      expect(result.matchingBracket(1), code.length - 1);
      expect(result.matchingBracket(code.length - 1), 1);
    });

    test('brackets in strings and comments match nothing', () {
      const code = 'f(")")';
      final result = _dart(code);
      expect(result.matchingBracket(3), -1);
    });

    test('unbalanced, non-bracket and out-of-range offsets', () {
      final result = _dart('f((x)');
      expect(result.matchingBracket(1), -1);
      expect(result.matchingBracket(0), -1);
      expect(result.matchingBracket(-1), -1);
      expect(result.matchingBracket(99), -1);
    });

    test('custom pairs and a search limit', () {
      final result = _dart('<a<b>>');
      expect(result.matchingBracket(0), -1);
      expect(result.matchingBracket(0, brackets: '<>'), 5);
      expect(result.matchingBracket(5, brackets: '<>'), 0);
      expect(result.matchingBracket(0, brackets: '<>', limit: 3), -1);
      expect(result.matchingBracket(5, brackets: '<>', limit: 3), -1);
    });

    test('works across lines in a large document', () {
      final body = List.filled(5000, '  x = "}";').join('\n');
      final code = 'f() {\n$body\n}';
      final result = _dart(code);
      expect(result.matchingBracket(4), code.length - 1);
      expect(result.matchingBracket(code.length - 1), 4);
    });
  });
}
