import '../advanced.dart';

/// Bash and POSIX shell scripts.
const bashLanguage = Grammar(
  name: 'bash',
  aliases: ['sh', 'shell', 'zsh', 'console'],
  fileExtensions: ['sh', 'bash', 'zsh'],
  shebangs: ['bash', 'sh', 'zsh', 'dash', 'ksh'],
  signatures: [
    r'^\s*(?:if|while|until)\s+\[\[?\s',
    r'^\s*(?:fi|done|esac)\s*$',
    r'\$\{?[A-Za-z_]\w*\}?',
    r'^\s*(?:export|local|readonly)\s+[A-Za-z_]\w*=',
    r'^\s*(?:echo|cd|mkdir|rm|sudo|apt|brew|npm|git)\s',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    TokenRule(r'(?<=^|[\s;|&(])#.*$', scope: Scopes.comment),
    IncludeRule('heredocs'),
    // A backslash outside quotes escapes the next character, so `\'` is not
    // the start of a string.
    TokenRule(r'\\[\s\S]'),
    IncludeRule('strings'),
    IncludeRule('variables'),
    // `NAME=value` and `NAME+=value`.
    TokenRule(
      r'(?<=^|[\s;|&(])[A-Za-z_]\w*(?=\+?=(?!=))',
      scope: Scopes.variable,
    ),
    TokenRule(r'(?<=^|[\s;|&(])--?[A-Za-z][\w-]*', scope: Scopes.attribute),
    TokenRule(r'(?<![\w.-])\d+(?![\w.])', scope: Scopes.number),
    KeywordRule(
      {
        Scopes.keyword: [
          'case', 'coproc', 'do', 'done', 'elif', 'else', 'esac', 'fi', //
          'for', 'function', 'if', 'in', 'select', 'then', 'time', 'until',
          'while',
        ],
        Scopes.function: [
          'alias', 'bg', 'break', 'builtin', 'cd', 'command', 'continue', //
          'declare', 'echo', 'eval', 'exec', 'exit', 'export', 'fg',
          'getopts', 'hash', 'jobs', 'kill', 'let', 'local', 'printf', 'pwd',
          'read', 'readonly', 'return', 'set', 'shift', 'source', 'test',
          'trap', 'type', 'typeset', 'ulimit', 'umask', 'unalias', 'unset',
          'wait',
        ],
        Scopes.literal: ['true', 'false'],
      },
      word: r'(?<![\w$/.-])[A-Za-z_][\w-]*',
      otherwise: [
        // `name() {` and `function name` declare functions.
        TokenRule(
          r'[A-Za-z_][\w-]*(?=[ \t]*\([ \t]*\))',
          scope: Scopes.function,
        ),
      ],
    ),
    TokenRule(r'&&|\|\||;;|[|&;]|[<>]{1,2}&?', scope: Scopes.operator),
  ],
  repository: {
    // `<<EOF … EOF`. The rest of the opening line stays ordinary text; the
    // body starts on the next line. A quoted delimiter disables expansion.
    'heredocs': [
      RegionRule(
        begin: r'''(?<!<)(<<-?)[ \t]*(['"])([A-Za-z_][\w-]*)\2([^\n]*)''',
        end: r'^\t*\3$',
        beginCaptures: {1: Scopes.operator, 3: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
      ),
      RegionRule(
        begin: r'(?<!<)(<<-?)[ \t]*\\?([A-Za-z_][\w-]*)([^\n]*)',
        end: r'^\t*\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [
          TokenRule(r'[^$`\\\n]+', scope: Scopes.string),
          TokenRule(r'\\[$`\\\n]', scope: Scopes.stringEscape),
          IncludeRule('variables'),
        ],
      ),
    ],
    'strings': [
      RegionRule(
        begin: r"\$'",
        end: "'",
        scope: Scopes.string,
        rules: [TokenRule(r'\\.', scope: Scopes.stringEscape)],
      ),
      RegionRule(begin: "'", end: "'", scope: Scopes.string),
      RegionRule(
        begin: '"',
        end: '"',
        scope: Scopes.string,
        rules: [
          TokenRule(r'\\[\\"$`\n]', scope: Scopes.stringEscape),
          IncludeRule('variables'),
        ],
      ),
      RegionRule(
        begin: '`',
        end: '`',
        scope: Scopes.interpolation,
        rules: [IncludeRule.self],
      ),
    ],
    'variables': [
      RegionRule(
        begin: r'\$\(\(',
        end: r'\)\)',
        scope: Scopes.interpolation,
        rules: [IncludeRule.self],
      ),
      RegionRule(
        begin: r'\$\(',
        end: r'\)',
        scope: Scopes.interpolation,
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
      RegionRule(begin: r'\$\{', end: r'\}', scope: Scopes.variable),
      TokenRule(r'\$(?:[A-Za-z_]\w*|[0-9@*#?$!-])', scope: Scopes.variable),
    ],
    'parens': [
      RegionRule(
        begin: r'\(',
        end: r'\)',
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
    ],
  },
);
