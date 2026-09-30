import 'package:flutter/material.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';
import 'package:val_highlight/val_highlight.dart';

/// App-wide defaults for code widgets, set once on [ThemeData.extensions].
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: [CodeTheme(light: myTheme)]),
/// )
/// ```
///
/// Anything set directly on a widget wins over these defaults.
@immutable
class CodeTheme extends ThemeExtension<CodeTheme> {
  /// Creates code defaults.
  const CodeTheme({
    this.light,
    this.dark,
    this.textStyle,
    this.padding,
    this.lineNumbers,
  });

  /// Theme used when the app is light. Defaults to `lightTheme`.
  final ValTheme? light;

  /// Theme used when the app is dark. Defaults to `darkTheme`.
  final ValTheme? dark;

  /// Base text style for code, merged over the default monospace style.
  final TextStyle? textStyle;

  /// Padding around code blocks.
  final EdgeInsetsGeometry? padding;

  /// Whether code blocks show line numbers.
  final bool? lineNumbers;

  /// The nearest [CodeTheme], if any.
  static CodeTheme? maybeOf(BuildContext context) =>
      Theme.of(context).extension<CodeTheme>();

  /// The [ValTheme] to use: [override] if given, otherwise the app default
  /// for the current brightness.
  static ValTheme resolve(BuildContext context, [ValTheme? override]) {
    if (override != null) return override;
    final codeTheme = maybeOf(context);
    return Theme.of(context).brightness == Brightness.dark
        ? codeTheme?.dark ?? darkTheme
        : codeTheme?.light ?? lightTheme;
  }

  /// The default code text style: monospace, merged with [CodeTheme] and
  /// then [override].
  ///
  /// Letter and word spacing are fixed at zero so an app-wide text theme
  /// cannot stretch code or its line numbers.
  static TextStyle textStyleOf(BuildContext context, [TextStyle? override]) {
    return const TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'Courier New'],
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0,
      wordSpacing: 0,
    ).merge(maybeOf(context)?.textStyle).merge(override);
  }

  @override
  CodeTheme copyWith({
    ValTheme? light,
    ValTheme? dark,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    bool? lineNumbers,
  }) {
    return CodeTheme(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      textStyle: textStyle ?? this.textStyle,
      padding: padding ?? this.padding,
      lineNumbers: lineNumbers ?? this.lineNumbers,
    );
  }

  @override
  CodeTheme lerp(covariant CodeTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
