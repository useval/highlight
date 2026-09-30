// Editor behaviour that only real text layout shows. Run on a device:
//   flutter test integration_test/editor_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

RenderEditable _editable(WidgetTester tester) {
  RenderEditable? found;
  void visit(RenderObject object) {
    if (object is RenderEditable) found ??= object;
    object.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodeField)));
  return found!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Trailing spaces typed at the end of an italic line (a Markdown quote, a
  // comment) must move the caret right away, not only after the next letter.
  final cases = {
    'markdown quote': (
      markdownLanguage,
      '# Title\n\n> A quote\n\nAfter\n',
      '> A quote',
    ),
    'dart comment': (dartLanguage, 'void main() {\n  // note\n}\n', '// note'),
  };
  for (final MapEntry(key: name, value: (language, doc, line))
      in cases.entries) {
    testWidgets('typed spaces move the caret: $name', (tester) async {
      final controller = HighlightTextController(text: doc, language: language);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(controller: controller, expands: true),
          ),
        ),
      );
      await tester.tap(find.byType(CodeField));
      await tester.pump();

      var at = doc.indexOf(line) + line.length;
      var text = doc;
      var previous = _editable(
        tester,
      ).getLocalRectForCaret(TextPosition(offset: at)).left;
      for (var i = 0; i < 3; i++) {
        text = text.replaceRange(at, at, ' ');
        at++;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: at),
          ),
        );
        await tester.pump();
        final x = _editable(
          tester,
        ).getLocalRectForCaret(TextPosition(offset: at)).left;
        expect(
          x,
          greaterThan(previous),
          reason: 'space ${i + 1} did not move the caret',
        );
        previous = x;
      }
    });
  }
}
