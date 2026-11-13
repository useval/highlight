import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/json.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// Highlighted once; the result is plain data and can be kept.
final result = const Highlighter().highlight(
  '{ "status": "paid", "total": 42.5 }',
  language: jsonLanguage,
);

/// Styles per scope stack, cached by `CodeStyles`.
final styles = CodeStyles(darkTheme);

/// A chat message with a highlighted line of JSON inside it.
class Message extends StatelessWidget {
  const Message({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The webhook sent this body:'),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(darkTheme.root.background!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text.rich(
                TextSpan(
                  style: styles.rootStyle(CodeTheme.textStyleOf(context)),
                  children: documentSpans(result, styles),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
