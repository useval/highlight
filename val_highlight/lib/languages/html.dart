import '../advanced.dart';
import '../src/languages/markup.dart';
import 'css.dart';
import 'javascript.dart';

/// HTML, with embedded CSS in `<style>` and JavaScript in `<script>`.
const htmlLanguage = Grammar(
  name: 'html',
  // Vue and Svelte single-file components are HTML with embedded script and
  // style elements.
  aliases: ['htm', 'xhtml', 'vue', 'svelte'],
  fileExtensions: ['html', 'htm', 'xhtml', 'vue', 'svelte'],
  caseInsensitive: true,
  signatures: [
    r'<!doctype\s+html',
    r'<(?:html|head|body|div|span|script|p|a|meta|link)\b[^>]*>',
    r'</(?:div|span|p|a|body|html)>',
  ],
  rules: markupRules,
  repository: {
    ...markupRepository,
    'tag': [_script, _style, markupTag],
  },
);

/// `<script>`: the opening tag, the embedded JavaScript and the closing tag
/// run in sequence inside one region.
const _script = RegionRule(
  begin: r'(?=<script\b)',
  end: r'(?<=</script\s*>)',
  rules: [
    RegionRule(
      begin: r'(<)(script)\b',
      end: '>',
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.tag},
      endScope: Scopes.punctuation,
      rules: [IncludeRule('attributes')],
    ),
    RegionRule(
      begin: r'(?<=<script\b[^>]*>)',
      end: r'(?=</[sS][cC][rR][iI][pP][tT]\s*>)',
      embed: javascriptLanguage,
    ),
    TokenRule(
      r'(</)(script)\s*(>)',
      captures: {1: Scopes.punctuation, 2: Scopes.tag, 3: Scopes.punctuation},
    ),
  ],
);

/// `<style>`, with embedded CSS. Same shape as [_script].
const _style = RegionRule(
  begin: r'(?=<style\b)',
  end: r'(?<=</style\s*>)',
  rules: [
    RegionRule(
      begin: r'(<)(style)\b',
      end: '>',
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.tag},
      endScope: Scopes.punctuation,
      rules: [IncludeRule('attributes')],
    ),
    RegionRule(
      begin: r'(?<=<style\b[^>]*>)',
      end: r'(?=</[sS][tT][yY][lL][eE]\s*>)',
      embed: cssLanguage,
    ),
    TokenRule(
      r'(</)(style)\s*(>)',
      captures: {1: Scopes.punctuation, 2: Scopes.tag, 3: Scopes.punctuation},
    ),
  ],
);
