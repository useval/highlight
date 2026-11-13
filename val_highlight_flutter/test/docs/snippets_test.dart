// The Flutter code samples written inline on the docs pages (docs/ at the
// repository root), compiled and pumped here so they keep working. The
// examples with previews live in tool/screenshots/examples/ and are
// rendered by the screenshot generator instead.
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = 'void main() {\n  print(1);\n}\n';

Widget _app(Widget child, {ThemeData? theme, ThemeData? darkTheme}) =>
    MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('code-view.mdx', (tester) async {
    final tapped = <String>[];
    void openDefinition(String name) => tapped.add(name);
    final views = [
      CodeView(
        source,
        language: dartLanguage,
        lineNumbers: true,
        gutterBuilder: (context, lineNumber, highlighted) => SizedBox(
          width: 32,
          child: Text(
            '$lineNumber',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: highlighted ? FontWeight.bold : null),
          ),
        ),
      ),
      CodeView(
        source,
        language: dartLanguage,
        onTokenTap: (token) {
          if (token.scope == Scopes.type) openDefinition(token.text);
        },
      ),
      const CodeView(source, fallbackLanguage: plainTextLanguage),
    ];
    for (final view in views) {
      await tester.pumpWidget(_app(view));
    }
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Expanded(
              child: CodeView(
                List.filled(600, source).join(),
                language: dartLanguage,
                lineNumbers: true,
                virtualizeAbove: 500,
              ),
            ),
          ],
        ),
      ),
    );
    final highlighter = CodeHighlighter(
      registry: allLanguagesRegistry(),
      isolateThreshold: 100000,
      cacheSize: 64,
    );
    expect(highlighter.cacheSize, 64);
    // Compiled only: preload schedules idle tasks the test binding would
    // leave pending.
    Future<void> preload() => CodeHighlighter.shared.preload([
      dartLanguage,
      kotlinLanguage,
      jsonLanguage,
    ]);
    expect(preload, isNotNull);
    CodeHighlighter.shared.clearCache();
  });

  testWidgets('code-field.mdx', (tester) async {
    final controller = HighlightTextController(
      language: dartLanguage,
      text: source,
    );
    addTearDown(controller.dispose);
    var toggled = 0;
    void myToggle() => toggled++;
    final fields = [
      CodeField(
        controller: controller,
        editing: const CodeEditing(autoClose: false),
      ),
      CodeField(
        controller: controller,
        indent: '    ',
        editing: CodeEditing(
          syntax: EditingSyntax.cStyle.copyWith(quotes: '"\'`'),
        ),
      ),
      CodeField(
        controller: controller,
        lineNumbers: true,
        highlightCurrentLine: true,
        highlightedLines: {3, 4},
      ),
      CodeField(controller: controller, shortcuts: const {}),
      Actions(
        actions: {
          ToggleCommentIntent: CallbackAction<ToggleCommentIntent>(
            onInvoke: (_) => myToggle(),
          ),
        },
        child: CodeField(controller: controller),
      ),
    ];
    for (final field in fields) {
      await tester.pumpWidget(_app(field));
    }
    // The Actions override replaces the default toggle.
    await tester.showKeyboard(find.byType(EditableText));
    controller.selection = const TextSelection.collapsed(offset: 0);
    final apple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    await tester.sendKeyDownEvent(
      apple ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(
      apple ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
    );
    expect(toggled, 1);
    expect(controller.text, source);

    controller.selection = const TextSelection.collapsed(offset: 0);
    final updated = toggleComment(
      controller.value,
      EditingSyntax.of(controller.language),
      result: controller.result,
    );
    if (updated != null) controller.value = updated;
    expect(controller.text, startsWith('// void main()'));
  });

  testWidgets('text-field.mdx', (tester) async {
    final controller = HighlightTextController(
      language: sqlLanguage,
      text: 'SELECT 1;',
    );
    addTearDown(controller.dispose);
    controller.window = (first: 0, last: 199);
    await tester.pumpWidget(
      _app(
        TextField(
          controller: controller,
          maxLines: null,
          inputFormatters: [CodeEditingFormatter(controller: controller)],
        ),
      ),
    );
  });

  testWidgets('themes.mdx', (tester) async {
    final controller = HighlightTextController(
      language: dartLanguage,
      theme: sepiaTheme,
    );
    addTearDown(controller.dispose);
    const codeTheme = CodeTheme(
      light: sepiaTheme,
      dark: dimTheme,
      textStyle: TextStyle(fontFamily: 'JetBrains Mono'),
      lineNumbers: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [codeTheme]),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [codeTheme],
        ),
        home: const Scaffold(
          body: CodeView(source, language: dartLanguage, theme: midnightTheme),
        ),
      ),
    );
    final context = tester.element(find.byType(CodeView));
    expect(CodeTheme.resolve(context), same(sepiaTheme));
    expect(CodeTheme.textStyleOf(context).fontSize, 14);
    expect(CodeTheme.textStyleOf(context).height, 1.5);

    const myTheme = ValTheme(
      name: 'my-theme',
      dark: true,
      root: Style(color: 0xFFE6E6E6, background: 0xFF1E1E2E),
      styles: {
        Scopes.comment: Style(color: 0xFF7F849C, italic: true),
        Scopes.keyword: Style(color: 0xFFCBA6F7, bold: true),
      },
    );
    expect(myTheme.lookup('keyword.control.flow')?.bold, isTrue);
  });
}
