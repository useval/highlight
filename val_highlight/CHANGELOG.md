## 1.0.0

The API is now stable: from here on, breaking changes only come with a new
major version.

### Breaking

* `HighlightResult.fromBuffers`, `rawEnds` and `rawStacks` are gone. A
  `HighlightResult` can be sent to another isolate as it is.
* `ScopeTable` can no longer be created or changed outside the package:
  its constructor, `nameId` and `push` are gone. Results from one
  `IncrementalHighlighter` share a table, and nothing else can now change
  it under them.
* `IncrementalHighlighter.lastRescannedLines` is read-only.
* `BlockRule` is a `base` class: your blocks must be `final`, `base` or
  `sealed` classes.
* `Operators` takes its characters as a required argument and `scope` by
  name. `Annotation` and `Preprocessor` take `sigil` and `scope` by name:
  `Preprocessor(sigil: '%')`.
* `LanguageRegistry` takes its languages as a required argument and
  `fallback` by name: `LanguageRegistry(languages, fallback: generic)`.
* `Detection.reason` is a `DetectionReason` instead of a string.
* `languages/c.dart` no longer exports `cKeywords`, `cTypes`, `cLiterals`
  and `cCommonRules`.
* `ValTheme.lookup` merges the styles of a dotted scope's prefixes, so
  `variable.language` takes what `variable` sets, then its own fields. It
  used to return only the most specific style, which disagreed with the CSS
  from `toCss`. The built-in themes look the same.
* `HighlightResult.matchingBracket` uses the language's
  `EditingSyntax.brackets` unless `brackets` is given.

### Added

* `HighlightResult.lineAt`, the line holding an offset.

### Fixed

* Highlighting time no longer grows with the square of the input on long
  runs of one pattern. Twenty languages were affected; 80,000 `#` in Swift
  took 49 seconds. A test now checks every language.
* A delimiter too long to compile, such as a 100,000-character code fence,
  threw `GrammarException`. Delimiters longer than 1,024 characters are now
  plain text.
* Each distinct heredoc tag, code fence or raw-string delimiter was cached
  for good, so memory grew without bound on a stream of them. At most 64
  are kept per grammar.
* `LanguageRegistry.add` listed a language twice when it was added twice.

### Changed

To keep that time linear, a few patterns are a little stricter:

* Markdown link text cannot contain `[`, and inline HTML tags cannot
  contain `<`.
* C++ `[[attributes]]` cannot contain `[`.
* JavaScript and TypeScript regular expression literals are capped at 300
  parts, with character classes up to 200 characters.
* In Ruby regular expressions, a character class ends at an unescaped `/`,
  as Ruby itself does.
* YAML keys in `{flow, mappings}` cannot contain `[]{},`, as YAML requires.
* A function name directly after `$` (`$name(`) is no longer marked as a
  call in C-like languages.

## 0.1.1

### Added

* **`EditingSyntax`** — how a language is edited: its line and block
  comment markers, bracket pairs and quote characters. Every built-in
  language declares one; set `Grammar.editing` on your own, or let
  `EditingSyntax.of` derive it from the grammar's `LineComment`,
  `BlockComment` and `QuotedString` blocks. `Grammar.extend` takes an
  `editing` argument.
* **`HighlightResult.matchingBracket`** — finds the matching bracket by
  walking tokens, skipping brackets inside strings and comments.
* **`HighlightResult.isStringOrCommentAt`**, **`isCommentAt`** and
  **`isInsideStringOrComment`** — tell code apart from strings and
  comments, at a character or at a caret position. Interpolations inside
  strings count as code.
* **`ScopeTable.isStringOrComment`** and **`isComment`** — the same
  questions for a scope stack, answered from a table built once per stack.

### Changed

* Markdown highlights HTML comments (`<!-- -->`) as comments.

## 0.1.0

First release.

`val_highlight` is a syntax highlighter written in pure Dart. It runs
anywhere Dart runs — the VM, Flutter on every platform, and the web — and is
the shared core of `val_highlight_flutter`.

### Added

* **55 languages** — Dart, Kotlin, Swift, Java, Objective-C, C, C++, C#, Go,
  Rust, Zig, JavaScript, TypeScript, JSX, TSX, HTML (with embedded CSS and
  JavaScript, including `.vue` and `.svelte`), CSS, SCSS, Less, PHP, Python,
  Ruby, Lua, Perl, Bash, PowerShell, Batch, R, Julia, Elixir, Erlang,
  Haskell, OCaml, F#, Scala, Clojure, Groovy / Gradle, SQL, JSON, YAML, TOML,
  XML, INI / properties, Protobuf, GraphQL, HCL / Terraform, nginx,
  Dockerfile, Makefile, CMake, Markdown (fenced code in any language),
  LaTeX, NASM, Solidity and diff.
* **`genericLanguage`** — a fallback that highlights code in any language
  reasonably, and **`plainTextLanguage`**.
* **Incremental highlighting** — `IncrementalHighlighter` re-scans only what
  an edit can affect.
* **Flat token output** — tokens as two integer lists with a shared scope
  table, plus a line API for renderers.
* **8 themes** — light, dark, sepia, dim, midnight, forest, high-contrast
  light and dark. Every colour meets WCAG AA contrast.
* **VS Code themes** — `ValTheme.fromVsCode` and `ValTheme.fromVsCodeJson`.
* **HTML output** — CSS classes with `ValTheme.toCss`, or inline styles.
* **Language detection** — `LanguageDetector`, by file name, shebang and
  content.
* **Grammar building blocks** — `LineComment`, `BlockComment`,
  `QuotedString`, `Interpolation`, `Numbers`, `Operators`, `Annotation`,
  `Preprocessor` and `CommonRules`, so most grammars need no regular
  expressions. Extend `BlockRule` for your own.
* **Customisation** — `Grammar.extend`, `Grammar.withKeywords`,
  `ValTheme.extend`, and `LanguageRegistry` with fallbacks and file-name
  matching.
