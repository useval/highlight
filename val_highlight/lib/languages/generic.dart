import '../advanced.dart';

/// A language-neutral grammar for code whose language is unknown.
///
/// It highlights what most programming, scripting and configuration
/// languages share: `//`, `/* */` and `#` comments, quoted strings, numbers,
/// a broad set of common keywords and literals, types, function calls,
/// annotations and operators. It is the fallback of
/// `allLanguagesRegistry()` and of `CodeView` when no language is given.
const genericLanguage = Grammar(
  name: 'generic',
  detectable: false,
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // C-family directives before `#` comments.
    TokenRule(
      r'^[ \t]*#[ \t]*(?:include|import|define|undef|if|ifdef|ifndef|elif|'
      r'else|endif|pragma|region|endregion|error|warning)\b.*$',
      scope: Scopes.meta,
    ),
    BlockComment('/**', '*/', scope: Scopes.commentDoc),
    BlockComment('/*', '*/'),
    LineComment('///', scope: Scopes.commentDoc),
    LineComment('//'),
    LineComment('#', afterSpace: true),
    QuotedString('"""', multiline: true),
    QuotedString("'''", multiline: true),
    QuotedString('"'),
    // A single quote only starts a string when it closes on the same line,
    // so Rust lifetimes and Lisp quotes stay plain.
    TokenRule(r"'(?:[^'\\\n]|\\.)*'", scope: Scopes.string),
    TokenRule(r'`[^`\n]*`', scope: Scopes.string),
    Annotation(),
    Numbers(suffix: '[uUlLfFdDnmM]{0,3}'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'and', 'as', 'async', 'await', 'break', 'case', //
          'catch', 'class', 'const', 'continue', 'def', 'default', 'defer',
          'delete', 'do', 'elif', 'else', 'elsif', 'end', 'enum', 'except',
          'export', 'extends', 'extern', 'final', 'finally', 'fn', 'for',
          'foreach', 'from', 'fun', 'func', 'function', 'go', 'goto', 'if',
          'impl', 'implements', 'import', 'in', 'include', 'inline',
          'instanceof', 'interface', 'internal', 'is', 'lambda', 'let',
          'loop', 'match', 'mod', 'module', 'mut', 'namespace', 'new', 'not',
          'object', 'of', 'open', 'operator', 'or', 'override', 'package',
          'private', 'protected', 'pub', 'public', 'raise', 'readonly',
          'record', 'ref', 'require', 'return', 'sealed', 'select',
          'static', 'struct', 'super', 'switch', 'then', 'throw', 'throws',
          'trait', 'try', 'type', 'typedef', 'typeof', 'union', 'unless',
          'until', 'use', 'using', 'val', 'var', 'virtual', 'volatile',
          'when', 'where', 'while', 'with', 'yield',
        ],
        Scopes.literal: [
          'true', 'false', 'null', 'nil', 'none', 'undefined', 'True', //
          'False', 'None', 'NULL', 'nullptr', 'NaN', 'Infinity',
        ],
        Scopes.variableLanguage: ['this', 'self', 'Self'],
        Scopes.typeBuiltin: [
          'any', 'bool', 'boolean', 'byte', 'char', 'double', 'float', //
          'int', 'long', 'number', 'short', 'str', 'string', 'uint',
          'unsigned', 'signed', 'usize', 'isize', 'void',
        ],
      },
      word: r'(?<![\w$])[A-Za-z_$][\w$]*',
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators(),
  ],
);
