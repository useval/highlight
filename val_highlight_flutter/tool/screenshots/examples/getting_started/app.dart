import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

void main() => runApp(const App());

const source = r'''
void main() {
  final name = 'world';
  print('Hello, $name!');
}''';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: CodeView(source, language: dartLanguage, lineNumbers: true),
        ),
      ),
    );
  }
}
