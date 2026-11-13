import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = r'''
/// Greets someone by name.
class Greeting extends StatelessWidget {
  const Greeting({super.key, this.name = 'you'});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text('Hello, $name!');
  }
}''';

class GreetingSource extends StatelessWidget {
  const GreetingSource({super.key});

  @override
  Widget build(BuildContext context) {
    return const CodeView(source, language: dartLanguage);
  }
}
