import '../advanced.dart';

/// C# (12+).
const csharpLanguage = Grammar(
  name: 'csharp',
  aliases: ['cs', 'c#'],
  fileExtensions: ['cs', 'csx'],
  signatures: [
    r'^using\s+System(?:\.[\w.]+)?;\s*$',
    r'^namespace\s+[\w.]+\s*[;{]?\s*$',
    r'\bpublic\s+(?:static\s+|sealed\s+|partial\s+)*class\s+\w+',
    r'\bConsole\.WriteLine\s*\(',
    r'\{\s*get;\s*(?:set;|init;)?\s*\}',
  ],
  rules: [
    Preprocessor(),
    LineComment('///', scope: Scopes.commentDoc),
    BlockComment('/*', '*/'),
    LineComment('//'),
    // Raw strings (C# 11): three or more quotes, closed by the same count.
    // With `$$`, interpolations are `{{…}}` and single braces are text.
    RegionRule(
      begin: r'\$\$+("{3,})',
      end: r'\1',
      scope: Scopes.string,
      endReferencesBegin: true,
      rules: [TokenRule(r'\{\{+[^{}\n]*\}\}+', scope: Scopes.interpolation)],
    ),
    RegionRule(
      begin: r'\$("{3,})',
      end: r'\1',
      scope: Scopes.string,
      endReferencesBegin: true,
      rules: [Interpolation('{', '}')],
    ),
    RegionRule(
      begin: r'("{3,})',
      end: r'\1',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    // Interpolated verbatim strings: $@"…" and @$"…".
    QuotedString(
      '"',
      prefix: r'(?:\$@|@\$)',
      escape: null,
      doubled: true,
      multiline: true,
      rules: [IncludeRule('interpolation')],
    ),
    // Verbatim strings: @"C:\path", with "" for a quote.
    QuotedString(
      '"',
      prefix: '@',
      escape: null,
      doubled: true,
      multiline: true,
    ),
    QuotedString('"', prefix: r'\$', rules: [IncludeRule('interpolation')]),
    QuotedString('"'),
    TokenRule(
      r"'(?:[^'\\\n]|\\(?:u[0-9a-fA-F]{4}|x[0-9a-fA-F]{1,4}|[^\n]))'",
      scope: Scopes.string,
    ),
    // Attributes on their own line: [Serializable], [HttpGet("x")].
    TokenRule(
      r'^([ \t]*\[)((?:assembly:|return:|module:)?[A-Z][\w.]*)',
      captures: {2: Scopes.meta},
    ),
    Numbers(octal: false, suffix: '(?:[uU][lL]?|[lL][uU]?|[fFdDmM])?'),
    // @identifiers: @class, @event used as names.
    TokenRule(r'@[A-Za-z_]\w*'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'add', 'alias', 'and', 'as', 'ascending', 'async', //
          'await', 'break', 'by', 'case', 'catch', 'checked', 'class', 'const',
          'continue', 'default', 'delegate', 'descending', 'do', 'else',
          'enum', 'equals', 'event', 'explicit', 'extern', 'file', 'finally',
          'fixed', 'for', 'foreach', 'from', 'get', 'global', 'goto', 'group',
          'if', 'implicit', 'in', 'init', 'interface', 'internal', 'into', 'is',
          'join', 'let', 'lock', 'managed', 'nameof', 'namespace', 'new',
          'not', 'notnull', 'on', 'operator', 'or', 'orderby', 'out',
          'override', 'params', 'partial', 'private', 'protected', 'public',
          'readonly', 'record', 'ref', 'remove', 'required', 'return',
          'scoped', 'sealed', 'select', 'set', 'sizeof', 'stackalloc',
          'static', 'struct', 'switch', 'throw', 'try', 'typeof', 'unchecked',
          'unmanaged', 'unsafe', 'using', 'var', 'virtual', 'volatile', 'when',
          'where', 'while', 'with', 'yield',
        ],
        Scopes.literal: ['true', 'false', 'null'],
        Scopes.variableLanguage: ['this', 'base'],
        Scopes.typeBuiltin: [
          'bool', 'byte', 'char', 'decimal', 'double', 'dynamic', 'float', //
          'int', 'long', 'nint', 'nuint', 'object', 'sbyte', 'short', 'string',
          'uint', 'ulong', 'ushort', 'void', 'Object', 'String',
        ],
      },
      // Methods are PascalCase, so calls are checked before types.
      otherwise: [CommonRules.functionCall, CommonRules.capitalizedType],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
  repository: {
    'interpolation': [
      TokenRule(r'\{\{|\}\}', scope: Scopes.stringEscape),
      Interpolation('{', '}'),
    ],
  },
);
