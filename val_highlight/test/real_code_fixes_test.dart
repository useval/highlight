// Regressions found by running the grammars over real code
// (tool/corpus_sweep.dart). Each test is a minimal form of a real file that
// used to be misread.
import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';

import 'helpers.dart';

void main() {
  group('engine', () {
    test('end can reference begin captures', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          RegionRule(
            begin: r'<(\w+)>',
            end: r'</\1>',
            scope: 'block',
            endReferencesBegin: true,
          ),
        ],
      );
      final r = highlightChecked('<a> </b> x </a> after', grammar);
      expect(scopeAt(r, ' x '), 'block');
      expect(scopeAt(r, 'after'), isNull);
    });

    test('special characters in the referenced text are literal', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          RegionRule(
            begin: r'\[(.)\]',
            end: r'\1\1',
            scope: 'block',
            endReferencesBegin: true,
          ),
        ],
      );
      final r = highlightChecked('[.] ab .. after', grammar);
      expect(scopeAt(r, 'ab'), 'block');
      expect(scopeAt(r, 'after'), isNull);
    });

    test('an embedding region closes from inside a nested region', () {
      const inner = Grammar(
        name: 'inner',
        rules: [RegionRule(begin: '"', end: '"', scope: 'string')],
      );
      const outer = Grammar(
        name: 'outer',
        rules: [RegionRule(begin: '<', end: '>', scope: 'embed', embed: inner)],
      );
      // The inner string never closes, but `>` still ends the embed.
      final r = highlightChecked('<a "b> after', outer);
      expect(scopeAt(r, 'b'), 'string');
      expect(scopeAt(r, 'after'), isNull);
    });
  });

  test('names after a dot are members, not keywords', () {
    final js = highlightChecked(
      'Array.from(x); a.set = 1; this.#items.push(1);',
      javascriptLanguage,
    );
    expect(scopeAt(js, 'from'), Scopes.function);
    expect(scopeAt(js, 'set ='), isNull);
    expect(scopeAt(js, 'push'), Scopes.function);

    final dart = highlightChecked(
      'dialog.show(); map.get; x..add(1);',
      dartLanguage,
    );
    expect(scopeAt(dart, 'show'), Scopes.function);
    expect(scopeAt(dart, 'get;'), isNull);
    expect(scopeAt(dart, 'add'), Scopes.function);

    final py = highlightChecked(
      'm = re.match(p, s)\nx.if_ = 1\n',
      pythonLanguage,
    );
    expect(scopeAt(py, 'match'), Scopes.function);
  });

  test('css: media query conditions', () {
    final r = highlightChecked(
      '@media screen and (max-width: 600px) { a { top: 0 } }',
      cssLanguage,
    );
    expect(scopeAt(r, 'max-width'), Scopes.property);
    expect(scopeAt(r, '600px'), Scopes.number);
  });

  test('bash: assignment targets are variables', () {
    final r = highlightChecked('A=1\nB+=2 && [[ a == b ]]\n', bashLanguage);
    expect(scopeAt(r, 'A='), Scopes.variable);
    expect(scopeAt(r, 'B+'), Scopes.variable);
    expect(scopeAt(r, 'a =='), isNull);
  });

  test('markdown: a fence closes even if its code leaves a string open', () {
    final r = Highlighter(registry: allLanguagesRegistry()).highlight(
      '```bash\nA\n   `-- D\n```\n\n# After\n',
      language: markdownLanguage,
    );
    expectCoverage(r);
    expect(scopeAt(r, '# After'), Scopes.heading);
  });

  test('markdown: backticks in the info string mean it is not a fence', () {
    final r = highlightChecked(
      '    ```adb shell screenrecord```\n\n# After\n',
      markdownLanguage,
    );
    expect(scopeAt(r, '# After'), Scopes.heading);
  });

  test('markdown: a longer fence is not closed by a shorter one', () {
    final r = highlightChecked(
      '````\n```\nstill code\n````\n# After\n',
      markdownLanguage,
    );
    expect(scopeAt(r, 'still code'), Scopes.code);
    expect(scopeAt(r, '# After'), Scopes.heading);
  });

  test('python: # inside an f-string format spec is not a comment', () {
    final r = highlightChecked(
      "x = f'<{type(self).__name__} at {id(self):#x}>'\ny = 1\n",
      pythonLanguage,
    );
    expect(scopeAt(r, "'<"), Scopes.string);
    expect(scopesAt(r, 'id('), [
      Scopes.string,
      Scopes.interpolation,
      Scopes.function,
    ]);
    expect(scopeAt(r, '1\n'), Scopes.number);
  });

  test('scala and kotlin: extra quotes end a triple-quoted string', () {
    for (final language in [scalaLanguage, kotlinLanguage]) {
      final r = highlightChecked(
        'val a = """"quoted""""\nval b = 1\n',
        language,
      );
      expect(scopeAt(r, 'quoted'), Scopes.string, reason: language.name);
      expect(scopeAt(r, 'val b'), Scopes.keyword, reason: language.name);
    }
  });

  test('ocaml: brackets inside attribute strings', () {
    final r = highlightChecked(
      'val sign : t -> int\n'
      '[@@deprecated "[since 2016-01] Replace [sign] with [robust_sign]"]\n'
      'val next : t\n',
      ocamlLanguage,
    );
    expect(scopeAt(r, '[@@deprecated'), Scopes.meta);
    expect(scopeAt(r, 'Replace'), Scopes.string);
    expect(scopeAt(r, 'val next'), Scopes.keyword);
  });

  test('python: raw f-strings keep backslashes literal', () {
    final r = highlightChecked("a = fr'\\{{', '\\{'\nb = 1\n", pythonLanguage);
    expect(scopeAt(r, '{{'), Scopes.stringEscape);
    expect(scopeAt(r, '1\n'), Scopes.number);
  });

  test('html: </script> ends a script even inside a comment', () {
    final r = highlightChecked(
      '<script>\nx = 1; //--></script>\n<p>after</p>',
      htmlLanguage,
    );
    expect(scopeAt(r, '//--'), Scopes.comment);
    expect(scopesAt(r, 'script>\n<p'), [Scopes.tag]);
    expect(scopeAt(r, 'p>after'), Scopes.tag);
  });

  test('markdown: an inline code span cannot run past a closing fence', () {
    final r = Highlighter(registry: allLanguagesRegistry()).highlight(
      '```markdown\na `b\n```\n\n# After `c`\n',
      language: markdownLanguage,
    );
    expectCoverage(r);
    expect(scopeAt(r, '# After'), Scopes.heading);
  });

  test('python: backslash-quote does not end a raw string', () {
    final r = highlightChecked("a = r'\\'\\'x'\nb = 1\n", pythonLanguage);
    expect(scopeAt(r, 'x'), Scopes.string);
    expect(scopeAt(r, '1\n'), Scopes.number);
  });

  test('yaml: quotes inside a plain value do not start strings', () {
    final r = highlightChecked(
      "description: Flutter's WKWebView control.\n"
      "if: steps.frozen == 'false'\n"
      'run: echo "hello"\n'
      'next: "real string"\n',
      yamlLanguage,
    );
    expect(scopeAt(r, 's WKWebView'), isNull);
    expect(scopeAt(r, 'next'), Scopes.property);
    expect(scopeAt(r, '"real string"'), Scopes.string);
  });

  test('yaml: block scalars run until indentation returns', () {
    final r = highlightChecked(
      'steps:\n'
      '  - name: Check\n'
      '    run: |\n'
      "      ruby -e '\n"
      '        puts "hi"\n'
      '\n'
      "      '\n"
      '  - name: Next\n'
      'top: >-\n'
      '  folded text\n'
      'after: 1\n',
      yamlLanguage,
    );
    expect(scopeAt(r, 'run'), Scopes.property);
    expect(scopeAt(r, '|'), Scopes.operator);
    expect(scopeAt(r, "ruby -e '"), Scopes.string);
    expect(scopeAt(r, 'Next'), isNull);
    expect(scopesAt(r, 'name: Next'), [Scopes.property]);
    expect(scopeAt(r, 'folded'), Scopes.string);
    expect(scopeAt(r, 'after'), Scopes.property);
    expect(scopeAt(r, '1\n'), Scopes.number);
  });

  group('bash', () {
    test('backslash-escaped quote outside quotes', () {
      final r = highlightChecked(
        "sed -e 's,^\",'\\', -e 's,x,y,'\necho done\n",
        bashLanguage,
      );
      expect(scopeAt(r, 'echo'), Scopes.function);
    });

    test('heredocs, with and without expansion', () {
      final r = highlightChecked(
        "cat <<EOF > out.txt\nHello \$USER, it's \"here\"\nEOF\n"
        "cat <<'END'\nraw \$HOME '\nEND\necho after\n",
        bashLanguage,
      );
      expect(scopeAt(r, 'EOF >'), Scopes.meta);
      expect(scopeAt(r, 'Hello'), Scopes.string);
      expect(scopesAt(r, r'$USER'), [Scopes.variable]);
      expect(scopeAt(r, 'raw'), Scopes.string);
      expect(scopeAt(r, r'$HOME'), Scopes.string);
      expect(scopeAt(r, 'echo after'), Scopes.function);
    });

    test('<<< here-strings are not heredocs', () {
      final r = highlightChecked('grep x <<< "\$v"\necho y\n', bashLanguage);
      expect(scopeAt(r, 'echo y'), Scopes.function);
    });
  });

  test('sql: dollar-quoted bodies with tags', () {
    final r = highlightChecked(
      r"CREATE FUNCTION f() AS $body$ SELECT 'x$$y'; $body$ LANGUAGE sql;",
      sqlLanguage,
    );
    expect(scopeAt(r, " SELECT 'x"), Scopes.string);
    expect(scopeAt(r, 'LANGUAGE'), isNull);
  });
}
