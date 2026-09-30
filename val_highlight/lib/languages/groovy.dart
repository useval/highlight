import '../advanced.dart';

/// Groovy, including Gradle build scripts (`build.gradle`).
const groovyLanguage = Grammar(
  name: 'groovy',
  aliases: ['gradle'],
  fileExtensions: ['groovy', 'gradle', 'gvy', 'gy', 'gsh'],
  fileNames: ['Jenkinsfile'],
  shebangs: ['groovy'],
  signatures: [
    r'^\s*(?:plugins|dependencies|repositories|android|buildscript)[ \t]*(?:\r?\n[ \t]*)?\{',
    r'''^\s*(?:implementation|api|testImplementation|classpath)\s+['"]''',
    r'^\s*apply\s+plugin:',
    r'\bdef\s+\w+\s*=',
    r'''\bprintln\s+['"]''',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    BlockComment('/**', '*/', scope: Scopes.commentDoc),
    BlockComment('/*', '*/'),
    LineComment('//'),
    // Triple-quoted: ''' is plain, """ is a GString.
    QuotedString("'''", multiline: true),
    QuotedString('"""', multiline: true, rules: [IncludeRule('gstring')]),
    QuotedString('"', rules: [IncludeRule('gstring')]),
    QuotedString("'"),
    Annotation(),
    Numbers(octal: false, suffix: '[gGlLiIdDfF]?'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'as', 'assert', 'break', 'case', 'catch', 'class', //
          'const', 'continue', 'def', 'default', 'do', 'else', 'enum',
          'extends', 'final', 'finally', 'for', 'goto', 'if', 'implements',
          'import', 'in', 'instanceof', 'interface', 'native', 'new',
          'package', 'permits', 'private', 'protected', 'public', 'record',
          'return', 'sealed', 'static', 'strictfp', 'switch',
          'synchronized', 'threadsafe', 'throw', 'throws', 'trait',
          'transient', 'try', 'var', 'volatile', 'while', 'yield',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.function: ['print', 'printf', 'println', 'sprintf'],
        Scopes.variableLanguage: ['this', 'super', 'it', 'owner', 'delegate'],
        Scopes.typeBuiltin: [
          'boolean', 'byte', 'char', 'double', 'float', 'int', 'long', //
          'short', 'void', 'BigDecimal', 'BigInteger', 'Boolean', 'Closure',
          'Double', 'GString', 'Integer', 'List', 'Long', 'Map', 'Object',
          'Set', 'String',
        ],
      },
      otherwise: [
        CommonRules.capitalizedType,
        CommonRules.functionCall,
        // Command calls without parentheses, as in Gradle:
        // `implementation 'a:b:1'`, `id "x"`, `android {`.
        TokenRule('[a-z]\\w*(?=[ \\t]+[\'"]|\\s*\\{)', scope: Scopes.function),
      ],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
  repository: {
    'gstring': [
      TokenRule(
        r'\$[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*',
        scope: Scopes.interpolation,
      ),
      Interpolation(r'${', '}'),
    ],
  },
);
