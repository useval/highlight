import '../advanced.dart';

/// Sass in SCSS syntax.
const scssLanguage = Grammar(
  name: 'scss',
  aliases: ['sass'],
  fileExtensions: ['scss'],
  caseInsensitive: true,
  signatures: [
    r'^\s*\$[\w-]+\s*:\s*[^;]+;',
    r'@(?:mixin|include|extend|use|forward)\s',
    r'#\{\$[\w-]+\}',
    r'^\s*&(?::|\.|-|__)',
  ],
  rules: [
    IncludeRule('comments'),
    IncludeRule('variableDeclaration'),
    IncludeRule('atRule'),
    IncludeRule('strings'),
    IncludeRule('variable'),
    IncludeRule('interpolation'),
    // Conditions such as `@media (max-width: 600px)` and argument lists.
    RegionRule(
      begin: r'\(',
      end: r'\)',
      rules: [
        IncludeRule('comments'),
        TokenRule(r'-?[_a-z][\w-]*(?=[ \t]*:)', scope: Scopes.property),
        IncludeRule('values'),
      ],
    ),
    TokenRule(r'%[\w-]+', scope: Scopes.type),
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
    'variableDeclaration': [
      // `$name: value;` declares a variable.
      RegionRule(
        begin: r'\$[\w-]+(?=[ \t]*:)',
        end: r';|(?=\})',
        beginScope: Scopes.variable,
        rules: [IncludeRule('values')],
      ),
    ],
    'atRule': [
      // Control directives take an expression up to `;` or `{`.
      RegionRule(
        begin: r'@(?:return|if|else[ \t]+if|each|for|while|debug|warn|error)\b',
        end: r'(?=[;{}])',
        beginScope: Scopes.keyword,
        rules: [IncludeRule('values')],
      ),
      // Names declared or used by mixins and functions.
      TokenRule(
        r'(?<=@(?:mixin|include|function)[ \t]{1,8})[\w-]+',
        scope: Scopes.function,
      ),
      TokenRule(r'@[\w-]+', scope: Scopes.keyword),
    ],
    'strings': [
      QuotedString('"', rules: [IncludeRule('interpolation')]),
      QuotedString("'", rules: [IncludeRule('interpolation')]),
    ],
    'variable': [TokenRule(r'\$[\w-]+', scope: Scopes.variable)],
    'interpolation': [
      Interpolation('#{', '}', rules: [IncludeRule('values')]),
    ],
    'block': [
      RegionRule(
        begin: r'\{',
        end: r'\}',
        rules: [
          IncludeRule('comments'),
          IncludeRule('variableDeclaration'),
          // A declaration: `name: value;`, where the name and the value may
          // interpolate `#{…}`.
          RegionRule(
            begin:
                r'(?:--[\w-]+|-?[_a-z][\w-]*(?:#\{[^}\n]*\}[\w-]*)*)'
                r'(?=[ \t]*:(?!:|[a-z-]+[ \t]*[{,])(?:[^{;}\n]|#\{[^}\n]*\})*(?:[;}]|$))',
            end: r';|(?=\})',
            beginScope: Scopes.property,
            rules: [IncludeRule('values')],
          ),
          // Otherwise a nested rule or an at-rule.
          IncludeRule.self,
        ],
      ),
    ],
    'values': [
      IncludeRule('comments'),
      IncludeRule('strings'),
      IncludeRule('variable'),
      IncludeRule('interpolation'),
      TokenRule(r'![a-z]+\b', scope: Scopes.keyword),
      TokenRule(r'#[0-9a-f]{3,8}\b', scope: Scopes.number),
      TokenRule(
        r'(?<![\w-])[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?(?:%|[a-z]+)?',
        scope: Scopes.number,
      ),
      TokenRule(r'--[\w-]+', scope: Scopes.variable),
      TokenRule(r'\b(?:true|false|null)\b', scope: Scopes.literal),
      TokenRule(
        r'\b(?:and|or|not|in|to|through|from)\b',
        scope: Scopes.keyword,
      ),
      RegionRule(
        begin: r'(url)(\()',
        end: r'\)',
        beginCaptures: {1: Scopes.function},
        scope: Scopes.string,
      ),
      TokenRule(r'[\w-]+(?=\()', scope: Scopes.function),
      // Other words, including hyphenated ones, are plain.
      TokenRule(r'-?[_a-z][\w-]*'),
      RegionRule(begin: r'\(', end: r'\)', rules: [IncludeRule('values')]),
      TokenRule(r'[-+*/%=<>!]=?', scope: Scopes.operator),
    ],
  },
);
