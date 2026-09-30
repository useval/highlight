import '../advanced.dart';

/// GraphQL queries and schema definitions.
const graphqlLanguage = Grammar(
  name: 'graphql',
  aliases: ['gql'],
  fileExtensions: ['graphql', 'gql', 'graphqls'],
  signatures: [
    r'^(?:query|mutation|subscription)\s+\w+\s*[({]',
    r'^fragment\s+\w+\s+on\s+\w+',
    r'^(?:type|input|interface)\s+\w+(?:\s+implements\s+[\w&\s]+)?\s*\{',
    r'\$\w+\s*:\s*\[?\w+!?\]?!?',
  ],
  rules: [
    LineComment('#'),
    // Descriptions and block strings.
    QuotedString('"""', multiline: true),
    QuotedString('"'),
    TokenRule(r'\$[A-Za-z_]\w*', scope: Scopes.variable),
    Annotation(),
    Numbers(hex: false, binary: false, octal: false, separator: null),
    // Field and argument names before `:`, even keyword-like ones such as
    // `input:`.
    TokenRule(r'[A-Za-z_]\w*(?=[ \t]*:)', scope: Scopes.property),
    KeywordRule(
      {
        Scopes.keyword: [
          'query', 'mutation', 'subscription', 'fragment', 'on', 'type', //
          'interface', 'union', 'enum', 'input', 'scalar', 'schema',
          'extend', 'directive', 'implements', 'repeatable',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.typeBuiltin: ['Int', 'Float', 'String', 'Boolean', 'ID'],
      },
      otherwise: [
        // ALL_CAPS enum values stay plain.
        TokenRule(r'[A-Z][A-Z0-9_]*[A-Z0-9](?!\w)'),
        CommonRules.capitalizedType,
        CommonRules.functionCall,
      ],
    ),
    TokenRule(r'\.\.\.|[!=|&]', scope: Scopes.operator),
  ],
);
