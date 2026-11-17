/// `CodeField`, a code editor built on `material_ui`'s `TextField`: everything
/// in `val_highlight_flutter.dart`, plus the editor.
///
/// ```dart
/// import 'package:val_highlight_flutter/material.dart';
/// import 'package:val_highlight/languages/dart.dart';
///
/// CodeField(controller: HighlightTextController(language: dartLanguage))
/// ```
///
/// The field needs a `material_ui` `MaterialApp` (or `Material`) above it.
/// In an app with another design system, give your own text field a
/// `HighlightTextController` and a `CodeEditingFormatter` instead.
library;

export 'val_highlight_flutter.dart';

export 'src/code_field.dart' show CodeField;
