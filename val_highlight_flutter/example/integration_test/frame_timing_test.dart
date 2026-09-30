// Frame-time benchmark: real frames, measured with FrameTiming.
//
// Run in profile mode (debug frames are not representative):
//   just bench-frames            # macOS
//   just bench-frames <device>   # any device id
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';
import 'package:val_highlight_flutter_example/samples.g.dart';

String _dartLines(int lines) {
  final sample = generatedSamples['dart']!.split('\n');
  return [for (var i = 0; i < lines; i++) sample[i % sample.length]].join('\n');
}

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(body: SafeArea(child: child)),
);

Future<void> _scroll(WidgetTester tester, {int flings = 8}) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < flings; i++) {
    await tester.fling(scrollable, const Offset(0, -1500), 3000);
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < flings; i++) {
    await tester.fling(scrollable, const Offset(0, 1500), 3000);
    await tester.pumpAndSettle();
  }
}

/// Waits until a background highlight has been applied.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scroll 20,000 lines', (tester) async {
    await tester.pumpWidget(
      _app(
        CodeView(_dartLines(20000), language: dartLanguage, lineNumbers: true),
      ),
    );
    await _settle(tester);
    await binding.watchPerformance(
      () => _scroll(tester),
      reportKey: 'scroll_20000_lines',
    );
  });

  testWidgets('scroll 20,000 lines, wrapped', (tester) async {
    await tester.pumpWidget(
      _app(
        CodeView(
          _dartLines(20000),
          language: dartLanguage,
          lineNumbers: true,
          wrap: true,
        ),
      ),
    );
    await _settle(tester);
    await binding.watchPerformance(
      () => _scroll(tester),
      reportKey: 'scroll_20000_lines_wrapped',
    );
  });

  testWidgets('scroll 800 lines as one text block', (tester) async {
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: CodeView(_dartLines(800), language: dartLanguage),
        ),
      ),
    );
    await _settle(tester);
    await binding.watchPerformance(
      () => _scroll(tester),
      reportKey: 'scroll_800_lines_block',
    );
  });

  for (final highlighted in [false, true]) {
    testWidgets('type in a 2,000-line editor (highlighted: $highlighted)', (
      tester,
    ) async {
      final controller = highlighted
          ? HighlightTextController(
              text: _dartLines(2000),
              language: dartLanguage,
            )
          : TextEditingController(text: _dartLines(2000));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      );
      await _settle(tester);
      final middle = controller.text.length ~/ 2;
      await binding.watchPerformance(
        () async {
          for (var i = 0; i < 120; i++) {
            final text = controller.text;
            controller.value = TextEditingValue(
              text: text.replaceRange(middle + i, middle + i, 'x'),
              selection: TextSelection.collapsed(offset: middle + i + 1),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
        reportKey: highlighted
            ? 'type_2000_line_editor'
            : 'type_2000_line_plain_baseline',
      );
    });
  }

  testWidgets('type in a 2,000-line CodeField', (tester) async {
    final controller = HighlightTextController(
      text: _dartLines(2000),
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(CodeField(controller: controller, expands: true)),
    );
    await _settle(tester);
    final middle = controller.text.length ~/ 2;
    await binding.watchPerformance(() async {
      for (var i = 0; i < 120; i++) {
        final text = controller.text;
        controller.value = TextEditingValue(
          text: text.replaceRange(middle + i, middle + i, 'x'),
          selection: TextSelection.collapsed(offset: middle + i + 1),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'type_2000_line_codefield');
  });

  testWidgets('scroll a 2,000-line CodeField', (tester) async {
    final controller = HighlightTextController(
      text: _dartLines(2000),
      language: dartLanguage,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(CodeField(controller: controller, expands: true)),
    );
    await _settle(tester);
    await binding.watchPerformance(
      () => _scroll(tester),
      reportKey: 'scroll_2000_line_codefield',
    );
  });
}
