import '../advanced.dart';

/// Kotlin, including Kotlin script (`.kts`, such as `build.gradle.kts`).
const kotlinLanguage = Grammar(
  name: 'kotlin',
  aliases: ['kt', 'kts'],
  fileExtensions: ['kt', 'kts'],
  shebangs: ['kotlin'],
  signatures: [
    r'\bfun\s+(?:<[^>]*>\s*)?[\w.]+\s*\(',
    r'\b(?:val|var)\s+\w+\s*(?::\s*[\w<>?, ]+)?=',
    r'\b(?:data|sealed|enum)\s+class\b',
    r'\bcompanion\s+object\b',
    r'^package\s+[\w.]+\s*$',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    BlockComment(
      '/**',
      '*/',
      scope: Scopes.commentDoc,
      rules: [
        TokenRule(r'@[a-z]+', scope: Scopes.keyword),
        BlockComment('/*', '*/', nested: true, scope: Scopes.commentDoc),
      ],
    ),
    BlockComment('/*', '*/', nested: true),
    LineComment('//'),
    // Raw strings: no escapes, but templates.
    QuotedString(
      '"""',
      escape: null,
      multiline: true,
      lastInRun: true,
      rules: [IncludeRule('templates')],
    ),
    QuotedString('"', rules: [IncludeRule('templates')]),
    TokenRule(
      r"'(?:[^'\\\n]|\\(?:u[0-9a-fA-F]{4}|[^\n]))'",
      scope: Scopes.string,
    ),
    Annotation(),
    // Labels: `loop@ for` and `break@loop`.
    TokenRule(r'[A-Za-z_]\w*@(?=\s)', scope: Scopes.meta),
    Numbers(octal: false, suffix: '(?:[uU][lL]?|[lL]|[fF])?'),
    // Backtick identifiers: `is`, `in` used as names.
    TokenRule(r'`[^`\n]+`'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'actual', 'annotation', 'as', 'break', 'by', 'catch', //
          'class', 'companion', 'const', 'constructor', 'continue',
          'crossinline', 'data', 'do', 'else', 'enum', 'expect', 'external',
          'final', 'finally', 'for', 'fun', 'get', 'if', 'import', 'in',
          'infix', 'init', 'inline', 'inner', 'interface', 'internal', 'is',
          'lateinit', 'noinline', 'object', 'open', 'operator', 'out',
          'override', 'package', 'private', 'protected', 'public', 'reified',
          'return', 'sealed', 'set', 'suspend', 'tailrec', 'throw', 'try',
          'typealias', 'typeof', 'val', 'var', 'vararg', 'when',
          'where', 'while',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.variableLanguage: ['this', 'super', 'it', 'field'],
        Scopes.typeBuiltin: [
          'Any', 'Array', 'Boolean', 'BooleanArray', 'Byte', 'ByteArray', //
          'Char', 'CharArray', 'CharSequence', 'Comparable', 'Double',
          'DoubleArray', 'Float', 'FloatArray', 'Int', 'IntArray', 'Iterable',
          'List', 'Long', 'LongArray', 'Map', 'MutableList', 'MutableMap',
          'MutableSet', 'Nothing', 'Number', 'Pair', 'Result', 'Sequence',
          'Set', 'Short', 'ShortArray', 'String', 'Throwable', 'Triple',
          'UByte', 'UInt', 'ULong', 'UShort', 'Unit',
        ],
      },
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|?:'),
  ],
  repository: {
    'templates': [
      TokenRule(r'\$[A-Za-z_]\w*', scope: Scopes.interpolation),
      Interpolation(r'${', '}'),
    ],
  },
);
