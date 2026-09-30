import '../advanced.dart';

/// A bare, basic-quoted or literal-quoted key.
const _key = r'''(?:[A-Za-z0-9_-]+|"(?:[^"\\\n]|\\.)*"|'[^'\n]*')''';

/// A dotted key such as `a."b".c`.
const _dottedKey = '$_key(?:[ \\t]*\\.[ \\t]*$_key)*';

/// TOML.
const tomlLanguage = Grammar(
  name: 'toml',
  fileExtensions: ['toml'],
  fileNames: ['Cargo.lock', 'Pipfile', 'poetry.lock'],
  signatures: [
    r'^\[\[[\w.-]+\]\]\s*$',
    r'^\[(?:package|dependencies|tool\.[\w-]+|workspace|build-system)\]\s*$',
    r'^[\w-]+\s*=\s*(?:"[^"]*"|\d+|true|false|\[)\s*$',
  ],
  rules: [
    LineComment('#'),
    // Table headers: `[a.b]` and `[[array.of.tables]]`.
    TokenRule(
      '^[ \\t]*\\[\\[[ \\t]*$_dottedKey[ \\t]*\\]\\]',
      scope: Scopes.heading,
    ),
    TokenRule('^[ \\t]*\\[[ \\t]*$_dottedKey[ \\t]*\\]', scope: Scopes.heading),
    // Keys at the start of a line, or after `{` or `,` in inline tables.
    TokenRule('^[ \\t]*$_dottedKey(?=[ \\t]*=)', scope: Scopes.property),
    TokenRule(
      '([{,])([ \\t]*)($_dottedKey)(?=[ \\t]*=)',
      captures: {1: Scopes.punctuation, 3: Scopes.property},
    ),
    QuotedString('"""', multiline: true),
    QuotedString("'''", escape: null, multiline: true),
    QuotedString('"'),
    QuotedString("'", escape: null),
    // Offset date-times, local date-times, dates and times.
    TokenRule(
      r'(?<![\w.:-])\d{4}-\d{2}-\d{2}(?:[Tt ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?'
      r'(?:[Zz]|[+-]\d{2}:\d{2})?)?(?![\w:])',
      scope: Scopes.number,
    ),
    TokenRule(
      r'(?<![\w.:-])\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?![\w:])',
      scope: Scopes.number,
    ),
    TokenRule(r'(?<![\w.])[+-]?(?:inf|nan)(?![\w.])', scope: Scopes.number),
    TokenRule(r'[+-](?=[0-9])', scope: Scopes.number),
    Numbers(),
    TokenRule(r'\b(?:true|false)\b', scope: Scopes.literal),
    TokenRule('=', scope: Scopes.operator),
    TokenRule(r'[\[\]{},]', scope: Scopes.punctuation),
  ],
);
