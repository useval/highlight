import '../advanced.dart';

/// Ruby, including Gemfiles, Podfiles, Rakefiles and Fastlane files.
const rubyLanguage = Grammar(
  name: 'ruby',
  aliases: ['rb', 'jruby', 'podfile', 'gemfile'],
  fileExtensions: ['rb', 'rake', 'gemspec', 'podspec', 'ru', 'rbw', 'thor'],
  fileNames: [
    'Gemfile', 'Rakefile', 'Podfile', 'Fastfile', 'Brewfile', 'Appfile', //
    'Matchfile', 'Pluginfile', 'Vagrantfile', 'Guardfile', 'Dangerfile',
    'Berksfile', 'Capfile',
  ],
  shebangs: ['ruby', 'jruby', 'rake'],
  signatures: [
    r'''^\s*require(?:_relative)?\s+['"][\w./-]+['"]\s*$''',
    r'\bdo\s*\|[\w, *&]+\|',
    r'^\s*def\s+(?:self\.)?\w+[?!]?(?:\(.*\))?\s*$',
    r'^\s*(?:attr_accessor|attr_reader|puts)\s',
    r'^\s*(?:module|class)\s+[A-Z]\w*(?:::\w+)*(?:\s*<\s*[A-Z][\w:]*)?\s*$',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // `=begin` … `=end` block comments.
    RegionRule(
      begin: r'^=begin\b',
      end: r'^=end\b.*$|(?![\s\S])',
      scope: Scopes.comment,
    ),
    // Everything after `__END__` is data.
    RegionRule(begin: r'^__END__$', end: r'(?![\s\S])', scope: Scopes.comment),
    IncludeRule('heredocs'),
    LineComment('#'),
    // Operator methods: def `(cmd), def [](i), def <=>(o), def -@.
    TokenRule(
      r'(?<=\bdef\s)(?:`|\[\]=?|[-+*/%<>=!~^&|]+@?)',
      scope: Scopes.function,
    ),
    // Character literals: ?a, ?", ?\n; not the ternary `a ? b : c`.
    TokenRule(
      r'(?<![\w)\]}])\?(?:\\(?:[MC]-)?[\s\S]|[^\s\\])(?!\w)',
      scope: Scopes.string,
    ),
    IncludeRule('strings'),
    // Symbols: `:name`, `:"quoted"`, `:name?`, and `key:` hash keys.
    TokenRule(r'(?<![:\w]):"(?:[^"\\\n]|\\.)*"', scope: _symbol),
    TokenRule(r'(?<![:\w]):[A-Za-z_]\w*[?!]?(?!:)', scope: _symbol),
    TokenRule(r'(?<![:\w])[A-Za-z_]\w*[?!]?:(?=[ \t\n)])', scope: _symbol),
    // A `/` starts a regular expression only where an expression starts.
    // It may span lines (`/x` mode) and interpolate.
    RegionRule(
      begin:
          r'(?<=(?:^|[(,=~!|&{\[;>])[ \t]*)/'
          r'|(?<=\b(?:if|unless|when|and|or|not|return|puts)[ \t]+)/(?![ \t])',
      end: r'/[imxounse]*',
      scope: Scopes.regexp,
      rules: [
        TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
        Interpolation('#{', '}'),
        TokenRule(r'\[(?:[^\]\\\n]|\\.)*\]'),
      ],
    ),
    TokenRule(r'@@?[A-Za-z_]\w*', scope: Scopes.variable),
    TokenRule(
      r'''\$(?:[A-Za-z_]\w*|[0-9]+|[!@&`'+~=/\\,;.<>*$?:"_])''',
      scope: Scopes.variable,
    ),
    Numbers(suffix: '[ri]{0,2}'),
    // After a `.`, a name is a method: never a keyword.
    TokenRule(r'(?<=\.)[A-Za-z_]\w*[?!]?(?=[ \t]*\()', scope: Scopes.function),
    TokenRule(r'(?<=\.)[A-Za-z_]\w*[?!]?'),
    KeywordRule(
      {
        Scopes.keyword: [
          'BEGIN', 'END', 'alias', 'and', 'begin', 'break', 'case', //
          'class', 'def', 'defined?', 'do', 'else', 'elsif', 'end', 'ensure',
          'for', 'if', 'in', 'module', 'next', 'not', 'or', 'redo', 'rescue',
          'retry', 'return', 'then', 'undef', 'unless', 'until', 'when',
          'while', 'yield', '__method__', '__FILE__', '__LINE__', '__dir__',
          '__ENCODING__',
        ],
        Scopes.literal: ['true', 'false', 'nil'],
        Scopes.variableLanguage: ['self', 'super'],
        Scopes.function: [
          'attr_accessor', 'attr_reader', 'attr_writer', 'block_given?', //
          'catch', 'extend', 'format', 'freeze', 'gets', 'include',
          'lambda', 'loop', 'module_function', 'p', 'pp', 'prepend',
          'print', 'private', 'private_constant', 'proc', 'protected',
          'public', 'puts', 'raise', 'rand', 'require', 'require_relative',
          'sleep', 'sprintf', 'throw',
        ],
      },
      word: r'(?<![\w@$])[A-Za-z_]\w*(?:[?!](?!=))?',
      otherwise: [
        TokenRule(r'(?<=\bdef\s)[A-Za-z_]\w*[?!=]?', scope: Scopes.function),
        CommonRules.capitalizedType,
        TokenRule(r'[A-Za-z_]\w*[?!]?(?=\()', scope: Scopes.function),
      ],
    ),
    // `&:name` passes a symbol as a block.
    TokenRule(r'&(?=:[A-Za-z_])', scope: Scopes.operator),
    Operators('+-*/%=<>!&|^~?:'),
  ],
  repository: {
    // `<<~EOS`, `<<-EOS`, `<<EOS`, with optional quotes. The body starts on
    // the next line; single quotes disable interpolation.
    'heredocs': [
      RegionRule(
        begin: r"(<<[~-]?)'([A-Za-z_]\w*)'([^\n]*)",
        end: r'^[ \t]*\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
      ),
      RegionRule(
        begin: r'(<<[~-])"?([A-Za-z_]\w*)"?([^\n]*)',
        end: r'^[ \t]*\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [IncludeRule('heredocBody')],
      ),
      RegionRule(
        // Only after a space, `(`, `,` or `=`, so `a<<b` stays a shift;
        // `class <<self` is not a heredoc.
        begin: r'(?<=[\s(,=])(<<)(?!self\b)"?([A-Za-z_]\w*)"?([^\n]*)',
        end: r'^\2$',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [IncludeRule('heredocBody')],
      ),
    ],
    'heredocBody': [
      TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
      Interpolation('#{', '}'),
      TokenRule(r'[^#\\\n]+|#', scope: Scopes.string),
    ],
    'strings': [
      QuotedString('"', multiline: true, rules: [Interpolation('#{', '}')]),
      QuotedString(
        "'",
        escape: null,
        multiline: true,
        rules: [TokenRule(r"\\[\\']", scope: Scopes.stringEscape)],
      ),
      QuotedString('`', multiline: true, rules: [Interpolation('#{', '}')]),
      // `%w[]`, `%i()`, `%q{}`, `%Q<>`, `%()`, `%r{}` and friends.
      _PercentLiteral('[qwis]', Scopes.string, interpolate: false),
      _PercentLiteral('[QWIx]?', Scopes.string, interpolate: true),
      _PercentLiteral('r', Scopes.regexp, interpolate: true, flags: '[imxo]*'),
    ],
  },
);

const _symbol = 'literal.symbol';

/// `%` literals with any of the usual delimiters. Paired delimiters nest.
final class _PercentLiteral extends BlockRule {
  const _PercentLiteral(
    this.kinds,
    this.scope, {
    required this.interpolate,
    this.flags = '',
  });

  final String kinds;
  final String scope;
  final bool interpolate;
  final String flags;

  @override
  List<Rule> expand() {
    // Non-interpolating forms only escape backslashes and delimiters.
    final extra = <Rule>[
      if (interpolate) ...const [
        TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
        Interpolation('#{', '}'),
      ] else
        const TokenRule(r'\\[\\()\[\]{}<>|!/]', scope: Scopes.stringEscape),
    ];
    // Only where an expression starts, so `a %(b)` style modulo stays an
    // operator when written without a space.
    const before = r'(?<=^|[\s(,=\[{;|&!])';
    return [
      for (final (open, close) in const [
        ('(', ')'),
        ('[', ']'),
        ('{', '}'),
        ('<', '>'),
      ])
        _paired(before, open, close, extra),
      for (final delimiter in const ['|', '!', '/'])
        RegionRule(
          begin: '$before%$kinds${RegExp.escape(delimiter)}',
          end: '${RegExp.escape(delimiter)}$flags',
          scope: scope,
          rules: extra,
        ),
    ];
  }

  RegionRule _paired(String before, String open, String close, List<Rule> x) {
    final o = RegExp.escape(open);
    final c = RegExp.escape(close);
    final inner = <Rule>[...x];
    inner.add(RegionRule(begin: o, end: c, rules: inner));
    return RegionRule(
      begin: '$before%$kinds$o',
      end: '$c$flags',
      scope: scope,
      rules: inner,
    );
  }
}
