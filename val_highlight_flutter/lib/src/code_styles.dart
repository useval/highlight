import 'package:flutter/painting.dart';
import 'package:val_highlight/val_highlight.dart';

/// Converts a `val_highlight` [Style] to a [TextStyle]. Unset fields stay
/// unset, so the result inherits from its parent span.
TextStyle textStyleFromStyle(Style style) {
  final lines = [
    if (style.underline ?? false) TextDecoration.underline,
    if (style.strikethrough ?? false) TextDecoration.lineThrough,
  ];
  final hasDecoration = style.underline != null || style.strikethrough != null;
  return TextStyle(
    color: style.color == null ? null : Color(style.color!),
    backgroundColor: style.background == null ? null : Color(style.background!),
    fontWeight: style.bold == null
        ? null
        : (style.bold! ? FontWeight.bold : FontWeight.normal),
    fontStyle: style.italic == null
        ? null
        : (style.italic! ? FontStyle.italic : FontStyle.normal),
    decoration: hasDecoration ? TextDecoration.combine(lines) : null,
  );
}

/// Text styles for the scope stacks of highlight results, resolved once per
/// stack and cached.
///
/// Stack `0` (plain text) gets an empty style so it inherits the root span.
/// Every other stack gets its full inherited style, so spans can be flat.
/// The cache grows as a table gains stacks, which lets incremental results
/// that share one table reuse it.
final class CodeStyles {
  /// Creates a style cache for [theme].
  CodeStyles(this.theme);

  /// The theme being applied.
  final ValTheme theme;

  ScopeTable? _table;
  final List<Style> _merged = [];
  final List<TextStyle> _text = [];

  /// Root style: the theme's base color (no background; containers paint
  /// that) merged over [base].
  TextStyle rootStyle(TextStyle base) {
    final color = theme.root.color;
    return color == null ? base : base.copyWith(color: Color(color));
  }

  /// Style for [stack] in [table].
  TextStyle of(ScopeTable table, int stack) {
    if (!identical(table, _table)) {
      _table = table;
      _merged
        ..clear()
        ..add(const Style());
      _text
        ..clear()
        ..add(const TextStyle());
    }
    for (var id = _merged.length; id <= stack; id++) {
      final style = _merged[table.parentOf(id)].merge(
        theme.lookup(table.scopeOf(id)!),
      );
      _merged.add(style);
      _text.add(textStyleFromStyle(style));
    }
    return _text[stack];
  }
}
