import '../result.dart';
import '../theme/theme.dart';

/// Renders a [HighlightResult] as HTML.
///
/// By default each scope becomes a `<span>` with CSS classes (pair it with
/// `ValTheme.toCss`). Pass [theme] to write inline `style` attributes instead,
/// which needs no stylesheet.
final class HtmlRenderer {
  /// Creates an HTML renderer.
  const HtmlRenderer({
    this.classPrefix = 'vh-',
    this.rootClass = 'vh',
    this.theme,
    this.wrap = false,
  });

  /// Prefix for scope classes. Scope `title.function` becomes classes
  /// `vh-title vh-title-function`, so a theme can style either level.
  final String classPrefix;

  /// Class of the `<pre>` element written when [wrap] is set.
  final String rootClass;

  /// When set, styles are written inline and no classes are used.
  final ValTheme? theme;

  /// Whether to wrap the output in `<pre class="vh"><code>…</code></pre>`.
  final bool wrap;

  /// Renders [result].
  String render(HighlightResult result) {
    final out = StringBuffer();
    final theme = this.theme;
    if (wrap) {
      if (theme != null) {
        out.write('<pre style="${theme.root.toCss()}"><code>');
      } else {
        out.write('<pre class="$rootClass"><code>');
      }
    }

    final table = result.scopes;
    final code = result.code;
    final opening = List<String?>.filled(table.stackCount, null);
    final computed = List<bool>.filled(table.stackCount, false);
    final open = <int>[];
    final opened = <bool>[];

    String? openTag(int stack) {
      if (computed[stack]) return opening[stack];
      computed[stack] = true;
      final scope = table.scopeOf(stack)!;
      final String? tag;
      if (theme != null) {
        final css = theme.lookup(scope)?.toCss() ?? '';
        tag = css.isEmpty ? null : '<span style="$css">';
      } else {
        tag = '<span class="${_classes(scope)}">';
      }
      return opening[stack] = tag;
    }

    for (var i = 0; i < result.tokenCount; i++) {
      final path = table.pathOf(result.tokenStack(i));
      var common = 0;
      while (common < open.length &&
          common < path.length &&
          open[common] == path[common]) {
        common++;
      }
      while (open.length > common) {
        open.removeLast();
        if (opened.removeLast()) out.write('</span>');
      }
      for (var p = common; p < path.length; p++) {
        final tag = openTag(path[p]);
        if (tag != null) out.write(tag);
        open.add(path[p]);
        opened.add(tag != null);
      }
      _escape(out, code, result.tokenStart(i), result.tokenEnd(i));
    }
    while (open.isNotEmpty) {
      open.removeLast();
      if (opened.removeLast()) out.write('</span>');
    }

    if (wrap) out.write('</code></pre>');
    return out.toString();
  }

  String _classes(String scope) {
    final parts = scope.split('.');
    final classes = StringBuffer();
    for (var i = 1; i <= parts.length; i++) {
      if (i > 1) classes.write(' ');
      classes.write(scopeClass(parts.take(i).join('.'), classPrefix));
    }
    return _escapeAttribute(classes.toString());
  }
}

void _escape(StringBuffer out, String code, int start, int end) {
  var from = start;
  for (var i = start; i < end; i++) {
    final String replacement;
    switch (code.codeUnitAt(i)) {
      case 0x26:
        replacement = '&amp;';
      case 0x3C:
        replacement = '&lt;';
      case 0x3E:
        replacement = '&gt;';
      default:
        continue;
    }
    out.write(code.substring(from, i));
    out.write(replacement);
    from = i + 1;
  }
  out.write(code.substring(from, end));
}

String _escapeAttribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
