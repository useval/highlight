import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/python.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = '''
def describe(order):
    """One line for the receipt."""
    return f"{order.quantity} x {order.name} at {order.price:.2f} each, shipped to {order.city}"''';

class Wrapped extends StatelessWidget {
  const Wrapped({super.key});

  @override
  Widget build(BuildContext context) {
    return const CodeView(
      source,
      language: pythonLanguage,
      wrap: true,
      lineNumbers: true,
    );
  }
}
