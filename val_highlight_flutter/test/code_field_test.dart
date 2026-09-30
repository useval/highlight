import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/src/code_field.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

String _lines(int n) =>
    List.generate(n, (i) => 'final value$i = compute($i); // $i').join('\n');

int _styledSpans(TextSpan span) {
  var count = 0;
  span.visitChildren((child) {
    if (child is TextSpan && child.style != null) count++;
    return true;
  });
  return count;
}

void main() {
  testWidgets('small documents are styled in full', (tester) async {
    final controller = HighlightTextController(
      text: _lines(50),
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller, expands: true)),
      ),
    );
    await tester.pump();
    expect(controller.window, isNull);
  });

  testWidgets('large documents style a window that follows scrolling', (
    tester,
  ) async {
    final controller = HighlightTextController(
      text: _lines(3000),
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: CodeField(
              controller: controller,
              expands: true,
              scrollController: scroll,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final first = controller.window;
    expect(first, isNotNull);
    expect(first!.first, 0);
    expect(first.last, lessThan(200));

    final context = tester.element(find.byType(EditableText));
    final span = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );
    expect(span.toPlainText(), controller.text);
    expect(_styledSpans(span), lessThan(2000));

    scroll.jumpTo(scroll.position.maxScrollExtent / 2);
    await tester.pump();
    await tester.pump();
    final moved = controller.window!;
    expect(moved.first, greaterThan(1000));
    expect(moved.last, lessThan(2000));
  });

  testWidgets('editing keeps the text exact', (tester) async {
    final controller = HighlightTextController(
      text: _lines(1000),
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: CodeField(controller: controller, expands: true),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.text = 'var added = 1;\n${controller.text}';
    await tester.pump();
    final context = tester.element(find.byType(EditableText));
    expect(
      controller
          .buildTextSpan(context: context, withComposing: false)
          .toPlainText(),
      controller.text,
    );
  });

  group('editing helpers', () {
    TextEditingValue at(String text, int base, [int? extent]) =>
        TextEditingValue(
          text: text,
          selection: TextSelection(
            baseOffset: base,
            extentOffset: extent ?? base,
          ),
        );

    test('Tab inserts an indent at the caret', () {
      final v = indentText(at('ab', 1), '  ');
      expect(v.text, 'a  b');
      expect(v.selection.baseOffset, 3);
    });

    test('Tab indents every selected line', () {
      final v = indentText(at('a\nb\n\nc', 0, 6), '  ');
      expect(v.text, '  a\n  b\n\n  c');
    });

    test('Shift+Tab outdents the selected lines', () {
      final v = outdentLines(at('    a\n  b\nc', 2, 8), '  ');
      expect(v.text, '  a\nb\nc');
    });

    test('Enter keeps indentation and adds a level after an opener', () {
      var v = newlineKeepingIndent(at('  x = 1', 7), '  ');
      expect(v.text, '  x = 1\n  ');
      expect(v.selection.baseOffset, 10);
      v = newlineKeepingIndent(at('  if (x) {', 10), '  ');
      expect(v.text, '  if (x) {\n    ');
    });
  });

  testWidgets('Tab and Enter keys edit instead of moving focus', (
    tester,
  ) async {
    final controller = HighlightTextController(
      text: 'f() {',
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller, expands: true)),
      ),
    );
    await tester.tap(find.byType(CodeField));
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, 'f() {\n  ');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.text, 'f() {\n    ');
    // Focus stays in the editor.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });
}
