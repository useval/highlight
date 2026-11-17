import '../advanced.dart';
import '../src/languages/c_family.dart';

/// C.
const cLanguage = Grammar(
  name: 'c',
  editing: EditingSyntax.cStyle,
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
