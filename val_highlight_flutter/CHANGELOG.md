## Unreleased

### Added

* **Editing essentials in `CodeField`**, configured with `CodeEditing`:
  * brackets and quotes close themselves, a typed closer steps over an
    automatic one, and Backspace deletes an empty automatic pair. Quotes
    stay single after a letter or digit and inside strings and comments;
  * typing a bracket or quote over a selection wraps it;
  * Enter between brackets, as in `{|}`, moves the closer onto its own
    line;
  * Ctrl+/ (Cmd+/ on Apple platforms) comments and uncomments lines, with
    the language's markers, or wraps a block comment where a language has
    no line comments. Doc comments (`///`, `//!`) and shebangs are
    commented out like code rather than stripped;
  * the bracket at the caret and its match are outlined.

  Brackets, quotes and comment markers come from the language's
  `EditingSyntax`. Typing is handled as text changes, so it works on
  on-screen keyboards and voice input as well as hardware keyboards, and
  text an input method is composing is never changed.
* **Line numbers in `CodeField`** — `lineNumbers`, `firstLineNumber` and
  `gutterStyle`, plus `highlightedLines`, `highlightCurrentLine` and their
  colors. They are painted from the text's own layout, so wrapped lines
  line up, only visible lines are painted, and they follow the text when
  a font finishes loading late.
* **Shortcuts as intents** — `IndentCodeIntent`, `OutdentCodeIntent` and
  `ToggleCommentIntent`. Rebind keys with `CodeField.shortcuts` (defaults in
  `CodeField.defaultShortcuts`), or override an intent with an `Actions`
  widget above the field.
* **`CodeEditingFormatter`** — the same typing behaviour for a plain
  `TextField` driven by a `HighlightTextController`.
* **`toggleComment`** — the comment toggle as a function on a
  `TextEditingValue`.
* **`CodeField.inputFormatters`** — more formatters, applied after the
  editing behaviour.

### Changed

* Typing in `CodeField` now auto-closes brackets and quotes, and Enter
  between brackets splits them across lines. Pass
  `editing: CodeEditing.none` for 0.1.0's behaviour, or turn off single
  behaviours with `CodeEditing`.
* Enter keeps the indentation on on-screen keyboards too, not only on
  hardware keyboards.
* Requires the unreleased `val_highlight` changes above (`EditingSyntax`
  and the bracket and context queries on `HighlightResult`).

## 0.1.0

First release.

`val_highlight_flutter` shows and edits syntax-highlighted code in Flutter,
using the `val_highlight` engine.

### Added

* **`CodeView`** — highlighted code with line numbers, highlighted lines,
  wrapping or horizontal scrolling, selection that never copies line
  numbers, a header slot, and custom gutter and line builders. Large files
  render lazily and are highlighted in a background isolate.
* **`CodeField`** — a code editor. Tab and Shift+Tab indent and outdent,
  Enter keeps the indentation, and large documents stay fast by colouring
  only the visible lines.
* **`HighlightTextController`** — highlights any `TextField` as you type,
  re-scanning only what each edit can affect.
* **Tappable tokens** — `CodeView.onTokenTap` and `CodeView.spanBuilder`.
* **`CodeTheme`** — app-wide defaults through `ThemeData.extensions`; follows
  light and dark mode.
* **`CodeHighlighter`** — result caching, isolate threshold, and `preload`
  to compile languages during idle frames.
* **Language detection and a generic fallback** when no language is given.
