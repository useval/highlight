import '../advanced.dart';
import '../src/languages/ecmascript.dart';

/// JavaScript with JSX elements, as used by React.
const jsxLanguage = Grammar(
  name: 'jsx',
  aliases: ['react'],
  fileExtensions: ['jsx'],
  signatures: [
    r'\breturn\s*\(?\s*<[A-Za-z>]',
    r'<[A-Z][\w.]*(?:\s+[\w-]+=|\s*/?>)',
    r'\bclassName=',
    r'</[A-Za-z][\w.]*>\s*\)?;?\s*$',
    r'''\bfrom\s+['"]react['"]''',
  ],
  rules: jsxRules,
  repository: {
    ...jsRepository,
    ...jsxRepository,
    'words': [
      ...jsMemberRules,
      KeywordRule(
        {
          Scopes.keyword: jsKeywords,
          Scopes.literal: jsLiterals,
          Scopes.variableLanguage: jsVariables,
          Scopes.typeBuiltin: jsBuiltins,
        },
        word: r'(?<![\w$#])#?[A-Za-z_$][\w$]*',
        otherwise: jsWordFallbacks,
      ),
    ],
  },
);
