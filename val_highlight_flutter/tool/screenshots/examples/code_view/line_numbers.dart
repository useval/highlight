import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/kotlin.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// Lines 12 to 19 of a longer file.
const excerpt = '''
fun total(items: List<Item>): Double {
    var sum = 0.0
    for (item in items) {
        sum += item.price * item.quantity
    }
    // Prices include tax.
    return sum
}''';

class Excerpt extends StatelessWidget {
  const Excerpt({super.key});

  @override
  Widget build(BuildContext context) {
    return const CodeView(
      excerpt,
      language: kotlinLanguage,
      lineNumbers: true,
      firstLineNumber: 12,
      highlightedLines: {14, 15, 16},
    );
  }
}
