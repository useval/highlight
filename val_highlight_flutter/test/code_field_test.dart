import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/src/code_field.dart';
import 'package:val_highlight_flutter/src/editor_decorations.dart';
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

  Future<HighlightTextController> pumpField(
    WidgetTester tester,
    String text, {
    int? caret,
    Widget Function(Widget field)? wrap,
    CodeField Function(HighlightTextController controller)? build,
  }) async {
    final controller = HighlightTextController(
      text: text,
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    final field =
        build?.call(controller) ??
        CodeField(controller: controller, expands: true);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: wrap?.call(field) ?? field)),
    );
    await tester.showKeyboard(find.byType(CodeField));
    controller.selection = TextSelection.collapsed(
      offset: caret ?? text.length,
    );
    await tester.pump();
    return controller;
  }

  Future<void> pressCombo(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  group('typing', () {
    testWidgets('text from an input method auto-closes brackets', (
      tester,
    ) async {
      final controller = await pumpField(tester, 'f');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'f(',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.text, 'f()');
      expect(controller.selection.baseOffset, 2);
    });

    testWidgets('a line break from an input method keeps the indentation', (
      tester,
    ) async {
      final controller = await pumpField(tester, '  f() {}', caret: 7);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  f() {\n}',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump();
      expect(controller.text, '  f() {\n    \n  }');
      expect(controller.selection.baseOffset, 12);
    });

    testWidgets('CodeEditing.none types plainly', (tester) async {
      final controller = await pumpField(
        tester,
        'f',
        build: (controller) => CodeField(
          controller: controller,
          expands: true,
          editing: CodeEditing.none,
        ),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'f(',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.text, 'f(');
    });

    testWidgets('extra input formatters run after the editing behaviour', (
      tester,
    ) async {
      final controller = await pumpField(
        tester,
        'f',
        build: (controller) => CodeField(
          controller: controller,
          expands: true,
          inputFormatters: [LengthLimitingTextInputFormatter(2)],
        ),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'f(',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.text, 'f(');
    });
  });

  group('shortcuts', () {
    testWidgets('Ctrl+/ toggles a comment', (tester) async {
      final controller = await pumpField(tester, 'a();\nb();', caret: 2);
      await pressCombo(tester, LogicalKeyboardKey.slash);
      expect(controller.text, '// a();\nb();');
      await pressCombo(tester, LogicalKeyboardKey.slash);
      expect(controller.text, 'a();\nb();');
    });

    testWidgets('Shift+Tab outdents', (tester) async {
      final controller = await pumpField(tester, '    a', caret: 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.text, '  a');
    });

    testWidgets('an Actions widget above can override an intent', (
      tester,
    ) async {
      var calls = 0;
      final controller = await pumpField(
        tester,
        'a();',
        wrap: (field) => Actions(
          actions: {
            ToggleCommentIntent: CallbackAction<ToggleCommentIntent>(
              onInvoke: (_) => calls++,
            ),
          },
          child: field,
        ),
      );
      await pressCombo(tester, LogicalKeyboardKey.slash);
      expect(calls, 1);
      expect(controller.text, 'a();');
    });

    testWidgets('custom shortcuts replace the defaults', (tester) async {
      final controller = await pumpField(
        tester,
        'a',
        build: (controller) => CodeField(
          controller: controller,
          expands: true,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                ToggleCommentIntent(),
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.text, 'a');
      await pressCombo(tester, LogicalKeyboardKey.keyK);
      expect(controller.text, '// a');
    });

    testWidgets('read-only fields do not edit', (tester) async {
      final controller = await pumpField(
        tester,
        'a',
        build: (controller) =>
            CodeField(controller: controller, expands: true, readOnly: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pressCombo(tester, LogicalKeyboardKey.slash);
      expect(controller.text, 'a');
    });
  });

  group('decorations', () {
    double textLeft(WidgetTester tester) =>
        tester.getTopLeft(find.byType(EditableText)).dx;

    testWidgets('line numbers paint in a gutter beside the text', (
      tester,
    ) async {
      await pumpField(
        tester,
        'a\nb\nc',
        build: (controller) =>
            CodeField(controller: controller, expands: true, lineNumbers: true),
      );
      expect(textLeft(tester), greaterThan(16));
      expect(
        find.byType(EditorDecorations),
        paints
          ..paragraph()
          ..paragraph()
          ..paragraph(),
      );
    });

    testWidgets('no gutter by default', (tester) async {
      await pumpField(tester, 'a\nb');
      expect(textLeft(tester), 0);
      expect(find.byType(EditorDecorations), isNot(paints..paragraph()));
    });

    testWidgets('numbers follow wrapped lines', (tester) async {
      final long = List.filled(60, 'word').join(' ');
      await pumpField(
        tester,
        '$long\nshort',
        wrap: (field) => SizedBox(width: 300, child: field),
        build: (controller) =>
            CodeField(controller: controller, expands: true, lineNumbers: true),
      );
      final editable = tester.allRenderObjects
          .whereType<RenderEditable>()
          .first;
      final lineHeight = editable.preferredLineHeight;
      final secondTop = editable
          .getLocalRectForCaret(TextPosition(offset: long.length + 1))
          .top;
      expect(secondTop, greaterThan(lineHeight * 2));
      // The second number sits beside the second line, below the wrapped
      // rows of the first.
      expect(
        find.byType(EditorDecorations),
        paints
          ..paragraph(
            offset: isA<Offset>().having((o) => o.dy, 'dy', lessThan(1)),
          )
          ..paragraph(
            offset: isA<Offset>().having(
              (o) => o.dy,
              'dy',
              greaterThan(lineHeight * 2),
            ),
          ),
      );
    });

    testWidgets('the gutter widens as the line count gains a digit', (
      tester,
    ) async {
      final controller = await pumpField(
        tester,
        List.filled(99, 'x').join('\n'),
        build: (controller) =>
            CodeField(controller: controller, expands: true, lineNumbers: true),
      );
      final before = textLeft(tester);
      controller.text = '${controller.text}\ny';
      await tester.pump();
      expect(textLeft(tester), greaterThan(before));
    });

    testWidgets('the caret line and highlighted lines get bands', (
      tester,
    ) async {
      await pumpField(
        tester,
        'a\nb\nc',
        caret: 0,
        build: (controller) => CodeField(
          controller: controller,
          expands: true,
          highlightCurrentLine: true,
          currentLineColor: const Color(0xFF00FF00),
          highlightedLines: const {3},
          highlightColor: const Color(0xFFFF0000),
        ),
      );
      expect(
        find.byType(EditorDecorations),
        paints
          ..rect(color: const Color(0xFF00FF00))
          ..rect(color: const Color(0xFFFF0000)),
      );
    });

    testWidgets('a bracket next to the caret is matched', (tester) async {
      await pumpField(
        tester,
        'f(a, b)',
        caret: 2,
        build: (controller) => CodeField(
          controller: controller,
          expands: true,
          bracketColor: const Color(0xFF0000FF),
        ),
      );
      expect(
        find.byType(EditorDecorations),
        paints
          ..rrect(color: const Color(0xFF0000FF))
          ..rrect(color: const Color(0xFF0000FF)),
      );
    });

    testWidgets('brackets in strings are not matched', (tester) async {
      await pumpField(tester, 'f("(")', caret: 4);
      expect(find.byType(EditorDecorations), isNot(paints..rrect()));
    });
  });
}
