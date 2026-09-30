// Incremental highlighting must match a full highlight after any edit, in
// every language. Uses each language's golden input as the document.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

List<(int, int, String)> _shape(HighlightResult r) => [
  for (final t in r.tokens) (t.start, t.end, t.scopes.join('>')),
];

void main() {
  final registry = allLanguagesRegistry();
  final highlighter = Highlighter(registry: registry);
  const inserts = [
    '\n', '\n\n', '(', ')', '{', '}', '[', '"', "'", '`', '/*', '*/', //
    '#', '--', '<<', '\\', ':', ';', 'x', ' ', '',
  ];

  for (final file in Directory('test/golden_inputs').listSync()) {
    if (file is! File) continue;
    final name = file.uri.pathSegments.last.split('.').first;
    test(name, () {
      final language = registry.lookup(name)!;
      final random = Random(name.hashCode);
      var text = file.readAsStringSync();
      final document = IncrementalHighlighter(
        language: language,
        text: text,
        registry: registry,
      );
      for (var step = 0; step < 60; step++) {
        final at = random.nextInt(text.length + 1);
        final end = min(text.length, at + random.nextInt(6));
        text = text.replaceRange(
          at,
          end,
          inserts[random.nextInt(inserts.length)],
        );
        final updated = document.update(text);
        final fullResult = highlighter.highlight(text, language: language);
        expect(
          _shape(updated),
          _shape(fullResult),
          reason: '$name, edit $step at $at',
        );
        // Line starts are spliced, not recounted; they must still agree.
        expect(updated.lineCount, fullResult.lineCount);
        for (var line = 0; line < updated.lineCount; line++) {
          expect(updated.lineStart(line), fullResult.lineStart(line));
        }
      }
    });
  }
}
