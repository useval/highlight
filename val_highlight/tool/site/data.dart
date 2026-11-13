// The facts the company website's val_highlight page shows, from the package
// itself: every built-in language (name, aliases, file extensions), every
// built-in theme, and what the HTML example on the page really outputs.
//
//   dart run tool/site/data.dart > out.json
//
// The website's `npm run product-assets` runs this; nothing on the page is
// typed by hand.
import 'dart:convert';
import 'dart:io';

import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';
import 'package:val_highlight/val_highlight.dart';

void main() {
  const htmlSource = 'final n = 42; // answer';
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'languages': [
        for (final g in allLanguages)
          {
            'name': g.name,
            'aliases': g.aliases,
            'extensions': g.fileExtensions,
          },
      ],
      'themes': [for (final t in allThemes) t.name],
      'html': {
        'source': htmlSource,
        'output': const Highlighter().toHtml(
          htmlSource,
          language: dartLanguage,
          renderer: const HtmlRenderer(wrap: true),
        ),
      },
    }),
  );
}
