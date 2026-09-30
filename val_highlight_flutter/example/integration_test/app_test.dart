// Smoke test of the example app on a real device or simulator:
//   flutter test integration_test/app_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';
import 'package:val_highlight_flutter_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every tab renders and the editor accepts input', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    expect(find.byType(CodeView), findsWidgets);

    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();
    expect(find.byType(CodeField), findsOneWidget);
    await tester.tap(find.byType(CodeField));
    await tester.enterText(find.byType(EditableText), 'void main() {}');
    await tester.pumpAndSettle();
    expect(find.textContaining('void main'), findsWidgets);

    await tester.tap(find.text('Large file'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(CodeView), findsOneWidget);
  });
}
