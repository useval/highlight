// Generates the README showcase images into `screenshots/` at the repository
// root.
//
// Not a test: it renders the widgets into PNGs. It lives under `tool/` so
// `flutter test` does not pick it up with the real suite, and it runs through
// the test harness only because that is the supported way to rasterise a
// Flutter widget to a file without opening a window.
//
// Run it with `just screenshots`.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';
import 'package:val_highlight/themes/midnight.dart';
import 'package:val_highlight/themes/sepia.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// Where the images land, relative to this file.
const _out = '../../../screenshots';

/// Logical width of one card.
const _cardWidth = 560.0;
const _pagePadding = 26.0;

const _dart = r'''
import 'package:flutter/material.dart';

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
  });
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
        extensions: const [
          // JetBrains Mono draws `=>` as an arrow; show the source as typed.
          CodeTheme(
            textStyle: TextStyle(fontFeatures: [FontFeature.disable('calt')]),
          ),
        ],
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
