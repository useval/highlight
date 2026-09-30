import '../advanced.dart';

/// Perl 5.
const perlLanguage = Grammar(
  name: 'perl',
  aliases: ['pl', 'pm'],
  fileExtensions: ['pl', 'pm', 't', 'psgi'],
  shebangs: ['perl'],
  signatures: [
    r'^\s*use\s+(?:strict|warnings|utf8)\s*;',
    r'^\s*my\s+[$@%]\w+',
    r'^\s*sub\s+\w+\s*\{',
    r'\$_\[\d\]|@_\b',
    r'=~\s*(?:s|m|tr|y)?[/{#|!]',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // POD documentation: `=head1` … `=cut`.
    RegionRule(
      begin: r'^=[a-zA-Z]\w*',
      end: r'^=cut\b.*$|(?![\s\S])',
      scope: Scopes.commentDoc,
    ),
    // Everything after `__END__` or `__DATA__` is data.
    RegionRule(
      begin: r'^__(?:END|DATA)__$',
      end: r'(?![\s\S])',
      scope: Scopes.comment,
    ),
    IncludeRule('heredocs'),
    // Variables come before comments so `$#array` is not a comment.
    IncludeRule('variables'),
    LineComment('#'),
    IncludeRule('quoteLike'),
    QuotedString('"', multiline: true, rules: [IncludeRule('interpolated')]),
    QuotedString(
      "'",
      escape: null,
      multiline: true,
      rules: [TokenRule(r"\\[\\']", scope: Scopes.stringEscape)],
    ),
    QuotedString('`', multiline: true, rules: [IncludeRule('interpolated')]),
    // A bare `/regex/` after a binding operator or where an expression
    // starts.
    TokenRule(
      r'(?<=(?:[=!]~|[(,;{]|\b(?:split|grep|if|unless|and|or|return))[ \t]{0,3})'
      r'/(?![\s*/=])(?:[^/\\\n]|\\.)+/[msixpodualngcer]*',
      scope: Scopes.regexp,
    ),
    Numbers(),
    TokenRule(r'(?<=->)[A-Za-z_]\w*', scope: Scopes.function),
    KeywordRule(
      {
        Scopes.keyword: [
          'and', 'catch', 'class', 'cmp', 'default', 'defer', 'do', 'else', //
          'elsif', 'eq', 'field', 'finally', 'for', 'foreach', 'ge', 'given',
          'goto', 'gt', 'if', 'last', 'le', 'local', 'lt', 'method', 'my',
          'ne', 'next', 'no', 'not', 'or', 'our', 'package', 'redo',
          'require', 'return', 'state', 'sub', 'try', 'unless', 'until',
          'use', 'when', 'while', 'xor', 'BEGIN', 'END', 'INIT', 'CHECK',
          'UNITCHECK',
        ],
        Scopes.literal: ['undef'],
        Scopes.variableLanguage: [
          '__PACKAGE__', '__FILE__', '__LINE__', '__SUB__', '__CLASS__', //
        ],
        Scopes.function: [
          'bless', 'chdir', 'chomp', 'chop', 'close', 'defined', 'delete', //
          'die', 'each', 'eval', 'exists', 'exit', 'grep', 'index', 'join',
          'keys', 'lc', 'length', 'localtime', 'map', 'mkdir', 'open',
          'pop', 'print', 'printf', 'push', 'ref', 'reverse', 'say',
          'scalar', 'shift', 'sort', 'splice', 'split', 'sprintf', 'substr',
          'time', 'uc', 'unlink', 'unshift', 'values', 'wantarray', 'warn',
        ],
      },
      otherwise: [
        TokenRule(r'(?<=\bsub\s)[A-Za-z_]\w*', scope: Scopes.function),
        // A bareword before `=>` is a quoted key.
        TokenRule(r'[A-Za-z_]\w*(?=[ \t]*=>)', scope: Scopes.property),
        TokenRule(r'_*[A-Z]\w*(?:::\w+)+|[A-Z]\w*(?=::)', scope: Scopes.type),
        _call,
      ],
    ),
    Operators('+-*/%=<>!&|^~?:.\\'),
  ],
  repository: {
    'variables': [
      TokenRule(r'\$#\{?[A-Za-z_][\w:]*\}?', scope: Scopes.variable),
      TokenRule(r'[$@%&]\{[A-Za-z_][\w:]*\}', scope: Scopes.variable),
      TokenRule(r'[$@%][A-Za-z_][\w]*(?:::\w+)*', scope: Scopes.variable),
      TokenRule(
        r'''\$(?:[0-9]+|[_&`'+!@/\\,;.0<>\[\]^]|\^\w)''',
        scope: Scopes.variable,
      ),
      TokenRule(r'@_|@ARGV|%ENV|%INC|@INC', scope: Scopes.variable),
    ],
    // Interpolation inside double-quoted text.
    'interpolated': [
      TokenRule(r'\$#[A-Za-z_]\w*', scope: Scopes.variable),
      TokenRule(
        r'[$@][A-Za-z_]\w*(?:->)?(?:\[[^\]\n]*\]|\{[^}\n]*\})*',
        scope: Scopes.variable,
      ),
      TokenRule(r'\$\{[^}\n]*\}', scope: Scopes.variable),
    ],
    // `<<"EOF"`, `<<'EOF'`, `<<EOF`, `<<~EOF`.
    'heredocs': [
      RegionRule(
        begin: r"(<<~?)'([A-Za-z_]\w*)'([^\n]*)",
        end: r'^[ \t]*\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
      ),
      RegionRule(
        begin: r'(<<~?)"?([A-Za-z_]\w*)"?([^\n]*)',
        end: r'^[ \t]*\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [
          TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
          IncludeRule('interpolated'),
          TokenRule(r'[^$@\\\n]+|[$@]', scope: Scopes.string),
        ],
      ),
    ],
    'quoteLike': [
      _QuoteLike('qq|qx', Scopes.string, interpolate: true),
      _QuoteLike('qw|q', Scopes.string),
      _QuoteLike(
        'qr|m',
        Scopes.regexp,
        interpolate: true,
        flags: '[msixpodualngc]*',
      ),
      // Substitution and transliteration: two parts with one delimiter.
      TokenRule(
        r'(?<![\w$@%&>-])(?:s|tr|y)([/|!#,])(?:[^\\\n]|\\.)*?\1(?:[^\\\n]|\\.)*?\1[msixpodualngcer]*',
        scope: Scopes.regexp,
      ),
      TokenRule(
        r'(?<![\w$@%&>-])(?:s|tr|y)\{(?:[^}\\\n]|\\.)*\}\s*\{(?:[^}\\\n]|\\.)*\}[msixpodualngcer]*',
        scope: Scopes.regexp,
      ),
    ],
  },
);

/// `q()`, `qq{}`, `qw[]`, `m//`, `qr<>` and friends with the usual
/// delimiters. Paired delimiters nest.
final class _QuoteLike extends BlockRule {
  const _QuoteLike(
    this.operators,
    this.scope, {
    this.interpolate = false,
    this.flags = '',
  });

  final String operators;
  final String scope;
  final bool interpolate;
  final String flags;

  @override
  List<Rule> expand() {
    final extra = <Rule>[
      const TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
      if (interpolate) const IncludeRule('interpolated'),
    ];
    // Not a sigil, a method (`->q`), or a hash key (`q =>`).
    final before = '(?<![\\w\$@%&>-])(?:$operators)';
    return [
      for (final (open, close) in const [
        ('(', ')'),
        ('[', ']'),
        ('{', '}'),
        ('<', '>'),
      ])
        _paired(before, RegExp.escape(open), RegExp.escape(close), extra),
      for (final delimiter in const ['/', '|', '!', '#', ','])
        RegionRule(
          begin: '$before${RegExp.escape(delimiter)}',
          end: '${RegExp.escape(delimiter)}$flags',
          scope: scope,
          rules: extra,
        ),
    ];
  }

  RegionRule _paired(String before, String o, String c, List<Rule> extra) {
    final inner = <Rule>[...extra];
    inner.add(RegionRule(begin: o, end: c, rules: inner));
    return RegionRule(
      begin: '$before\\s?$o',
      end: '$c$flags',
      scope: scope,
      rules: inner,
    );
  }
}

/// A name followed by `(` on the same line is a call. (Lookahead stays on
/// the line so incremental re-highlighting never needs to look further.)
const _call = TokenRule(
  r'[A-Za-z_$][\w$]*(?=[ \t]*\()',
  scope: Scopes.function,
);
