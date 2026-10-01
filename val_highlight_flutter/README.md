<p align="center">
  <img src="https://raw.githubusercontent.com/useval/highlight/main/assets/plusfinity-logo.png" width="112" alt="Plusfinity logo">
</p>

<h1 align="center">val_highlight_flutter</h1>

<p align="center"><strong>Syntax-highlighted code for Flutter.</strong></p>

<p align="center">
  Show code with <code>CodeView</code> and edit it with <code>CodeField</code>.<br>
  55 languages, eight themes, and large files that stay smooth.
</p>

<p align="center">
  <a href="https://pub.dev/packages/val_highlight_flutter"><img src="https://img.shields.io/pub/v/val_highlight_flutter?color=F47C3C" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/val_highlight_flutter/score"><img src="https://img.shields.io/pub/points/val_highlight_flutter?color=44C11F" alt="Pub Points"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-1687D2.svg" alt="BSD-3-Clause license"></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/val_highlight">⚙️ Engine</a> ·
  <a href="https://github.com/useval/highlight">💻 GitHub</a> ·
  <a href="https://pub.dev/packages/val_highlight_flutter">📦 pub.dev</a>
</p>

---

## ✨ Why val_highlight_flutter?

- **Two widgets, one line each** — `CodeView(source, language: dartLanguage)`
  to show code, `CodeField(controller: …)` to edit it.
- **Smooth on large files** — a 20,000-line file scrolls with no dropped
  frames, and typing in a 2,000-line editor takes about 14 ms per keystroke.
- **Real editing** — Tab and Shift+Tab indent and outdent, Enter keeps the
  indentation, and every edit re-highlights only what it can affect.
- **Native rendering** — plain Flutter text, no WebView and no platform
  code. Works on Android, iOS, macOS, Windows, Linux and the web.
- **Follows your app** — light and dark themes switch with the app, and
  `CodeTheme` sets defaults once for every code block.
- **Interactive** — tap handlers and custom spans per token, for
  jump-to-definition, links and tooltips.

## 🛠️ Quick start

```bash
flutter pub add val_highlight_flutter
```

```dart
import 'package:val_highlight_flutter/val_highlight_flutter.dart';
import 'package:val_highlight/languages/dart.dart';

CodeView(source, language: dartLanguage)
```

This package re-exports the core API of
[`val_highlight`](https://pub.dev/packages/val_highlight). Languages and
themes are separate imports under `package:val_highlight/languages/` and
`package:val_highlight/themes/`, so an app ships only what it uses.

## 📄 CodeView

```dart
CodeView(
  source,
  language: kotlinLanguage,
  lineNumbers: true,
  highlightedLines: {3, 4},
  wrap: true,
  header: const Text('MainActivity.kt'),
  onTokenTap: (token) => print('${token.scope}: ${token.text}'),
)
```

- **Line numbers** — `lineNumbers`, `firstLineNumber`; a custom
  `gutterBuilder`.
- **Highlighted lines** — `highlightedLines`, `highlightColor`.
- **Wrapping** — `wrap: true`, or scroll long lines horizontally.
- **Selection and copying** — on by default (`selectable`); line numbers are
  never copied.
- **Custom rendering** — `lineBuilder` wraps each row, `header` adds a title
  bar or copy button, `spanBuilder` replaces any token's span.
- **Tappable tokens** — `onTokenTap` receives each token's text, offsets,
  line and scopes.
- **Unknown languages** — with no `language`, pass
  `detectLanguages: allLanguages` to detect it; otherwise the generic
  grammar highlights what most languages share (`fallbackLanguage` changes
  this).
- **Large files** — code with more than `virtualizeAbove` lines (1,000 by
  default), placed where its height is bounded, renders lazily. Inputs
  above 50,000 characters are highlighted in a background isolate while
  plain text shows.

## ⌨️ CodeField

```dart
final controller = HighlightTextController(language: dartLanguage);

CodeField(controller: controller, expands: true)
```

`CodeField` is a `TextField` for code:

- monospace, no autocorrect or smart quotes;
- Tab and Shift+Tab indent and outdent (`indent` sets the unit);
- Enter keeps the current indentation, adding a level after `{`, `[`, `(`
  or `:`;
- each edit re-scans only the lines it can affect.

Flutter lays out a text field's whole text on every change, and styled runs
make that slower. So for documents over 300 lines, `CodeField` colours only
the visible lines plus a margin, and the coloured window follows scrolling.

`HighlightTextController` also works in a plain `TextField` for short
documents. For long ones, use `CodeField`, or set `controller.window`
yourself.

## 🎨 Themes

The theme follows the app's brightness: `lightTheme` or `darkTheme` by
default. Choose any of the eight built-in themes, a VS Code theme, or your
own:

```dart
CodeView(source, language: dartLanguage, theme: midnightTheme)
```

Set app-wide defaults once:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [
      CodeTheme(
        light: sepiaTheme,
        dark: dimTheme,
        textStyle: const TextStyle(fontFamily: 'JetBrains Mono'),
        lineNumbers: true,
      ),
    ],
  ),
)
```

## ⚙️ CodeHighlighter

`CodeHighlighter.shared` highlights for every widget, with a result cache.
Create your own to change the isolate threshold or cache size, or to resolve
languages named inside code, such as Markdown fences:

```dart
final highlighter = CodeHighlighter(registry: allLanguagesRegistry());

CodeView(markdown, language: markdownLanguage, highlighter: highlighter)
```

Call `CodeHighlighter.shared.preload([dartLanguage, …])` at startup to
compile languages during idle frames, so the first code shown in each has no
compile delay (1–3 ms per language otherwise).

## 🧱 Lower level

- `CodeStyles` converts a `ValTheme` into cached `TextStyle`s.
- `lineSpans`, `documentSpans` and `exactSpans` turn a `HighlightResult` into
  `TextSpan`s for your own widgets.

## 📸 Screenshots

| <img alt="Dart in CodeView with line numbers and highlighted lines" src="https://raw.githubusercontent.com/useval/highlight/main/screenshots/code-view.png"><br>**CodeView**<br>Line numbers, highlighted lines, selection. | <img alt="Python being edited in CodeField" src="https://raw.githubusercontent.com/useval/highlight/main/screenshots/editor.png"><br>**CodeField**<br>An editor that highlights as you type. | <img alt="Markdown with bash, Python and JSON code fences" src="https://raw.githubusercontent.com/useval/highlight/main/screenshots/embedded.png"><br>**Languages inside languages**<br>Markdown fences, HTML with CSS and JavaScript. |
|---|---|---|

## ⚡ Performance

Frame timings on a MacBook, in profile mode:

| Scenario | Build time avg / p90 | Missed frames |
|---|---|---|
| Scroll a 20,000-line `CodeView` | 1.3 / 2.6 ms | 0 of 926 |
| Same, wrapped | 1.3 / 2.6 ms | 0 of 927 |
| Scroll 800 lines as one text block | 0.3 / 0.4 ms | 0 of 915 |
| Type in a 2,000-line `CodeField` | 14.3 / 15.7 ms | 4 of 120 |
| Type in a plain `TextField`, same text, no highlighting | 17.4 / 17.6 ms | 120 of 120 |
| Scroll a 2,000-line `CodeField` | 3.7 / 7.1 ms | 15 of 926 |

The missed frames while scrolling a `CodeField` happen when its coloured
window moves, which makes Flutter lay out the whole field again.

## 🧪 Example

The [example](example) app has a gallery of every language and theme, a live
editor, and a large file rendered lazily.

## Built by Val

`val_highlight_flutter` is part of [Val](https://useval.io), the live visual
layer for AI agents.

## 💬 Community

Issues and pull requests are welcome on
[GitHub](https://github.com/useval/highlight); see the
[contributing guide](https://github.com/useval/highlight/blob/main/CONTRIBUTING.md). If the package helps your
project, consider giving it a like on
[pub.dev](https://pub.dev/packages/val_highlight_flutter) or a star on
GitHub.

## 📄 License

BSD 3-Clause — see [LICENSE](LICENSE).
