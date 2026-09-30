import '../advanced.dart';

/// JSON, including the comments allowed by JSONC.
const jsonLanguage = Grammar(
  name: 'json',
  aliases: ['jsonc'],
  fileExtensions: ['json', 'jsonc'],
  signatures: [
    r'^\s*[\[{]\s*$|^\s*[\[{]\s*"',
    r'"[^"\n]*"\s*:\s*["\[{\d tfn-]',
  ],
  rules: [
    TokenRule(r'//.*$', scope: Scopes.comment),
    RegionRule(begin: r'/\*', end: r'\*/', scope: Scopes.comment),
    // A string followed by `:` is an object key.
    RegionRule(
      begin: r'"(?=(?:[^"\\\n]|\\.)*"[ \t]*(?:\r?\n[ \t]*)?:)',
      end: r'"',
      scope: Scopes.property,
      rules: [IncludeRule('escape')],
    ),
    RegionRule(
      begin: r'"',
      end: r'"|$',
      scope: Scopes.string,
      rules: [IncludeRule('escape')],
    ),
    TokenRule(
      r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?',
      scope: Scopes.number,
    ),
    TokenRule(r'\b(?:true|false|null)\b', scope: Scopes.literal),
    TokenRule(r'[{}\[\],:]', scope: Scopes.punctuation),
  ],
  repository: {
    'escape': [
      TokenRule(
        r'\\(?:["\\/bfnrt]|u[0-9A-Fa-f]{4})',
        scope: Scopes.stringEscape,
      ),
      TokenRule(r'\\.', scope: Scopes.invalid),
    ],
  },
);
