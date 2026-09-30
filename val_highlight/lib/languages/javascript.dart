import '../advanced.dart';
import '../src/languages/ecmascript.dart';

/// JavaScript, including JSX-free modern syntax.
const javascriptLanguage = Grammar(
  name: 'javascript',
  aliases: ['js', 'mjs', 'cjs'],
  fileExtensions: ['js', 'mjs', 'cjs'],
  shebangs: ['node', 'deno', 'bun'],
  signatures: [
    r'\bconsole\.log\(',
    r'^\s*(?:import .* from |export (?:default|const|function))',
    r'\bfunction\s*\w*\s*\(',
    r'=>\s*[{(]',
    r'\b(?:const|let)\s+\w+\s*=',
  ],
  rules: jsRules,
  repository: {
    ...jsRepository,
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
