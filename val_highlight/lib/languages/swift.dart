import '../advanced.dart';

/// Swift (6), including raw strings, macros and result builders.
const swiftLanguage = Grammar(
  name: 'swift',
  fileExtensions: ['swift'],
  shebangs: ['swift'],
  signatures: [
    r'^import\s+(?:SwiftUI|UIKit|Foundation|Combine)\s*$',
    r'\bfunc\s+\w+\s*(?:<[^>]*>)?\s*\([^)]*\)\s*(?:async\s+)?(?:throws\s+)?->',
    r'\bguard\s+let\b',
    r'\b(?:struct|class)\s+\w+\s*:\s*(?:View|ObservableObject|Codable)\b',
    r'\bif\s+let\s+\w+\s*=',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    BlockComment(
      '/**',
      '*/',
      scope: Scopes.commentDoc,
      rules: [BlockComment('/*', '*/', nested: true, scope: Scopes.commentDoc)],
    ),
    BlockComment('/*', '*/', nested: true),
    LineComment('///', scope: Scopes.commentDoc),
    LineComment('//'),
    // Raw strings: `#"…"#`, `##"""…"""##`. The closing quote needs as many
    // `#` as the opening one.
    RegionRule(
      begin: r'(#+)"""',
      end: r'"""\1',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    RegionRule(
      begin: r'(#+)"',
      end: r'"\1|$',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    // Interpolation comes before escapes, since both start with `\`.
    QuotedString(
      '"""',
      escape: null,
      multiline: true,
      rules: [IncludeRule('stringContent')],
    ),
    QuotedString('"', escape: null, rules: [IncludeRule('stringContent')]),
    // Directives and macros: #if, #available, #selector, #Preview.
    TokenRule(r'#[A-Za-z_]\w*', scope: Scopes.meta),
    Annotation(),
    Numbers(octal: true),
    // Anonymous closure arguments and property wrapper projections.
    TokenRule(r'\$\w+', scope: Scopes.variable),
    // Backtick identifiers: `default`, `class` used as names.
    TokenRule(r'`[A-Za-z_]\w*`'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'actor', 'any', 'as', 'associatedtype', 'async', 'await', //
          'borrowing', 'break', 'case', 'catch', 'class', 'consume',
          'consuming', 'continue', 'convenience', 'default', 'defer', 'deinit',
          'didSet', 'do', 'dynamic', 'each', 'else', 'enum', 'extension',
          'fallthrough', 'fileprivate', 'final', 'for', 'func', 'get', 'guard',
          'if', 'import', 'in', 'indirect', 'infix', 'init', 'inout',
          'internal', 'is', 'isolated', 'lazy', 'let', 'macro', 'mutating',
          'nonisolated', 'nonmutating', 'open', 'operator', 'optional',
          'override', 'package', 'postfix', 'precedencegroup', 'prefix',
          'private', 'protocol', 'public', 'repeat', 'required', 'rethrows',
          'return', 'sending', 'set', 'some', 'static', 'struct', 'subscript',
          'switch', 'throw', 'throws', 'try', 'typealias', 'unowned', 'var',
          'weak', 'where', 'while', 'willSet',
        ],
        Scopes.literal: ['true', 'false', 'nil'],
        Scopes.variableLanguage: ['self', 'Self', 'super'],
        Scopes.typeBuiltin: [
          'Any', 'AnyObject', 'Array', 'Bool', 'Character', 'Dictionary', //
          'Double', 'Error', 'Float', 'Int', 'Int8', 'Int16', 'Int32', 'Int64',
          'Never', 'Optional', 'Result', 'Set', 'String', 'Substring', 'UInt',
          'UInt8', 'UInt16', 'UInt32', 'UInt64', 'Void',
        ],
      },
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
  repository: {
    'stringContent': [
      RegionRule(
        begin: r'\\\(',
        end: r'\)',
        scope: Scopes.interpolation,
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
      TokenRule(
        r'\\(?:u\{[0-9a-fA-F]{1,8}\}|[\s\S])',
        scope: Scopes.stringEscape,
      ),
    ],
    // Keeps `( )` balanced inside `\( )`.
    'parens': [
      RegionRule(
        begin: r'\(',
        end: r'\)',
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
    ],
  },
);
