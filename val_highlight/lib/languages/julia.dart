import '../advanced.dart';

/// Julia.
const juliaLanguage = Grammar(
  name: 'julia',
  aliases: ['jl'],
  fileExtensions: ['jl'],
  shebangs: ['julia'],
  signatures: [
    r'^\s*using\s+[A-Z]\w*(?:\s*,\s*[A-Z]\w*)*\s*$',
    r'^\s*(?:mutable\s+)?struct\s+[A-Z]\w*(?:\{[^}]*\})?\s*(?:<:\s*\w+)?\s*$',
    r'::\s*(?:Int|Float|Vector|String|AbstractArray)\w*',
    r'^\s*function\s+\w+!?\(',
    r'\bprintln\(',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    BlockComment('#=', '=#', nested: true),
    LineComment('#'),
    // Docstrings and multi-line strings with interpolation.
    QuotedString('"""', multiline: true, rules: [IncludeRule('interpolated')]),
    // Non-interpolating string macros: raw"…", r"…" (regex), b"…".
    QuotedString(
      '"',
      prefix: r'(?<![\w.])(?:raw|b)',
      escape: null,
      multiline: true,
      rules: [TokenRule(r'\\["\\]', scope: Scopes.stringEscape)],
    ),
    QuotedString(
      '"',
      prefix: r'(?<![\w.])r',
      escape: null,
      multiline: true,
      scope: Scopes.regexp,
      rules: [TokenRule(r'\\["\\]', scope: Scopes.stringEscape)],
    ),
    QuotedString('"', multiline: true, rules: [IncludeRule('interpolated')]),
    // Command literals.
    QuotedString('`', multiline: true, rules: [IncludeRule('interpolated')]),
    // Characters, but not the transpose operator in `A'`.
    TokenRule(r"(?<![\w)\]}'.])'(?:[^'\\\n]|\\[^\n]+?)'", scope: Scopes.string),
    Annotation(),
    // Symbols: `:name`, not ranges `a:b` or the ternary `x ? a : b`.
    TokenRule(r'(?<=[\s(,\[{=]|^):[A-Za-z_]\w*', scope: 'literal.symbol'),
    Numbers(suffix: '(?:im)?'),
    // Type annotations and bounds: `x::Int`, `T <: Number`.
    TokenRule(r'(?<=::|<:|>:)\s?[A-Za-z_]\w*', scope: Scopes.type),
    TokenRule(r'(?<=\.)[A-Za-z_]\w*!?(?=[ \t]*\()', scope: Scopes.function),
    TokenRule(r'(?<=\.)[A-Za-z_]\w*'),
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'baremodule', 'begin', 'break', 'catch', 'const', //
          'continue', 'do', 'else', 'elseif', 'end', 'export', 'finally',
          'for', 'function', 'global', 'if', 'import', 'in', 'isa', 'let',
          'local', 'macro', 'module', 'mutable', 'outer', 'primitive',
          'public', 'quote', 'return', 'struct', 'try', 'type', 'using',
          'where', 'while',
        ],
        Scopes.literal: [
          'true', 'false', 'nothing', 'missing', 'NaN', 'Inf', 'pi', //
          'NaN32', 'Inf32', 'undef',
        ],
        Scopes.typeBuiltin: [
          'AbstractArray', 'AbstractDict', 'AbstractFloat', //
          'AbstractMatrix', 'AbstractString', 'AbstractVector', 'Any',
          'Array', 'BigFloat', 'BigInt', 'Bool', 'Char', 'Complex',
          'DataType', 'Dict', 'Exception', 'Float16', 'Float32', 'Float64',
          'Function', 'IO', 'Int', 'Int8', 'Int16', 'Int32', 'Int64',
          'Int128', 'Integer', 'Matrix', 'Missing', 'NamedTuple', 'Nothing',
          'Number', 'Pair', 'Rational', 'Real', 'Set', 'String', 'Symbol',
          'Tuple', 'Type', 'UInt', 'UInt8', 'UInt16', 'UInt32', 'UInt64',
          'UInt128', 'Union', 'UnionAll', 'Vector',
        ],
      },
      word: r'(?<![\w@!])[A-Za-z_]\w*(?:!(?!=))?',
      otherwise: [
        CommonRules.capitalizedType,
        TokenRule(r'[A-Za-z_]\w*!?(?=\()', scope: Scopes.function),
      ],
    ),
    Operators(r'+-*/\^%=<>!&|~?:$÷'),
  ],
  repository: {
    'interpolated': [
      Interpolation(
        r'$(',
        ')',
        rules: [IncludeRule('parens'), IncludeRule.self],
      ),
      TokenRule(r'\$[A-Za-z_]\w*', scope: Scopes.interpolation),
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
