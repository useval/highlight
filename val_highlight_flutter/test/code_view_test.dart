import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

/// Every leaf `(text, color)` in the rich texts below [finder].
List<(String, Color?)> _leaves(WidgetTester tester, [Finder? finder]) {
  final leaves = <(String, Color?)>[];
  void visit(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return;
    final style = inherited?.merge(span.style) ?? span.style;
    if (span.text != null && span.text!.isNotEmpty) {
      leaves.add((span.text!, style?.color));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  for (final rich in tester.widgetList<RichText>(
    finder ?? find.byType(RichText),
  )) {
    visit(rich.text, null);
  }
  return leaves;
}

Color? _colorOf(WidgetTester tester, String text) {
  for (final (t, color) in _leaves(tester)) {
    if (t == text) return color;
  }
  return null;
}

Color _c(int argb) => Color(argb);

void main() {
  testWidgets('highlights with the light theme by default', (tester) async {
    await tester.pumpWidget(
      _app(const CodeView('final x = 1;', language: dartLanguage)),
    );
    expect(
      _colorOf(tester, 'final'),
      _c(lightTheme.lookup(Scopes.keyword)!.color!),
    );
    expect(_colorOf(tester, '1'), _c(lightTheme.lookup(Scopes.number)!.color!));
    expect(_colorOf(tester, ' x '), _c(lightTheme.root.color!));
  });

  testWidgets('follows dark brightness', (tester) async {
    await tester.pumpWidget(
      _app(
        const CodeView('final x = 1;', language: dartLanguage),
        theme: ThemeData(brightness: Brightness.dark),
      ),
    );
    expect(
      _colorOf(tester, 'final'),
      _c(darkTheme.lookup(Scopes.keyword)!.color!),
    );
  });

  testWidgets('CodeTheme extension and widget theme override', (tester) async {
    final custom = lightTheme.extend(
      styles: {Scopes.keyword: const Style(color: 0xFF123456)},
    );
    await tester.pumpWidget(
      _app(
        const CodeView('final x;', language: dartLanguage),
        theme: ThemeData(extensions: [CodeTheme(light: custom)]),
      ),
    );
    expect(_colorOf(tester, 'final'), const Color(0xFF123456));

    await tester.pumpWidget(
      _app(
        const CodeView('final x;', language: dartLanguage, theme: darkTheme),
        theme: ThemeData(extensions: [CodeTheme(light: custom)]),
      ),
    );
    expect(
      _colorOf(tester, 'final'),
      _c(darkTheme.lookup(Scopes.keyword)!.color!),
    );
  });

  testWidgets('line numbers', (tester) async {
    await tester.pumpWidget(
      _app(
        const CodeView(
          'a\nb\nc',
          language: dartLanguage,
          lineNumbers: true,
          firstLineNumber: 10,
        ),
      ),
    );
    expect(find.text('10'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('13'), findsNothing);
  });

  testWidgets('wrapped rows with highlighted lines and custom builders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CodeView(
          'one\ntwo\nthree',
          language: plainTextLanguage,
          wrap: true,
          lineNumbers: true,
          highlightedLines: const {2},
          highlightColor: const Color(0xFFFF0000),
          gutterBuilder: (context, number, highlighted) =>
              SizedBox(width: 30, child: Text(highlighted ? '>' : '$number')),
          lineBuilder: (context, line, child) =>
              KeyedSubtree(key: ValueKey('line$line'), child: child),
        ),
      ),
    );
    expect(find.text('>'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const ValueKey('line2')), findsOneWidget);
    final box = tester.widget<ColoredBox>(
      find
          .ancestor(of: find.text('>'), matching: find.byType(ColoredBox))
          .first,
    );
    expect(box.color, const Color(0xFFFF0000));
  });

  for (final spacing in [null, 2.0]) {
    testWidgets('wrapped lines never wrap line numbers ($spacing)', (
      tester,
    ) async {
      final code = List.generate(
        120,
        (i) =>
            'final v$i = compute($i) + other * 2; // a line long enough to wrap',
      ).join('\n');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: TextTheme(bodyMedium: TextStyle(letterSpacing: spacing)),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: CodeView(
                  code,
                  language: dartLanguage,
                  wrap: true,
                  lineNumbers: true,
                ),
              ),
            ),
          ),
        ),
      );
      for (final number in ['1', '10', '100', '120']) {
        expect(
          tester.getSize(find.text(number)).height,
          closeTo(14 * 1.5, 0.5),
          reason: 'line number $number wrapped',
        );
      }
    });
  }

  for (final wrap in [false, true]) {
    testWidgets('onTokenTap reports the tapped token (wrap: $wrap)', (
      tester,
    ) async {
      final tapped = <CodeToken>[];
      await tester.pumpWidget(
        _app(
          CodeView(
            'final total = compute(1);\nreturn total;',
            language: dartLanguage,
            wrap: wrap,
            lineNumbers: wrap,
            onTokenTap: tapped.add,
          ),
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('compute'));
      await tester.pump();
      expect(tapped.single.text, 'compute');
      expect(tapped.single.scope, Scopes.function);
      expect(tapped.single.line, 0);

      await tester.tapOnText(find.textRange.ofSubstring('return'));
      await tester.pump();
      expect(tapped.last.text, 'return');
      expect(tapped.last.line, 1);
    });
  }

  testWidgets('spanBuilder replaces token spans', (tester) async {
    await tester.pumpWidget(
      _app(
        CodeView(
          'final x = 1;',
          language: dartLanguage,
          spanBuilder: (context, token, style) => TextSpan(
            text: token.text,
            style: token.scope == Scopes.keyword
                ? const TextStyle(color: Color(0xFF00FF00))
                : style,
          ),
        ),
      ),
    );
    expect(_colorOf(tester, 'final'), const Color(0xFF00FF00));
    expect(_colorOf(tester, '1'), _c(lightTheme.lookup(Scopes.number)!.color!));
  });

  testWidgets('large code in bounded height builds only visible rows', (
    tester,
  ) async {
    final code = List.generate(5000, (i) => 'var v$i = $i;').join('\n');
    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 300,
          child: CodeView(code, language: dartLanguage, lineNumbers: true),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5000'), findsNothing);
    final rows = _leaves(tester).where((l) => l.$1 == 'var').length;
    expect(rows, lessThan(60));
  });

  testWidgets('isolate path shows plain text, then highlights', (tester) async {
    final highlighter = CodeHighlighter(isolateThreshold: 10);
    await tester.pumpWidget(
      _app(
        CodeView(
          'final value = 1;',
          language: dartLanguage,
          highlighter: highlighter,
        ),
      ),
    );
    expect(_colorOf(tester, 'final'), isNull);
    await tester.runAsync(
      () => highlighter.highlight('final value = 1;', dartLanguage),
    );
    await tester.pumpAndSettle();
    expect(
      _colorOf(tester, 'final'),
      _c(lightTheme.lookup(Scopes.keyword)!.color!),
    );
  });

  testWidgets('detects the language when none is given', (tester) async {
    await tester.pumpWidget(
      _app(
        const CodeView(
          'def main():\n    return None\n',
          detectLanguages: allLanguages,
        ),
      ),
    );
    expect(
      _colorOf(tester, 'def'),
      _c(lightTheme.lookup(Scopes.keyword)!.color!),
    );
  });

  testWidgets('header is shown', (tester) async {
    await tester.pumpWidget(
      _app(
        const CodeView(
          'x',
          language: plainTextLanguage,
          header: Text('main.dart'),
        ),
      ),
    );
    expect(find.text('main.dart'), findsOneWidget);
  });

  group('CodeHighlighter', () {
    testWidgets('preload compiles languages in idle time', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final done = CodeHighlighter.shared.preload([dartLanguage, jsonLanguage]);
      await tester.pumpAndSettle();
      await done;
    });

    test('caches results and evicts the oldest', () {
      final highlighter = CodeHighlighter(cacheSize: 2);
      final a = highlighter.highlightSync('a', dartLanguage);
      expect(highlighter.highlightSync('a', dartLanguage), same(a));
      highlighter.highlightSync('b', dartLanguage);
      highlighter.highlightSync('c', dartLanguage);
      expect(highlighter.cached('a', dartLanguage), isNull);
      expect(highlighter.cached('c', dartLanguage), isNotNull);
    });
  });

  group('HighlightTextController', () {
    testWidgets('spans cover the text exactly and follow edits', (
      tester,
    ) async {
      final controller = HighlightTextController(
        text: 'final a = 1;\r\nvar b;',
        language: dartLanguage,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(TextField(controller: controller, maxLines: null)),
      );
      final context = tester.element(find.byType(TextField));

      String plain(TextSpan span) => span.toPlainText();
      var span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      expect(plain(span), controller.text);

      controller.text = 'final a = "s";\r\nvar b;';
      span = controller.buildTextSpan(context: context, withComposing: false);
      expect(plain(span), controller.text);
      final leaves = <(String, Color?)>[];
      span.visitChildren((child) {
        if (child is TextSpan && child.text != null) {
          leaves.add((child.text!, child.style?.color));
        }
        return true;
      });
      expect(
        leaves.firstWhere((l) => l.$1 == '"s"').$2,
        _c(lightTheme.lookup(Scopes.string)!.color!),
      );
    });

    testWidgets('composing range is underlined', (tester) async {
      final controller = HighlightTextController(
        text: 'final abc;',
        language: dartLanguage,
      );
      addTearDown(controller.dispose);
      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 6, end: 9),
      );
      await tester.pumpWidget(_app(TextField(controller: controller)));
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: true,
      );
      TextSpan? composed;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == 'abc') composed = child;
        return true;
      });
      expect(composed?.style?.decoration, TextDecoration.underline);
    });

    test('changing language notifies listeners', () {
      final controller = HighlightTextController(
        text: '{}',
        language: dartLanguage,
      );
      var notified = 0;
      controller.addListener(() => notified++);
      controller.language = jsonLanguage;
      expect(notified, 1);
      expect(controller.result.language, same(jsonLanguage));
      controller.dispose();
    });
  });
}
