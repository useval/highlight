import '../advanced.dart';

/// OCaml.
const ocamlLanguage = Grammar(
  name: 'ocaml',
  aliases: ['ml'],
  fileExtensions: ['ml', 'mli'],
  signatures: [
    r'\blet\s+rec\s+\w+',
    r'\bmatch\s+.*\s+with\s*$',
    r'^\s*\|\s*[A-Z]\w*.*->',
    r'\bmodule\s+[A-Z]\w*\s*=\s*struct\b',
    r';;\s*$',
  ],
  rules: [
    BlockComment('(**', '*)', nested: true, scope: Scopes.commentDoc),
    BlockComment('(*', '*)', nested: true),
    // Quoted strings: `{|raw|}`, `{id|raw|id}`.
    RegionRule(
      begin: r'\{([a-z_]*)\|',
      end: r'\|\1\}',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    QuotedString('"', multiline: true),
    // Character literals, then type variables (`'a`), which have no
    // closing quote.
    TokenRule(
      r"(?<![\w'])'(?:[^'\\\n]|\\(?:[\\"
      r'''"'ntbr ]|\d{3}|x[0-9a-fA-F]{2}|o[0-3][0-7]{2}))'''
      "'",
      scope: Scopes.string,
    ),
    TokenRule(r"(?<![\w'])'[a-z_][\w']*", scope: Scopes.type),
    // Attributes: `[@@deriving show]`. The attribute name is metadata; its
    // payload is ordinary code, so strings and brackets inside it (as in
    // `[@@deprecated "[since 2016] use [x]"]`) are read as such.
    RegionRule(
      begin: r'\[@{1,3}[\w.]*',
      end: r'\]',
      beginScope: Scopes.meta,
      endScope: Scopes.meta,
      rules: [IncludeRule('attributeBrackets'), IncludeRule.self],
    ),
    Numbers(suffix: '[lLn]?'),
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'and', 'as', 'assert', 'begin', 'class', 'constraint', 'do', //
          'done', 'downto', 'effect', 'else', 'end', 'exception', 'external',
          'for', 'fun', 'function', 'functor', 'if', 'in', 'include',
          'inherit', 'initializer', 'lazy', 'let', 'match', 'method',
          'module', 'mutable', 'new', 'nonrec', 'object', 'of', 'open', 'or',
          'private', 'rec', 'sig', 'struct', 'then', 'to', 'try', 'type',
          'val', 'virtual', 'when', 'while', 'with', 'land', 'lor', 'lxor',
          'lsl', 'lsr', 'asr', 'mod',
        ],
        Scopes.literal: ['true', 'false'],
        Scopes.typeBuiltin: [
          'int', 'float', 'string', 'char', 'bool', 'unit', 'list', //
          'array', 'option', 'result', 'ref', 'exn', 'bytes', 'int32',
          'int64', 'nativeint', 'format', 'lazy_t', 'seq',
        ],
      },
      word: r"(?<![\w'])[A-Za-z_][\w']*",
      otherwise: [TokenRule(r"[A-Z][\w']*", scope: Scopes.type)],
    ),
    Operators(r'!$%&*+-./:<=>?@^|~'),
  ],
  repository: {
    'attributeBrackets': [
      RegionRule(
        begin: r'\[',
        end: r'\]',
        rules: [IncludeRule('attributeBrackets'), IncludeRule.self],
      ),
    ],
  },
);
