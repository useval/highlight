import 'package:test/test.dart';
import 'package:val_highlight/val_highlight.dart';
import 'package:val_highlight/languages/all.dart';

void main() {
  group('lines', () {
    const highlighter = Highlighter();

    test('line offsets exclude line breaks, including CRLF', () {
      final r = highlighter.highlight('a\r\nbb\n\nc\n', language: jsonLanguage);
      expect(r.lineCount, 5);
      expect(
        [
          for (var i = 0; i < r.lineCount; i++)
            r.code.substring(r.lineStart(i), r.lineEnd(i)),
        ],
        ['a', 'bb', '', 'c', ''],
      );
    });

    test('segments split tokens that span lines', () {
      final r = highlighter.highlight('/* a\nb */ 1', language: dartLanguage);
      final lines = <List<(String, String?)>>[];
      for (var i = 0; i < r.lineCount; i++) {
        final segments = <(String, String?)>[];
        r.forEachSegment(i, (start, end, stack) {
          segments.add((r.code.substring(start, end), r.scopes.scopeOf(stack)));
        });
        lines.add(segments);
      }
      expect(lines, [
        [('/* a', Scopes.comment)],
        [('b */', Scopes.comment), (' ', null), ('1', Scopes.number)],
      ]);
    });

    test('tokenAt finds the covering token', () {
      final r = highlighter.highlight('x = 1', language: dartLanguage);
      expect(r.tokenAt(0), 0);
      expect(r.tokenStack(r.tokenAt(4)), isNot(0));
      expect(r.tokenAt(5), r.tokenCount);
    });
  });

  group('LanguageDetector', () {
    const detector = LanguageDetector();

    test('file name wins', () {
      final d = detector.detect('x', allLanguages, fileName: 'a/b.PY');
      expect(d?.language, same(pythonLanguage));
      expect(d?.reason, 'file name');
    });

    test('shebang', () {
      expect(
        detector.detect('#!/usr/bin/env python3\nx', allLanguages)?.language,
        same(pythonLanguage),
      );
      expect(
        detector.detect('#!/bin/bash\necho hi', allLanguages)?.language,
        same(bashLanguage),
      );
    });

    final samples = <Grammar, String>{
      dartLanguage:
          "import 'package:flutter/material.dart';\n\n"
          'void main() {\n  final List<int> xs = [1, 2];\n  print(xs);\n}\n',
      pythonLanguage:
          'import os\n\ndef main(argv):\n    if not argv:\n'
          '        return None\n    for a in argv:\n        print(a)\n',
      javascriptLanguage:
          "const x = require('x');\nfunction go() {\n"
          "  console.log('hi');\n  return () => x;\n}\n",
      jsonLanguage: '{\n  "a": [1, 2, true],\n  "b": {"c": null}\n}\n',
      htmlLanguage:
          '<!DOCTYPE html>\n<html><body><div class="a">x</div></body></html>',
      sqlLanguage:
          'SELECT a, b FROM t WHERE a > 1 ORDER BY b;\n'
          'INSERT INTO t (a) VALUES (1);',
      yamlLanguage: 'name: app\nversion: 1.0\ndependencies:\n  - a\n  - b\n',
      markdownLanguage:
          '# Title\n\nSome text with [a link](http://x).\n\n- item\n- item\n',
      diffLanguage: 'diff --git a/x b/x\n@@ -1,2 +1,2 @@\n-a\n+b\n',
    };
    for (final MapEntry(key: language, value: code) in samples.entries) {
      test('detects ${language.name}', () {
        expect(detector.detect(code, allLanguages)?.language, same(language));
      });
    }

    test('returns null for prose', () {
      expect(detector.detect('hello there', allLanguages), isNull);
    });
  });
}
