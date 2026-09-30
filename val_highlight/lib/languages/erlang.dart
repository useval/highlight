import '../advanced.dart';

/// Erlang.
const erlangLanguage = Grammar(
  name: 'erlang',
  aliases: ['erl'],
  fileExtensions: ['erl', 'hrl', 'escript'],
  fileNames: ['rebar.config'],
  signatures: [
    r'^-module\(\w+\)\.',
    r'^-export\(\[',
    r'\breceive\b[\s\S]*?\bend\b',
    r'\w+\s*\([^)]*\)\s*->',
  ],
  rules: [
    LineComment('%'),
    // Module attributes: `-module(x).`, `-spec`, `-record`.
    TokenRule(r'^-[a-z_]\w*', scope: Scopes.meta),
    // Macros: `?MODULE`, `??Arg`.
    TokenRule(r'\?\??[A-Za-z_][\w@]*', scope: Scopes.meta),
    // Character literals: `$a`, `$\n`, `$\x{41}`.
    TokenRule(
      r'\$(?:\\(?:\^[\s\S]|[0-7]{1,3}|x[0-9a-fA-F]{2}|x\{[0-9a-fA-F]+\}|'
      r'[\s\S])|[\s\S])',
      scope: Scopes.string,
    ),
    QuotedString('"""', escape: null, multiline: true),
    QuotedString(
      '"',
      multiline: true,
      rules: [TokenRule(r'~[\d.*]*[a-zA-Z~]', scope: Scopes.stringEscape)],
    ),
    // Quoted atoms: `'hello world'`.
    QuotedString("'", scope: Scopes.literal),
    // Record names: `#state{`, `S#state.count`.
    TokenRule(r'#[a-z_][\w@]*', scope: Scopes.type),
    // Numbers in a base: `16#FF`, `2#1010`.
    TokenRule(r'(?<![\w@.])\d+#[0-9a-zA-Z_]+', scope: Scopes.number),
    Numbers(hex: false, binary: false, octal: false),
    KeywordRule(
      {
        Scopes.keyword: [
          'after', 'and', 'andalso', 'band', 'begin', 'bnot', 'bor', 'bsl', //
          'bsr', 'bxor', 'case', 'catch', 'cond', 'div', 'else', 'end', 'fun',
          'if', 'let', 'maybe', 'not', 'of', 'or', 'orelse', 'receive', 'rem',
          'try', 'when', 'xor',
        ],
        Scopes.literal: ['true', 'false', 'undefined', 'ok', 'error'],
      },
      word: r'(?<![\w@])[A-Za-z_][\w@]*',
      otherwise: [
        TokenRule(
          r'[a-z][\w@]*(?=[ \t]*(?:\r?\n[ \t]*)?\()',
          scope: Scopes.function,
        ),
        TokenRule(r'[A-Z_][\w@]*', scope: Scopes.variable),
      ],
    ),
    Operators(r'+-*/=<>!|:?'),
  ],
);
