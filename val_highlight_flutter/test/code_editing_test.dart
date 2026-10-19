import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/css.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/languages/plaintext.dart';
import 'package:val_highlight/languages/python.dart';
import 'package:val_highlight/languages/rust.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// A document being typed into through a [CodeEditingFormatter], the way
/// a text field applies it.
class _Doc {
  _Doc(
    String text, {
    int? caret,
    Grammar language = dartLanguage,
    CodeEditing editing = const CodeEditing(),
  }) : controller = HighlightTextController(text: text, language: language) {
    controller.selection = TextSelection.collapsed(
      offset: caret ?? text.length,
    );
    formatter = CodeEditingFormatter(controller: controller, editing: editing);
  }

  final HighlightTextController controller;
  late final CodeEditingFormatter formatter;

  String get text => controller.text;
  TextSelection get selection => controller.selection;

  /// [text] with `|` at the caret, or `[` `]` around the selection.
  String get shown {
    final s = selection;
    if (s.isCollapsed) return text.replaceRange(s.start, s.start, '|');
    return '${text.substring(0, s.start)}[${text.substring(s.start, s.end)}]'
        '${text.substring(s.end)}';
  }

  void _apply(TextEditingValue value) {
    controller.value = formatter.formatEditUpdate(controller.value, value);
  }

  /// Types [chars] one at a time, replacing the selection.
  void type(String chars) {
    for (final char in chars.split('')) {
      final value = controller.value;
      final s = value.selection;
      _apply(
        TextEditingValue(
          text: value.text.replaceRange(s.start, s.end, char),
          selection: TextSelection.collapsed(offset: s.start + 1),
        ),
      );
    }
  }

  void backspace() {
    final value = controller.value;
    final s = value.selection;
    final start = s.isCollapsed ? s.start - 1 : s.start;
    _apply(
      TextEditingValue(
        text: value.text.replaceRange(start, s.end, ''),
        selection: TextSelection.collapsed(offset: start),
      ),
    );
  }

  void select(int start, [int? end]) {
    controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: end ?? start,
    );
  }
}

void main() {
  group('auto-closing', () {
    test('brackets close and the closer is stepped over', () {
      final doc = _Doc('f');
      doc.type('(');
      expect(doc.shown, 'f(|)');
      doc.type('x');
      expect(doc.shown, 'f(x|)');
      doc.type(')');
      expect(doc.shown, 'f(x)|');
      doc.type(';');
      expect(doc.shown, 'f(x);|');
    });

    test('nested brackets step over in order', () {
      final doc = _Doc('');
      doc.type('{[(');
      expect(doc.shown, '{[(|)]}');
      doc.type(')]}');
      expect(doc.shown, '{[()]}|');
    });

    test('brackets stay single before a word', () {
      final doc = _Doc('value', caret: 0);
      doc.type('(');
      expect(doc.shown, '(|value');
    });

    test('a typed closer is not swallowed unless it was automatic', () {
      final doc = _Doc('f()', caret: 2);
      doc.type(')');
      expect(doc.shown, 'f()|)');
    });

    test('Backspace deletes an automatic empty pair', () {
      final doc = _Doc('f');
      doc.type('(');
      doc.backspace();
      expect(doc.shown, 'f|');
    });

    test('Backspace leaves a typed pair alone', () {
      final doc = _Doc('f()', caret: 2);
      doc.backspace();
      expect(doc.shown, 'f|)');
    });

    test('quotes close, but not after a word or inside a string', () {
      final doc = _Doc('x = ');
      doc.type('"');
      expect(doc.shown, 'x = "|"');
      doc.type('hi"');
      expect(doc.shown, 'x = "hi"|');

      final word = _Doc('don');
      word.type("'");
      expect(word.shown, "don'|");

      final inString = _Doc('x = "a  b"', caret: 7);
      inString.type("'");
      expect(inString.shown, 'x = "a \'| b"');
    });

    test('quotes do not close in comments', () {
      final doc = _Doc('// say ');
      doc.type('"');
      expect(doc.shown, '// say "|');
    });

    test('language quotes: Rust lifetimes stay single', () {
      final doc = _Doc('fn f<', language: rustLanguage);
      doc.type("'");
      expect(doc.shown, "fn f<'|");
    });

    test('plain text closes nothing', () {
      final doc = _Doc('', language: plainTextLanguage);
      doc.type('("');
      expect(doc.shown, '("|');
    });

    test('a closer is forgotten once the caret leaves its line', () {
      final doc = _Doc('a\nb');
      doc.select(1);
      doc.type('(');
      expect(doc.shown, 'a(|)\nb');
      doc.select(5);
      doc.select(2);
      doc.type('x');
      doc.select(doc.text.length);
      doc.select(3);
      expect(doc.shown, 'a(x|)\nb');
      // Still on the line: steps over.
      doc.type(')');
      expect(doc.shown, 'a(x)|\nb');
    });

    test('closers survive edits made elsewhere on the line', () {
      final doc = _Doc('');
      doc.type('f(');
      doc.type('a, b');
      expect(doc.shown, 'f(a, b|)');
      doc.backspace();
      doc.type('c)');
      expect(doc.shown, 'f(a, c)|');
    });

    test('an outside change forgets the closers', () {
      final doc = _Doc('');
      doc.type('(');
      // A closer would now sit where the automatic one was.
      doc.controller.value = const TextEditingValue(
        text: '))',
        selection: TextSelection.collapsed(offset: 1),
      );
      doc.type(')');
      expect(doc.shown, '))|)');
    });

    test('text being composed is never changed', () {
      final doc = _Doc('f');
      final value = doc.formatter.formatEditUpdate(
        doc.controller.value,
        const TextEditingValue(
          text: 'f(',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      expect(value.text, 'f(');
    });

    test('can be turned off', () {
      final doc = _Doc('f', editing: const CodeEditing(autoClose: false));
      doc.type('("');
      expect(doc.shown, 'f("|');
    });
  });

  group('wrapping a selection', () {
    test('brackets and quotes wrap the selection', () {
      final doc = _Doc('a value b');
      doc.select(2, 7);
      doc.type('(');
      expect(doc.shown, 'a ([value]) b');
      doc.type('"');
      expect(doc.shown, 'a ("[value]") b');
    });

    test('other characters replace it', () {
      final doc = _Doc('a value b');
      doc.select(2, 7);
      doc.type('x');
      expect(doc.shown, 'a x| b');
    });

    test('can be turned off', () {
      final doc = _Doc(
        'a value b',
        editing: const CodeEditing(wrapSelection: false),
      );
      doc.select(2, 7);
      doc.type('(');
      expect(doc.shown, 'a (| b');
    });
  });

  group('Enter', () {
    test('keeps the indentation and indents after an opener', () {
      final doc = _Doc('  if (x) {');
      doc.type('\n');
      expect(doc.shown, '  if (x) {\n    |');
    });

    test('splits a bracket pair onto three lines', () {
      final doc = _Doc('  f() {}', caret: 7);
      doc.type('\n');
      expect(doc.shown, '  f() {\n    |\n  }');
    });

    test('after an automatic pair', () {
      final doc = _Doc('');
      doc.type('[\n');
      expect(doc.shown, '[\n  |\n]');
    });

    test('can be turned off', () {
      final doc = _Doc('  x', editing: const CodeEditing(autoIndent: false));
      doc.type('\n');
      expect(doc.shown, '  x\n|');
    });
  });

  group('toggleComment', () {
    TextEditingValue? toggle(
      String text,
      int start, [
      int? end,
      Grammar language = dartLanguage,
    ]) {
      final value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
      );
      return toggleComment(
        value,
        EditingSyntax.of(language),
        result: const Highlighter().highlight(text, language: language),
      );
    }

    test('comments the caret line and back', () {
      final on = toggle('  a();\nb();', 3)!;
      expect(on.text, '  // a();\nb();');
      expect(on.selection.baseOffset, 6);
      final off = toggle(on.text, on.selection.baseOffset)!;
      expect(off.text, '  a();\nb();');
      expect(off.selection.baseOffset, 3);
    });

    test('aligns markers at the smallest indentation and skips blanks', () {
      const text = '  if (a) {\n    b();\n\n  }';
      final on = toggle(text, 0, text.length)!;
      expect(on.text, '  // if (a) {\n  //   b();\n\n  // }');
      expect(on.selection.start, 0);
      expect(on.selection.end, on.text.length);
      expect(toggle(on.text, 0, on.text.length)!.text, text);
    });

    test('comments every line when only some are commented', () {
      final on = toggle('// a\nb', 0, 6)!;
      expect(on.text, '// // a\n// b');
    });

    test('a selection ending at a line start leaves that line alone', () {
      final on = toggle('a\nb\n', 0, 2)!;
      expect(on.text, '// a\nb\n');
    });

    test('a marker inside a string is not a comment', () {
      const text = 'x = """\n// not a comment\n""";';
      final on = toggle(text, 9)!;
      expect(on.text, 'x = """\n// // not a comment\n""";');
    });

    test('doc comments are content, not comment markers', () {
      final on = toggle('/// Docs.\nvoid f() {}', 0, 21)!;
      expect(on.text, '// /// Docs.\n// void f() {}');
      expect(
        toggle(on.text, 0, on.text.length)!.text,
        '/// Docs.\nvoid f() {}',
      );

      expect(toggle('  /// Docs.', 5)!.text, '  // /// Docs.');
      expect(toggle('  // /// Docs.', 5)!.text, '  /// Docs.');
    });

    test('Rust inner doc comments and shebangs are content', () {
      expect(
        toggle('//! Crate.', 0, null, rustLanguage)!.text,
        '// //! Crate.',
      );
      expect(
        toggle('#!/usr/bin/env python', 0, null, pythonLanguage)!.text,
        '# #!/usr/bin/env python',
      );
    });

    test(
      'without highlighting, a repeated marker character is a doc comment',
      () {
        final value = toggleComment(
          const TextEditingValue(
            text: '/// Docs.',
            selection: TextSelection.collapsed(offset: 0),
          ),
          EditingSyntax.cStyle,
        )!;
        expect(value.text, '// /// Docs.');
      },
    );

    test('uses the language marker', () {
      expect(toggle('x = 1', 0, null, pythonLanguage)!.text, '# x = 1');
    });

    test('block comments wrap the line or selection', () {
      final line = toggle('  a { b: c; }', 4, null, cssLanguage)!;
      expect(line.text, '  /* a { b: c; } */');
      expect(toggle(line.text, 6, null, cssLanguage)!.text, '  a { b: c; }');

      final part = toggle('a { b: c; }', 4, 9, cssLanguage)!;
      expect(part.text, 'a { /* b: c; */ }');
      expect(
        part.text.substring(part.selection.start, part.selection.end),
        'b: c;',
      );
    });

    test('languages without comments do nothing', () {
      expect(toggle('text', 0, null, plainTextLanguage), isNull);
    });

    test('a selection past the end does nothing', () {
      expect(toggle('a', 0, 5), isNull);
    });
  });
}
