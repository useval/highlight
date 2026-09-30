import '../advanced.dart';

/// At-rules that are not variables in Less.
const _atRules =
    '@(?:media|import|charset|namespace|supports|font-face|keyframes|'
    '-webkit-keyframes|page|plugin|document|container|layer|property)'
    r'(?![\w-])';

/// Less.
const lessLanguage = Grammar(
  name: 'less',
  fileExtensions: ['less'],
  caseInsensitive: true,
  signatures: [
    r'^\s*@[\w-]+\s*:\s*[^;]+;',
    r'@\{[\w-]+\}',
    r'^\s*\.[\w-]+\s*\([^)]*\)\s*(?:when\b[^{]*)?\{',
    r'\.[\w-]+\s*\(\s*\)\s*;',
  ],
  rules: [
    IncludeRule('comments'),
    TokenRule(_atRules, scope: Scopes.keyword),
    IncludeRule('variableDeclaration'),
    IncludeRule('strings'),
    IncludeRule('variable'),
    RegionRule(
      begin: r'\(',
      end: r'\)',
      rules: [
        IncludeRule('comments'),
        TokenRule(r'-?[_a-z][\w-]*(?=[ \t]*:)', scope: Scopes.property),
        IncludeRule('values'),
      ],
    ),
    TokenRule(r'\bwhen\b', scope: Scopes.keyword),
    // Mixin calls and definitions: `.rounded(4px);`.
    TokenRule(
      r'[.#][\w-]+(?=[ \t]*(?:\r?\n[ \t]*)?\()',
      scope: Scopes.function,
    ),
    TokenRule(r'\.-?[_a-z][\w-]*', scope: Scopes.type),
    TokenRule(r'#-?[_a-z][\w-]*', scope: Scopes.meta),
    TokenRule(r'::?[a-z-]+', scope: Scopes.keyword),
    RegionRule(
      begin: r'\[',
      end: r'\]',
      scope: Scopes.attribute,
      rules: [IncludeRule('strings')],
    ),
    TokenRule(r'&|\*|[>+~]', scope: Scopes.operator),
    TokenRule(r'-?[_a-z][\w-]*', scope: Scopes.tag),
    IncludeRule('block'),
  ],
  repository: {
    'comments': [BlockComment('/*', '*/'), LineComment('//')],
    'strings': [
      QuotedString('"', rules: [IncludeRule('variable')]),
      QuotedString("'", rules: [IncludeRule('variable')]),
    ],
    'variableDeclaration': [
      // `@name: value;` declares a variable.
      RegionRule(
        begin: r'@[\w-]+(?=[ \t]*:)',
        end: r';|(?=\})',
        beginScope: Scopes.variable,
        rules: [IncludeRule('values')],
      ),
    ],
    'variable': [
      // `@{name}` interpolation, `@name` and `@@name`.
      TokenRule(r'@\{[\w-]+\}|@@?[\w-]+', scope: Scopes.variable),
    ],
    'block': [
      RegionRule(
        begin: r'\{',
        end: r'\}',
        rules: [
          IncludeRule('comments'),
          TokenRule(_atRules, scope: Scopes.keyword),
          IncludeRule('variableDeclaration'),
          // A declaration: `name: value;`. The name and the value may
          // interpolate `@{…}`.
          RegionRule(
            begin:
                r'(?:--[\w-]+|(?:@\{[\w-]+\}|-?[_a-z])(?:[\w-]|@\{[\w-]+\})*)'
                r'(?=[ \t]*:(?!:|[a-z-]+[ \t]*[{,])(?:[^{;}\n]|@\{[^}\n]*\})*(?:[;}]|$))',
            end: r';|(?=\})',
            beginScope: Scopes.property,
            rules: [IncludeRule('values')],
          ),
          IncludeRule.self,
        ],
      ),
    ],
    'values': [
      IncludeRule('comments'),
      IncludeRule('strings'),
      IncludeRule('variable'),
      TokenRule(r'!important\b', scope: Scopes.keyword),
      TokenRule(r'#[0-9a-f]{3,8}\b', scope: Scopes.number),
      TokenRule(
        r'(?<![\w-])[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?(?:%|[a-z]+)?',
        scope: Scopes.number,
      ),
      TokenRule(r'--[\w-]+', scope: Scopes.variable),
      TokenRule(r'\b(?:true|false|and|not|when)\b', scope: Scopes.keyword),
      // `~"escaped"` strings.
      TokenRule('~(?=["\'])', scope: Scopes.operator),
      RegionRule(
        begin: r'(url)(\()',
        end: r'\)',
        beginCaptures: {1: Scopes.function},
        scope: Scopes.string,
      ),
      TokenRule(r'[.#]?[\w-]+(?=\()', scope: Scopes.function),
      // Other words, including hyphenated ones, are plain.
      TokenRule(r'-?[_a-z][\w-]*'),
      RegionRule(begin: r'\(', end: r'\)', rules: [IncludeRule('values')]),
      TokenRule(r'[-+*/%=<>!]=?', scope: Scopes.operator),
    ],
  },
);
