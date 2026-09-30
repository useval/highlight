import '../advanced.dart';
import '../src/languages/ecmascript.dart';

/// TypeScript with JSX elements, as used by React.
const tsxLanguage = Grammar(
  name: 'tsx',
  fileExtensions: ['tsx'],
  signatures: [
    r'\breturn\s*\(?\s*<[A-Za-z>]',
    r'<[A-Z][\w.]*(?:\s+[\w-]+=|\s*/?>)',
    r'\bclassName=',
    r'''\bfrom\s+['"]react['"]''',
    r'\b(?:interface|type)\s+\w*Props\b',
    r':\s*(?:React\.)?(?:FC|ReactNode|JSX\.Element)\b',
  ],
  rules: jsxRules,
  repository: {
    ...jsRepository,
    ...jsxRepository,
    'words': [
      ...jsMemberRules,
      KeywordRule(
        {
          Scopes.keyword: [...jsKeywords, ...tsExtraKeywords],
          Scopes.literal: jsLiterals,
          Scopes.variableLanguage: jsVariables,
          Scopes.typeBuiltin: [...jsBuiltins, ...tsExtraBuiltins],
        },
        word: r'(?<![\w$#])#?[A-Za-z_$][\w$]*',
        otherwise: jsWordFallbacks,
      ),
    ],
  },
);
