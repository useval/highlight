import '../advanced.dart';

/// Scala 2 and 3.
const scalaLanguage = Grammar(
  name: 'scala',
  aliases: ['sc'],
  fileExtensions: ['scala', 'sc', 'sbt'],
  signatures: [
    r'\bobject\s+\w+\s+extends\s+App\b',
    r'\bdef\s+\w+(?:\[[^\]]*\])?\s*\([^)]*\)\s*:\s*\w+',
    r'\bcase\s+class\s+\w+',
    r'\bimport\s+scala\.',
    r'\b(?:given|using)\s+\w+\s*:',
  ],
  rules: [
    BlockComment(
      '/**',
      '*/',
      scope: Scopes.commentDoc,
      rules: [BlockComment('/*', '*/', nested: true, scope: Scopes.commentDoc)],
    ),
    BlockComment('/*', '*/', nested: true),
    LineComment('//'),
    // Interpolated strings: s"…", f"…", raw"…", and custom ones.
    QuotedString(
      '"""',
      prefix: r'[A-Za-z_]\w*',
      escape: null,
      multiline: true,
      lastInRun: true,
      rules: [IncludeRule('interpolation')],
    ),
    QuotedString('"""', escape: null, multiline: true, lastInRun: true),
    // raw"…" keeps backslashes.
    QuotedString(
      '"',
      prefix: 'raw',
      escape: null,
      rules: [IncludeRule('interpolation')],
    ),
    QuotedString(
      '"',
      prefix: r'[A-Za-z_]\w*',
      rules: [IncludeRule('interpolation')],
    ),
    QuotedString('"'),
    TokenRule(
      r"'(?:[^'\\\n]|\\(?:u[0-9a-fA-F]{4}|[^\n]))'",
      scope: Scopes.string,
    ),
    Annotation(),
    Numbers(octal: false, suffix: '[lLfFdD]?'),
    TokenRule(r'`[^`\n]+`'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'case', 'catch', 'class', 'def', 'derives', 'do', //
          'else', 'end', 'enum', 'export', 'extends', 'extension', 'final',
          'finally', 'for', 'forSome', 'given', 'if', 'implicit', 'import',
          'infix', 'inline', 'lazy', 'macro', 'match', 'new', 'object',
          'opaque', 'open', 'override', 'package', 'private', 'protected',
          'return', 'sealed', 'then', 'throw', 'trait', 'transparent', 'try',
          'type', 'using', 'val', 'var', 'while', 'with', 'yield',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.variableLanguage: ['this', 'super'],
        Scopes.typeBuiltin: [
          'Any', 'AnyRef', 'AnyVal', 'Array', 'Boolean', 'Byte', 'Char', //
          'Double', 'Either', 'Float', 'Int', 'List', 'Long', 'Map', 'Nothing',
          'Null', 'Option', 'Seq', 'Set', 'Short', 'String', 'Unit', 'Vector',
        ],
      },
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|^~?:#'),
  ],
  repository: {
    'interpolation': [
      TokenRule(r'\$\$', scope: Scopes.stringEscape),
      TokenRule(r'\$[A-Za-z_]\w*', scope: Scopes.interpolation),
      Interpolation(r'${', '}'),
    ],
  },
);
