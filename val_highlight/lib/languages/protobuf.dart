import '../advanced.dart';

/// Protocol Buffers (proto2, proto3 and editions).
const protobufLanguage = Grammar(
  name: 'protobuf',
  aliases: ['proto'],
  fileExtensions: ['proto'],
  signatures: [
    r'''^syntax\s*=\s*["']proto[23]["']\s*;''',
    r'^message\s+\w+\s*\{',
    r'\brpc\s+\w+\s*\(\s*(?:stream\s+)?[\w.]+\s*\)\s*returns\b',
    r'^\s*(?:repeated|optional)\s+[\w.]+\s+\w+\s*=\s*\d+',
  ],
  rules: [
    BlockComment('/*', '*/'),
    LineComment('//'),
    QuotedString('"'),
    QuotedString("'"),
    Numbers(binary: false, octal: false, separator: null),
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'syntax', 'edition', 'package', 'import', 'option', 'message', //
          'enum', 'service', 'rpc', 'returns', 'stream', 'oneof', 'map',
          'reserved', 'extensions', 'extend', 'to', 'max', 'repeated',
          'optional', 'required', 'weak', 'public', 'group',
        ],
        Scopes.typeBuiltin: [
          'double', 'float', 'int32', 'int64', 'uint32', 'uint64', 'sint32', //
          'sint64', 'fixed32', 'fixed64', 'sfixed32', 'sfixed64', 'bool',
          'string', 'bytes',
        ],
        Scopes.literal: ['true', 'false', 'inf', 'nan'],
      },
      otherwise: [
        CommonRules.functionCall,
        // ALL_CAPS enum values stay plain.
        TokenRule(r'[A-Z][A-Z0-9_]*[A-Z0-9](?!\w)'),
        CommonRules.capitalizedType,
      ],
    ),
    TokenRule(r'[=;]', scope: Scopes.operator),
  ],
);
