import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/typescript.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = '''
interface Order {
  id: string;
  items: Item[];
}

function total(order: Order): Price {
  return sum(order.items.map(priceOf));
}''';

/// Underlines every type name, as links to their definitions would be.
class LinkedTypes extends StatelessWidget {
  const LinkedTypes({super.key});

  @override
  Widget build(BuildContext context) {
    return CodeView(
      source,
      language: typescriptLanguage,
      spanBuilder: (context, token, style) {
        if (token.scope != Scopes.type) {
          return TextSpan(text: token.text, style: style);
        }
        return TextSpan(
          text: token.text,
          style: style?.copyWith(decoration: TextDecoration.underline),
        );
      },
    );
  }
}
