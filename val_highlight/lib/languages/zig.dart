import '../advanced.dart';

/// Zig.
const zigLanguage = Grammar(
  name: 'zig',
  fileExtensions: ['zig', 'zon'],
  signatures: [
    r'@import\("std"\)',
    r'\bpub\s+fn\s+\w+\s*\(',
    r'\b(?:comptime|errdefer|orelse)\b',
    r'!void\b',
  ],
  rules: [
    LineComment('//!', scope: Scopes.commentDoc),
    LineComment('///', scope: Scopes.commentDoc),
    LineComment('//'),
    // Multiline string lines: `\\ text`.
    TokenRule(r'\\\\.*$', scope: Scopes.string),
    QuotedString('"'),
    TokenRule(r"'(?:[^'\\\n]|\\[^\n]+?)'", scope: Scopes.string),
    // Builtins (`@import`) and quoted identifiers (`@"name"`).
    TokenRule(r'@[A-Za-z_]\w*', scope: Scopes.function),
    QuotedString('"', prefix: '@', scope: Scopes.variable),
    Numbers(),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'addrspace', 'align', 'allowzero', 'and', 'anyframe', 'anytype', //
          'asm', 'break', 'callconv', 'catch', 'comptime', 'const',
          'continue', 'defer', 'else', 'enum', 'errdefer', 'error', 'export',
          'extern', 'fn', 'for', 'if', 'inline', 'linksection', 'noalias',
          'noinline', 'nosuspend', 'opaque', 'or', 'orelse', 'packed', 'pub',
          'resume', 'return', 'struct', 'suspend', 'switch', 'test',
          'threadlocal', 'try', 'union', 'unreachable', 'usingnamespace',
          'var', 'volatile', 'while', 'async', 'await',
        ],
        Scopes.literal: ['true', 'false', 'null', 'undefined'],
        Scopes.typeBuiltin: [
          'bool', 'void', 'noreturn', 'type', 'anyerror', 'anyopaque', //
          'comptime_int', 'comptime_float', 'isize', 'usize', 'f16', 'f32',
          'f64', 'f80', 'f128', 'c_char', 'c_short', 'c_ushort', 'c_int',
          'c_uint', 'c_long', 'c_ulong', 'c_longlong', 'c_ulonglong',
          'c_longdouble',
        ],
      },
      otherwise: [
        // Arbitrary-width integers: `u8`, `i32`, `u7`.
        TokenRule(r'[iu]\d+(?![\w$])', scope: Scopes.typeBuiltin),
        // SCREAMING_CASE names are constants, not types.
        TokenRule(r'[A-Z][A-Z0-9]*_[A-Z0-9_]*(?![\w$])'),
        CommonRules.capitalizedType,
        CommonRules.functionCall,
      ],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
