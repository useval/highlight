import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/sql.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

class QueryField extends StatefulWidget {
  const QueryField({super.key});

  @override
  State<QueryField> createState() => _QueryFieldState();
}

class _QueryFieldState extends State<QueryField> {
  final controller = HighlightTextController(
    language: sqlLanguage,
    text: "SELECT name, total\nFROM orders\nWHERE status = 'paid'\nLIMIT 10;",
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        maxLines: null,
        style: CodeTheme.textStyleOf(context),
        decoration: const InputDecoration(
          labelText: 'Query',
          border: OutlineInputBorder(),
        ),
        inputFormatters: [CodeEditingFormatter(controller: controller)],
      ),
    );
  }
}
