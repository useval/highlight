import '../advanced.dart';

/// Ends a plain YAML scalar: end of line, a comment, or a flow separator.
const _scalarEnd = r'(?=[ \t]*(?:$|#|,|\]|\}))';

/// Where a plain YAML scalar may start: after `key:`, a list dash, a flow
/// opener or separator, or at the start of a line.
const _scalarStart = r'(?<=(?:^|[,\[{]|:[ \t]|(?:^|[ \t])-[ \t])[ \t]*)';

/// A mapping key: plain, double-quoted or single-quoted.
const _key =
    r'''(?:[^\s#:\-\[\]{},'"!&*|>%@`][^#:\n]*?|-[^\s#:\n][^#:\n]*?'''
    r'''|"(?:[^"\\\n]|\\.)*"|'(?:[^'\n]|'')*')''';

/// What follows a key: optional spaces, then `:` and a space or line end.
const _keyEnd = r'(?=[ \t]*:(?:[ \t]|$))';

/// A block scalar ends at a line start that is not blank and not indented
/// deeper than the opening line (`\1`, its indentation), or at the end of
/// the document.
const _blockEnd = r'^(?![ \t]*$)(?!\1[ \t])|(?![\s\S])';

/// YAML.
const yamlLanguage = Grammar(
  name: 'yaml',
  aliases: ['yml'],
  fileExtensions: ['yaml', 'yml'],
  signatures: [
    r'^[A-Za-z_][\w-]*:[ \t]*$',
    r'^[A-Za-z_][\w-]*:[ \t]+[^\s{\[]',
    r'^[ \t]*-[ \t]+[A-Za-z_][\w-]*:[ \t]',
    r'^---[ \t]*$',
  ],
  rules: [
    TokenRule(r'(?<=^|\s)#.*$', scope: Scopes.comment),
    TokenRule(r'^(?:---|\.\.\.)(?=\s|$)', scope: Scopes.meta),
    TokenRule(r'^%.*$', scope: Scopes.meta),
    // Block scalars: `key: |` or `- >-` followed by lines indented deeper
    // than the line that opened them. The block ends at the first
    // non-blank line that is not. The rule starts at the indicator, and
    // captures the line's indentation in its lookbehind for the end.
    RegionRule(
      begin:
          r'(?<=^([ \t]*)(?![ \t])(?:[^\n]*[:\-])?[ \t]*)'
          r'[|>][-+0-9]*(?=[ \t]*(?:#.*)?$)',
      end: _blockEnd,
      beginScope: Scopes.operator,
      endReferencesBegin: true,
      rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
    ),
    // `key:` at the start of a line, after any indentation and list dashes.
    TokenRule(
      '^([ \\t]*)((?:-[ \\t]+)*)($_key)$_keyEnd',
      captures: {2: Scopes.punctuation, 3: Scopes.property},
    ),
    // `key:` inside a flow mapping, after `{` or `,`.
    TokenRule(
      '([{,])([ \\t]*)($_key)$_keyEnd',
      captures: {1: Scopes.punctuation, 3: Scopes.property},
    ),
    TokenRule(r'[&*][^\s,\[\]{}]+', scope: Scopes.variable),
    TokenRule(r'!!?[\w/.-]*', scope: Scopes.type),
    // Quotes start a string only where a value starts; inside a plain
    // value (`echo "hi"`, `x == 'y'`) they are ordinary characters.
    RegionRule(
      begin: '$_scalarStart"',
      end: '"',
      scope: Scopes.string,
      rules: [
        TokenRule(
          r'\\(?:x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|[\s\S])',
          scope: Scopes.stringEscape,
        ),
      ],
    ),
    RegionRule(
      begin: "$_scalarStart'",
      end: "'(?!')",
      scope: Scopes.string,
      rules: [TokenRule("''", scope: Scopes.stringEscape)],
    ),
    TokenRule(
      '$_scalarStart(?:true|false|True|False|TRUE|FALSE|null|Null|NULL|~)'
      '$_scalarEnd',
      scope: Scopes.literal,
    ),
    TokenRule(
      '$_scalarStart[-+]?(?:0x[0-9A-Fa-f_]+|0o[0-7_]+|'
      r'(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?|\.(?:inf|Inf|INF|nan|NaN|NAN))'
      '$_scalarEnd',
      scope: Scopes.number,
    ),
    TokenRule(r'^[ \t]*-(?=[ \t]|$)', scope: Scopes.punctuation),
    TokenRule(r'[\[\]{},]', scope: Scopes.punctuation),
  ],
);
