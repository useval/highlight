import '../advanced.dart';

/// Rust.
const rustLanguage = Grammar(
  name: 'rust',
  aliases: ['rs'],
  fileExtensions: ['rs'],
  signatures: [
    r'\bfn\s+\w+\s*(?:<[^>\n]*>)?\s*\(',
    r'\blet\s+mut\b',
    r'#\[derive\(',
    r'\b(?:println|vec|format)!\s*[(\[]',
    r'\bimpl(?:<[^>\n]*>)?\s+\w+(?:<[^>\n]*>)?\s+for\s+\w+',
  ],
  rules: [
    LineComment('//!', scope: Scopes.commentDoc),
    LineComment('///', scope: Scopes.commentDoc),
    LineComment('//'),
    BlockComment('/**', '*/', nested: true, scope: Scopes.commentDoc),
    BlockComment('/*', '*/', nested: true),
    // Attributes: `#[derive(Debug)]`, `#![allow(dead_code)]`.
    RegionRule(
      begin: r'#!?\[',
      end: r'\]',
      scope: Scopes.meta,
      rules: [IncludeRule('attribute')],
    ),
    // Raw strings: `r"…"`, `r#"…"#`, `br##"…"##`.
    RegionRule(
      begin: r'(?<![\w$])[bc]?r(#*)"',
      end: r'"\1',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    QuotedString(
      '"',
      prefix: r'(?<![\w$])[bc]?',
      multiline: true,
      escape: null,
      rules: [
        TokenRule(
          r'\\(?:x[0-9a-fA-F]{2}|u\{[0-9a-fA-F_]{1,6}\}|[\s\S])',
          scope: Scopes.stringEscape,
        ),
      ],
    ),
    // Character and byte literals. A lifetime (`'a`) has no closing quote.
    TokenRule(
      r"(?<![\w$])b?'(?:[^'\\\n]|\\(?:[nrt\\0'"
      r'"]|x[0-9a-fA-F]{2}|u\{[0-9a-fA-F_]{1,6}\}))'
      "'",
      scope: Scopes.string,
    ),
    TokenRule(r"'[A-Za-z_]\w*(?!')", scope: Scopes.variable),
    Numbers(suffix: r'(?:_?(?:[iu](?:8|16|32|64|128|size)|f32|f64))?'),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'as', 'async', 'await', 'break', 'const', 'continue', 'crate', //
          'dyn', 'else', 'enum', 'extern', 'fn', 'for', 'gen', 'if', 'impl',
          'in', 'let', 'loop', 'macro_rules', 'match', 'mod', 'move', 'mut',
          'pub', 'ref', 'return', 'safe', 'static', 'struct', 'super',
          'trait', 'try', 'type', 'union', 'unsafe', 'use', 'where', 'while',
          'yield', 'abstract', 'become', 'box', 'do', 'final', 'macro',
          'override', 'priv', 'typeof', 'unsized', 'virtual',
        ],
        Scopes.literal: ['true', 'false', 'None', 'Some', 'Ok', 'Err'],
        Scopes.variableLanguage: ['self', 'Self'],
        Scopes.typeBuiltin: [
          'bool', 'char', 'str', 'i8', 'i16', 'i32', 'i64', 'i128', //
          'isize', 'u8', 'u16', 'u32', 'u64', 'u128', 'usize', 'f32', 'f64',
          'String', 'Vec', 'Option', 'Result', 'Box', 'Rc', 'Arc',
          'HashMap', 'HashSet', 'BTreeMap',
        ],
      },
      otherwise: [
        // Macro invocations: `println!(`, `vec![`, `matches!{`.
        TokenRule(
          r'[A-Za-z_]\w*!(?=[ \t]*(?:\r?\n[ \t]*)?[(\[{])',
          scope: Scopes.function,
        ),
        // SCREAMING_CASE names are constants, not types.
        TokenRule(r'[A-Z][A-Z0-9]*_[A-Z0-9_]*(?![\w$])'),
        CommonRules.capitalizedType,
        CommonRules.functionCall,
      ],
    ),
    Operators('+-*/%=<>!&|^~?:@'),
  ],
  repository: {
    'attribute': [
      QuotedString('"'),
      RegionRule(begin: r'\[', end: r'\]', rules: [IncludeRule('attribute')]),
    ],
  },
);
