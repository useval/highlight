@TestOn('vm')
library;

import 'dart:isolate';

import 'package:test/test.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/val_highlight.dart';

void main() {
  test('a result can be made in another isolate and sent back', () async {
    const code = 'void main() => print("hi");';
    final result = await Isolate.run(
      () => const Highlighter().highlight(code, language: dartLanguage),
    );
    final here = const Highlighter().highlight(code, language: dartLanguage);
    expect(result.tokenCount, here.tokenCount);
    expect(
      [for (final t in result.tokens) '${t.scopes}:${t.text}'],
      [for (final t in here.tokens) '${t.scopes}:${t.text}'],
    );
  });
}
