import '../advanced.dart';

/// Directives that open a block.
const _blocks =
    '(?:http|server|location|events|upstream|stream|mail|types|map|geo|if|'
    'limit_except|split_clients)';

/// nginx configuration.
const nginxLanguage = Grammar(
  name: 'nginx',
  aliases: ['nginxconf'],
  fileNames: ['nginx.conf'],
  signatures: [
    r'^\s*server\s*\{',
    r'^\s*location\s+(?:[=~^*]+\s*)?/\S*\s*\{',
    r'^\s*(?:proxy_pass|listen|server_name|root)\s+\S',
    r'\$(?:host|remote_addr|request_uri|scheme)\b',
  ],
  rules: [
    LineComment('#', afterSpace: true),
    QuotedString('"', rules: [IncludeRule('variables')]),
    QuotedString("'", rules: [IncludeRule('variables')]),
    IncludeRule('variables'),
    // Block directives, at a line start or after `{` or `;`.
    TokenRule('^([ \\t]*)($_blocks)\\b', captures: {2: Scopes.keyword}),
    TokenRule('(?<=[{;])[ \\t]*$_blocks\\b', scope: Scopes.keyword),
    // Any other directive: the first word of a statement.
    TokenRule(r'^([ \t]*)([A-Za-z_]\w*)', captures: {2: Scopes.property}),
    TokenRule(r'(?<=[{;])[ \t]*[A-Za-z_]\w*', scope: Scopes.property),
    // Location modifiers and comparisons.
    TokenRule(r'(?<=\s)(?:\^~|~\*|!~\*|!~|~|=)(?=\s)', scope: Scopes.operator),
    TokenRule(r'\b(?:on|off)\b', scope: Scopes.literal),
    // Sizes and durations: `10m`, `30s`, `1h`.
    TokenRule(
      r'(?<![\w$.:/-])\d+(?:\.\d+)?(?:[kKmMgG]|ms|s|h|d|w|y)?(?![\w.:/-])',
      scope: Scopes.number,
    ),
    TokenRule(r'[{};]', scope: Scopes.punctuation),
  ],
  repository: {
    'variables': [
      TokenRule(
        r'\$\{[A-Za-z_]\w*\}|\$[A-Za-z_0-9]\w*',
        scope: Scopes.variable,
      ),
    ],
  },
);
