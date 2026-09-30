import 'package:test/test.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';

void main() {
  const highlighter = Highlighter();

  group('HtmlRenderer', () {
    test('classes include every scope level and nest correctly', () {
      const grammar = Grammar(
        name: 'x',
        rules: [
          RegionRule(
            begin: '"',
            end: '"',
            scope: 'string',
            rules: [TokenRule(r'\\.', scope: 'string.escape')],
          ),
        ],
      );
      final html = highlighter.toHtml(r'a "b\n" c', language: grammar);
      expect(
        html,
        'a <span class="vh-string">"b'
        r'<span class="vh-string vh-string-escape">\n</span>"</span> c',
      );
    });

    test('escapes html in code', () {
      const grammar = Grammar(name: 'x', rules: []);
      expect(
        highlighter.toHtml('<a & b>', language: grammar),
        '&lt;a &amp; b&gt;',
      );
    });

    test('wrap and inline theme styles', () {
      final html = highlighter.toHtml(
        'null',
        language: dartLanguage,
        renderer: const HtmlRenderer(theme: lightTheme, wrap: true),
      );
      expect(
        html,
        '<pre style="color:#2b2f36;background-color:#fafafb;"><code>'
        '<span style="color:#0b61b8;">null</span></code></pre>',
      );
    });

    test('closes spans when the scope path changes', () {
      final html = highlighter
          .highlight(r'"$a" 1', language: dartLanguage)
          .toHtml();
      final opens = '<span'.allMatches(html).length;
      final closes = '</span>'.allMatches(html).length;
      expect(opens, closes);
    });
  });

  group('ValTheme', () {
    test('lookup cascades from specific to general', () {
      const theme = ValTheme(
        name: 't',
        styles: {'title': Style(color: 1), 'title.function': Style(color: 2)},
      );
      expect(theme.lookup('title.function.call')?.color, 2);
      expect(theme.lookup('title.class')?.color, 1);
      expect(theme.lookup('other'), isNull);
    });

    test('resolve inherits from parent scopes and root', () {
      final result = highlighter.highlight(r'"${x}"', language: dartLanguage);
      final styles = darkTheme.resolve(result.scopes);
      // `${`, `x` and `}` share a stack, so they merge into one token.
      final token = result.tokens.firstWhere((t) => t.text == r'${x}');
      final style = styles[token.stack];
      expect(style.color, darkTheme.styles['interpolation']!.color);
      expect(style.background, darkTheme.root.background);
    });

    test('extend overrides single scopes and merges root', () {
      final theme = lightTheme.extend(
        root: const Style(background: 0xFF000000),
        styles: {Scopes.keyword: const Style(bold: true)},
      );
      expect(theme.lookup(Scopes.keyword), const Style(bold: true));
      expect(theme.lookup(Scopes.string), lightTheme.lookup(Scopes.string));
      expect(theme.root.color, lightTheme.root.color);
      expect(theme.root.background, 0xFF000000);
    });

    test('toCss orders general scopes before specific ones', () {
      const theme = ValTheme(
        name: 't',
        root: Style(color: 0xFF000000),
        styles: {
          'a.b': Style(color: 0x80FF0000, bold: true),
          'a': Style(italic: true),
        },
      );
      expect(
        theme.toCss(),
        '.vh{color:#000000;}\n'
        '.vh .vh-a{font-style:italic;}\n'
        '.vh .vh-a-b{color:rgba(255,0,0,0.502);font-weight:bold;}\n',
      );
    });
  });
}
