// The reference parts of the docs (docs/api/ at the repository root) are
// generated from the source of both packages. This fails when a public
// declaration, a default, a doc comment, a language or a theme changed
// without them being regenerated, and when the docs fall behind the source
// in the other ways listed below.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';

import '../../tool/docs/api_reference.dart' show generateDocs;

void main() {
  test('docs/api matches the source', () {
    final files = generateDocs(Directory.current);
    expect(files, isNotEmpty);
    for (final MapEntry(key: path, value: content) in files.entries) {
      final file = File(path);
      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        content,
        reason:
            '$path is out of date — run `dart run tool/docs/api_reference.dart` '
            'in val_highlight_flutter/',
      );
    }
    final extra = [
      for (final f in Directory('../docs/api').listSync().whereType<File>())
        if (!files.containsKey(f.path)) f.path,
    ];
    expect(extra, isEmpty, reason: 'not generated any more');
  });

  // That every public declaration is documented is checked, independently
  // of the generator, by api_completeness_test.dart.

  test('every example has its image, rendered by the generator', () {
    final generator = File(
      'tool/screenshots/generate_test.dart',
    ).readAsStringSync();
    final examples = Directory('tool/screenshots/examples')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(examples, isNotEmpty);
    for (final file in examples) {
      final name = file.path
          .substring('tool/screenshots/examples/'.length)
          .replaceAll('.dart', '');
      if (name == 'themes/sample') continue; // one image per theme
      expect(
        generator.contains(name),
        isTrue,
        reason: '$name is not rendered by tool/screenshots/generate_test.dart',
      );
      expect(
        File('../docs/images/$name.png').existsSync(),
        isTrue,
        reason: 'run `just docs-screenshots`',
      );
    }
    for (final theme in allThemes) {
      expect(
        File('../docs/images/themes/${theme.name}.png').existsSync(),
        isTrue,
      );
    }
  });

  test('counts in the docs prose match the source', () {
    final languages = allLanguages.length - 2; // generic and plain text
    final pages = Directory('../docs')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.mdx') && !f.path.contains('/api/'));
    for (final page in pages) {
      final text = page.readAsStringSync();
      for (final m in RegExp(
        r'\b(\d+) (?:built-in )?languages\b',
      ).allMatches(text)) {
        expect(int.parse(m[1]!), languages, reason: '${page.path}: "${m[0]}"');
      }
      for (final m in RegExp(
        r'\b(\d+) (?:built-in )?themes\b',
      ).allMatches(text)) {
        expect(
          int.parse(m[1]!),
          allThemes.length,
          reason: '${page.path}: "${m[0]}"',
        );
      }
    }
  });
}
