<p align="center">
  <img src="https://raw.githubusercontent.com/useval/highlight/main/assets/plusfinity-logo.png" width="112" alt="Plusfinity logo">
</p>

<h1 align="center">val_highlight</h1>

<p align="center"><strong>Syntax highlighting in pure Dart.</strong></p>

<p align="center">
  55 languages, incremental updates, themes, and HTML output.<br>
  Runs anywhere Dart runs: the VM, Flutter on every platform, and the web.
</p>

<p align="center">
  <a href="https://pub.dev/packages/val_highlight"><img src="https://img.shields.io/pub/v/val_highlight?color=F47C3C" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/val_highlight/score"><img src="https://img.shields.io/pub/points/val_highlight?color=44C11F" alt="Pub Points"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-1687D2.svg" alt="BSD-3-Clause license"></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/val_highlight_flutter">🦋 Flutter widgets</a> ·
  <a href="https://github.com/useval/highlight">💻 GitHub</a> ·
  <a href="https://pub.dev/packages/val_highlight">📦 pub.dev</a>
</p>

---

## ✨ Why val_highlight?

- **Pure Dart** — no native code, no WebView, no JavaScript. The same engine
  runs in Flutter apps, on servers, in command-line tools and on the web.
- **Linear time** — highlighting time grows in step with input size. On
  native code it averages about 43 MB/s across realistic sources; compiled
  to JavaScript, about 62 MB/s.
- **Incremental** — after an edit, only the lines it can affect are
  re-scanned: about 0.4 ms per keystroke in a 9,600-line file.
- **Light** — every language and theme is a separate `const` import, so an
  app ships only what it uses.
- **Customisable** — themes, grammars, renderers and detection can all be
  extended or replaced, with the same API the built-in languages use.
- **Tested on real code** — every grammar has reviewed golden snapshots,
  edge-case tests and incremental fuzzing, and has been run over tens of
  thousands of real source files.

> For Flutter, use [`val_highlight_flutter`](https://pub.dev/packages/val_highlight_flutter).
> It adds `CodeView`, `CodeField` and theme integration on top of this
> package.

## 🛠️ Quick start

```bash
dart pub add val_highlight
```

```dart
import 'package:val_highlight/val_highlight.dart';
import 'package:val_highlight/languages/dart.dart';

final html = const Highlighter().toHtml(source, language: dartLanguage);
```

Pair the HTML with a theme's stylesheet:

```dart
import 'package:val_highlight/themes/light.dart';

final css = lightTheme.toCss(); // .vh { … } .vh .vh-keyword { … }
```

Or write inline styles, with no stylesheet:

```dart
final result = const Highlighter().highlight(source, language: dartLanguage);
final html = result.toHtml(const HtmlRenderer(theme: lightTheme, wrap: true));
```

## 🌐 Languages

55 languages, plus a generic fallback and plain text:

| Area | Languages |
|---|---|
| Mobile and apps | Dart, Kotlin, Swift, Java, Objective-C, C#, Groovy / Gradle |
| Web | HTML (with embedded CSS and JavaScript; also `.vue`, `.svelte`), CSS, SCSS, Less, JavaScript, TypeScript, JSX, TSX, PHP, GraphQL |
| Systems | C, C++, Rust, Go, Zig, NASM assembly |
| Scripting | Python, Ruby, Lua, Perl, Bash, PowerShell, Batch, R, Julia, Elixir |
| Functional | Haskell, OCaml, F#, Scala, Clojure, Erlang |
| Data and config | JSON, YAML, TOML, XML, INI / properties, Protobuf, SQL, HCL / Terraform, nginx |
| Build and tools | Dockerfile, Makefile, CMake, diff |
| Docs | Markdown (fenced code in any language), LaTeX |
| Other | Solidity |

Import one language with `package:val_highlight/languages/<name>.dart` (for
example `languages/kotlin.dart` for `kotlinLanguage`), or all of them with
`languages/all.dart` (`allLanguages`, `allLanguagesRegistry()`).

Each language knows its aliases (`kt`, `c++`, `yml`, …), file extensions and
file names (`Dockerfile`, `CMakeLists.txt`, `Podfile`, …):

```dart
final registry = allLanguagesRegistry();
registry.lookup('kt');                   // kotlinLanguage
registry.forFileName('lib/main.dart');   // dartLanguage
registry.resolve('something-unknown');   // genericLanguage (the fallback)
```

**Unknown languages.** `genericLanguage` highlights code in any language
reasonably: comments, strings, numbers, common keywords, types, calls and
operators. It is the fallback of `allLanguagesRegistry()` for unknown names
and Markdown fences.

**Detection.** `const LanguageDetector().detect(code, allLanguages)` guesses
from the file name, a `#!` line, or the content.

## 🎨 Themes

`lightTheme`, `darkTheme`, `sepiaTheme`, `dimTheme`, `midnightTheme`,
`forestTheme`, `highContrastLightTheme` and `highContrastDarkTheme`, from
`package:val_highlight/themes/<name>.dart`, or all of them with
`themes/all.dart` (`allThemes`). Every colour meets WCAG AA contrast (4.5:1);
the high-contrast themes meet 7:1.

Adjust a theme, or build one from scratch:

```dart
final mine = lightTheme.extend(
  styles: {Scopes.keyword: const Style(color: 0xFFE8590C, bold: true)},
);
```

Use an existing VS Code theme:

```dart
final theme = ValTheme.fromVsCodeJson(
  File('my-theme-color-theme.json').readAsStringSync(),
);
```

It reads the editor colours and `tokenColors`, matching TextMate scopes the
way VS Code does. Comments and trailing commas are allowed.

## 🧩 Tokens and incremental updates

A `HighlightResult` stores tokens as two flat integer lists that cover the
whole source with no gaps. Each token carries a scope stack such as
`string > interpolation > number`:

```dart
for (final token in result.tokens) {
  print('${token.scopes.join(' > ')}: ${token.text}');
}

// Per line, for renderers:
result.forEachSegment(line, (start, end, stack) { … });
```

For editors, `IncrementalHighlighter` keeps a document highlighted as it
changes:

```dart
final document = IncrementalHighlighter(language: dartLanguage, text: source);
final updated = document.update(editedSource);
```

## 🔧 Changing a built-in language

```dart
// Add or remove keywords; a word can also move to another scope.
final myDart = dartLanguage.withKeywords(
  add: {Scopes.typeBuiltin: ['Widget', 'BuildContext']},
  remove: ['get', 'set'],
);

// Put your own rules first; they win over the built-in ones.
final withTodos = dartLanguage.extend(
  rules: [const TokenRule(r'\bTODO\b', scope: 'todo')],
);

// Replace a named part of a grammar. `grammar.repository.keys` lists them.
final quiet = dartLanguage.extend(repository: {'numbers': []});
```

A new scope such as `todo` only needs a theme entry:
`lightTheme.extend(styles: {'todo': const Style(bold: true)})`.

## ✍️ Writing a grammar

Most grammars need no regular expressions. Building blocks cover what
languages repeat:

```dart
import 'package:val_highlight/advanced.dart';

const iniLanguage = Grammar(
  name: 'ini',
  fileExtensions: ['ini'],
  rules: [
    LineComment(';'),
    LineComment('#', afterSpace: true),
    QuotedString('"'),
    Numbers(),
    KeywordRule({Scopes.literal: ['true', 'false', 'on', 'off']}),
    Operators('='),
  ],
);
```

| Block | Covers |
|---|---|
| `LineComment('//')` | a comment to the end of the line; `afterSpace: true` for `#`-style comments |
| `BlockComment('/*', '*/')` | a delimited comment; `nested: true` where comments nest |
| `QuotedString('"')` | a string with escapes; options for `prefix`, `doubled` quotes, `multiline`, `lastInRun`, a custom `end`, and inner `rules` |
| `Interpolation(r'${', '}')` | an expression inside a string, with balanced braces |
| `Numbers()` | decimals, floats, exponents, hex, binary and octal, digit separators, suffixes |
| `Operators('+-*/=')` | runs of operator characters |
| `Annotation('@')` | annotations, attributes and decorators |
| `Preprocessor('#')` | `#include`-style lines, with `\` continuations |
| `KeywordRule({...})` | word lists per scope, with fallback rules for other words |
| `CommonRules.*` | capitalised types, function calls, and members after `.` |

Blocks are ordinary rules, so they mix freely with `TokenRule`, `RegionRule`
(nested sections such as strings and comments) and `IncludeRule` (reusable
rule lists). Extend `BlockRule` to make your own blocks.

The earliest match wins; among rules that match at the same position, the
first one listed wins. `grammar.validate()` reports mistakes immediately.

More region options:

- `endReferencesBegin: true` lets `\1`–`\9` in `end` stand for text that
  `begin` captured — heredocs, raw strings, Markdown fences.
- `embed: grammar` or `embedCapture: n` runs another language inside the
  region. The region's end closes it from any depth, the way `</script>`
  ends a script in a browser.
- `Grammar(restartLine: …)` tells incremental highlighting where it can
  safely restart when a rule reads more than one line ahead.

**Keeping a grammar fast.** Start patterns with something specific — a
literal, a small character class, or `^` for line-start rules — rather than
`.`, a negated class, or a lookbehind. On native platforms, most patterns run
as small Dart matchers instead of the regular expression engine; results are
identical either way.

## ⚡ Performance

Measured on a MacBook, compiled to native code, best of several runs:

| Input | Highlight + HTML |
|---|---|
| 600 lines of Dart | 1.5 ms |
| 2,400 lines | 4.3 ms |
| 9,600 lines | 13.9 ms |

Across ten languages of realistic source, highlighting averages about
43 MB/s natively and about 62 MB/s compiled to JavaScript. One keystroke with
`IncrementalHighlighter` in a 9,600-line file takes about 0.4 ms.

## Built by Val

`val_highlight` is part of [Val](https://useval.io), the live visual layer
for AI agents.

## 💬 Community

Issues and pull requests are welcome on
[GitHub](https://github.com/useval/highlight); see the
[contributing guide](https://github.com/useval/highlight/blob/main/CONTRIBUTING.md). If the package helps your
project, consider giving it a like on
[pub.dev](https://pub.dev/packages/val_highlight) or a star on GitHub.

## 📄 License

BSD 3-Clause — see [LICENSE](LICENSE).
