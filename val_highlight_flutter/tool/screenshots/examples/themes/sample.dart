import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = r'''
/// A greeting, repeated [count] times.
@immutable
class Greeter {
  const Greeter(this.name, {this.count = 3});

  final String name;
  final int count;

  // One line per greeting.
  String greet() => 'Hi, $name!\n' * count;
  bool get isEmpty => name.isEmpty || count < 1;
}''';

class ThemeSample extends StatelessWidget {
  const ThemeSample({super.key, required this.theme});

  final ValTheme theme;

  @override
  Widget build(BuildContext context) {
    return CodeView(source, language: dartLanguage, theme: theme);
  }
}
