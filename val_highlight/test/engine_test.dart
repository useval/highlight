import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';

import 'helpers.dart';

void main() {
  group('scanner', () {
    test('empty input yields no tokens', () {
      final result = highlightChecked('', const Grammar(name: 'x', rules: []));
      expect(result.tokenCount, 0);
    });

    test('grammar with no rules yields one plain token', () {
      final result = highlightChecked(
        'plain text',
        const Grammar(name: 'x', rules: []),
      );
      expect(result.tokenCount, 1);
      expect(result.tokens.single.scope, isNull);
    });

    test('earliest match wins, then first listed rule', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          TokenRule('ab', scope: 'first'),
          TokenRule('abc', scope: 'second'),
          TokenRule('b', scope: 'third'),
        ],
      );
      final result = highlightChecked('xabc', grammar);
      expect(scoped(result), [('ab', 'first')]);
    });

    test('regions nest and restore the outer scope', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          RegionRule(
            begin: r'\(',
            end: r'\)',
            scope: 'paren',
            rules: [
              IncludeRule.self,
              TokenRule(r'\d+', scope: 'num'),
            ],
          ),
        ],
      );
      final result = highlightChecked('a(1(2)3)b', grammar);
      expect(scopesAt(result, '2'), ['paren', 'paren', 'num']);
      expect(scopesAt(result, '3'), ['paren', 'num']);
      expect(scopeAt(result, 'b'), isNull);
    });

    test('begin and end delimiters get their own scopes', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          RegionRule(
            begin: '<',
            end: '>',
            scope: 'tag',
            beginScope: 'open',
            endScope: 'close',
          ),
        ],
      );
      final result = highlightChecked('<a>', grammar);
      expect(scopesAt(result, '<'), ['tag', 'open']);
      expect(scopesAt(result, 'a'), ['tag']);
      expect(scopesAt(result, '>'), ['tag', 'close']);
    });

    test('captures scope parts of a token', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          TokenRule(
            r'(\w+)\s*=\s*(\d+)',
            scope: 'assign',
            captures: {1: 'name', 2: 'value'},
          ),
        ],
      );
      final result = highlightChecked('x = 42;', grammar);
      expect(scopesAt(result, 'x'), ['assign', 'name']);
      expect(scopesAt(result, ' = '), ['assign']);
      expect(scopesAt(result, '42'), ['assign', 'value']);
      expect(scopeAt(result, ';'), isNull);
    });

    test('backreferences still work after rules are combined', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          TokenRule(r'(a)(b)', scope: 'ab'),
          TokenRule(r'''(['"]).*?\1''', scope: 'string'),
        ],
      );
      final result = highlightChecked(''' "it's" ''', grammar);
      expect(scoped(result), [('"it\'s"', 'string')]);
    });

    test('keyword lookup, then otherwise rules, then plain', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          KeywordRule(
            {
              'keyword': ['if'],
            },
            otherwise: [TokenRule('[A-Z]\\w*', scope: 'type')],
          ),
        ],
      );
      final result = highlightChecked('if Foo bar', grammar);
      expect(scoped(result), [('if', 'keyword'), ('Foo', 'type')]);
    });

    test('case-insensitive grammars match keywords in any case', () {
      const grammar = Grammar(
        name: 'x',
        caseInsensitive: true,
        rules: [
          KeywordRule({
            'keyword': ['select'],
          }),
        ],
      );
      final result = highlightChecked('SELECT Select', grammar);
      expect(scoped(result), [('SELECT', 'keyword'), ('Select', 'keyword')]);
    });

    test('zero-width loops cannot hang the scanner', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          TokenRule(r'(?=a)', scope: 'never'),
          RegionRule(begin: r'(?=b)', end: r'(?=b)', scope: 'loop'),
        ],
      );
      final result = highlightChecked('aabb', grammar);
      expect(result.code, 'aabb');
    });

    test('unterminated region runs to the end of input', () {
      const grammar = Grammar(
        name: 'x',
        rules: [RegionRule(begin: '"', end: '"', scope: 'string')],
      );
      final result = highlightChecked('x "abc', grammar);
      expect(scopeAt(result, 'abc'), 'string');
    });
  });

  group('grammar errors', () {
    test('invalid pattern names the grammar and pattern', () {
      const grammar = Grammar(name: 'bad', rules: [TokenRule('(')]);
      expect(
        () => grammar.validate(),
        throwsA(
          isA<GrammarException>()
              .having((e) => e.grammar, 'grammar', 'bad')
              .having((e) => e.message, 'message', contains('/(/')),
        ),
      );
    });

    test('unknown include', () {
      const grammar = Grammar(name: 'bad', rules: [IncludeRule('missing')]);
      expect(() => grammar.validate(), throwsA(isA<GrammarException>()));
    });

    test('include cycle', () {
      const grammar = Grammar(
        name: 'bad',
        rules: [IncludeRule('a')],
        repository: {
          'a': [IncludeRule('b')],
          'b': [IncludeRule('a')],
        },
      );
      expect(() => grammar.validate(), throwsA(isA<GrammarException>()));
    });

    test('errors inside regions surface through compileAll', () {
      const grammar = Grammar(
        name: 'bad',
        rules: [
          RegionRule(begin: 'a', end: 'b', rules: [TokenRule('[')]),
        ],
      );
      expect(() => grammar.validate(), throwsA(isA<GrammarException>()));
    });
  });

  test('extend puts new rules first', () {
    const base = Grammar(
      name: 'x',
      rules: [TokenRule('foo', scope: 'old')],
    );
    final extended = base.extend(rules: [const TokenRule('foo', scope: 'new')]);
    final result = highlightChecked('foo', extended);
    expect(scoped(result), [('foo', 'new')]);
    expect(extended.name, 'x');
  });

  test('withKeywords adds, moves and removes words everywhere', () {
    const base = Grammar(
      name: 'x',
      rules: [
        KeywordRule({
          'keyword': ['if', 'get'],
          'literal': ['nil'],
        }),
        RegionRule(
          begin: r'\(',
          end: r'\)',
          rules: [
            KeywordRule({
              'keyword': ['if'],
            }),
          ],
        ),
      ],
    );
    final changed = base.withKeywords(
      add: {
        'type': ['Widget'],
        'keyword': ['nil'],
      },
      remove: ['get'],
    );
    final r = highlightChecked('if get nil Widget (Widget if)', changed);
    expect(scopesAt(r, 'if'), ['keyword']);
    expect(scopeAt(r, 'get'), isNull);
    expect(scopeAt(r, 'nil'), 'keyword');
    expect(scopeAt(r, 'Widget'), 'type');
    expect(scopeAt(r, 'Widget if'), 'type');
    expect(scopeAt(r, 'if)'), 'keyword');
  });

  group('LanguageRegistry', () {
    const a = Grammar(
      name: 'alpha',
      aliases: ['al'],
      fileExtensions: ['alp'],
      rules: [],
    );

    test('finds by name, alias, extra alias and file name', () {
      final registry = LanguageRegistry([])..add(a, aliases: ['A1']);
      expect(registry.lookup('ALPHA'), same(a));
      expect(registry.lookup('al'), same(a));
      expect(registry.lookup('a1'), same(a));
      expect(registry.forFileName('lib/main.ALP'), same(a));
      expect(registry.forFileName('noext'), isNull);
    });

    test('highlightByName throws for unknown names', () {
      final highlighter = Highlighter(registry: LanguageRegistry([a]));
      expect(highlighter.highlightByName('x', name: 'al').language, same(a));
      expect(
        () => highlighter.highlightByName('x', name: 'nope'),
        throwsA(isA<UnknownLanguageException>()),
      );
    });
  });
}
