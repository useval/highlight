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
