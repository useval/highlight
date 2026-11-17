// An app built the way most apps still are, on package:flutter/material.dart
// rather than material_ui. The widgets-layer library must work there.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

void main() {
  testWidgets(
    'CodeView, a controller and CodeTheme in a flutter/material app',
    (tester) async {
      final controller = HighlightTextController(
        text: 'final x = 1;',
        language: dartLanguage,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => CodeTheme(
            data: CodeThemeData(brightness: Theme.of(context).brightness),
            child: child!,
          ),
          home: Scaffold(
            body: SelectionArea(
              child: Column(
                children: [
                  const CodeView('void main() {}', language: dartLanguage),
                  TextField(controller: controller, maxLines: null),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(CodeView));
      expect(CodeTheme.resolve(context), same(darkTheme));
    },
  );
}
