import '../engine/scope_table.dart';
import 'vscode.dart';

/// Visual style for one scope. Unset fields inherit from the enclosing scope.
///
/// Colors are ARGB integers such as `0xFF1E7A3A`, so styles are `const` and
/// cost nothing to convert on any platform.
final class Style {
  /// Creates a style.
  const Style({
    this.color,
    this.background,
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
  });

  /// Foreground color as ARGB.
  final int? color;

  /// Background color as ARGB.
  final int? background;

  /// Bold text.
  final bool? bold;

  /// Italic text.
  final bool? italic;

  /// Underlined text.
  final bool? underline;

  /// Struck-through text.
  final bool? strikethrough;

  /// Whether every field is unset.
  bool get isEmpty =>
      color == null &&
      background == null &&
      bold == null &&
      italic == null &&
      underline == null &&
      strikethrough == null;

  /// Returns this style with the set fields of [other] applied on top.
  Style merge(Style? other) {
    if (other == null || other.isEmpty) return this;
    if (isEmpty) return other;
    return Style(
      color: other.color ?? color,
      background: other.background ?? background,
      bold: other.bold ?? bold,
      italic: other.italic ?? italic,
      underline: other.underline ?? underline,
      strikethrough: other.strikethrough ?? strikethrough,
    );
  }

  /// Returns a copy with the given fields replaced.
  Style copyWith({
    int? color,
    int? background,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
  }) {
    return Style(
      color: color ?? this.color,
      background: background ?? this.background,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
    );
  }

  /// CSS declarations for this style, such as `color:#1e7a3a;`.
  String toCss() {
    final out = StringBuffer();
    if (color != null) out.write('color:${cssColor(color!)};');
    if (background != null) {
      out.write('background-color:${cssColor(background!)};');
    }
    if (bold != null) out.write('font-weight:${bold! ? 'bold' : 'normal'};');
    if (italic != null) {
      out.write('font-style:${italic! ? 'italic' : 'normal'};');
    }
    if (underline != null || strikethrough != null) {
      final lines = [
        if (underline ?? false) 'underline',
        if (strikethrough ?? false) 'line-through',
      ];
      out.write('text-decoration:${lines.isEmpty ? 'none' : lines.join(' ')};');
    }
    return out.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Style &&
      other.color == color &&
      other.background == background &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strikethrough == strikethrough;

  @override
  int get hashCode =>
      Object.hash(color, background, bold, italic, underline, strikethrough);
}

/// Formats an ARGB color as CSS.
String cssColor(int argb) {
  final alpha = (argb >> 24) & 0xFF;
  final rgb = argb & 0xFFFFFF;
  if (alpha == 0xFF) return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  final r = (rgb >> 16) & 0xFF;
  final g = (rgb >> 8) & 0xFF;
  final b = rgb & 0xFF;
  final a = (alpha / 255).toStringAsFixed(3);
  return 'rgba($r,$g,$b,$a)';
}

/// A color theme: a [root] style plus a style per scope.
///
/// Scope lookup cascades: `title.function.call` tries `title.function.call`,
/// then `title.function`, then `title`.
final class ValTheme {
  /// Creates a theme.
  const ValTheme({
    required this.name,
    this.root = const Style(),
    this.styles = const {},
    this.dark = false,
  });

  /// Builds a theme from a decoded VS Code color theme (the JSON object of
  /// a `*-color-theme.json` file).
  ///
  /// Uses the editor foreground and background, the theme `type` for
  /// [dark], and `tokenColors`, matching TextMate scopes the way VS Code
  /// does. [name] defaults to the theme's own `name`.
  factory ValTheme.fromVsCode(Map<String, Object?> json, {String? name}) =>
      themeFromVsCode(json, name: name);

  /// Like [ValTheme.fromVsCode], from the text of a theme file. Comments and
  /// trailing commas (JSONC) are allowed.
  factory ValTheme.fromVsCodeJson(String source, {String? name}) =>
      themeFromVsCodeJson(source, name: name);

  /// Theme name.
  final String name;

  /// Base style for all code, including the background color.
  final Style root;

  /// Style per scope.
  final Map<String, Style> styles;

  /// Whether this is a dark theme.
  final bool dark;

  /// Style for [scope] alone, using the cascade, without inheritance.
  Style? lookup(String scope) {
    var key = scope;
    while (true) {
      final style = styles[key];
      if (style != null) return style;
      final dot = key.lastIndexOf('.');
      if (dot < 0) return null;
      key = key.substring(0, dot);
    }
  }

  /// Effective style of every stack in [table], indexed by stack id.
  ///
  /// Each stack inherits from its parent, starting from [root].
  List<Style> resolve(ScopeTable table) {
    final count = table.stackCount;
    final resolved = List<Style>.filled(count, root);
    for (var stack = 1; stack < count; stack++) {
      final scope = table.scopeOf(stack)!;
      resolved[stack] = resolved[table.parentOf(stack)].merge(lookup(scope));
    }
    return resolved;
  }

  /// Returns a copy with the given fields replaced.
  ValTheme copyWith({
    String? name,
    Style? root,
    Map<String, Style>? styles,
    bool? dark,
  }) {
    return ValTheme(
      name: name ?? this.name,
      root: root ?? this.root,
      styles: styles ?? this.styles,
      dark: dark ?? this.dark,
    );
  }

  /// Returns a theme built on this one.
  ///
  /// [root] is merged over the current root. Each entry in [styles] replaces
  /// the style for that scope.
  ValTheme extend({String? name, Style? root, Map<String, Style>? styles}) {
    return ValTheme(
      name: name ?? this.name,
      root: this.root.merge(root),
      styles: styles == null ? this.styles : {...this.styles, ...styles},
      dark: dark,
    );
  }

  /// CSS for this theme, matching the classes written by `HtmlRenderer`.
  ///
  /// [rootClass] is the class of the wrapping element. Scope `a.b` maps to
  /// class `<classPrefix>a-b`.
  String toCss({String classPrefix = 'vh-', String rootClass = 'vh'}) {
    final out = StringBuffer()..write('.$rootClass{${root.toCss()}}\n');
    final scopes = styles.keys.toList()
      ..sort((a, b) {
        final depth = '.'.allMatches(a).length - '.'.allMatches(b).length;
        return depth != 0 ? depth : a.compareTo(b);
      });
    for (final scope in scopes) {
      final css = styles[scope]!.toCss();
      if (css.isEmpty) continue;
      out.write('.$rootClass .${scopeClass(scope, classPrefix)}{$css}\n');
    }
    return out.toString();
  }
}

/// CSS class for [scope], such as `vh-title-function` for `title.function`.
String scopeClass(String scope, String classPrefix) =>
    '$classPrefix${scope.replaceAll('.', '-')}';
