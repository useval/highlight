import 'dart:convert';
import 'dart:math' as math;

import '../grammar/scopes.dart';
import 'theme.dart';

/// TextMate scopes that stand for each `val_highlight` scope, most specific
/// first. The first TextMate scope that any theme rule matches is used.
const vsCodeScopeMap = <String, List<String>>{
  Scopes.comment: ['comment'],
  Scopes.commentDoc: ['comment.block.documentation', 'comment'],
  Scopes.string: ['string'],
  Scopes.stringEscape: ['constant.character.escape'],
  Scopes.interpolation: [
    'meta.embedded',
    'punctuation.definition.template-expression',
  ],
  Scopes.number: ['constant.numeric'],
  Scopes.keyword: [
    'keyword.control',
    'keyword',
    'storage.type',
    'storage.modifier',
    'storage',
  ],
  Scopes.literal: ['constant.language'],
  Scopes.type: ['entity.name.type', 'entity.name.class', 'support.class'],
  Scopes.typeBuiltin: ['support.type', 'storage.type'],
  Scopes.function: [
    'entity.name.function',
    'support.function',
    'meta.function-call',
  ],
  Scopes.variable: ['variable'],
  Scopes.variableLanguage: ['variable.language'],
  Scopes.meta: [
    'meta.decorator',
    'meta.annotation',
    'entity.name.function.decorator',
    'meta.preprocessor',
    'keyword.control.directive',
  ],
  Scopes.property: [
    'support.type.property-name',
    'meta.object-literal.key',
    'variable.other.property',
  ],
  Scopes.punctuation: ['punctuation'],
  Scopes.operator: ['keyword.operator'],
  Scopes.tag: ['entity.name.tag'],
  Scopes.attribute: ['entity.other.attribute-name'],
  Scopes.regexp: ['string.regexp'],
  Scopes.heading: ['markup.heading'],
  Scopes.emphasis: ['markup.italic'],
  Scopes.strong: ['markup.bold'],
  Scopes.link: ['markup.underline.link', 'string.other.link'],
  Scopes.code: ['markup.inline.raw', 'markup.raw'],
  Scopes.quote: ['markup.quote'],
  Scopes.addition: ['markup.inserted'],
  Scopes.deletion: ['markup.deleted'],
  Scopes.invalid: ['invalid'],
};

/// One theme rule: a selector and the settings it defines.
final class _Rule {
  _Rule(
    this.selector,
    this.index,
    this.foreground,
    this.background,
    this.fontStyle,
  );

  final String selector;
  final int index;
  final int? foreground;
  final int? background;
  final String? fontStyle;
}

/// Builds a [ValTheme] from a decoded VS Code color theme.
///
/// Reads `colors['editor.foreground']` and `colors['editor.background']`
/// for the root (falling back to a `tokenColors` entry without a scope),
/// `type` for [ValTheme.dark], and `tokenColors` for scopes. Each property
/// (foreground, background, font style) is taken from the most specific
/// matching rule, as VS Code does: a selector matches a scope it equals or
/// is a dot-separated prefix of, longer selectors win, and later rules win
/// ties. For selectors with spaces (descendant selectors), only the last
/// segment is used; selectors with exclusions (`-`) are ignored.
ValTheme themeFromVsCode(Map<String, Object?> json, {String? name}) {
  final colors = json['colors'];
  int? editorColor(String key) {
    if (colors is! Map) return null;
    final value = colors[key];
    return value is String ? parseVsCodeColor(value) : null;
  }

  var foreground = editorColor('editor.foreground');
  var background = editorColor('editor.background');

  final rules = <_Rule>[];
  final tokenColors = json['tokenColors'];
  if (tokenColors is List) {
    for (final entry in tokenColors) {
      if (entry is! Map) continue;
      final settings = entry['settings'];
      if (settings is! Map) continue;
      final fg = settings['foreground'];
      final bg = settings['background'];
      final fontStyle = settings['fontStyle'];
      final fgColor = fg is String ? parseVsCodeColor(fg) : null;
      final bgColor = bg is String ? parseVsCodeColor(bg) : null;
      final style = fontStyle is String ? fontStyle : null;
      final scope = entry['scope'];
      if (scope == null) {
        // Global settings.
        foreground ??= fgColor;
        background ??= bgColor;
        continue;
      }
      final selectors = <String>[
        if (scope is String) ...scope.split(','),
        if (scope is List) ...scope.whereType<String>(),
      ];
      for (var selector in selectors) {
        selector = selector.trim();
        if (selector.isEmpty || selector.contains(' -')) continue;
        if (selector.startsWith('-')) continue;
        final space = selector.lastIndexOf(RegExp(r'\s'));
        if (space >= 0) selector = selector.substring(space + 1);
        rules.add(_Rule(selector, rules.length, fgColor, bgColor, style));
      }
    }
  }

  final type = json['type'];
  final bool dark;
  if (type is String) {
    dark = type == 'dark' || (type.startsWith('hc') && type != 'hc-light');
  } else {
    dark = background != null && _luminance(background) < 0.5;
  }

  final styles = <String, Style>{};
  for (final MapEntry(key: scope, value: targets) in vsCodeScopeMap.entries) {
    for (final target in targets) {
      final style = _styleFor(target, rules);
      if (style != null) {
        styles[scope] = style;
        break;
      }
    }
  }

  final themeName = json['name'];
  return ValTheme(
    name: name ?? (themeName is String ? themeName : 'vscode'),
    dark: dark,
    root: Style(color: foreground, background: background),
    styles: styles,
  );
}

/// [themeFromVsCode] for a theme file's text, which may be JSONC (with
/// comments and trailing commas).
ValTheme themeFromVsCodeJson(String source, {String? name}) {
  final decoded = jsonDecode(stripJsonc(source));
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('A VS Code theme must be a JSON object');
  }
  return themeFromVsCode(decoded, name: name);
}

bool _matches(String selector, String target) =>
    target == selector ||
    (target.startsWith(selector) && target.codeUnitAt(selector.length) == 0x2E);

/// The style of [target], or `null` if no rule matches it.
Style? _styleFor(String target, List<_Rule> rules) {
  _Rule? best(bool Function(_Rule) has) {
    _Rule? winner;
    for (final rule in rules) {
      if (!has(rule) || !_matches(rule.selector, target)) continue;
      if (winner == null ||
          rule.selector.length > winner.selector.length ||
          (rule.selector.length == winner.selector.length &&
              rule.index > winner.index)) {
        winner = rule;
      }
    }
    return winner;
  }

  final fg = best((r) => r.foreground != null);
  final bg = best((r) => r.background != null);
  final font = best((r) => r.fontStyle != null);
  if (fg == null && bg == null && font == null) return null;

  bool? italic, bold, underline, strikethrough;
  final fontStyle = font?.fontStyle;
  if (fontStyle != null) {
    // A font style lists every style that applies; the rest are off, so an
    // empty string resets them all.
    final parts = fontStyle.split(RegExp(r'\s+')).toSet();
    italic = parts.contains('italic');
    bold = parts.contains('bold');
    underline = parts.contains('underline');
    strikethrough = parts.contains('strikethrough');
  }
  return Style(
    color: fg?.foreground,
    background: bg?.background,
    italic: italic,
    bold: bold,
    underline: underline,
    strikethrough: strikethrough,
  );
}

/// Parses `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA` into ARGB, or returns
/// `null` if [value] is not such a color.
int? parseVsCodeColor(String value) {
  var hex = value.trim();
  if (!hex.startsWith('#')) return null;
  hex = hex.substring(1);
  if (hex.length == 3 || hex.length == 4) {
    hex = [for (final c in hex.split('')) '$c$c'].join();
  }
  if (hex.length == 6) hex = '${hex}FF';
  if (hex.length != 8) return null;
  final rgba = int.tryParse(hex, radix: 16);
  if (rgba == null) return null;
  final alpha = rgba & 0xFF;
  return (alpha << 24) | (rgba >> 8);
}

/// Removes `//` and `/* */` comments outside strings, and trailing commas
/// before `}` or `]`.
String stripJsonc(String source) {
  final withoutComments = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source.codeUnitAt(i);
    if (c == 0x22) {
      // A string: copy it whole, honouring escapes.
      final start = i++;
      while (i < n && source.codeUnitAt(i) != 0x22) {
        if (source.codeUnitAt(i) == 0x5C) i++;
        i++;
      }
      i++;
      withoutComments.write(source.substring(start, i > n ? n : i));
      continue;
    }
    if (c == 0x2F && i + 1 < n) {
      final next = source.codeUnitAt(i + 1);
      if (next == 0x2F) {
        while (i < n && source.codeUnitAt(i) != 0x0A) {
          i++;
        }
        continue;
      }
      if (next == 0x2A) {
        final end = source.indexOf('*/', i + 2);
        i = end < 0 ? n : end + 2;
        continue;
      }
    }
    withoutComments.writeCharCode(c);
    i++;
  }

  final text = withoutComments.toString();
  final out = StringBuffer();
  i = 0;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x22) {
      final start = i++;
      while (i < text.length && text.codeUnitAt(i) != 0x22) {
        if (text.codeUnitAt(i) == 0x5C) i++;
        i++;
      }
      i++;
      out.write(text.substring(start, i > text.length ? text.length : i));
      continue;
    }
    if (c == 0x2C) {
      var j = i + 1;
      while (j < text.length && ' \t\r\n'.contains(text[j])) {
        j++;
      }
      if (j < text.length && (text[j] == '}' || text[j] == ']')) {
        i++;
        continue;
      }
    }
    out.writeCharCode(c);
    i++;
  }
  return out.toString();
}

double _luminance(int argb) {
  double channel(int shift) {
    final v = ((argb >> shift) & 0xFF) / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}
