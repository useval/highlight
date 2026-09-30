import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import '../helpers.dart';

void main() {
  for (final language in [jsxLanguage, tsxLanguage]) {
    group(language.name, () {
      HighlightResult hl(String code) => highlightChecked(code, language);

      test('elements, attributes, children and matching close tags', () {
        final r = hl(
          'const a = <div className="x" id={id}>Don\'t {name} &amp;</div>;\n'
          'const b = 1;\n',
        );
        expect(scopeAt(r, 'div'), Scopes.tag);
        expect(scopeAt(r, 'className'), Scopes.attribute);
        expect(scopeAt(r, '"x"'), Scopes.string);
        expect(scopeAt(r, "Don't"), isNull);
        expect(scopeAt(r, '&amp;'), Scopes.stringEscape);
        expect(scopeAt(r, '</'), Scopes.punctuation);
        expect(scopeAt(r, 'const b'), Scopes.keyword);
        expect(scopeAt(r, '1;'), Scopes.number);
      });

      test('components, dotted names, self-closing and spread', () {
        final r = hl('x = <Modal.Dialog {...props} open />; y = 2;');
        expect(scopeAt(r, 'Modal.Dialog'), Scopes.type);
        expect(scopeAt(r, '...'), Scopes.operator);
        expect(scopeAt(r, 'open'), Scopes.attribute);
        expect(scopeAt(r, '2;'), Scopes.number);
      });

      test('fragments and nested elements', () {
        final r = hl('return <><b>a</b><i>b</i></>;\nlet z = 3;');
        expect(scopeAt(r, '<>'), Scopes.punctuation);
        expect(scopeAt(r, 'b>a'), Scopes.tag);
        expect(scopeAt(r, '</>'), Scopes.punctuation);
        expect(scopeAt(r, 'let'), Scopes.keyword);
      });

      test('a close tag must match the open tag', () {
        final r = hl('f(<div><p>a</div></p></div>)\nlet z = 3;');
        expect(scopeAt(r, 'let'), Scopes.keyword);
      });

      test('expressions hold JavaScript and nested JSX', () {
        final r = hl(
          'return (\n  <ul>\n    {items.map((i) => <li key={i}>{i > 2 ? "a" : "b"}</li>)}\n  </ul>\n);',
        );
        expect(scopeAt(r, 'map'), Scopes.function);
        expect(scopeAt(r, 'li'), Scopes.tag);
        expect(scopeAt(r, '"a"'), Scopes.string);
        expect(scopeAt(r, '> 2'), Scopes.operator);
      });

      test('a `>` inside an attribute string does not end the tag', () {
        final r = hl('x = <a title="x > y">t</a>;');
        expect(scopeAt(r, '"x > y"'), Scopes.string);
        expect(scopeAt(r, 't<'), isNull);
      });

      test('comparisons are not elements', () {
        final r = hl('if (a < b && c > d) { x = a <b; }');
        expect(scoped(r).where((t) => t.$2 == Scopes.tag), isEmpty);
        expect(scopeAt(r, '< b'), Scopes.operator);
      });
    });
  }

  test('tsx: type parameters are not elements', () {
    final r = highlightChecked(
      'const id = <T,>(v: T): T => v;\n'
      'function f<T extends object>(x: T) { return x; }\n'
      'const g = <T extends unknown>(v: T) => v;\n'
      'type F = { run?: <R>(fn: () => R) => R };\n',
      tsxLanguage,
    );
    expect(scoped(r).where((t) => t.$2 == Scopes.tag), isEmpty);
    expect(scopeAt(r, 'extends object'), Scopes.keyword);
    expect(scopeAt(r, 'return'), Scopes.keyword);
  });

  test('tsx: type arguments on a component', () {
    final r = highlightChecked(
      'x = <List<number> items={[1]} />; let y = 1;',
      tsxLanguage,
    );
    expect(scopeAt(r, 'List'), Scopes.type);
    expect(scopeAt(r, 'items'), Scopes.attribute);
    expect(scopeAt(r, 'let'), Scopes.keyword);
  });

  test('plain JavaScript and TypeScript do not parse JSX', () {
    final js = highlightChecked('x = <div>a</div>;', javascriptLanguage);
    expect(scoped(js).where((t) => t.$2 == Scopes.tag), isEmpty);
    final ts = highlightChecked('x = <T>(y);', typescriptLanguage);
    expect(scoped(ts).where((t) => t.$2 == Scopes.tag), isEmpty);
  });

  test('file names and detection', () {
    final registry = allLanguagesRegistry();
    expect(registry.forFileName('App.jsx'), same(jsxLanguage));
    expect(registry.forFileName('App.tsx'), same(tsxLanguage));
    expect(registry.forFileName('app.js'), same(javascriptLanguage));
    expect(registry.forFileName('app.ts'), same(typescriptLanguage));
    const react =
        "import { useState } from 'react';\n"
        'export default function App() {\n'
        '  const [n, setN] = useState(0);\n'
        '  return <button className="b" onClick={() => setN(n + 1)}>{n}</button>;\n'
        '}\n';
    expect(
      const LanguageDetector().detect(react, allLanguages)?.language,
      same(jsxLanguage),
    );
  });
}
