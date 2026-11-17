import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/python.dart';
import 'package:val_highlight_flutter/material.dart';

const source = '''
from dataclasses import dataclass


@dataclass
class Order:
    sku: str
    qty: int = 1

    def total(self, price: float) -> float:
        return self.qty * price''';

class OrderEditor extends StatefulWidget {
  const OrderEditor({super.key});

  @override
  State<OrderEditor> createState() => _OrderEditorState();
}

class _OrderEditorState extends State<OrderEditor> {
  final controller = HighlightTextController(
    language: pythonLanguage,
    text: source,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CodeField paints no background; paint the theme's behind it.
    final theme = CodeTheme.resolve(context, controller.theme);
    return ColoredBox(
      color: Color(theme.root.background!),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CodeField(
          controller: controller,
          lineNumbers: true,
          highlightCurrentLine: true,
        ),
      ),
    );
  }
}
