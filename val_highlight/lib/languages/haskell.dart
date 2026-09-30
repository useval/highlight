import '../advanced.dart';

/// Haskell.
const haskellLanguage = Grammar(
  name: 'haskell',
  aliases: ['hs'],
  fileExtensions: ['hs', 'lhs'],
  signatures: [
    r'^module\s+[A-Z][\w.]*(?:\s*\(|\s+where)',
    r'^import\s+(?:qualified\s+)?[A-Z][\w.]*',
    r'^\w+\s*::\s*\S',
    r'\bderiving\s*\(',
    r'\{-#\s*LANGUAGE\b',
  ],
  rules: [
    // Pragmas: `{-# LANGUAGE OverloadedStrings #-}`.
    RegionRule(begin: r'\{-#', end: r'#-\}', scope: Scopes.meta),
    BlockComment('{-', '-}', nested: true),
    // `--` starts a comment unless it is part of an operator such as `-->`.
    TokenRule(r'--+(?![!#$%&*+./<=>?@\\^|~:]).*$', scope: Scopes.comment),
    QuotedString('"'),
    // Character literals; a prime inside a name (`x'`) is not one.
    TokenRule(r"(?<![\w'])'(?:[^'\\\n]|\\[^\n]+?)'", scope: Scopes.string),
    Numbers(),
    KeywordRule(
      {
        Scopes.keyword: [
          'as', 'case', 'class', 'data', 'default', 'deriving', 'do', //
          'else', 'family', 'forall', 'foreign', 'hiding', 'if', 'import',
          'in', 'infix', 'infixl', 'infixr', 'instance', 'let', 'mdo',
          'module', 'newtype', 'of', 'qualified', 'then', 'type', 'where',
        ],
        Scopes.literal: [
          'True', 'False', 'Nothing', 'Just', 'Left', 'Right', 'otherwise', //
          'undefined',
        ],
        Scopes.typeBuiltin: [
          'Int', 'Integer', 'Double', 'Float', 'Char', 'String', 'Bool', //
          'Maybe', 'Either', 'IO', 'Word', 'Rational', 'Ordering',
        ],
      },
      word: r"(?<![\w'])[A-Za-z_][\w']*",
      otherwise: [
        TokenRule(r"[A-Z][\w']*", scope: Scopes.type),
        // A name being given a type signature: `lookup :: ...`.
        TokenRule(
          r"[a-z_][\w']*(?=[ \t]*(?:\r?\n[ \t]*)?::)",
          scope: Scopes.function,
        ),
      ],
    ),
    Operators(r'!#$%&*+./<=>?@\^|~:-'),
  ],
);
