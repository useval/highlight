import 'dart:math';

import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/src/engine/first_chars.dart';
import 'package:val_highlight/src/engine/scanner.dart';
import 'package:val_highlight/val_highlight.dart';

import '../benchmark/samples.dart';

Set<String> _chars(FirstChars f) => {
  for (var c = 32; c < 127; c++)
    if (f.hasAscii(c)) String.fromCharCode(c),
};

FirstChars _first(String pattern, {bool ci = false}) =>
    firstCharsOf(pattern, caseInsensitive: ci, unicode: false);

List<(int, int, String)> _shape(HighlightResult r) => [
  for (final t in r.tokens) (t.start, t.end, t.scopes.join('>')),
];

void main() {
  group('firstCharsOf', () {
    test('literals, classes and alternation', () {
      expect(_chars(_first('ab|cd')), {'a', 'c'});
      expect(_chars(_first(r'[x-z\d]')), {
        'x',
        'y',
        'z',
        ...'0123456789'.split(''),
      });
      expect(_chars(_first(r'\\n')), {r'\'});
      expect(_first(r'"').eof, isFalse);
    });

    test('optional prefixes add the next item', () {
      expect(_chars(_first(r'-?\d')), {'-', ...'0123456789'.split('')});
      expect(_chars(_first(r'a*b')), {'a', 'b'});
      expect(_chars(_first(r'(?:ab)?c')), {'a', 'c'});
    });

    test('zero-width assertions', () {
      expect(_chars(_first(r'\bfoo')), {'f'});
      expect(_chars(_first(r'(?<![\w$])x')), {'x'});
      expect(_chars(_first(r'^#')), {'#'});
      expect(_chars(_first(r'(?=<s)')), {'<'});
      final end = _first(r"'|$");
      expect(end.hasAscii(0x0A), isTrue);
      expect(end.eof, isTrue);
      expect(_chars(end).contains("'"), isTrue);
    });

    test('case-insensitive literals include both cases', () {
      expect(_chars(_first('s', ci: true)), {'s', 'S'});
      expect(_first('s', ci: true).nonAscii, isTrue);
    });

    test('negated classes and dot include non-ASCII', () {
      final negated = _first(r'[^"]');
      expect(negated.nonAscii, isTrue);
      expect(negated.hasAscii(0x22), isFalse);
      expect(_first('.').hasAscii(0x0A), isFalse);
    });

    test('unsupported syntax falls back to any', () {
      // A pattern starting with a backreference can start anywhere.
      final any = _first(r'\1x');
      expect(any.hasAscii(0x62), isTrue);
      expect(any.eof, isTrue);
      // After a consumed character, the backreference no longer matters.
      expect(_chars(_first(r'(a)\1')), {'a'});
      // Unicode property escapes are not analysed: the whole pattern falls
      // back to "anywhere", which is slower but still correct.
      expect(_first(r'a(?=\p{L})').asciiCount, 128);
    });
  });

  group('dispatch gives exactly the combined-expression result', () {
    const highlighter = Highlighter();
    final registry = allLanguagesRegistry();

    // Combined expression, dispatch with RegExp, and dispatch with the
    // plain-Dart matchers must all agree.
    List<(int, int, String)> both(Grammar language, String code) {
      final h = Highlighter(registry: registry);
      Scanner.useDispatch = false;
      final combined = _shape(h.highlight(code, language: language));
      Scanner.useDispatch = true;
      Scanner.useFastMatchers = false;
      final dispatched = _shape(h.highlight(code, language: language));
      Scanner.useFastMatchers = true;
      final fast = _shape(h.highlight(code, language: language));
      expect(dispatched, combined, reason: '${language.name}: $code');
      expect(fast, combined, reason: 'fast ${language.name}: $code');
      return fast;
    }

    tearDown(() {
      Scanner.useDispatch = true;
      Scanner.useFastMatchers = true;
    });

    test('benchmark samples', () {
      for (final MapEntry(key: language, value: code)
          in benchmarkSamples.entries) {
        both(language, code);
      }
      expect(highlighter, isNotNull);
    });

    test('random text in every language', () {
      final random = Random(42);
      const alphabet = 'abcXYZ_09 \t\n\r"\'`\$#@/*\\<>{}[]()=:;,.-+!?&|%~^é€😀';
      for (final language in allLanguages) {
        for (var run = 0; run < 40; run++) {
          final length = random.nextInt(120);
          final code = String.fromCharCodes([
            for (var i = 0; i < length; i++)
              alphabet.codeUnitAt(random.nextInt(alphabet.length)),
          ]);
          both(language, code);
        }
      }
    });

    test('samples with random edits', () {
      final random = Random(9);
      for (final MapEntry(key: language, value: sample)
          in benchmarkSamples.entries) {
        var code = sample;
        for (var step = 0; step < 30; step++) {
          final at = random.nextInt(code.length + 1);
          final end = min(code.length, at + random.nextInt(5));
          code = code.replaceRange(
            at,
            end,
            ['"', '/*', '`', '\n', '{', "'", ''][random.nextInt(7)],
          );
          both(language, code);
        }
      }
    });
  });
}
