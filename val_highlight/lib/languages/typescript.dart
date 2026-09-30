import '../advanced.dart';
import '../src/languages/ecmascript.dart';

/// TypeScript.
const typescriptLanguage = Grammar(
  name: 'typescript',
  aliases: ['ts', 'mts', 'cts'],
  fileExtensions: ['ts', 'mts', 'cts'],
  shebangs: ['ts-node', 'tsx'],
  signatures: [
    r'\b(?:interface|type)\s+[A-Z]\w*\s*(?:<[^>]*>)?\s*[={]',
    r':\s*(?:string|number|boolean|void|any|unknown)\b',
    r'\b(?:private|public|protected|readonly)\s+\w+\s*[:(]',
    r'\bas\s+(?:const|[A-Z]\w*)\b',
  ],
  rules: jsRules,
  repository: {
    ...jsRepository,
    'words': [
      ...jsMemberRules,
      KeywordRule(
        {
          Scopes.keyword: [
            ...jsKeywords,
            'abstract', 'asserts', 'declare', 'enum', 'implements', //
            'infer', 'interface', 'is', 'keyof', 'module', 'namespace',
            'override', 'private', 'protected', 'public', 'readonly',
            'satisfies', 'type', 'unique',
          ],
          Scopes.literal: jsLiterals,
          Scopes.variableLanguage: jsVariables,
          Scopes.typeBuiltin: [
            ...jsBuiltins,
            'any', 'bigint', 'boolean', 'never', 'number', 'object', //
            'Partial', 'Readonly', 'Record', 'string', 'symbol', 'unknown',
          ],
        },
        word: r'(?<![\w$#])#?[A-Za-z_$][\w$]*',
        otherwise: jsWordFallbacks,
      ),
    ],
  },
);
