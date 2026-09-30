import '../advanced.dart';

/// Java (21+), including records, sealed types and text blocks.
const javaLanguage = Grammar(
  name: 'java',
  aliases: ['jsp'],
  fileExtensions: ['java'],
  signatures: [
    r'\bpublic\s+(?:final\s+|abstract\s+)?class\s+\w+',
    r'\bpublic\s+static\s+void\s+main\s*\(\s*String',
    r'^import\s+(?:static\s+)?[\w.]+(?:\.\*)?;\s*$',
    r'^package\s+[\w.]+;\s*$',
    r'\bSystem\.out\.println\s*\(',
  ],
  rules: [
    BlockComment(
      '/**',
      '*/',
      scope: Scopes.commentDoc,
      rules: [TokenRule(r'@[a-zA-Z]+', scope: Scopes.keyword)],
    ),
    BlockComment('/*', '*/'),
    LineComment('//'),
    // Text blocks.
    QuotedString('"""', multiline: true),
    QuotedString('"'),
    TokenRule(
      r"'(?:[^'\\\n]|\\(?:u+[0-9a-fA-F]{4}|[0-7]{1,3}|[^\n]))'",
      scope: Scopes.string,
    ),
    Annotation(),
    Numbers(octal: false, suffix: '[lLfFdD]?'),
    TokenRule(r'\bnon-sealed\b', scope: Scopes.keyword),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'assert', 'break', 'case', 'catch', 'class', 'const', //
          'continue', 'default', 'do', 'else', 'enum', 'extends', 'final',
          'finally', 'for', 'goto', 'if', 'implements', 'import',
          'instanceof', 'interface', 'native', 'new', 'package', 'permits',
          'private', 'protected', 'public', 'record', 'return', 'sealed',
          'static', 'strictfp', 'switch', 'synchronized', 'throw', 'throws',
          'transient', 'try', 'var', 'volatile', 'when', 'while', 'yield',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.variableLanguage: ['this', 'super'],
        Scopes.typeBuiltin: [
          'boolean', 'byte', 'char', 'double', 'float', 'int', 'long', //
          'short', 'void', 'Boolean', 'Byte', 'Character', 'Double', 'Float',
          'Integer', 'Long', 'Number', 'Object', 'Short', 'String', 'Void',
        ],
      },
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
