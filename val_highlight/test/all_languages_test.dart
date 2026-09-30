import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';

import 'helpers.dart';

void main() {
  test('every built-in grammar compiles', () {
    for (final language in allLanguages) {
      language.validate();
    }
  });

  test('every grammar covers arbitrary input', () {
    const noise = 'a"b\'c`d\${e}f/*g<h>i#j\n--k[l](m)\\n{o}:p;q@r\$s~t|u&v';
    for (final language in allLanguages) {
      for (var cut = 0; cut <= noise.length; cut += 7) {
        highlightChecked(noise.substring(0, cut), language);
      }
    }
  });

  test('registry finds every language by name and extension', () {
    final registry = allLanguagesRegistry();
    for (final language in allLanguages) {
      expect(registry.lookup(language.name), same(language));
      for (final extension in language.fileExtensions) {
        expect(registry.forFileName('file.$extension'), same(language));
      }
    }
  });

  group('javascript', () {
    test('keywords, strings, templates, regex and numbers', () {
      final r = highlightChecked(
        r'const re = /a\/b[/]+/gi; let s = `x ${a + {b: 1}.b} y`; 10n; foo(1);',
        javascriptLanguage,
      );
      expect(scopeAt(r, 'const'), Scopes.keyword);
      expect(scopeAt(r, '/a'), Scopes.regexp);
      expect(scopeAt(r, '`x'), Scopes.string);
      expect(scopesAt(r, 'b: 1'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, ' y`'), Scopes.string);
      expect(scopeAt(r, '10n'), Scopes.number);
      expect(scopeAt(r, 'foo'), Scopes.function);
    });

    test('division is not a regex', () {
      final r = highlightChecked('a = b / c / d;', javascriptLanguage);
      expect(scoped(r).where((t) => t.$2 == Scopes.regexp), isEmpty);
    });
  });

  test('typescript adds type keywords', () {
    final r = highlightChecked(
      'interface A { x: string; readonly y: number }',
      typescriptLanguage,
    );
    expect(scopeAt(r, 'interface'), Scopes.keyword);
    expect(scopeAt(r, 'string'), Scopes.typeBuiltin);
    expect(scopeAt(r, 'readonly'), Scopes.keyword);
    expect(scopeAt(r, 'A '), Scopes.type);
  });

  group('python', () {
    test('defs, decorators, f-strings, raw strings, builtins', () {
      final r = highlightChecked(
        '@cache\ndef f(self, x=None):\n'
        '    return f"{x!r:>{w}} {{lit}}" + r"\\d" + b"\\n"\n',
        pythonLanguage,
      );
      expect(scopeAt(r, '@cache'), Scopes.meta);
      expect(scopeAt(r, 'def'), Scopes.keyword);
      expect(scopeAt(r, 'f('), Scopes.function);
      expect(scopeAt(r, 'self'), Scopes.variableLanguage);
      expect(scopeAt(r, 'None'), Scopes.literal);
      expect(scopesAt(r, 'x!r'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, '{{'), Scopes.stringEscape);
      expect(scopeAt(r, r'\d'), Scopes.string);
      expect(scopeAt(r, r'\n'), Scopes.stringEscape);
    });

    test('docstrings span lines', () {
      final r = highlightChecked('"""a\nb"""\nx = 1', pythonLanguage);
      expect(scopeAt(r, 'b"'), Scopes.string);
      expect(scopeAt(r, '1'), Scopes.number);
    });
  });

  test('bash', () {
    final r = highlightChecked(
      '#!/bin/bash\n# note\nif [ -f "\$HOME/x" ]; then echo \$(ls -la) \${N}; fi',
      bashLanguage,
    );
    expect(scopeAt(r, '#!'), Scopes.meta);
    expect(scopeAt(r, '# note'), Scopes.comment);
    expect(scopeAt(r, 'if'), Scopes.keyword);
    expect(scopeAt(r, '-f'), Scopes.attribute);
    expect(scopesAt(r, r'$HOME'), [Scopes.string, Scopes.variable]);
    expect(scopeAt(r, 'echo'), Scopes.function);
    expect(scopesAt(r, 'ls'), [Scopes.interpolation]);
    expect(scopeAt(r, r'${N}'), Scopes.variable);
  });

  test('yaml', () {
    final r = highlightChecked(
      'key: value # c\nlist:\n  - name: "q\\n"\n    on: true\n    n: 1.5\n'
      'anchor: &a x\nref: *a\n',
      yamlLanguage,
    );
    expect(scopeAt(r, 'key'), Scopes.property);
    expect(scopeAt(r, 'value'), isNull);
    expect(scopeAt(r, '# c'), Scopes.comment);
    expect(scopeAt(r, 'name'), Scopes.property);
    expect(scopeAt(r, r'\n'), Scopes.stringEscape);
    expect(scopeAt(r, 'true'), Scopes.literal);
    expect(scopeAt(r, '1.5'), Scopes.number);
    expect(scopeAt(r, '&a'), Scopes.variable);
    expect(scopeAt(r, '*a'), Scopes.variable);
  });

  test('css', () {
    final r = highlightChecked(
      '.btn:hover, #id > a { color: #fff; margin: 0 1.5em !important; '
      'background: url(x.png); --gap: var(--x); }\n'
      '@media (max-width: 600px) { .a { top: 0 } }',
      cssLanguage,
    );
    expect(scopeAt(r, '.btn'), Scopes.type);
    expect(scopeAt(r, ':hover'), Scopes.keyword);
    expect(scopeAt(r, '#id'), Scopes.meta);
    expect(scopeAt(r, 'a {'), Scopes.tag);
    expect(scopeAt(r, 'color'), Scopes.property);
    expect(scopeAt(r, '#fff'), Scopes.number);
    expect(scopeAt(r, '1.5em'), Scopes.number);
    expect(scopeAt(r, '!important'), Scopes.keyword);
    expect(scopeAt(r, 'x.png'), Scopes.string);
    expect(scopeAt(r, '--gap'), Scopes.property);
    expect(scopeAt(r, 'var'), Scopes.function);
    expect(scopeAt(r, '@media'), Scopes.keyword);
    expect(scopeAt(r, 'top'), Scopes.property);
  });

  test('sql', () {
    final r = highlightChecked(
      "SELECT id, count(*) FROM users WHERE name = 'o''k' AND age > 18 "
      '-- c\n',
      sqlLanguage,
    );
    expect(scopeAt(r, 'SELECT'), Scopes.keyword);
    expect(scopeAt(r, 'count'), Scopes.function);
    expect(scopeAt(r, "''"), Scopes.stringEscape);
    expect(scopeAt(r, '18'), Scopes.number);
    expect(scopeAt(r, '-- c'), Scopes.comment);
  });

  test('xml', () {
    final r = highlightChecked(
      '<?xml version="1.0"?>\n<!-- c --><a b="x &amp; y"><![CDATA[<z>]]></a>',
      xmlLanguage,
    );
    expect(scopeAt(r, '<?xml'), Scopes.meta);
    expect(scopeAt(r, ' c '), Scopes.comment);
    expect(scopeAt(r, 'a b'), Scopes.tag);
    expect(scopeAt(r, 'b='), Scopes.attribute);
    expect(scopeAt(r, '&amp;'), Scopes.stringEscape);
    expect(scopeAt(r, '<z>'), Scopes.string);
  });

  group('html embeds css and javascript', () {
    test('script and style content use the embedded grammars', () {
      final r = highlightChecked(
        '<div class="a"><script type="module">const x = "</div>";</script>'
        '<style>.a { color: red }</style><p>after</p></div>',
        htmlLanguage,
      );
      expect(scopeAt(r, 'div'), Scopes.tag);
      expect(scopeAt(r, 'class'), Scopes.attribute);
      expect(scopeAt(r, 'type'), Scopes.attribute);
      expect(scopeAt(r, 'const'), Scopes.keyword);
      expect(scopeAt(r, '"</div>"'), Scopes.string);
      expect(scopeAt(r, 'color'), Scopes.property);
      expect(scopeAt(r, 'p>'), Scopes.tag);
      expect(scopeAt(r, 'after'), isNull);
    });

    test('empty script element', () {
      final r = highlightChecked(
        '<script src="a.js"></script><b>x</b>',
        htmlLanguage,
      );
      expect(scopeAt(r, 'src'), Scopes.attribute);
      expect(scopeAt(r, 'b>'), Scopes.tag);
    });
  });

  group('markdown', () {
    const doc =
        '# Title\n\nSome **bold**, *em* and `code` with [a link](http://x).\n\n'
        '```dart\nfinal x = 1;\n```\n\n```unknown\nplain\n```\n> quote\n- item\n';

    test('inline and block syntax', () {
      final r = highlightChecked(doc, markdownLanguage);
      expect(scopeAt(r, '# Title'), Scopes.heading);
      expect(scopeAt(r, '**bold**'), Scopes.strong);
      expect(scopeAt(r, '*em*'), Scopes.emphasis);
      expect(scopeAt(r, '`code`'), Scopes.code);
      expect(scopeAt(r, '[a link]'), Scopes.link);
      expect(scopeAt(r, '> quote'), Scopes.quote);
      expect(scopeAt(r, '- item'), Scopes.punctuation);
    });

    test('fences use the registry, its fallback, else plain code', () {
      final highlighter = Highlighter(registry: allLanguagesRegistry());
      final r = highlighter.highlight(doc, language: markdownLanguage);
      expectCoverage(r);
      expect(scopeAt(r, '```dart'), Scopes.code);
      expect(scopeAt(r, 'final'), Scopes.keyword);
      // An unknown fence language falls back to the generic grammar, where
      // `plain` is an ordinary word.
      expect(scopeAt(r, 'plain'), isNull);

      final noFallback = Highlighter(
        registry: LanguageRegistry(allLanguages),
      ).highlight(doc, language: markdownLanguage);
      expect(scopeAt(noFallback, 'plain'), Scopes.code);

      final noRegistry = highlightChecked(doc, markdownLanguage);
      expect(scopeAt(noRegistry, 'final'), Scopes.code);
    });
  });

  test('diff', () {
    final r = highlightChecked(
      'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@ ctx\n-old\n+new\n',
      diffLanguage,
    );
    expect(scopeAt(r, 'diff --git'), Scopes.meta);
    expect(scopeAt(r, '@@ -1'), Scopes.heading);
    expect(scopeAt(r, '-old'), Scopes.deletion);
    expect(scopeAt(r, '+new'), Scopes.addition);
  });
}
