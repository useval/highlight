import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// A snippet whose language nobody said.
const snippet = '''
def fizzbuzz(n):
    for i in range(1, n + 1):
        if i % 15 == 0:
            print("FizzBuzz")
        elif i % 3 == 0:
            print("Fizz")
        else:
            print(i)''';

class Detected extends StatelessWidget {
  const Detected({super.key});

  @override
  Widget build(BuildContext context) {
    return const CodeView(snippet, detectLanguages: allLanguages);
  }
}
