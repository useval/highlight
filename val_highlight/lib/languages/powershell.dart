import '../advanced.dart';

/// PowerShell. Keywords and operators are case-insensitive.
const powershellLanguage = Grammar(
  name: 'powershell',
  aliases: ['ps1', 'pwsh', 'ps', 'posh'],
  fileExtensions: ['ps1', 'psm1', 'psd1'],
  shebangs: ['pwsh', 'powershell'],
  caseInsensitive: true,
  signatures: [
    r'\b(?:Get|Set|New|Remove|Write|Invoke|Import|Test)-[A-Z][a-zA-Z]+',
    r'^\s*param\s*\(',
    r'\$(?:PSScriptRoot|PSVersionTable|env:\w+)',
    r'\s-(?:eq|ne|like|match|notmatch)\s',
    r'\[CmdletBinding\(',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    BlockComment('<#', '#>'),
    LineComment('#'),
    // Here-strings: `@"` … `"@` expands variables, `@'` … `'@` does not.
    RegionRule(
      begin: r'@"(?=[ \t]*$)',
      end: r'^"@',
      scope: Scopes.string,
      rules: [IncludeRule('expandable')],
    ),
    RegionRule(begin: r"@'(?=[ \t]*$)", end: r"^'@", scope: Scopes.string),
    // The escape character is the backtick.
    QuotedString(
      '"',
      escape: '`',
      multiline: true,
      rules: [IncludeRule('expandable')],
    ),
    QuotedString("'", escape: null, doubled: true, multiline: true),
    IncludeRule('variables'),
    // Attributes: `[CmdletBinding()]`, `[Parameter(Mandatory)]`.
    TokenRule(r'(?<=\[)[A-Za-z_][\w.]*(?=\()', scope: Scopes.meta),
    // Type literals: `[string]`, `[System.IO.Path]`, `[int[]]`.
    TokenRule(r'\[[A-Za-z_][\w.]*(?:\[\])?\](?!\()', scope: Scopes.type),
    // Comparison and logical operators, then other `-Parameters`.
    TokenRule(
      r'(?<![\w$])-(?:c|i)?(?:eq|ne|gt|ge|lt|le|like|notlike|match|notmatch|'
      r'contains|notcontains|in|notin|replace|split|join|is|isnot|as)\b|'
      r'(?<![\w$])-(?:and|or|not|xor|band|bor|bxor|bnot|shl|shr|f)\b',
      scope: Scopes.operator,
    ),
    TokenRule(r'(?<![\w$])-[A-Za-z][A-Za-z0-9]*', scope: Scopes.attribute),
    Numbers(octal: false, separator: null, suffix: r'(?:[kmgtp]b)?[ld]?'),
    // Cmdlets and functions named `Verb-Noun`.
    TokenRule(
      r'(?<![\w$-])[A-Za-z]+-[A-Za-z][A-Za-z0-9]*(?![\w-])',
      scope: Scopes.function,
    ),
    TokenRule(r'(?<=::)[A-Za-z_]\w*', scope: Scopes.function),
    _memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'begin', 'break', 'catch', 'class', 'clean', 'configuration', //
          'continue', 'data', 'define', 'do', 'dynamicparam', 'else',
          'elseif', 'end', 'enum', 'exit', 'filter', 'finally', 'for',
          'foreach', 'from', 'function', 'hidden', 'if', 'in',
          'inlinescript', 'parallel', 'param', 'process', 'return',
          'sequence', 'static', 'switch', 'throw', 'trap', 'try', 'until',
          'using', 'var', 'while', 'workflow',
        ],
      },
      otherwise: [
        TokenRule(r'(?<=\bfunction\s)[A-Za-z_][\w-]*', scope: Scopes.function),
      ],
    ),
    Operators('+-*/%=<>!|,'),
  ],
  repository: {
    'variables': [
      TokenRule(r'\$(?:true|false|null)\b', scope: Scopes.literal),
      TokenRule(r'\$this\b', scope: Scopes.variableLanguage),
      TokenRule(r'\$\{[^}\n]*\}', scope: Scopes.variable),
      TokenRule(
        r'[$@](?:(?:global|local|script|private|using|env|variable):)?'
        r'[A-Za-z_]\w*|\$[_?^$]',
        scope: Scopes.variable,
      ),
    ],
    // Inside double quotes: variables and `$( … )` subexpressions.
    'expandable': [
      RegionRule(
        begin: r'\$\(',
        end: r'\)',
        scope: Scopes.interpolation,
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
      IncludeRule('variables'),
    ],
    'parens': [
      RegionRule(
        begin: r'\(',
        end: r'\)',
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
    ],
  },
);

/// After a `.`, a name followed by `(` on the same line is a call.
const _memberCall = TokenRule(
  r'(?<=\.)[A-Za-z_$][\w$]*(?=[ \t]*\()',
  scope: Scopes.function,
);
