import '../advanced.dart';

/// Go.
const goLanguage = Grammar(
  name: 'go',
  aliases: ['golang'],
  fileExtensions: ['go'],
  signatures: [
    r'^package\s+\w+\s*$',
    r'\bfunc\s+(?:\([^)]*\)\s*)?\w+\s*\(',
    r':=',
    r'^import\s+\(',
  ],
  rules: [
    BlockComment('/*', '*/'),
    LineComment('//'),
    QuotedString('"'),
    // Raw strings span lines and have no escapes.
    QuotedString('`', escape: null, multiline: true),
    // Rune literals: 'a', '\n', 'é'.
    TokenRule(r"'(?:[^'\\\n]|\\[^\n]+?)'", scope: Scopes.string),
    Numbers(suffix: 'i?'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'break', 'case', 'chan', 'const', 'continue', 'default', 'defer', //
          'else', 'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import',
          'interface', 'map', 'package', 'range', 'return', 'select',
          'struct', 'switch', 'type', 'var',
        ],
        Scopes.literal: ['true', 'false', 'nil', 'iota'],
        Scopes.typeBuiltin: [
          'any', 'bool', 'byte', 'comparable', 'complex64', 'complex128', //
          'error', 'float32', 'float64', 'int', 'int8', 'int16', 'int32',
          'int64', 'rune', 'string', 'uint', 'uint8', 'uint16', 'uint32',
          'uint64', 'uintptr',
        ],
        Scopes.function: [
          'append', 'cap', 'clear', 'close', 'complex', 'copy', 'delete', //
          'imag', 'len', 'make', 'max', 'min', 'new', 'panic', 'print',
          'println', 'real', 'recover',
        ],
      },
      // Capitalised names are exported, not types, in Go: types are the
      // names declared with `type`, and anything called is a function,
      // including generic calls such as `New[K, V](`.
      otherwise: [
        TokenRule(r'(?<=\btype[ \t]{1,8})[A-Za-z_]\w*', scope: Scopes.type),
        CommonRules.functionCall,
        TokenRule(r'[A-Za-z_]\w*(?=\[[^\]\n]*\]\s*\()', scope: Scopes.function),
        // `Name[K, V]{` is a composite literal of a generic type.
        TokenRule(r'[A-Za-z_]\w*(?=\[[^\]\n]*\]\s*\{)', scope: Scopes.type),
      ],
    ),
    Operators('+-*/%=<>!&|^~:'),
  ],
);
