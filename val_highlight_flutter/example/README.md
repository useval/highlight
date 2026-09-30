# val_highlight_flutter example

A showcase of `CodeView`, `CodeField` and `HighlightTextController`: every
built-in language and theme, line numbers, wrapping, highlighted lines,
tappable tokens, a live editor, and a large file rendered lazily.

Runs on Android, iOS, macOS, Windows, Linux and the web. From the
repository root:

```sh
just devices                 # list available devices
just example-flutter         # run; asks which device to use
just example-flutter chrome  # run on a specific device
```

A platform can only be built on a matching host: iOS and macOS need a Mac,
Windows needs Windows, and Linux needs Linux.
