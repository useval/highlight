<h1 align="center">val_highlight</h1>

<p align="center"><strong>Syntax highlighting for Dart and Flutter.</strong></p>

<p align="center">
  A pure-Dart engine with 55 languages, incremental updates and themes,<br>
  plus Flutter widgets to show and edit code.
</p>

<p align="center">
  <a href="https://pub.dev/packages/val_highlight"><img src="https://img.shields.io/pub/v/val_highlight?label=val_highlight&color=F47C3C" alt="val_highlight on pub.dev"></a>
  <a href="https://pub.dev/packages/val_highlight_flutter"><img src="https://img.shields.io/pub/v/val_highlight_flutter?label=val_highlight_flutter&color=F47C3C" alt="val_highlight_flutter on pub.dev"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-1687D2.svg" alt="BSD-3-Clause license"></a>
</p>

---

## 📦 Packages

| Package | Use it for |
|---|---|
| [`val_highlight`](val_highlight/) | The engine, in pure Dart: 55 languages plus a generic fallback, flat tokens, incremental updates, language detection, 8 themes, VS Code theme import and HTML output. Runs on the VM, in Flutter and on the web. |
| [`val_highlight_flutter`](val_highlight_flutter/) | Flutter widgets: `CodeView` to show code, `CodeField` to edit it, `HighlightTextController`, and `CodeTheme` for app-wide defaults. |

A `val_highlight_jaspr` package is planned, built on the same engine.

```dart
// Flutter
CodeView(source, language: dartLanguage)

// Pure Dart
final html = const Highlighter().toHtml(source, language: dartLanguage);
```

## ⚡ Performance

`just bench` compiles to native code, highlights a Dart file and renders it
to HTML (best of 5 runs, on a MacBook):

| Lines | Highlight + HTML |
|---|---|
| 600 | 1.5 ms |
| 2,400 | 4.3 ms |
| 9,600 | 13.9 ms |

`just bench-languages` measures about 256 KB of realistic source per
language on native code. It averages about 43 MB/s, from 30 MB/s (HTML) to
64 MB/s (Markdown). `just bench-js` runs the same test compiled to
JavaScript, where it averages about 62 MB/s.

With incremental highlighting, one keystroke in the 9,600-line file takes
about 0.4 ms. Frame timings for scrolling and typing in Flutter are in the
[`val_highlight_flutter` README](val_highlight_flutter/README.md)
(`just bench-frames`).

### How it works

- **One pass, no copying.** The scanner walks the source by offset, never
  copies it, and time grows in step with input size.
- **First-character dispatch.** Each rule's pattern is analysed once to find
  the characters it can start with. The scanner skips positions where no
  rule can start, and tries only the rules that can. Rules anchored with `^`
  are tried only at line starts. States with a rule that can start almost
  anywhere fall back to one combined regular expression. Both paths give
  identical results, and fuzz tests check this.
- **Plain-Dart matchers.** On native platforms, most patterns run as small
  Dart matchers instead of the regular expression engine, with identical
  results (checked by fuzz tests). Browsers compile regular expressions to
  machine code, so the web keeps using them.
- **Flat output.** Tokens are two integer lists, not a tree of objects.

## 🛠️ Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces).
The Flutter version is pinned in `.fvmrc` (3.44.2), and the `justfile` runs
everything through [FVM](https://fvm.app):

```sh
just setup            # install the pinned SDK and fetch dependencies
just check            # format check, analyze, all tests (VM and JS)
just devices          # list available devices
just example-flutter  # run the Flutter example; asks which device to use
just example-web      # run the Flutter example in Chrome
just example-dart     # run the pure-Dart example
just bench            # benchmark
```

Run `just` with no arguments to list every command.

**Note:** with Xcode 27, Flutter 3.44.2 (the pinned version) fails to build
for iOS, and to build macOS apps in profile or release mode, such as the
frame benchmark. Its architecture check rejects Xcode 27's `lipo` output.
Flutter 3.47 builds both. Web, Android and macOS debug builds work with the
pin.

## Built by Val

`val_highlight` is part of [Val](https://useval.io), the live visual layer
for AI agents.

## 💬 Community

Issues and pull requests are welcome. Run `just check` before opening a pull
request.

## 📄 License

BSD 3-Clause — see [LICENSE](LICENSE).
