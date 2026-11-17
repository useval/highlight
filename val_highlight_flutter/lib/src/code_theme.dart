import 'package:flutter/widgets.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';
import 'package:val_highlight/val_highlight.dart';

/// App-wide defaults for the code widgets, provided by a [CodeTheme].
///
/// Anything set directly on a widget wins over these defaults.
@immutable
final class CodeThemeData {
  /// Creates code defaults.
  const CodeThemeData({
    this.light,
    this.dark,
    this.brightness,
    this.textStyle,
    this.padding,
    this.lineNumbers,
  });

  /// Theme used when [brightness] is light. Defaults to `lightTheme`.
  final ValTheme? light;

  /// Theme used when [brightness] is dark. Defaults to `darkTheme`.
  final ValTheme? dark;

  /// Whether to use [light] or [dark]. Defaults to the platform's
  /// brightness, from [MediaQuery]. Set it from your app's theme when the
  /// app does not follow the platform:
  ///
  /// ```dart
  /// CodeThemeData(brightness: Theme.of(context).brightness)
  /// ```
  final Brightness? brightness;

  /// Base text style for code, merged over the default monospace style.
  final TextStyle? textStyle;

  /// Padding around code in `CodeView`.
  final EdgeInsetsGeometry? padding;

  /// Whether `CodeView` and `CodeField` show line numbers.
  final bool? lineNumbers;

  /// Returns a copy with the given fields replaced.
  CodeThemeData copyWith({
    ValTheme? light,
    ValTheme? dark,
    Brightness? brightness,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    bool? lineNumbers,
  }) {
    return CodeThemeData(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      brightness: brightness ?? this.brightness,
      textStyle: textStyle ?? this.textStyle,
      padding: padding ?? this.padding,
      lineNumbers: lineNumbers ?? this.lineNumbers,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CodeThemeData &&
      other.light == light &&
      other.dark == dark &&
      other.brightness == brightness &&
      other.textStyle == textStyle &&
      other.padding == padding &&
      other.lineNumbers == lineNumbers;

  @override
  int get hashCode =>
      Object.hash(light, dark, brightness, textStyle, padding, lineNumbers);
}

/// Sets [CodeThemeData] for the code widgets below it.
///
/// It works in any app, whatever its design system. Put one above your
/// app's content, for example in `MaterialApp.builder`, so it can follow
/// the app's own brightness:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => CodeTheme(
///     data: CodeThemeData(
///       light: sepiaTheme,
///       dark: dimTheme,
///       brightness: Theme.of(context).brightness,
///     ),
///     child: child!,
///   ),
/// )
/// ```
///
/// Without a [CodeTheme], the widgets use `lightTheme` or `darkTheme` by
/// the platform's brightness.
class CodeTheme extends InheritedTheme {
  /// Provides [data] to the code widgets in [child].
  const CodeTheme({super.key, required this.data, required super.child});

  /// The defaults.
  final CodeThemeData data;

  /// The nearest [CodeThemeData], if any.
  static CodeThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CodeTheme>()?.data;

  /// The nearest [CodeThemeData], or the default one.
  static CodeThemeData of(BuildContext context) =>
      maybeOf(context) ?? const CodeThemeData();

  /// The brightness the code widgets use: [CodeThemeData.brightness], or
  /// the platform's.
  static Brightness brightnessOf(BuildContext context) =>
      maybeOf(context)?.brightness ??
      MediaQuery.maybePlatformBrightnessOf(context) ??
      Brightness.light;

  /// The [ValTheme] to use: [override] if given, otherwise the default for
  /// [brightnessOf].
  static ValTheme resolve(BuildContext context, [ValTheme? override]) {
    if (override != null) return override;
    final data = maybeOf(context);
    return brightnessOf(context) == Brightness.dark
        ? data?.dark ?? darkTheme
        : data?.light ?? lightTheme;
  }

  /// The default code text style: monospace, merged with
  /// [CodeThemeData.textStyle] and then [override].
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
  Widget wrap(BuildContext context, Widget child) =>
      CodeTheme(data: data, child: child);

  @override
  bool updateShouldNotify(CodeTheme oldWidget) => data != oldWidget.data;
}
