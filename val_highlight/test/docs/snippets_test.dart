// The code samples on the docs' engine pages (docs/ at the repository root),
// and the results those pages say they give. A change that makes a page
// wrong fails here; fix the page in the same change.
import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';

List<String> _tokens(HighlightResult result) => [
  for (final token in result.tokens)
    '${token.scopes.join(' > ')}: "${token.text}"',
];

void main() {
  group('docs/engine/highlighting.mdx', () {
    test('tokens and their scope stacks', () {
      const source = r"var s = 'Hi ${name.length}!';";
      final result = const Highlighter().highlight(
        source,
        language: dartLanguage,
      );
      expect(_tokens(result), [
        'keyword: "var"',
        ': " s "',
        'operator: "="',
        ': " "',
        'string: "\'Hi "',
        r'string > interpolation: "${name.length}"',
        'string: "!\'"',
        ': ";"',
      ]);
    });

    test('lines', () {
      final result = const Highlighter().highlight(
        'a\r\nb\n',
        language: plainTextLanguage,
      );
      expect(result.lineCount, 3);
      expect(result.lineEnd(0), 1); // excludes \r\n
      final empty = const Highlighter().highlight('', language: dartLanguage);
      expect(empty.lineCount, 1);
    });

    test('editor queries', () {
      final result = const Highlighter().highlight(
        'f(")") + g[1]',
        language: dartLanguage,
      );
      expect(result.matchingBracket(1), 5);
      expect(result.matchingBracket(10), 12);
      expect(result.isStringOrCommentAt(3), isTrue);
      expect(result.isInsideStringOrComment(3), isTrue);
      expect(result.isInsideStringOrComment(5), isFalse);
    });

    test('highlightByName', () {
      expect(
        () => const Highlighter().highlightByName('x', name: 'dart'),
        throwsA(isA<UnknownLanguageException>()),
      );
      final highlighter = Highlighter(registry: allLanguagesRegistry());
      final result = highlighter.highlightByName('a: 1', name: 'yml');
      expect(result.language, same(yamlLanguage));
    });
  });

  group('docs/engine/html.mdx', () {
    const source = 'final n = 42; // answer';

    test('classes', () {
      final html = const Highlighter().toHtml(
        source,
        language: dartLanguage,
        renderer: const HtmlRenderer(wrap: true),
      );
      expect(
        html,
        '<pre class="vh"><code><span class="vh-keyword">final</span> n '
        '<span class="vh-operator">=</span> '
        '<span class="vh-number">42</span>; '
        '<span class="vh-comment">// answer</span></code></pre>',
      );
      expect(
        lightTheme.toCss(),
        startsWith('.vh{color:#2b2f36;background-color:#fafafb;}\n'),
      );
      expect(lightTheme.toCss(), contains('.vh .vh-keyword{color:#b0226e;}\n'));
    });

    test('inline styles', () {
      final result = const Highlighter().highlight(
        source,
        language: dartLanguage,
      );
      final html = result.toHtml(
        const HtmlRenderer(theme: lightTheme, wrap: true),
      );
      expect(
        html,
        '<pre style="color:#2b2f36;background-color:#fafafb;"><code>'
        '<span style="color:#b0226e;">final</span> n '
        '<span style="color:#5b616b;">=</span> '
        '<span style="color:#9a5b00;">42</span>; '
        '<span style="color:#687080;font-style:italic;">// answer</span>'
        '</code></pre>',
      );
    });

    test('nested scopes get a class per level', () {
      expect(
        const Highlighter().toHtml('/// Hi', language: dartLanguage),
        '<span class="vh-comment vh-comment-doc">/// Hi</span>',
      );
      expect(scopeClass('comment.doc', 'vh-'), 'vh-comment-doc');
      expect(cssColor(0x80FF0000), 'rgba(255,0,0,0.502)');
    });

    test('two themes on one page', () {
      const renderer = HtmlRenderer(rootClass: 'code-dark', wrap: true);
      final html = const Highlighter().toHtml(
        'x',
        language: dartLanguage,
        renderer: renderer,
      );
      expect(html, startsWith('<pre class="code-dark">'));
      expect(
        darkTheme.toCss(rootClass: 'code-dark'),
        startsWith('.code-dark{'),
      );
    });

    test('escaping', () {
      expect(
        const Highlighter().toHtml('<a & b>', language: plainTextLanguage),
        '&lt;a &amp; b&gt;',
      );
    });
  });

  group('docs/engine/incremental.mdx', () {
    test('an edit re-scans only what it can affect', () {
      final source = [
        for (var i = 0; i < 2000; i++) 'int f$i() => $i;',
      ].join('\n');
      final document = IncrementalHighlighter(
        language: dartLanguage,
        text: source,
      );
      expect(document.lastRescannedLines, 2000);

      final renamed = document.update(
        source.replaceFirst('f1000()', 'f1000x()'),
      );
      expect(document.lastRescannedLines, 2);
      expect(renamed, same(document.result));

      // An unclosed block comment changes every line after it.
      document.update(source.replaceFirst('int f1000', '/* int f1000'));
      expect(document.lastRescannedLines, 1001);

      // The result always equals a full highlight.
      final full = const Highlighter().highlight(
        document.result.code,
        language: dartLanguage,
      );
      expect(_tokens(document.result), _tokens(full));
    });
  });

  group('docs/engine/lookup.mdx', () {
    test('registry', () {
      final registry = allLanguagesRegistry();
      expect(registry.lookup('kt'), same(kotlinLanguage));
      expect(registry.lookup('YML'), same(yamlLanguage));
      expect(registry.lookup('something-unknown'), isNull);
      expect(registry.resolve('something-unknown'), same(genericLanguage));
      expect(registry.forFileName('lib/main.dart'), same(dartLanguage));
      expect(registry.forFileName('Dockerfile'), same(dockerfileLanguage));
      expect(registry.forFileName('build.gradle.kts'), same(kotlinLanguage));
      expect(registry.resolveFileName('notes.xyz'), same(genericLanguage));
    });

    test('a smaller registry', () {
      final registry = LanguageRegistry([
        dartLanguage,
        jsonLanguage,
        yamlLanguage,
      ], fallback: plainTextLanguage);
      registry.add(bashLanguage, aliases: ['terminal']);
      expect(registry.lookup('terminal'), same(bashLanguage));
      expect(registry.resolve('kotlin'), same(plainTextLanguage));
    });

    test('detection', () {
      const detector = LanguageDetector();
      final byContent = detector.detect(
        'def f(x):\n    return x * 2\n',
        allLanguages,
      );
      expect(byContent?.language, same(pythonLanguage));
      expect(byContent?.reason, DetectionReason.content);

      final byName = detector.detect('', allLanguages, fileName: 'src/lib.rs');
      expect(byName?.language, same(rustLanguage));
      expect(byName?.reason, DetectionReason.fileName);

      final byShebang = detector.detect(
        '#!/usr/bin/env python3\nprint(1)\n',
        allLanguages,
      );
      expect(byShebang?.language, same(pythonLanguage));
      expect(byShebang?.reason, DetectionReason.shebang);

      expect(detector.detect('hello there', allLanguages), isNull);
      expect(
        [
          for (final g in allLanguages)
            if (!g.detectable) g,
        ],
        [genericLanguage, plainTextLanguage],
      );
    });

    test('embedded languages need a registry', () {
      const markdown = '# Title\n\n```json\n{"ok": true}\n```\n';
      final plain = const Highlighter().highlight(
        markdown,
        language: markdownLanguage,
      );
      expect(_tokens(plain), contains('code: "{"ok": true}"'));
      final withRegistry = Highlighter(
        registry: allLanguagesRegistry(),
      ).highlight(markdown, language: markdownLanguage);
      expect(_tokens(withRegistry), contains('property: ""ok""'));
    });
  });

  group('docs/customize/changing-a-language.mdx', () {
    test('withKeywords', () {
      final myDart = dartLanguage.withKeywords(
        add: {
          Scopes.typeBuiltin: ['Widget', 'BuildContext'],
        },
        remove: ['get', 'set'],
      );
      final result = const Highlighter().highlight(
        'Widget get x',
        language: myDart,
      );
      expect(_tokens(result), ['type.builtin: "Widget"', ': " get x"']);
    });

    test('extend: your rules first, but the earliest match wins', () {
      final withTodos = dartLanguage.extend(
        rules: [const TokenRule(r'\bTODO\b', scope: 'todo')],
      );
      final result = const Highlighter().highlight(
        'TODO(); // TODO: ship',
        language: withTodos,
      );
      expect(_tokens(result), [
        'todo: "TODO"',
        ': "(); "',
        'comment: "// TODO: ship"',
      ]);
    });

    test('repository', () {
      expect(dartLanguage.repository.keys, contains('numbers'));
      final quiet = dartLanguage.extend(repository: {'numbers': []});
      final result = const Highlighter().highlight('x = 42', language: quiet);
      expect(_tokens(result).where((t) => t.startsWith('number')), isEmpty);
    });

    test('editing', () {
      final backticks = dartLanguage.extend(
        editing: EditingSyntax.cStyle.copyWith(quotes: '"\'`'),
      );
      expect(EditingSyntax.of(backticks).quotes, '"\'`');
    });
  });

  group('docs/customize/writing-a-grammar.mdx', () {
    const confLanguage = Grammar(
      name: 'conf',
      fileExtensions: ['conf'],
      rules: [
        LineComment(';'),
        LineComment('#', afterSpace: true),
        QuotedString('"'),
        Numbers(),
        KeywordRule({
          Scopes.literal: ['true', 'false', 'on', 'off'],
        }),
        Operators('='),
      ],
    );

    test('a grammar from building blocks', () {
      confLanguage.validate();
      final result = const Highlighter().highlight(
        'port = 8080 ; main\nname = "web#1"',
        language: confLanguage,
      );
      expect(_tokens(result), [
        ': "port "',
        'operator: "="',
        ': " "',
        'number: "8080"',
        ': " "',
        'comment: "; main"',
        ': "\nname "',
        'operator: "="',
        ': " "',
        'string: ""web#1""',
      ]);
      // Derived from the blocks: the shortest line comment, the first of
      // equals.
      expect(EditingSyntax.of(confLanguage).lineComment, ';');
      expect(EditingSyntax.of(confLanguage).quotes, '"');
    });

    test('validate reports mistakes', () {
      const broken = Grammar(name: 'broken', rules: [IncludeRule('missing')]);
      expect(broken.validate, throwsA(isA<GrammarException>()));
    });

    test('editing syntax of built-in languages', () {
      expect(EditingSyntax.of(pythonLanguage).lineComment, '#');
      expect(EditingSyntax.of(pythonLanguage).quotes, '"\'');
      expect(EditingSyntax.of(cssLanguage).lineComment, isNull);
      expect(EditingSyntax.of(cssLanguage).blockComment, ('/*', '*/'));
      expect(EditingSyntax.of(rustLanguage).quotes, '"');
      expect(EditingSyntax.of(sqlLanguage).lineComment, '--');
    });
  });

  group('docs/themes.mdx', () {
    test('extend', () {
      final mine = lightTheme.extend(
        name: 'mine',
        styles: {Scopes.keyword: const Style(color: 0xFFE8590C, bold: true)},
      );
      expect(mine.lookup(Scopes.keyword)?.bold, isTrue);
      expect(mine.lookup(Scopes.string), lightTheme.lookup(Scopes.string));
    });

    test('a dotted scope builds on its prefixes', () {
      expect(
        lightTheme.lookup('keyword.control.flow'),
        lightTheme.lookup(Scopes.keyword),
      );
    });

    test('VS Code themes', () {
      final theme = ValTheme.fromVsCodeJson('''
{
  // JSONC: comments and trailing commas are fine.
  "name": "Mine",
  "type": "dark",
  "colors": { "editor.foreground": "#dddddd", "editor.background": "#111111" },
  "tokenColors": [
    { "scope": ["keyword", "storage"], "settings": { "foreground": "#ff00ff" } },
    { "scope": "comment", "settings": { "fontStyle": "italic" } },
  ],
}''');
      expect(theme.name, 'Mine');
      expect(theme.dark, isTrue);
      expect(
        theme.root,
        const Style(color: 0xFFDDDDDD, background: 0xFF111111),
      );
      expect(theme.lookup(Scopes.keyword)?.color, 0xFFFF00FF);
      expect(theme.lookup(Scopes.comment)?.italic, isTrue);
    });
  });
  group('docs/engine/streaming.mdx', () {
    test('streaming updates re-scan only the end', () {
      final registry = allLanguagesRegistry();
      final document = IncrementalHighlighter(
        language: markdownLanguage,
        registry: registry,
      );
      const reply =
          'Here is the fix:\n\n```dart\nvoid main() {\n  print("hi");\n}\n```\n'
          '\nAnd the config:\n\n```json\n{"a": [1, 2]}\n```\n';
      final text = List.filled(40, reply).join();
      var sent = '';
      var maxRescanned = 0;
      for (var i = 0; i < text.length; i += 20) {
        sent = text.substring(0, i + 20 > text.length ? text.length : i + 20);
        document.update(sent);
        if (sent.length > 200 && document.lastRescannedLines > maxRescanned) {
          maxRescanned = document.lastRescannedLines;
        }
      }
      final full = Highlighter(
        registry: registry,
      ).highlight(text, language: markdownLanguage);
      expect(_tokens(document.result), _tokens(full));
      expect(maxRescanned, lessThan(20));
    });
  });

  group('docs/upgrading.mdx', () {
    test('1.0 forms of the changed calls', () {
      final registry = LanguageRegistry([
        dartLanguage,
        yamlLanguage,
      ], fallback: plainTextLanguage);
      expect(registry.resolve('nope'), same(plainTextLanguage));
      expect(LanguageRegistry(const []).languages, isEmpty);

      final detection = const LanguageDetector().detect(
        '',
        allLanguages,
        fileName: 'a.dart',
      );
      expect(detection?.reason == DetectionReason.fileName, isTrue);

      const blocks = <Rule>[
        Operators('+-*/%=<>!&|^~?:'),
        Operators('+-*/=', scope: Scopes.operator),
        Annotation(scope: Scopes.meta),
        Preprocessor(sigil: '%'),
        _Pragma(),
      ];
      const grammar = Grammar(name: 'blocks', rules: blocks);
      grammar.validate();

      final result = const Highlighter().highlight(
        '<a(b>',
        language: dartLanguage,
      );
      expect(result.matchingBracket(2, brackets: '()[]{}'), -1);
    });
  });

  group('docs/reference/troubleshooting.mdx', () {
    test('a registry with a fallback never throws', () {
      final highlighter = Highlighter(registry: allLanguagesRegistry());
      expect(
        highlighter.highlightByName('x', name: 'nope').language,
        same(genericLanguage),
      );
      expect(allLanguagesRegistry().lookup('nope'), isNull);
      expect(
        () => const Highlighter().highlightByName('x', name: 'dart'),
        throwsA(isA<UnknownLanguageException>()),
      );
    });

    test('validate finds grammar mistakes', () {
      const broken = Grammar(name: 'broken', rules: [TokenRule('(')]);
      expect(
        broken.validate,
        throwsA(
          isA<GrammarException>().having(
            (e) => e.toString(),
            'message',
            contains('broken'),
          ),
        ),
      );
    });
  });
}

final class _Pragma extends BlockRule {
  const _Pragma();

  @override
  List<Rule> expand() => const [TokenRule('#pragma', scope: Scopes.meta)];
}
