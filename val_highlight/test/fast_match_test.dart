import 'dart:math';

import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/src/engine/compiler.dart';
import 'package:val_highlight/src/engine/fast_match.dart';
import 'package:val_highlight/val_highlight.dart';

import '../benchmark/samples.dart';

/// Every branch pattern of every state reachable in [grammar], with the
/// flags it is compiled with.
Iterable<(String, bool)> _patterns(Grammar grammar) sync* {
  final compiled = CompiledGrammar.of(grammar)..compileAll();
  final seen = Set<CompiledState>.identity();
  final pending = [compiled.root];
  while (pending.isNotEmpty) {
    final state = pending.removeLast();
    if (!seen.add(state)) continue;
    for (final alternative in state.alternatives) {
      yield (alternative.pattern, state.owner.grammar.caseInsensitive);
      final keywords = alternative.keywords;
      if (keywords != null) {
        for (final (rule, _, _) in keywords.otherwise) {
          yield (rule.pattern, state.owner.grammar.caseInsensitive);
        }
      }
      if (alternative.kind == AlternativeKind.region) {
        pending.add(state.owner.inner(alternative));
      }
    }
  }
}

void _expectSame(String pattern, bool caseInsensitive, String text) {
  final fast = compileFastPattern(
    pattern,
    caseInsensitive: caseInsensitive,
    unicode: false,
    needsCaptures: false,
  );
  if (fast == null) return;
  final regex = RegExp(
    pattern,
    multiLine: true,
    caseSensitive: !caseInsensitive,
  );
  for (var p = 0; p <= text.length; p++) {
    final expected = regex.matchAsPrefix(text, p)?.end ?? -1;
    final actual = fast.matchAt(text, p);
    if (actual != expected) {
      fail(
        '/$pattern/ at $p in ${text.substring(p, min(text.length, p + 20))}'
        ': fast=$actual regexp=$expected',
      );
    }
  }
}

int _match(String pattern, String text, [int pos = 0, bool ci = false]) =>
    compileFastPattern(
      pattern,
      caseInsensitive: ci,
      unicode: false,
      needsCaptures: false,
    )!.matchAt(text, pos);

void main() {
  group('supported syntax', () {
    test('literals, classes and quantifiers', () {
      expect(_match('ab', 'abc'), 2);
      expect(_match(r'[a-c]+', 'abcd'), 3);
      expect(_match(r'\d{2,3}', '12345'), 3);
      expect(_match(r'x*', 'y'), 0);
      expect(_match(r'a.c', 'a\nc'), -1);
    });

    test('backtracking into quantifiers and groups', () {
      expect(_match(r'\w*x', 'aaxbx!'), 5);
      expect(_match(r'(?:a|ab)c', 'abc'), 3);
      expect(_match(r'1(?:\.5)?(?![\w.])', '1.5x'), -1);
      expect(_match(r'\d+(?:\.\d+)?(?!\w)', '1.5x'), 1);
      expect(_match(r'a*?b', 'aaab'), 4);
      expect(_match(r'(</)()(\s*>)', '</ >'), 4);
      expect(_match(r'a(?:)b', 'ab'), 2);
      expect(_match(r'"(?:[^"\\\n]|\\.)*"', r'"a\"b" x'), 6);
      expect(_match(r"'(?:[^'\n]|'')*'", "'it''s' x"), 7);
      expect(_match(r'(?:ab|c)+c', 'ababcc'), 6);
      expect(_match(r'(?:ab|c)*?c', 'abc'), 3);
      final long = '"${'x' * 200000}"';
      expect(_match(r'"(?:[^"\\\n]|\\.)*"', long), long.length);
    });

    test('anchors and lookarounds', () {
      expect(_match(r'^#', 'x\n#', 2), 3);
      expect(_match(r'^#', 'x#', 1), -1);
      expect(_match(r"'|$", 'ab', 2), 2);
      expect(_match(r'(?<![\w$])x', 'ax', 1), -1);
      expect(_match(r'(?<=^|\s)#.*$', 'a #c\nd', 2), 4);
      expect(_match(r'foo(?=\s*\()', 'foo  (', 0), 3);
      expect(_match(r'\bin\b', 'int'), -1);
    });

    test('case-insensitive', () {
      expect(_match('select', 'SeLeCt', 0, true), 6);
      expect(_match('[a-c]+', 'AbC', 0, true), 3);
    });

    test('unsupported syntax is rejected', () {
      // (?:a|ab)+ could match a repetition in two ways, so it is rejected.
      for (final pattern in [r'(a)\1', r'\p{L}', r'(?<=a+)b', r'(?:a|ab)+']) {
        expect(
          compileFastPattern(
            pattern,
            caseInsensitive: false,
            unicode: false,
            needsCaptures: false,
          ),
          isNull,
          reason: pattern,
        );
      }
      expect(
        // Captures inside lookarounds are not tracked.
        compileFastPattern(
          r'(?=(a))a',
          caseInsensitive: false,
          unicode: false,
          needsCaptures: true,
        ),
        isNull,
      );
    });
  });

  group('captures', () {
    List<String?> groups(String pattern, String text) {
      final fast = compileFastPattern(
        pattern,
        caseInsensitive: false,
        unicode: false,
        needsCaptures: true,
      )!;
      expect(fast.matchAt(text, 0), greaterThanOrEqualTo(0));
      return [
        for (var g = 1; g <= fast.groupCount; g++)
          fast.groupStart(g) < 0
              ? null
              : text.substring(fast.groupStart(g), fast.groupEnd(g)),
      ];
    }

    test('match RegExp groups, including backtracking and optional groups', () {
      for (final (pattern, text) in [
        (r'(</?)([^\s/>]+)', '</div>'),
        (r'(\w+)\s*(=)\s*(\d+)?', 'x = '),
        (r'(?:(a)|(b))c', 'bc'),
        (r'(a*)(a)', 'aaa'),
        (r'(?<name>\w+):', 'key:'),
      ]) {
        final expected = RegExp(pattern).matchAsPrefix(text)!;
        expect(groups(pattern, text), [
          for (var g = 1; g <= expected.groupCount; g++) expected[g],
        ], reason: pattern);
      }
    });
  });

  group('same results as RegExp', () {
    final random = Random(3);
    const alphabet = 'abzAZ_09 .-+*/\\\t\n\r"\'`\$#@:;,=<>!?&|%~^()[]{}éß€😀 ';

    for (final language in allLanguages) {
      test(language.name, () {
        final patterns = _patterns(language).toSet();
        final texts = [
          ...benchmarkSamples.values,
          for (var n = 0; n < 12; n++)
            String.fromCharCodes([
              for (var i = random.nextInt(80); i > 0; i--)
                alphabet.codeUnitAt(random.nextInt(alphabet.length)),
            ]),
        ];
        for (final (pattern, ci) in patterns) {
          for (final text in texts) {
            _expectSame(pattern, ci, text);
          }
        }
      });
    }
  });
}
