/// Every built-in theme.
///
/// Import a single theme from `package:val_highlight/themes/<name>.dart` to
/// ship only what you use.
library;

import '../val_highlight.dart';
import 'dark.dart';
import 'dim.dart';
import 'forest.dart';
import 'high_contrast_dark.dart';
import 'high_contrast_light.dart';
import 'light.dart';
import 'midnight.dart';
import 'sepia.dart';

export 'dark.dart';
export 'dim.dart';
export 'forest.dart';
export 'high_contrast_dark.dart';
export 'high_contrast_light.dart';
export 'light.dart';
export 'midnight.dart';
export 'sepia.dart';

/// Every built-in theme.
const allThemes = <ValTheme>[
  lightTheme,
  darkTheme,
  sepiaTheme,
  dimTheme,
  midnightTheme,
  forestTheme,
  highContrastLightTheme,
  highContrastDarkTheme,
];
