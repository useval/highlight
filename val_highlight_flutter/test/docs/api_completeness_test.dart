// Every public symbol of both packages is documented in docs/, checked
// independently of the generator that writes docs/api/: the public API comes
// from the analyzer (test/docs/public_api.dart), not from the generator's
// `pages` list or its source scanner, so a symbol the generator was never
// told about, a member it skipped, or a doc paragraph it dropped fails here.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'public_api.dart';

void main() {
  late final List<ApiItem> api;
  setUpAll(() async => api = await publicApi(Directory.current));

  test('the analyzer sees the whole public API', () {
    final libraries = publicLibraryUris(Directory.current);
    for (final uri in [
      'package:val_highlight/advanced.dart',
      'package:val_highlight/languages/all.dart',
      'package:val_highlight/languages/dart.dart',
      'package:val_highlight/themes/all.dart',
      'package:val_highlight/themes/dark.dart',
      'package:val_highlight/val_highlight.dart',
      'package:val_highlight_flutter/val_highlight_flutter.dart',
      'package:val_highlight_flutter/material.dart',
    ]) {
      expect(libraries, contains(uri));
    }
    final ids = {for (final i in api) i.id};
    // One of each kind, from each kind of library.
    for (final id in [
      'CodeView',
      'CodeView.new',
      'CodeThemeData.brightness',
      'CodeLineDetails.lineNumber',
      'CodeView.code',
      'CodeField.defaultShortcuts',
      'Grammar.validate',
      'ValTheme.fromVsCode',
      'TokenRule',
      'Scopes.keyword',
      'CodeGutterBuilder',
      'lineSpans',
      'dartLanguage',
      'allLanguagesRegistry',
      'darkTheme',
      'allThemes',
      'package:val_highlight/val_highlight.dart',
    ]) {
      expect(ids, contains(id));
    }
    // Private and engine-internal names stay out.
    expect(ids.where((id) => id.startsWith('_') || id.contains('._')), isEmpty);
  });

  test('every public symbol, member and doc paragraph is in docs/', () {
    final gaps = undocumented(api, Directory('../docs'));
    expect(
      gaps,
      isEmpty,
      reason:
          '${gaps.length} gap(s). Add a missing symbol to `pages` in '
          'tool/docs/api_reference.dart, give an undocumented one a doc '
          'comment, then run `just docs`.',
    );
  });

  test('the check reports a gap when the docs have one', () {
    final copy = Directory.systemTemp.createTempSync('vh_docs_');
    addTearDown(() => copy.deleteSync(recursive: true));
    for (final f in Directory('../docs').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.mdx')) continue;
      final rel = f.path.substring('../docs/'.length);
      var text = f.readAsStringSync();
      if (rel == 'api/_code-view.mdx') {
        // Drop the `CodeView` heading, and a doc paragraph from the table.
        text = text
            .replaceFirst('### `CodeView`\n', '')
            .replaceFirst('Source code to show.', '');
      }
      File('${copy.path}/$rel')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    final gaps = undocumented(api, copy);
    expect(gaps, contains('CodeView: no section in docs/api/'));
    expect(
      gaps,
      anyElement(startsWith('CodeView.code: paragraph not in docs')),
    );
  });
}
