import '../advanced.dart';

/// Lua 5.4, including Luau-style usage in game and editor scripts.
const luaLanguage = Grammar(
  name: 'lua',
  aliases: ['luau'],
  fileExtensions: ['lua', 'luau', 'rockspec'],
  shebangs: ['lua', 'luajit'],
  signatures: [
    r'^\s*local\s+function\s+\w+',
    r'^\s*local\s+[\w, ]+\s*=\s*require\s*\(?',
    r'\bthen\s*$',
    r'~=',
    r'^\s*--\[\[',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // Long comments and strings: `--[[ ]]`, `[==[ ]==]`; the closing bracket
    // must have the same number of `=`.
    RegionRule(
      begin: r'--\[(=*)\[',
      end: r'\]\1\]',
      scope: Scopes.comment,
      endReferencesBegin: true,
    ),
    LineComment('--'),
    RegionRule(
      begin: r'\[(=*)\[',
      end: r'\]\1\]',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    QuotedString('"', escape: null, rules: [_escape]),
    QuotedString("'", escape: null, rules: [_escape]),
    Numbers(binary: false, octal: false, separator: null),
    // Attributes on locals: `local x <const> = 1`.
    TokenRule(r'<(?:const|close)>', scope: Scopes.meta),
    // `obj.field`, `obj:method(`, and calls with a string or table argument.
    TokenRule(
      r'''(?<=[.:])[A-Za-z_]\w*(?=[ \t]*[({"'])''',
      scope: Scopes.function,
    ),
    TokenRule(r'(?<=\.)[A-Za-z_]\w*'),
    KeywordRule(
      {
        Scopes.keyword: [
          'and', 'break', 'do', 'else', 'elseif', 'end', 'for', 'function', //
          'goto', 'if', 'in', 'local', 'not', 'or', 'repeat', 'return',
          'then', 'until', 'while',
        ],
        Scopes.literal: ['nil', 'true', 'false'],
        Scopes.variableLanguage: ['self', '_G', '_ENV', '_VERSION'],
        Scopes.typeBuiltin: [
          'coroutine', 'debug', 'io', 'math', 'os', 'package', 'string', //
          'table', 'utf8',
        ],
        Scopes.function: [
          'assert', 'collectgarbage', 'dofile', 'error', 'getmetatable', //
          'ipairs', 'load', 'loadfile', 'next', 'pairs', 'pcall', 'print',
          'rawequal', 'rawget', 'rawlen', 'rawset', 'require', 'select',
          'setmetatable', 'tonumber', 'tostring', 'type', 'unpack', 'warn',
          'xpcall',
        ],
      },
      otherwise: [
        TokenRule(
          r'(?<=\bfunction\s)[A-Za-z_]\w*(?=[ \t]*\()',
          scope: Scopes.function,
        ),
        TokenRule(
          r'''[A-Za-z_]\w*(?=[ \t]*[("']|[ \t]*\{)''',
          scope: Scopes.function,
        ),
      ],
    ),
    TokenRule(r'::[A-Za-z_]\w*::', scope: Scopes.meta),
    TokenRule(r'\.\.\.?', scope: Scopes.operator),
    Operators('+-*/%^#&~|<>='),
  ],
);

/// Escapes: `\n`, `\x41`, `\u{48}`, `\65`, and `\z` (skip whitespace).
const _escape = TokenRule(
  r'\\(?:u\{[0-9a-fA-F]+\}|x[0-9a-fA-F]{2}|\d{1,3}|z\s*|[\s\S])',
  scope: Scopes.stringEscape,
);
