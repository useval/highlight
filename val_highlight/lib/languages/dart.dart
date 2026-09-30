import '../advanced.dart';

/// Dart.
const dartLanguage = Grammar(
  name: 'dart',
  fileExtensions: ['dart'],
  rules: [
    IncludeRule('comments'),
    IncludeRule('strings'),
    TokenRule(r'@[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*', scope: Scopes.meta),
    IncludeRule('numbers'),
    IncludeRule('words'),
    TokenRule(r'=>|[-+*/%~^&|!<>=?]=?|\.\.\.?|\?\?=?', scope: Scopes.operator),
  ],
  repository: {
    'comments': [
      TokenRule(r'///.*$', scope: Scopes.commentDoc),
      TokenRule(r'//.*$', scope: Scopes.comment),
      RegionRule(
        begin: r'/\*\*(?!/)',
        end: r'\*/',
        scope: Scopes.commentDoc,
        rules: [IncludeRule('nestedComment')],
      ),
      RegionRule(
        begin: r'/\*',
        end: r'\*/',
        scope: Scopes.comment,
        rules: [IncludeRule('nestedComment')],
      ),
    ],
    // Dart block comments nest.
    'nestedComment': [
      RegionRule(
        begin: r'/\*',
        end: r'\*/',
        rules: [IncludeRule('nestedComment')],
      ),
    ],
    'strings': [
      RegionRule(begin: r"(?<![\w$])r'''", end: "'''", scope: Scopes.string),
      RegionRule(begin: r'(?<![\w$])r"""', end: '"""', scope: Scopes.string),
      RegionRule(begin: r"(?<![\w$])r'", end: r"'|$", scope: Scopes.string),
      RegionRule(begin: r'(?<![\w$])r"', end: r'"|$', scope: Scopes.string),
      RegionRule(
        begin: "'''",
        end: "'''",
        scope: Scopes.string,
        rules: [IncludeRule('stringContent')],
      ),
      RegionRule(
        begin: '"""',
        end: '"""',
        scope: Scopes.string,
        rules: [IncludeRule('stringContent')],
      ),
      RegionRule(
        begin: "'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [IncludeRule('stringContent')],
      ),
      RegionRule(
        begin: '"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [IncludeRule('stringContent')],
      ),
    ],
    'stringContent': [
      TokenRule(
        r'\\(?:u\{[0-9A-Fa-f]{1,6}\}|u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|[\s\S])',
        scope: Scopes.stringEscape,
      ),
      TokenRule(r'\$[A-Za-z_][A-Za-z0-9_]*', scope: Scopes.interpolation),
      RegionRule(
        begin: r'\$\{',
        end: r'\}',
        scope: Scopes.interpolation,
        rules: [IncludeRule('interpolationBody')],
      ),
    ],
    // Braces inside `${...}` must balance before the interpolation ends.
    'interpolationBody': [
      RegionRule(
        begin: r'\{',
        end: r'\}',
        rules: [IncludeRule('interpolationBody')],
      ),
      IncludeRule.self,
    ],
    'numbers': [
      TokenRule(
        r'(?<![\w$])(?:0[xX][0-9A-Fa-f](?:[0-9A-Fa-f_]*[0-9A-Fa-f])?'
        r'|(?:\d(?:[\d_]*\d)?(?:\.\d(?:[\d_]*\d)?)?|\.\d(?:[\d_]*\d)?)'
        r'(?:[eE][+-]?\d(?:[\d_]*\d)?)?)(?![\w$])',
        scope: Scopes.number,
      ),
    ],
    'words': [
      // After a `.`, a name is a member: never a keyword (`.show()`,
      // `.set()`), and a function when called.
      TokenRule(
        r'(?<=\.)[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
        scope: Scopes.function,
      ),
      TokenRule(r'(?<=\.)[A-Za-z_$][\w$]*'),
      KeywordRule(
        {
          Scopes.keyword: [
            'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', //
            'case', 'catch', 'class', 'const', 'continue', 'covariant',
            'default', 'deferred', 'do', 'else', 'enum', 'export', 'extends',
            'extension', 'external', 'factory', 'final', 'finally', 'for',
            'get', 'hide', 'if', 'implements', 'import', 'in', 'interface',
            'is', 'late', 'library', 'mixin', 'new', 'on', 'operator', 'part',
            'required', 'rethrow', 'return', 'sealed', 'set', 'show',
            'static', 'switch', 'sync', 'throw', 'try', 'typedef', 'var',
            'when', 'while', 'with', 'yield',
          ],
          Scopes.literal: ['true', 'false', 'null'],
          Scopes.variableLanguage: ['this', 'super'],
          Scopes.typeBuiltin: [
            'bool', 'double', 'dynamic', 'Duration', 'Enum', 'Function', //
            'Future', 'FutureOr', 'int', 'Iterable', 'List', 'Map', 'Never',
            'Null', 'num', 'Object', 'Record', 'Set', 'Stream', 'String',
            'Symbol', 'Type', 'void',
          ],
        },
        word: r'(?<![\w$])[A-Za-z_$][\w$]*',
        otherwise: [
          // Capitalised identifiers are types by Dart convention.
          TokenRule(r'_*[A-Z][\w$]*', scope: Scopes.type),
          // An identifier followed by `(` or `<T>(` is a function.
          TokenRule(
            r'[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
            scope: Scopes.function,
          ),
        ],
      ),
    ],
  },
);
