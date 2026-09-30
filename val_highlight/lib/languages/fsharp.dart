import '../advanced.dart';

/// F#.
const fsharpLanguage = Grammar(
  name: 'fsharp',
  aliases: ['fs', 'f#'],
  fileExtensions: ['fs', 'fsi', 'fsx'],
  signatures: [
    r'\blet\s+(?:mutable|rec|inline)\s+\w+',
    r'^\s*open\s+System\b',
    r'\|>\s*\w+',
    r'\[<\w+',
    r'^\s*module\s+[A-Z][\w.]*\s*=?\s*$',
  ],
  rules: [
    // Directives: `#if DEBUG`, `#nowarn "40"`, `#r "nuget: X"`.
    TokenRule(
      r'^[ \t]*#(?:if|else|elif|endif|nowarn|r|load|light|line|time|I|'
      r'help|quit|indent)\b.*$',
      scope: Scopes.meta,
    ),
    BlockComment('(*', '*)', nested: true),
    LineComment('///', scope: Scopes.commentDoc),
    LineComment('//'),
    // Attributes: `[<EntryPoint>]`.
    RegionRule(
      begin: r'\[<',
      end: r'>\]',
      scope: Scopes.meta,
      rules: [QuotedString('"')],
    ),
    QuotedString(
      '"""',
      prefix: r'\$',
      escape: null,
      multiline: true,
      rules: [
        TokenRule(r'\{\{|\}\}', scope: Scopes.stringEscape),
        Interpolation('{', '}'),
      ],
    ),
    QuotedString('"""', escape: null, multiline: true),
    // Verbatim strings: `@"C:\dir"`, with `""` for a quote.
    QuotedString(
      '"',
      prefix: r'(?:\$@|@\$)',
      escape: null,
      doubled: true,
      multiline: true,
      rules: [
        TokenRule(r'\{\{|\}\}', scope: Scopes.stringEscape),
        Interpolation('{', '}'),
      ],
    ),
    QuotedString(
      '"',
      prefix: '@',
      escape: null,
      doubled: true,
      multiline: true,
    ),
    QuotedString(
      '"',
      prefix: r'\$',
      multiline: true,
      rules: [
        TokenRule(r'\{\{|\}\}', scope: Scopes.stringEscape),
        Interpolation('{', '}'),
      ],
    ),
    QuotedString('"', multiline: true),
    // Characters (`'a'`, `'\n'`, `'a'B`); generic parameters (`'T`) have
    // no closing quote.
    TokenRule(r"(?<![\w'])'(?:[^'\\\n]|\\[^\n]+?)'B?", scope: Scopes.string),
    TokenRule(r"(?<![\w'])'[A-Za-z_]\w*", scope: Scopes.type),
    Numbers(suffix: '(?:uy|UL|[uU][ylsLn]?|[ylsLn]|[fFmMIN])?'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'and', 'as', 'assert', 'base', 'begin', 'class', //
          'const', 'default', 'delegate', 'do', 'do!', 'done', 'downcast',
          'downto', 'elif', 'else', 'end', 'exception', 'extern', 'finally',
          'fixed', 'for', 'fun', 'function', 'global', 'if', 'in', 'inherit',
          'inline', 'interface', 'internal', 'lazy', 'let', 'let!', 'match',
          'match!', 'member', 'module', 'mutable', 'namespace', 'new', 'not',
          'of', 'open', 'or', 'override', 'private', 'public', 'rec',
          'return', 'return!', 'select', 'sig', 'static', 'struct', 'then',
          'to', 'try', 'type', 'upcast', 'use', 'use!', 'val', 'void',
          'when', 'while', 'with', 'yield', 'yield!', 'and!',
        ],
        Scopes.literal: ['true', 'false', 'null', 'None', 'Some'],
        Scopes.variableLanguage: ['this', 'base', '__SOURCE_DIRECTORY__'],
        Scopes.typeBuiltin: [
          'bool', 'byte', 'sbyte', 'int', 'int8', 'int16', 'int32', //
          'int64', 'uint', 'uint8', 'uint16', 'uint32', 'uint64', 'nativeint',
          'unativeint', 'char', 'string', 'decimal', 'float', 'float32',
          'double', 'single', 'unit', 'obj', 'bigint', 'list', 'array',
          'seq', 'option', 'voption', 'exn', 'Result', 'Async', 'Task',
        ],
      },
      word: r"(?<![\w'])[A-Za-z_][\w']*!?",
      // F# applies functions with a space (`f x`), so only `name(` counts
      // as a call.
      otherwise: [
        CommonRules.capitalizedType,
        TokenRule(r"[A-Za-z_][\w']*(?=\()", scope: Scopes.function),
      ],
    ),
    Operators(r'!%&*+-./<=>?@^|~:'),
  ],
);
