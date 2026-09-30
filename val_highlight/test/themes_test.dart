import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:val_highlight/themes/all.dart';

double _luminance(int argb) {
  double channel(int shift) {
    final v = ((argb >> shift) & 0xFF) / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

double contrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('theme names are unique', () {
    final names = allThemes.map((t) => t.name).toSet();
    expect(names.length, allThemes.length);
  });

  for (final theme in allThemes) {
    group(theme.name, () {
      test('defines every scope the light theme defines', () {
        expect(theme.styles.keys.toSet(), lightTheme.styles.keys.toSet());
      });

      test('text is readable against its background', () {
        final minimum = theme.name.contains('high-contrast') ? 7.0 : 4.5;
        final background = theme.root.background!;
        expect(
          contrast(theme.root.color!, background),
          greaterThanOrEqualTo(minimum),
        );
        for (final MapEntry(key: scope, value: style) in theme.styles.entries) {
          final color = style.color;
          if (color == null) continue;
          final ratio = contrast(color, style.background ?? background);
          expect(
            ratio,
            greaterThanOrEqualTo(minimum),
            reason: '$scope: ${ratio.toStringAsFixed(2)}',
          );
        }
      });

      test('dark flag matches the background', () {
        expect(theme.dark, _luminance(theme.root.background!) < 0.5);
      });
    });
  }
}
