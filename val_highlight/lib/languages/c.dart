import '../advanced.dart';

/// C keywords (C23 included).
const cKeywords = [
  'alignas', 'alignof', 'auto', 'break', 'case', 'const', 'constexpr', //
  'continue', 'default', 'do', 'else', 'enum', 'extern', 'for', 'goto', 'if',
  'inline', 'register', 'restrict', 'return', 'sizeof', 'static',
  'static_assert', 'struct', 'switch', 'thread_local', 'typedef', 'typeof',
  'union', 'volatile', 'while', '_Alignas', '_Alignof', '_Atomic',
  '_Generic', '_Noreturn', '_Static_assert', '_Thread_local',
];

/// C built-in and standard types.
const cTypes = [
  'bool', 'char', 'double', 'float', 'int', 'long', 'short', 'signed', //
  'unsigned', 'void', 'size_t', 'ssize_t', 'ptrdiff_t', 'intptr_t',
  'uintptr_t', 'int8_t', 'int16_t', 'int32_t', 'int64_t', 'uint8_t',
  'uint16_t', 'uint32_t', 'uint64_t', 'wchar_t', 'FILE', '_Bool',
  '_Complex',
];

/// C literals.
const cLiterals = ['true', 'false', 'NULL', 'nullptr'];

/// Rules shared by C, C++ and Objective-C.
const cCommonRules = <Rule>[
  Preprocessor(),
  BlockComment('/**', '*/', scope: Scopes.commentDoc),
  BlockComment('/*', '*/'),
  LineComment('///', scope: Scopes.commentDoc),
  LineComment('//'),
  QuotedString('"', prefix: r'(?:u8|[uUL])?'),
  // Character literals: 'a', '\n', L'x'.
  TokenRule(r"(?:u8|[uUL])?'(?:[^'\\\n]|\\[^\n]+?)'", scope: Scopes.string),
  Numbers(octal: false, separator: "'", suffix: '[uUlLfFzZ]{0,3}'),
];

/// C.
const cLanguage = Grammar(
  name: 'c',
  aliases: ['h'],
  fileExtensions: ['c', 'h'],
  signatures: [
    r'^#include\s*<[\w./]+\.h>',
    r'\bint\s+main\s*\(',
    r'\b(?:printf|malloc|free|sizeof)\s*\(',
  ],
  rules: [
    ...cCommonRules,
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: cKeywords,
        Scopes.typeBuiltin: cTypes,
        Scopes.literal: cLiterals,
      },
      otherwise: [CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
