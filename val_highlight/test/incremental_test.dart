import 'dart:math';

import 'package:test/test.dart';
import 'package:val_highlight/val_highlight.dart';
import 'package:val_highlight/languages/all.dart';

import 'helpers.dart';

/// `(start, end, scopes)` for every token; comparable across results that
/// use different scope tables.
List<(int, int, String)> _shape(HighlightResult r) => [
  for (final t in r.tokens) (t.start, t.end, t.scopes.join('>')),
];

void _expectSameAsFull(HighlightResult incremental, {LanguageRegistry? reg}) {
  expectCoverage(incremental);
  final full = Highlighter(
    registry: reg,
  ).highlight(incremental.code, language: incremental.language);
  expect(_shape(incremental), _shape(full));
}

const _dartSource = r'''
/// Docs.
class Foo<T> extends Bar {
  final int x = 0x1F; // trailing
  /* block /* nested */ still */
  String greet(String name) => "Hello $name ${x + {1: 2}[1]}";
  Future<void> run() async {
    await Future.delayed(const Duration(seconds: 1));
  }
}
''';

void main() {
  test('first result matches a full highlight', () {
    final doc = IncrementalHighlighter(
      language: dartLanguage,
      text: _dartSource,
    );
    _expectSameAsFull(doc.result);
  });

  test('typing inside a line re-scans only nearby lines', () {
    final source = List.filled(200, 'var x = foo(1); // c\n').join();
    final doc = IncrementalHighlighter(language: dartLanguage, text: source);
    final at = source.length ~/ 2;
    final edited = '${source.substring(0, at)}y${source.substring(at)}';
    _expectSameAsFull(doc.update(edited));
    expect(doc.lastRescannedLines, lessThanOrEqualTo(3));
  });

  test('opening a block comment re-scans to the end, closing restores', () {
    final source = List.filled(50, 'var x = 1;\n').join();
    final doc = IncrementalHighlighter(language: dartLanguage, text: source);
    final opened = '/*$source';
    _expectSameAsFull(doc.update(opened));
    expect(scopeAt(doc.result, 'var'), Scopes.comment);
    _expectSameAsFull(doc.update(source));
    expect(scopeAt(doc.result, 'var'), Scopes.keyword);
  });

  test('changing language re-highlights', () {
    final doc = IncrementalHighlighter(language: jsonLanguage, text: 'true');
    doc.language = dartLanguage;
    expect(doc.result.language, same(dartLanguage));
    _expectSameAsFull(doc.result);
  });

  test('random edits always match a full highlight', () {
    final random = Random(7);
    const alphabet = 'ab /*"\'\${}()\n#`<>:-\\1';
    final registry = allLanguagesRegistry();
    for (final language in [
      dartLanguage,
      javascriptLanguage,
      pythonLanguage,
      htmlLanguage,
      markdownLanguage,
      yamlLanguage,
    ]) {
      final doc = IncrementalHighlighter(
        language: language,
        text: _dartSource,
        registry: registry,
      );
      var text = _dartSource;
      for (var step = 0; step < 150; step++) {
        final at = random.nextInt(text.length + 1);
        final remove = random.nextInt(4);
        final end = min(text.length, at + remove);
        final insert = String.fromCharCodes([
          for (var i = random.nextInt(4); i > 0; i--)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        text = text.replaceRange(at, end, insert);
        final result = doc.update(text);
        expect(result.code, text);
        _expectSameAsFull(result, reg: registry);
      }
    }
  });
}
