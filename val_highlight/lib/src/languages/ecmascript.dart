import '../../advanced.dart';

// Building blocks shared by the JavaScript and TypeScript grammars.

/// JavaScript reserved and contextual keywords.
const jsKeywords = [
  'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', //
  'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export',
  'extends', 'finally', 'for', 'from', 'function', 'get', 'if', 'import',
  'in', 'instanceof', 'let', 'new', 'of', 'return', 'set', 'static',
  'switch', 'throw', 'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
];

/// JavaScript literal constants.
const jsLiterals = ['true', 'false', 'null', 'undefined', 'NaN', 'Infinity'];

/// JavaScript language variables.
const jsVariables = ['this', 'super', 'arguments'];

/// JavaScript global objects and constructors.
const jsBuiltins = [
  'Array', 'ArrayBuffer', 'BigInt', 'Boolean', 'console', 'DataView', //
  'Date', 'document', 'Error', 'globalThis', 'Intl', 'JSON', 'Map', 'Math',
  'Number', 'Object', 'Promise', 'Proxy', 'Reflect', 'RegExp', 'Set',
  'String', 'Symbol', 'TypeError', 'WeakMap', 'WeakSet', 'window',
];

/// Repository shared by JavaScript and TypeScript. The including grammar
/// must define a `words` entry.
const jsRepository = <String, List<Rule>>{
  'comments': [
    RegionRule(
      begin: r'/\*\*(?!/)',
      end: r'\*/',
      scope: Scopes.commentDoc,
      rules: [TokenRule(r'@\w+', scope: Scopes.keyword)],
    ),
    RegionRule(begin: r'/\*', end: r'\*/', scope: Scopes.comment),
    TokenRule(r'//.*$', scope: Scopes.comment),
  ],
  'strings': [
    RegionRule(
      begin: "'",
      end: r"'|$",
      scope: Scopes.string,
      rules: [IncludeRule('escape')],
    ),
    RegionRule(
      begin: '"',
      end: r'"|$',
      scope: Scopes.string,
      rules: [IncludeRule('escape')],
    ),
    RegionRule(
      begin: '`',
      end: '`',
      scope: Scopes.string,
      rules: [
        IncludeRule('escape'),
        RegionRule(
          begin: r'\$\{',
          end: r'\}',
          scope: Scopes.interpolation,
          rules: [IncludeRule('braces'), IncludeRule.self],
        ),
      ],
    ),
  ],
  'escape': [
    TokenRule(
      r'\\(?:x[0-9A-Fa-f]{2}|u\{[0-9A-Fa-f]+\}|u[0-9A-Fa-f]{4}|[\s\S])',
      scope: Scopes.stringEscape,
    ),
  ],
  // Keeps `{ }` balanced inside `${ }`.
  'braces': [
    RegionRule(
      begin: r'\{',
      end: r'\}',
      rules: [IncludeRule('braces'), IncludeRule.self],
    ),
  ],
  // A `/` starts a regex only where an expression may begin.
  'regexp': [
    TokenRule(
      r'(?<=(?:^|[(,=:\[!&|?{};+\-*%<>~^]|\breturn|\btypeof|\bcase)\s*)'
      r'/(?![*/])(?:[^/\\\[\n]|\\.|\[(?:[^\]\\\n]|\\.)*\])+/[dgimsuvy]*',
      scope: Scopes.regexp,
    ),
  ],
  'numbers': [
    TokenRule(
      r'(?<![\w$])(?:0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+'
      r'|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?)n?'
      r'(?![\w$])',
      scope: Scopes.number,
    ),
  ],
  'decorator': [TokenRule(r'@[A-Za-z_$][\w$.]*', scope: Scopes.meta)],
  'operators': [
    TokenRule(
      r'=>|\?\?=?|\?\.|\.\.\.|\*\*=?|[=!]==?|&&=?|\|\|=?|<<=?|>>>?=?'
      r'|[-+*/%&|^~!<>=?]=?',
      scope: Scopes.operator,
    ),
  ],
};

/// After a `.`, a name is a member: never a keyword (`Array.from`), and a
/// function when called.
const jsMemberRules = [
  TokenRule(
    r'(?<=\.)#?[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
    scope: Scopes.function,
  ),
  TokenRule(r'(?<=\.)#?[A-Za-z_$][\w$]*'),
];

/// Rules tried on identifiers that are not keywords.
const jsWordFallbacks = [
  TokenRule(r'_*[A-Z][\w$]*', scope: Scopes.type),
  TokenRule(
    r'[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
    scope: Scopes.function,
  ),
];

/// Top-level rules shared by JavaScript and TypeScript.
const jsRules = [
  TokenRule(r'^#!.*$', scope: Scopes.meta),
  IncludeRule('comments'),
  IncludeRule('strings'),
  IncludeRule('regexp'),
  IncludeRule('numbers'),
  IncludeRule('decorator'),
  IncludeRule('words'),
  IncludeRule('operators'),
];

/// TypeScript keywords beyond JavaScript's. Keep in sync with
/// `typescriptLanguage`.
const tsExtraKeywords = [
  'abstract', 'asserts', 'declare', 'enum', 'implements', 'infer', //
  'interface', 'is', 'keyof', 'module', 'namespace', 'override', 'private',
  'protected', 'public', 'readonly', 'satisfies', 'type', 'unique',
];

/// TypeScript built-in types beyond JavaScript's. Keep in sync with
/// `typescriptLanguage`.
const tsExtraBuiltins = [
  'any', 'bigint', 'boolean', 'never', 'number', 'object', 'Partial', //
  'Readonly', 'Record', 'string', 'symbol', 'unknown',
];

// JSX, shared by the JSX and TSX grammars.

/// Where a JSX element may start: at the start of a line or after a token
/// that begins an expression. Stays on one line, so incremental
/// highlighting never depends on earlier lines.
const _jsxContext = r'(?<=(?:^|[(,=:?&|{\[;]|\breturn|\bdefault|=>)[ \t]*)';

/// A lower-case element (`div`, `my-element`, `svg:path`) or a fragment
/// (`<>`). The name is capture 2; fragments leave it empty. Type arguments
/// may follow a name, as in `<List<number> …>`.
const _jsxLowerStart =
    r'(<)(?:([a-z][\w-]*(?::[\w-]+)?)'
    r'(?:<[^<>\n]*(?:<[^<>\n]*>[^<>\n]*)*>)?'
    r'(?=[\s/>])|(?=>))';

/// A component: capitalised or dotted (`Card`, `Foo.Bar`, `motion.div`).
/// `<T extends …>` and `<T>(…)` are TypeScript type parameters, not
/// elements.
const _jsxComponentStart =
    r'(<)([A-Z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*'
    r'|[a-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+)'
    r'(?:<[^<>\n]*(?:<[^<>\n]*>[^<>\n]*)*>)?'
    r'(?=[\s/>])(?!\s+extends\b|>\s*\()';

/// Self-closing `/>`, or the closing tag matching the opening name. The
/// lookahead keeps the name group non-empty for fragments (`</>`).
const _jsxEnd = r'(/>)|(</)(\2(?=\s*>))(\s*>)';

/// Opening tag, then children, then the closing tag.
const _jsxElementRules = <Rule>[
  IncludeRule('jsxAttributes'),
  TokenRule('>', scope: Scopes.punctuation),
  IncludeRule('jsxChildren'),
];

/// Repository entries for JSX. The including grammar must list `jsx` among
/// its top-level rules, before `regexp` and `operators`.
const jsxRepository = <String, List<Rule>>{
  // Elements where an expression may start.
  'jsx': [
    RegionRule(
      begin: _jsxContext + _jsxLowerStart,
      end: _jsxEnd,
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.tag},
      endCaptures: {
        1: Scopes.punctuation,
        2: Scopes.punctuation,
        3: Scopes.tag,
        4: Scopes.punctuation,
      },
      endReferencesBegin: true,
      rules: _jsxElementRules,
    ),
    RegionRule(
      begin: _jsxContext + _jsxComponentStart,
      end: _jsxEnd,
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.type},
      endCaptures: {
        1: Scopes.punctuation,
        2: Scopes.punctuation,
        3: Scopes.type,
        4: Scopes.punctuation,
      },
      endReferencesBegin: true,
      rules: _jsxElementRules,
    ),
  ],
  // Elements nested among children.
  'jsxChild': [
    RegionRule(
      begin: _jsxLowerStart,
      end: _jsxEnd,
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.tag},
      endCaptures: {
        1: Scopes.punctuation,
        2: Scopes.punctuation,
        3: Scopes.tag,
        4: Scopes.punctuation,
      },
      endReferencesBegin: true,
      rules: _jsxElementRules,
    ),
    RegionRule(
      begin: _jsxComponentStart,
      end: _jsxEnd,
      beginCaptures: {1: Scopes.punctuation, 2: Scopes.type},
      endCaptures: {
        1: Scopes.punctuation,
        2: Scopes.punctuation,
        3: Scopes.type,
        4: Scopes.punctuation,
      },
      endReferencesBegin: true,
      rules: _jsxElementRules,
    ),
  ],
  // The attributes of an opening tag, up to `>` or `/>`. Starts right after
  // the tag name; skipped when the tag closes at once (`<div>`).
  'jsxAttributes': [
    RegionRule(
      begin:
          r'(?<=<[A-Za-z_$][\w$.:-]*'
          r'(?:<[^<>\n]*(?:<[^<>\n]*>[^<>\n]*)*>)?)(?!/?>)',
      end: r'(?=/?>)',
      rules: [
        IncludeRule('comments'),
        TokenRule(r'[A-Za-z_$][\w$:-]*', scope: Scopes.attribute),
        TokenRule('=', scope: Scopes.operator),
        RegionRule(begin: '"', end: '"', scope: Scopes.string),
        RegionRule(begin: "'", end: "'", scope: Scopes.string),
        IncludeRule('jsxExpression'),
      ],
    ),
  ],
  // Children: text stays plain.
  'jsxChildren': [
    IncludeRule('jsxChild'),
    IncludeRule('jsxExpression'),
    TokenRule(
      r'&(?:[A-Za-z][\w]*|#\d+|#[xX][\da-fA-F]+);',
      scope: Scopes.stringEscape,
    ),
  ],
  // `{expression}`, with full JavaScript (and JSX) inside.
  'jsxExpression': [
    RegionRule(
      begin: r'\{',
      end: r'\}',
      beginScope: Scopes.punctuation,
      endScope: Scopes.punctuation,
      rules: [IncludeRule('braces'), IncludeRule.self],
    ),
  ],
};

/// Top-level rules for JSX and TSX: [jsRules] with elements.
const jsxRules = [
  TokenRule(r'^#!.*$', scope: Scopes.meta),
  IncludeRule('comments'),
  IncludeRule('strings'),
  IncludeRule('jsx'),
  IncludeRule('regexp'),
  IncludeRule('numbers'),
  IncludeRule('decorator'),
  IncludeRule('words'),
  IncludeRule('operators'),
];
