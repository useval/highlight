import '../advanced.dart';

/// R.
const rLanguage = Grammar(
  name: 'r',
  aliases: ['rscript', 'splus'],
  fileExtensions: ['r', 'rprofile'],
  fileNames: ['.Rprofile'],
  shebangs: ['Rscript'],
  signatures: [
    r'\w\s*<-\s*function\s*\(',
    r'^\s*library\(\w+\)',
    r'%>%|\|>',
    r'\bc\([^)]*\)',
    r'\bdata\.frame\(',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // roxygen documentation comments.
    LineComment("#'", scope: Scopes.commentDoc),
    LineComment('#'),
    // Raw strings: r"(...)", R"[...]", r"-{...}-".
    IncludeRule('raw'),
    QuotedString('"', multiline: true),
    QuotedString("'", multiline: true),
    // Backtick-quoted names: `my var`.
    TokenRule(r'`[^`\n]*`'),
    Numbers(binary: false, octal: false, separator: null, suffix: '[Li]?'),
    // `\(x) x + 1` is shorthand for `function(x) x + 1`.
    TokenRule(r'\\(?=\()', scope: Scopes.keyword),
    // User operators and pipes: %>%, %in%, %%.
    TokenRule(r'%[^%\n]*%', scope: Scopes.operator),
    KeywordRule(
      {
        Scopes.keyword: [
          'break', 'else', 'for', 'function', 'if', 'in', 'next', 'repeat', //
          'return', 'switch', 'while',
        ],
        Scopes.literal: [
          'TRUE', 'FALSE', 'NULL', 'NA', 'NA_integer_', 'NA_real_', //
          'NA_character_', 'NA_complex_', 'Inf', 'NaN', 'T', 'F',
        ],
        Scopes.function: [
          'c', 'cat', 'data.frame', 'library', 'list', 'matrix', 'paste', //
          'paste0', 'print', 'require', 'source', 'stop', 'stopifnot',
          'suppressWarnings', 'tryCatch', 'vector', 'warning',
        ],
      },
      // Names may contain dots: `data.frame`, `is.na`.
      word: r'(?<![\w.])[A-Za-z.][\w.]*',
      otherwise: [
        TokenRule(r'[A-Za-z.][\w.]*(?=[ \t]*\()', scope: Scopes.function),
      ],
    ),
    Operators(r'+-*/^=<>!&|~$@:?\'),
  ],
  repository: {
    'raw': [
      RegionRule(
        begin: r'''[rR]"(-*)\(''',
        end: r'''\)\1"''',
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
      RegionRule(
        begin: r'''[rR]"(-*)\[''',
        end: r'''\]\1"''',
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
      RegionRule(
        begin: r'''[rR]"(-*)\{''',
        end: r'''\}\1"''',
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
      RegionRule(
        begin: r'''[rR]'(-*)\(''',
        end: r"\)\1'",
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
      RegionRule(
        begin: r'''[rR]'(-*)\[''',
        end: r"\]\1'",
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
      RegionRule(
        begin: r'''[rR]'(-*)\{''',
        end: r"\}\1'",
        scope: Scopes.string,
        endReferencesBegin: true,
      ),
    ],
  },
);
