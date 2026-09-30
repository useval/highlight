import '../advanced.dart';

/// Elixir.
const elixirLanguage = Grammar(
  name: 'elixir',
  aliases: ['ex', 'exs'],
  fileExtensions: ['ex', 'exs', 'heex'],
  fileNames: ['mix.lock'],
  shebangs: ['elixir'],
  signatures: [
    r'^\s*defmodule\s+[A-Z][\w.]*\s+do\s*$',
    r'^\s*defp?\s+\w+[?!]?(?:\(.*\))?\s*(?:when\s.*)?do\s*$',
    r'\|>\s*\w',
    r'\bfn\s+[^\n]*->',
    r'^\s*@(?:moduledoc|doc|spec)\b',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    LineComment('#'),
    // `@doc """…"""` heredocs, strings and charlists.
    QuotedString('"""', multiline: true, rules: [Interpolation('#{', '}')]),
    QuotedString("'''", multiline: true, rules: [Interpolation('#{', '}')]),
    QuotedString('"', multiline: true, rules: [Interpolation('#{', '}')]),
    QuotedString("'", multiline: true, rules: [Interpolation('#{', '}')]),
    // Sigils: lowercase interpolate, uppercase do not.
    _Sigils(),
    // Atoms: `:ok`, `:"quoted"`, and `key:` in keyword lists.
    TokenRule(r'(?<![:\w]):"(?:[^"\\\n]|\\.)*"', scope: _atom),
    TokenRule(r'(?<![:\w]):[A-Za-z_]\w*[?!]?', scope: _atom),
    TokenRule(r'(?<![:\w])[A-Za-z_]\w*[?!]?:(?=[ \t\n])', scope: _atom),
    // Character literals: ?a, ?\n.
    TokenRule(r'(?<![\w?])\?(?:\\.|[^\s\\])', scope: Scopes.string),
    // Module attributes: @doc, @spec, @impl.
    Annotation(),
    Numbers(),
    TokenRule(r'(?<=\.)[a-z_]\w*[?!]?(?=[ \t]*\()', scope: Scopes.function),
    TokenRule(r'(?<=\.)[a-z_]\w*[?!]?'),
    KeywordRule(
      {
        Scopes.keyword: [
          'after', 'alias', 'and', 'case', 'catch', 'cond', 'def', //
          'defdelegate', 'defexception', 'defguard', 'defguardp', 'defimpl',
          'defmacro', 'defmacrop', 'defmodule', 'defoverridable', 'defp',
          'defprotocol', 'defstruct', 'do', 'else', 'end', 'fn', 'for', 'if',
          'import', 'in', 'not', 'or', 'quote', 'raise', 'receive',
          'require', 'rescue', 'reraise', 'throw', 'try', 'unless',
          'unquote', 'unquote_splicing', 'use', 'when', 'with',
        ],
        Scopes.literal: ['true', 'false', 'nil'],
        Scopes.variableLanguage: [
          '__MODULE__', '__ENV__', '__CALLER__', '__DIR__', //
          '__STACKTRACE__',
        ],
      },
      word: r'(?<![\w@:])[A-Za-z_]\w*(?:[?!](?!=))?',
      otherwise: [
        TokenRule(
          r'(?<=\bdef[pm]?\s|\bdefmacrop?\s)[a-z_]\w*[?!]?',
          scope: Scopes.function,
        ),
        CommonRules.capitalizedType,
        TokenRule(r'[a-z_]\w*[?!]?(?=[ \t]*\()', scope: Scopes.function),
      ],
    ),
    TokenRule(r'\.\.(?://)?', scope: Scopes.operator),
    Operators(r'+-*/=<>!&|^~\\%'),
  ],
);

const _atom = 'literal.symbol';

/// `~r/…/i`, `~s(…)`, `~w[…]a`, `~S"""…"""` and friends.
final class _Sigils extends BlockRule {
  const _Sigils();

  @override
  List<Rule> expand() => [
    for (final (letters, interpolate, scope) in const [
      ('r', true, Scopes.regexp),
      ('R', false, Scopes.regexp),
      ('[a-qs-z]', true, Scopes.string),
      ('[A-QS-Z][A-Z]*', false, Scopes.string),
    ])
      ..._forLetters(letters, interpolate, scope),
  ];

  List<Rule> _forLetters(String letters, bool interpolate, String scope) {
    final rules = <Rule>[
      const TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
      if (interpolate) const Interpolation('#{', '}'),
    ];
    const modifiers = '[a-zA-Z]*';
    return [
      for (final quote in const ['"""', "'''"])
        RegionRule(
          begin: '~$letters$quote',
          end: '$quote$modifiers',
          scope: scope,
          rules: rules,
        ),
      for (final (open, close) in const [
        ('(', ')'),
        ('[', ']'),
        ('{', '}'),
        ('<', '>'),
        ('/', '/'),
        ('|', '|'),
        ('"', '"'),
        ("'", "'"),
      ])
        RegionRule(
          begin: '~$letters${RegExp.escape(open)}',
          end: '${RegExp.escape(close)}$modifiers',
          scope: scope,
          rules: rules,
        ),
    ];
  }
}
