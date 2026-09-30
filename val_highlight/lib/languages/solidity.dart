import '../advanced.dart';

/// Solidity.
const solidityLanguage = Grammar(
  name: 'solidity',
  aliases: ['sol'],
  fileExtensions: ['sol'],
  signatures: [
    r'^\s*pragma\s+solidity\b',
    r'//\s*SPDX-License-Identifier:',
    r'\bcontract\s+\w+(?:\s+is\s+\w+)?\s*\{',
    r'\bmsg\.sender\b',
    r'\bfunction\s+\w+\s*\([^)]*\)\s*(?:external|public)\b',
  ],
  rules: [
    TokenRule(r'^[ \t]*pragma\b.*$', scope: Scopes.meta),
    LineComment('///', scope: Scopes.commentDoc),
    BlockComment(
      '/**',
      '*/',
      scope: Scopes.commentDoc,
      rules: [TokenRule(r'@\w+', scope: Scopes.keyword)],
    ),
    BlockComment('/*', '*/'),
    LineComment('//'),
    QuotedString('"', prefix: r'(?<![\w$])(?:unicode|hex)?'),
    QuotedString("'", prefix: r'(?<![\w$])(?:unicode|hex)?'),
    Numbers(binary: false, octal: false),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          'abstract', 'anonymous', 'as', 'assembly', 'break', //
          'calldata', 'catch', 'constant', 'constructor', 'continue',
          'contract', 'delete', 'do', 'else', 'emit', 'enum', 'error',
          'event', 'external', 'fallback', 'for', 'function', 'if',
          'immutable', 'import', 'indexed', 'interface', 'internal', 'is',
          'layout', 'library', 'mapping', 'memory', 'modifier', 'new',
          'override', 'payable', 'pragma', 'private', 'public', 'pure',
          'receive', 'return', 'returns', 'revert', 'storage', 'struct',
          'transient', 'try', 'type', 'unchecked', 'using', 'view',
          'virtual', 'while',
        ],
        Scopes.literal: ['true', 'false'],
        Scopes.number: [
          'wei', 'gwei', 'ether', 'seconds', 'minutes', 'hours', 'days', //
          'weeks',
        ],
        Scopes.variableLanguage: ['this', 'super', 'msg', 'block', 'tx', 'abi'],
        Scopes.typeBuiltin: [
          'address', 'bool', 'string', 'bytes', 'byte', 'int', 'uint', //
          'fixed', 'ufixed',
        ],
        Scopes.function: [
          'require', 'assert', 'keccak256', 'sha256', 'ripemd160', //
          'ecrecover', 'addmod', 'mulmod', 'selfdestruct', 'blockhash',
          'blobhash', 'gasleft',
        ],
      },
      otherwise: [
        // Sized types: `uint256`, `int8`, `bytes32`, `fixed128x18`.
        TokenRule(
          r'(?:u?int(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|'
          r'136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)|'
          r'bytes(?:[1-9]|[12]\d|3[0-2])|u?fixed\d+x\d+)(?![\w$])',
          scope: Scopes.typeBuiltin,
        ),
        // SCREAMING_CASE names are constants, not types.
        TokenRule(r'[A-Z][A-Z0-9]*_[A-Z0-9_]*(?![\w$])'),
        CommonRules.capitalizedType,
        CommonRules.functionCall,
      ],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
