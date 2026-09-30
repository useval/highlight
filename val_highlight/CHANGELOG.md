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
