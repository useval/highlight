// Generates the README showcase images into `screenshots/` at the repository
// root, and the docs' images into `docs/images/`.
//
// The docs' component, theme and getting-started images are rendered from
// the example files in `tool/screenshots/examples/`, which the docs pages
// show beside them, so a picture and its code cannot drift apart.
//
// Not a test: it renders the widgets into PNGs. It lives under `tool/` so
// `flutter test` does not pick it up with the real suite, and it runs through
// the test harness only because that is the supported way to rasterise a
// Flutter widget to a file without opening a window.
//
// Run it with `just screenshots`.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';
import 'package:val_highlight_flutter/material.dart';

import 'examples/code_field/editor.dart' as code_field_editor;
import 'examples/code_view/basic.dart' as code_view_basic;
import 'examples/code_view/detect.dart' as code_view_detect;
import 'examples/code_view/header.dart' as code_view_header;
import 'examples/code_view/line_numbers.dart' as code_view_line_numbers;
import 'examples/code_view/markdown.dart' as code_view_markdown;
import 'examples/code_view/span_builder.dart' as code_view_span_builder;
import 'examples/code_view/wrap.dart' as code_view_wrap;
import 'examples/getting_started/app.dart' as getting_started_app;
import 'examples/rendering/inline_spans.dart' as rendering_inline_spans;
import 'examples/text_field/query.dart' as text_field_query;
import 'examples/themes/sample.dart' as themes_sample;

/// Where the images land, relative to this file.
const _out = '../../../screenshots';

/// The docs' images, at 2× for high-density screens (the README's are 1×).
/// Relative to the package root, where `flutter test` runs.
const _docsOut = '../docs/images';

/// Renders for the company website's val_highlight page: the same examples
/// with no page or rounding around them (the site draws its own frame), at
/// 3×, and the frames of the typing clip. Under `build/`, so never committed;
/// the website's `npm run product-assets` runs this group (`site:`).
const _siteOut = 'build/site';

/// What the typing clip types into a `CodeField`.
const _typed = '''Stream<int> countdown(int from) async* {
  for (var i = from; i > 0; i--) {
    yield i; // one tick a second
    await Future.delayed(second);
  }
}''';

/// One docs image per example file: `examples/<page>/<name>.dart` renders to
/// `docs/images/<page>/<name>.png`. `test/docs/api_reference_test.dart`
/// checks that every example file is listed here.
final _examples = <String, Widget>{
  'code_view/basic': const code_view_basic.GreetingSource(),
  'code_view/line_numbers': const code_view_line_numbers.Excerpt(),
  'code_view/header': const code_view_header.FileCard(),
  'code_view/wrap': const code_view_wrap.Wrapped(),
  'code_view/span_builder': const code_view_span_builder.LinkedTypes(),
  'code_view/detect': const code_view_detect.Detected(),
  'code_view/markdown': const code_view_markdown.ReleaseNotes(),
  'code_field/editor': const code_field_editor.OrderEditor(),
  'text_field/query': const text_field_query.QueryField(),
  'rendering/inline_spans': const rendering_inline_spans.Message(),
};

/// Where each example puts the caret, as a user would: after this text.
/// An editor with a caret shows its current line and bracket match.
const _carets = {
  'code_field/editor': 'def total(',
  'text_field/query': 'WHERE status',
};

/// Logical width of a docs preview, and the page around it: 492 in all,
/// the width the docs site shows images at.
const _previewWidth = 460.0;
const _previewPadding = 16.0;

/// Writes the frame under [key] to [path] at twice its logical size.
///
/// `matchesGoldenFile` captures at 1×, which reads soft on a high-density
/// screen; the docs site shows these images at their logical width.
Future<void> _save2x(
  WidgetTester tester,
  Key key,
  String path, {
  double ratio = 2,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Logical width of one card.
const _cardWidth = 560.0;
const _pagePadding = 26.0;

const _dart = r'''
import 'package:material_ui/material_ui.dart';

/// Shows a greeting that counts taps.
class Greeting extends StatefulWidget {
  const Greeting({super.key, required this.name});

  final String name;

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _taps++),
      child: Text('Hello, ${widget.name}! Taps: $_taps'),
    );
  }
}''';

const _tsx = r'''
import { useState } from "react";

type Props = {
  items: string[];
  onPick?: (item: string) => void;
};

export function Picker({ items, onPick }: Props) {
  const [query, setQuery] = useState("");
  const shown = items.filter((i) => i.includes(query));

  return (
    <div className="picker">
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {shown.length === 0 && <p>No match for "{query}"</p>}
      <ul>
        {shown.map((item) => (
          <li key={item} onClick={() => onPick?.(item)}>
            {item}
          </li>
        ))}
      </ul>
    </div>
  );
}''';

const _markdown = '''
# Release notes

**v2.1** adds a `--watch` flag and *quicker* rebuilds.

```bash
dart pub global activate shipit
shipit build --watch --out=build/web
```

```python
def changed(files: list[str]) -> bool:
    return any(f.endswith(".dart") for f in files)
```

```json
{ "watch": true, "delay": 250, "ignore": ["build/"] }
```

> Each fence is highlighted in its own language.''';

const _python = '''
from dataclasses import dataclass


@dataclass
class Order:
    sku: str
    qty: int = 1
    price: float = 0.0

    @property
    def total(self) -> float:
        return self.qty * self.price


orders = [Order("apple", 3, 0.5), Order("pear", 2, 1.25)]
print(f"Total: {sum(o.total for o in orders):.2f}")''';

void main() {
  setUpAll(_loadFonts);
  // The getting-started app is a whole MaterialApp; keep the debug banner
  // out of its picture.
  WidgetsApp.debugAllowBannerOverride = false;

  _docs();
  _site();

  _shoot(
    'code-view',
    title: 'greeting.dart',
    theme: lightTheme,
    child: const CodeView(
      _dart,
      language: dartLanguage,
      theme: lightTheme,
      lineNumbers: true,
      highlightedLines: {19, 20},
    ),
  );

  _shoot(
    'dark-theme',
    title: 'picker.tsx',
    theme: midnightTheme,
    child: const CodeView(_tsx, language: tsxLanguage, theme: midnightTheme),
  );

  _shoot(
    'embedded',
    title: 'CHANGELOG.md',
    theme: sepiaTheme,
    child: CodeView(
      _markdown,
      language: markdownLanguage,
      theme: sepiaTheme,
      wrap: true,
      highlighter: CodeHighlighter(registry: allLanguagesRegistry()),
    ),
  );

  _shoot(
    'editor',
    title: 'orders.py',
    theme: darkTheme,
    // A focused field has a blinking caret, so the frame never settles.
    settle: false,
    child: const _Editor(),
  );
}

void _shoot(
  String name, {
  required String title,
  required ValTheme theme,
  required Widget child,
  bool settle = true,
}) {
  testWidgets(name, (tester) async {
    const width = _pagePadding * 2 + _cardWidth;
    tester.view.physicalSize = const Size(width * 2, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Showcase(title: title, theme: theme, child: child),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byKey(_Showcase.frameKey),
      matchesGoldenFile('$_out/$name.png'),
    );
    // The same scene at 2×, for the docs' overview.
    await _save2x(tester, _Showcase.frameKey, '$_docsOut/showcase/$name.png');
  });
}

/// The docs' images.
void _docs() {
  for (final MapEntry(key: name, value: example) in _examples.entries) {
    testWidgets('docs: $name', (tester) async {
      _size(tester, 1800);
      await tester.pumpWidget(_Preview(child: example));
      await tester.pumpAndSettle();
      final caret = _carets[name];
      if (caret != null) {
        // Focus the field and put the caret where a user would have.
        await tester.showKeyboard(find.byType(EditableText));
        final controller = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        final at = controller.text.indexOf(caret) + caret.length;
        controller.selection = TextSelection.collapsed(offset: at);
        // A focused field has a blinking caret, so the frame never settles.
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _save2x(tester, _Preview.frameKey, '$_docsOut/$name.png');
    });
  }

  // The theme gallery: the same sample in every built-in theme.
  for (final theme in allThemes) {
    testWidgets('docs: theme ${theme.name}', (tester) async {
      _size(tester, 1800);
      await tester.pumpWidget(
        _Preview(child: themes_sample.ThemeSample(theme: theme)),
      );
      await tester.pumpAndSettle();
      await _save2x(
        tester,
        _Preview.frameKey,
        '$_docsOut/themes/${theme.name}.png',
      );
    });
  }

  // The getting-started app, whole, in a small phone-shaped window.
  testWidgets('docs: getting_started/app', (tester) async {
    _size(tester, 1800);
    const key = ValueKey('getting-started');
    await tester.pumpWidget(
      const Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: _previewWidth + 2 * _previewPadding,
            height: 220,
            child: getting_started_app.App(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _save2x(tester, key, '$_docsOut/getting_started/app.png');
  });
}

/// The website's renders: bare, at 3×.
void _site() {
  void size(WidgetTester tester, {double ratio = 3}) {
    tester.view.physicalSize = Size(_previewWidth * ratio, 3000);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
  }

  for (final MapEntry(key: name, value: example) in _examples.entries) {
    testWidgets('site: $name', (tester) async {
      size(tester);
      await tester.pumpWidget(_Preview(bare: true, child: example));
      await tester.pumpAndSettle();
      final caret = _carets[name];
      if (caret != null) {
        await tester.showKeyboard(find.byType(EditableText));
        final controller = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        final at = controller.text.indexOf(caret) + caret.length;
        controller.selection = TextSelection.collapsed(offset: at);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _save2x(tester, _Preview.frameKey, '$_siteOut/$name.png', ratio: 3);
    });
  }

  for (final theme in allThemes) {
    testWidgets('site: theme ${theme.name}', (tester) async {
      size(tester);
      await tester.pumpWidget(
        _Preview(bare: true, child: themes_sample.ThemeSample(theme: theme)),
      );
      await tester.pumpAndSettle();
      await _save2x(
        tester,
        _Preview.frameKey,
        '$_siteOut/themes/${theme.name}.png',
        ratio: 3,
      );
    });
  }

  // The typing clip: [_typed] arrives a few characters a frame in a
  // CodeField, with the caret at the end — the editor re-highlighting as it
  // grows. One frame every 80 ms (12.5 fps), at 2× so the video stays small.
  testWidgets('site: typing frames', (tester) async {
    size(tester, ratio: 2);
    final dir = Directory('$_siteOut/typing-frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final controller = HighlightTextController(language: dartLanguage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _Preview(
        bare: true,
        child: Builder(
          builder: (context) {
            final theme = CodeTheme.resolve(context, controller.theme);
            return ColoredBox(
              color: Color(theme.root.background!),
              child: SizedBox(
                height: 200,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CodeField(
                    controller: controller,
                    lineNumbers: true,
                    highlightCurrentLine: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    var frame = 0;
    Future<void> capture() => _save2x(
      tester,
      _Preview.frameKey,
      '${dir.path}/${(frame++).toString().padLeft(3, '0')}.png',
    );
    const step = 4;
    for (var n = 0; n <= _typed.length; n += step) {
      final text = _typed.substring(0, n);
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await tester.pump(const Duration(milliseconds: 80));
      await capture();
    }
    controller.value = const TextEditingValue(
      text: _typed,
      selection: TextSelection.collapsed(offset: _typed.length),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      await capture();
    }
  });
}

void _size(WidgetTester tester, double height) {
  const width = _previewWidth + 2 * _previewPadding;
  tester.view.physicalSize = Size(width * 2, height);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// A docs preview: the example on a white card, on the page colour the docs
/// site letterboxes thumbnails with, in a light Material 3 app.
///
/// The example sits in a vertical scroll view, as code on a page usually
/// does, so its height is its content's.
class _Preview extends StatelessWidget {
  const _Preview({required this.child, this.bare = false});

  static const frameKey = ValueKey('docs-preview');

  final Widget child;

  /// Just the example on white: no page colour, no rounding (for the website).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      builder: (context, child) => CodeTheme(
        data: CodeThemeData(
          brightness: Theme.of(context).brightness,
          // JetBrains Mono draws `=>` as an arrow; show the source as typed.
          textStyle: const TextStyle(
            fontFeatures: [FontFeature.disable('calt')],
          ),
        ),
        child: child!,
      ),
      home: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: frameKey,
            child: Container(
              color: bare ? null : const Color(0xFFECEFF6),
              padding: bare
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(_previewPadding),
              child: SizedBox(
                width: _previewWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(bare ? 0 : 12),
                  child: Material(color: Colors.white, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A `CodeField` with a word selected, so the image reads as an editor.
class _Editor extends StatefulWidget {
  const _Editor();

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _controller = HighlightTextController(
    text: _python,
    language: pythonLanguage,
    theme: darkTheme,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final start = _controller.text.indexOf('total(self)');
    _controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + 'total'.length,
    );
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(darkTheme.root.background!),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CodeField(controller: _controller, focusNode: _focus),
      ),
    );
  }
}

/// One card on a soft page.
class _Showcase extends StatelessWidget {
  const _Showcase({
    required this.title,
    required this.theme,
    required this.child,
  });

  static const frameKey = ValueKey('showcase-frame');

  final String title;
  final ValTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: theme.dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => CodeTheme(
        data: CodeThemeData(
          brightness: Theme.of(context).brightness,
          // JetBrains Mono draws `=>` as an arrow; show the source as typed.
          textStyle: const TextStyle(
            fontFeatures: [FontFeature.disable('calt')],
          ),
        ),
        child: child!,
      ),
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: frameKey,
          child: Container(
            padding: const EdgeInsets.all(_pagePadding),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F6FB), Color(0xFFE4E9F2)],
              ),
            ),
            child: _Card(title: title, theme: theme, child: child),
          ),
        ),
      ),
    );
  }
}

/// The code, drawn as a small window so the image reads as a piece of an app.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.theme, required this.child});

  final String title;
  final ValTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = Color(theme.root.background!);
    final foreground = Color(theme.root.color!);
    final bar = Color.lerp(background, foreground, 0.05)!;
    final hairline = Color.lerp(background, foreground, 0.12)!;

    return SizedBox(
      width: _cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9DEE7)),
          // No shadow: the test renderer draws a blurred shadow as a hard
          // slab, so the border alone separates card from page.
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleBar(
                  title: title,
                  color: bar,
                  hairline: hairline,
                  textColor: foreground.withValues(alpha: 0.6),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A window title bar: three lights and the file name.
class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.color,
    required this.hairline,
    required this.textColor,
  });

  static const _lights = [
    Color(0xFFFF5F57),
    Color(0xFFFEBC2E),
    Color(0xFF28C840),
  ];

  final String title;
  final Color color;
  final Color hairline;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _lights.length; i++) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _lights[i],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads real fonts. `flutter test` renders with a placeholder font in which
/// every glyph is a black box, so the families have to be registered by hand.
Future<void> _loadFonts() async {
  final sdk = _flutterSdkRoot();
  if (sdk != null) {
    final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
    final roboto = ['Regular', 'Medium', 'Bold'];
    await _loadFamily('Roboto', [
      for (final face in roboto) File('$fonts/Roboto-$face.ttf'),
    ]);
    // Text with no font family lands on the test font; draw it with Roboto.
    for (final fallback in const ['FlutterTest', 'Ahem']) {
      await _loadFamily(fallback, [File('$fonts/Roboto-Regular.ttf')]);
    }
    await _loadFamily('MaterialIcons', [
      File('$fonts/MaterialIcons-Regular.otf'),
    ]);
  }
  // The widgets ask for `monospace` by default.
  final mono = [File('tool/screenshots/fonts/JetBrainsMono-Regular.ttf')];
  for (final family in const ['monospace', 'Menlo', 'Consolas']) {
    await _loadFamily(family, mono);
  }
}

Future<void> _loadFamily(String family, List<File> files) async {
  final loader = FontLoader(family);
  for (final file in files.where((file) => file.existsSync())) {
    loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

/// Walks up from the test binary until the SDK's font cache appears.
Directory? _flutterSdkRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return dir;
    }
    if (dir.parent.path == dir.path) return null;
    dir = dir.parent;
  }
  return null;
}
