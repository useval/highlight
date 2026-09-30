import '../advanced.dart';

/// CSS, including nesting and custom properties.
const cssLanguage = Grammar(
  name: 'css',
  fileExtensions: ['css'],
  caseInsensitive: true,
  signatures: [
    r'^\s*[.#]?[\w-]+(?:\s*[,>+~]\s*[.#]?[\w-]+)*\s*\{',
    r'^\s*[\w-]+\s*:\s*[^;{}]+;\s*$',
    r'@(?:media|import|keyframes|font-face)\b',
  ],
  rules: [
    IncludeRule('comments'),
    IncludeRule('atRule'),
    IncludeRule('strings'),
    // Conditions such as `@media (max-width: 600px)`.
    RegionRule(
      begin: r'\(',
      end: r'\)',
      rules: [
        IncludeRule('comments'),
        TokenRule(
          r'--?[_a-z][\w-]*(?=[ \t]*:)|[_a-z][\w-]*(?=[ \t]*:)',
          scope: Scopes.property,
        ),
        IncludeRule('values'),
        TokenRule(r'\b(?:and|or|not|only)\b', scope: Scopes.keyword),
      ],
    ),
    TokenRule(r'\.-?[_a-z][\w-]*', scope: Scopes.type),
    TokenRule(r'#-?[_a-z][\w-]*', scope: Scopes.meta),
    TokenRule(r'::?[a-z-]+(?:\([^)]*\))?', scope: Scopes.keyword),
    RegionRule(
      begin: r'\[',
      end: r'\]',
      scope: Scopes.attribute,
      rules: [IncludeRule('strings')],
    ),
    TokenRule(r'&|\*', scope: Scopes.operator),
    TokenRule(r'-?[_a-z][\w-]*', scope: Scopes.tag),
    IncludeRule('block'),
  ],
  repository: {
    'comments': [RegionRule(begin: r'/\*', end: r'\*/', scope: Scopes.comment)],
    'atRule': [TokenRule(r'@[\w-]+', scope: Scopes.keyword)],
    'strings': [
      RegionRule(
        begin: '"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [TokenRule(r'\\.', scope: Scopes.stringEscape)],
      ),
      RegionRule(
        begin: "'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [TokenRule(r'\\.', scope: Scopes.stringEscape)],
      ),
    ],
    'block': [
      RegionRule(
        begin: r'\{',
        end: r'\}',
        rules: [
          IncludeRule('comments'),
          // A declaration: `name: value;`.
          RegionRule(
            begin:
                r'(--[\w-]+|-?[_a-z][\w-]*)(?=[ \t]*:(?!:|[a-z-]+[ \t]*[{,]))',
            end: r';|(?=\})',
            beginCaptures: {1: Scopes.property},
            rules: [IncludeRule('values')],
          ),
          // Otherwise a nested rule, as in CSS nesting or `@media`.
          IncludeRule.self,
        ],
      ),
    ],
    'values': [
      IncludeRule('comments'),
      IncludeRule('strings'),
      TokenRule(r'!important\b', scope: Scopes.keyword),
      TokenRule(r'#[0-9a-f]{3,8}\b', scope: Scopes.number),
      TokenRule(
        r'(?<![\w-])[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?(?:%|[a-z]+)?',
        scope: Scopes.number,
      ),
      TokenRule(r'--[\w-]+', scope: Scopes.variable),
      RegionRule(
        begin: r'(url)(\()',
        end: r'\)',
        beginCaptures: {1: Scopes.function},
        scope: Scopes.string,
      ),
      TokenRule(r'[\w-]+(?=\()', scope: Scopes.function),
      RegionRule(begin: r'\(', end: r'\)', rules: [IncludeRule('values')]),
    ],
  },
);
