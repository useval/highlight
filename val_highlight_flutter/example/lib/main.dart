import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

import 'samples.dart';

void main() => runApp(const ExampleApp());

/// Resolves Markdown code fences to every built-in language.
final highlighter = CodeHighlighter(registry: allLanguagesRegistry());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'val_highlight',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFB0226E)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFB0226E),
        brightness: Brightness.dark,
      ),
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('val_highlight'),
            actions: [
              IconButton(
                tooltip: 'Toggle theme',
                icon: const Icon(Icons.brightness_6),
                onPressed: () => setState(() {
                  _mode = _mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                }),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Gallery'),
                Tab(text: 'Editor'),
                Tab(text: 'Large file'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [GalleryPage(), EditorPage(), LargeFilePage()],
          ),
        ),
      ),
    );
  }
}

/// Every language with the display options.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  Grammar _language = dartLanguage;

  bool _lineNumbers = true;
  bool _wrap = false;
  bool _highlight = false;
  bool _customKeyword = false;

  /// The picked theme, or `null` to follow the app's light/dark mode.
  ValTheme? _theme;

  @override
  Widget build(BuildContext context) {
    final base =
        _theme ??
        (Theme.of(context).brightness == Brightness.dark
            ? darkTheme
            : lightTheme);
    final theme = _customKeyword
        ? base.extend(
            styles: {
              Scopes.keyword: const Style(color: 0xFFE8590C, bold: true),
            },
          )
        : _theme;
    final code = samples[_language]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<Grammar>(
              value: _language,
              onChanged: (value) => setState(() => _language = value!),
              items: [
                for (final language in samples.keys)
                  DropdownMenuItem(value: language, child: Text(language.name)),
              ],
            ),
            DropdownButton<ValTheme?>(
              value: _theme,
              onChanged: (value) => setState(() => _theme = value),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Theme: follow app'),
                ),
                for (final theme in allThemes)
                  DropdownMenuItem(value: theme, child: Text(theme.name)),
              ],
            ),
            _toggle('Line numbers', _lineNumbers, (v) => _lineNumbers = v),
            _toggle('Wrap', _wrap, (v) => _wrap = v),
            _toggle('Highlight lines 2-3', _highlight, (v) => _highlight = v),
            _toggle(
              'Custom keyword style',
              _customKeyword,
              (v) => _customKeyword = v,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CodeView(
            code,
            language: _language,
            theme: theme,
            highlighter: highlighter,
            lineNumbers: _lineNumbers,
            wrap: _wrap,
            highlightedLines: _highlight ? const {2, 3} : const {},
            onTokenTap: (token) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '${token.scopes.isEmpty ? 'plain text' : token.scopes.join(' › ')}: ${token.text}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              ),
            header: _Header(title: _language.name, code: code),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Detected automatically',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const CodeView(
          'def greet(name):\n    return f"Hello, {name}"\n',
          detectLanguages: allLanguages,
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) set) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (v) => setState(() => set(v)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.code});

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A live editor using [HighlightTextController].
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final HighlightTextController _controller = HighlightTextController(
    text: samples[dartLanguage],
    language: dartLanguage,
    registry: allLanguagesRegistry(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CodeTheme.resolve(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: DropdownButton<Grammar>(
            value: _controller.language,
            onChanged: (value) => setState(() {
              _controller.language = value!;
              _controller.text = samples[value]!;
            }),
            items: [
              for (final language in samples.keys)
                DropdownMenuItem(value: language, child: Text(language.name)),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Color(theme.root.background ?? 0),
            child: CodeField(
              controller: _controller,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Twenty thousand lines, rendered lazily and highlighted off the UI thread.
class LargeFilePage extends StatelessWidget {
  const LargeFilePage({super.key});

  static final String _code = largeSample(1000);

  @override
  Widget build(BuildContext context) {
    return CodeView(
      _code,
      language: dartLanguage,
      lineNumbers: true,
      highlighter: highlighter,
    );
  }
}
