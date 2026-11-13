import 'package:material_ui/material_ui.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

/// Resolves the language named on each fence.
final highlighter = CodeHighlighter(registry: allLanguagesRegistry());

const notes = r'''
## Setup

Install the CLI, then **build**:

```bash
export PORT=8080  # the default
shipit serve --port "$PORT"
```

```json
{ "watch": true, "delay": 250 }
```''';

class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return CodeView(
      notes,
      language: markdownLanguage,
      highlighter: highlighter,
    );
  }
}
