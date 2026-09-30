import '../advanced.dart';

/// SQL, covering the common ANSI syntax plus popular dialect keywords.
const sqlLanguage = Grammar(
  name: 'sql',
  aliases: ['postgresql', 'postgres', 'mysql', 'sqlite', 'plsql', 'tsql'],
  fileExtensions: ['sql'],
  caseInsensitive: true,
  signatures: [
    r'\bselect\b[\s\S]*?\bfrom\b',
    r'\binsert\s+into\b',
    r'\bcreate\s+(?:table|index|view|function)\b',
    r'\bupdate\s+\w+\s+set\b',
  ],
  rules: [
    TokenRule(r'--.*$', scope: Scopes.comment),
    RegionRule(begin: r'/\*', end: r'\*/', scope: Scopes.comment),
    RegionRule(
      begin: "'",
      end: "'(?!')",
      scope: Scopes.string,
      rules: [TokenRule("''", scope: Scopes.stringEscape)],
    ),
    // PostgreSQL dollar quoting: `$$…$$` or `$tag$…$tag$`.
    RegionRule(
      begin: r'\$([A-Za-z_]\w*)?\$',
      end: r'\$\1\$',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    RegionRule(begin: '"', end: '"', scope: Scopes.property),
    RegionRule(begin: '`', end: '`', scope: Scopes.property),
    RegionRule(begin: r'\[', end: r'\]', scope: Scopes.property),
    TokenRule(
      r'(?<![\w.])(?:0x[0-9a-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:e[-+]?\d+)?)(?![\w.])',
      scope: Scopes.number,
    ),
    TokenRule(r'[:@$]\w+|\?', scope: Scopes.variable),
    KeywordRule(
      {
        Scopes.keyword: [
          'add', 'all', 'alter', 'and', 'any', 'as', 'asc', 'begin', //
          'between', 'by', 'cascade', 'case', 'check', 'column', 'commit',
          'constraint', 'create', 'cross', 'database', 'declare', 'default',
          'delete', 'desc', 'distinct', 'drop', 'else', 'end', 'exists',
          'explain', 'foreign', 'from', 'full', 'function', 'grant', 'group',
          'having', 'if', 'in', 'index', 'inner', 'insert', 'intersect',
          'into', 'is', 'join', 'key', 'left', 'like', 'limit', 'natural',
          'not', 'offset', 'on', 'or', 'order', 'outer', 'over', 'partition',
          'primary', 'procedure', 'references', 'replace', 'returning',
          'returns', 'revoke', 'right', 'rollback', 'schema', 'select', 'set',
          'table', 'then', 'to', 'transaction', 'trigger', 'truncate',
          'union', 'unique', 'update', 'using', 'values', 'view', 'when',
          'where', 'window', 'with',
        ],
        Scopes.literal: ['null', 'true', 'false', 'unknown'],
        Scopes.typeBuiltin: [
          'bigint', 'binary', 'bit', 'blob', 'boolean', 'bool', 'char', //
          'date', 'datetime', 'decimal', 'double', 'float', 'int', 'integer',
          'interval', 'json', 'jsonb', 'money', 'numeric', 'real', 'serial',
          'smallint', 'text', 'time', 'timestamp', 'timestamptz', 'tinyint',
          'uuid', 'varchar',
        ],
      },
      otherwise: [
        TokenRule(r'\w+(?=[ \t]*(?:\r?\n[ \t]*)?\()', scope: Scopes.function),
      ],
    ),
    TokenRule(r'<>|!=|<=|>=|\|\||::|[-+*/%<>=]', scope: Scopes.operator),
  ],
);
