import 'package:test/test.dart';
import 'package:val_highlight/val_highlight.dart';

const _theme = '''
{
  // A hand-written theme in the JSONC format VS Code uses.
  "name": "Test Theme",
  "type": "dark",
  "colors": {
    "editor.foreground": "#E0E0E0",
    "editor.background": "#1E1E1E", /* block comment */
  },
  "tokenColors": [
    { "settings": { "foreground": "#FFFFFF" } },
    { "scope": "comment", "settings": { "foreground": "#6A9955", "fontStyle": "italic" } },
    { "scope": "comment.block.documentation", "settings": { "foreground": "#608B4E" } },
    { "scope": ["string", "string.quoted"], "settings": { "foreground": "#CE9178" } },
    { "scope": "keyword, storage.type", "settings": { "foreground": "#569CD6" } },
    { "scope": "keyword.control", "settings": { "foreground": "#C586C0", "fontStyle": "bold underline" } },
    { "scope": "keyword.control", "settings": { "foreground": "#D16DC1" } },
    { "scope": "constant.numeric", "settings": { "foreground": "#B5C", "fontStyle": "" } },
    { "scope": "entity.name.function", "settings": { "foreground": "#DCDCAA80" } },
    { "scope": "meta.class entity.name.type", "settings": { "foreground": "#4EC9B0" } },
    { "scope": "markup.inserted", "settings": { "foreground": "#B5CEA8", "background": "#1F3A1F" } },
    { "scope": "markup.deleted", "settings": { "fontStyle": "strikethrough" } },
    { "scope": "string -string.regexp", "settings": { "foreground": "#FF0000" } },
    { "scope": "url: \\"not a comment // here\\"", "settings": {} },
  ],
}
''';

void main() {
  final theme = ValTheme.fromVsCodeJson(_theme);

  test('root, name and type', () {
    expect(theme.name, 'Test Theme');
    expect(theme.dark, isTrue);
    expect(theme.root.color, 0xFFE0E0E0);
    expect(theme.root.background, 0xFF1E1E1E);
    expect(ValTheme.fromVsCodeJson(_theme, name: 'x').name, 'x');
  });

  test('scope forms: string, comma-separated and list', () {
    expect(theme.lookup(Scopes.string)?.color, 0xFFCE9178);
    expect(theme.lookup(Scopes.typeBuiltin)?.color, 0xFF569CD6);
    expect(theme.lookup(Scopes.comment)?.color, 0xFF6A9955);
  });

  test('most specific selector wins; later rule wins ties', () {
    // keyword maps to keyword.control first, which has two rules.
    expect(theme.lookup(Scopes.keyword)?.color, 0xFFD16DC1);
    // Font style comes from the most specific rule that sets one.
    expect(theme.lookup(Scopes.keyword)?.bold, isTrue);
    expect(theme.lookup(Scopes.keyword)?.underline, isTrue);
    expect(theme.lookup(Scopes.keyword)?.italic, isFalse);
    expect(theme.lookup(Scopes.commentDoc)?.color, 0xFF608B4E);
    // The doc comment inherits the italic font style from `comment`.
    expect(theme.lookup(Scopes.commentDoc)?.italic, isTrue);
  });

  test('font styles, backgrounds and empty resets', () {
    final number = theme.lookup(Scopes.number)!;
    expect(number.color, 0xFFBB55CC);
    expect(number.italic, isFalse);
    expect(number.bold, isFalse);
    final added = theme.lookup(Scopes.addition)!;
    expect(added.background, 0xFF1F3A1F);
    expect(theme.lookup(Scopes.deletion)?.strikethrough, isTrue);
  });

  test('colour forms', () {
    expect(theme.lookup(Scopes.function)?.color, 0x80DCDCAA);
  });

  test('descendant selectors use their last segment', () {
    expect(theme.lookup(Scopes.type)?.color, 0xFF4EC9B0);
  });

  test('selectors with exclusions are ignored', () {
    expect(theme.lookup(Scopes.string)?.color, isNot(0xFFFF0000));
  });

  test('unmapped scopes stay unset', () {
    expect(theme.lookup(Scopes.tag), isNull);
  });

  test('light themes and type detection', () {
    final light = ValTheme.fromVsCode({
      'colors': {'editor.background': '#FFFFFF'},
    });
    expect(light.dark, isFalse);
    expect(light.name, 'vscode');
    expect(ValTheme.fromVsCode({'type': 'hc-light'}).dark, isFalse);
    expect(ValTheme.fromVsCode({'type': 'hc-black'}).dark, isTrue);
    expect(
      ValTheme.fromVsCode({
        'colors': {'editor.background': '#000'},
      }).dark,
      isTrue,
    );
  });

  test('rejects non-object JSON', () {
    expect(() => ValTheme.fromVsCodeJson('[]'), throwsFormatException);
  });
}
