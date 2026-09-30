// Golden snapshots: realistic code in every language.
//
// Each `test/golden_inputs/<language>.txt` holds source code in the
// language named by the file; its reviewed highlighting is stored in
// `test/goldens/<language>.txt`. Any change to how a language is highlighted
// fails here until the snapshot is reviewed and updated with:
//
//   UPDATE_GOLDENS=1 dart test test/golden_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

/// Scoped tokens as `«scopes:text»`, plain text as is, line breaks kept.
String render(HighlightResult result) {
  final out = StringBuffer();
  for (final token in result.tokens) {
    if (token.scope == null) {
      out.write(token.text);
    } else {
      out.write('«${token.scopes.join('>')}:${token.text}»');
    }
  }
  return out.toString();
}

void main() {
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';
  final registry = allLanguagesRegistry();
  final highlighter = Highlighter(registry: registry);
  final inputs =
      Directory('test/golden_inputs').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('every language has a golden input', () {
    final covered = {
      for (final file in inputs) file.uri.pathSegments.last.split('.').first,
    };
    final missing = [
      for (final language in allLanguages)
        if (language.detectable && !covered.contains(language.name))
          language.name,
    ];
    expect(missing, isEmpty);
  });

  for (final input in inputs) {
    final name = input.uri.pathSegments.last.split('.').first;
    test(name, () {
      final language = registry.lookup(name);
      expect(language, isNotNull, reason: 'no language named $name');
      final code = input.readAsStringSync();
      final actual = render(highlighter.highlight(code, language: language!));
      final golden = File('test/goldens/$name.txt');
      if (update) {
        golden
          ..createSync(recursive: true)
          ..writeAsStringSync(actual);
        return;
      }
      expect(
        golden.existsSync(),
        isTrue,
        reason: 'missing golden; run with UPDATE_GOLDENS=1',
      );
      expect(actual, golden.readAsStringSync());
    });
  }
}
