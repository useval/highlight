import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';
import 'package:val_highlight_flutter_example/main.dart';

void main() {
  testWidgets('gallery renders highlighted code', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(CodeView), findsWidgets);
    expect(find.text('dart'), findsWidgets);
  });
}
