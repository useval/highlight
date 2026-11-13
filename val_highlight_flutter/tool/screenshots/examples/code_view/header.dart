import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/yaml.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

const source = '''
name: shop
environment:
  sdk: ^3.9.0
dependencies:
  val_highlight_flutter: ^0.1.2''';

class FileCard extends StatelessWidget {
  const FileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CodeView(
      source,
      language: yamlLanguage,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
        child: Row(
          children: [
            const Text('pubspec.yaml'),
            const Spacer(),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () =>
                  Clipboard.setData(const ClipboardData(text: source)),
            ),
          ],
        ),
      ),
    );
  }
}
