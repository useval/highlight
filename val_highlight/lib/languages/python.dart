import '../advanced.dart';

/// Python 3.
const pythonLanguage = Grammar(
  name: 'python',
  aliases: ['py', 'py3', 'gyp'],
  fileExtensions: ['py', 'pyw', 'pyi'],
  shebangs: ['python', 'python3'],
  signatures: [
    r'^\s*def\s+\w+\s*\(.*\)\s*(?:->\s*[^:]+)?:\s*$',
    r'^\s*(?:from\s+[\w.]+\s+)?import\s+[\w.]+(?:\s+as\s+\w+)?\s*$',
    r'^\s*class\s+\w+(?:\([^)]*\))?:\s*$',
    r'^\s*(?:elif|except|finally)\b.*:\s*$',
    r'''if __name__ == ['"]__main__['"]''',
  ],
  rules: [
    TokenRule(r'#.*$', scope: Scopes.comment),
    IncludeRule('expression'),
  ],
  repository: {
    // Everything but comments, so `#` inside f-string braces (as in
    // `f'{x:#x}'`) is not read as a comment.
    'expression': [
      IncludeRule('strings'),
      TokenRule(r'(?<=^[ \t]*)@[A-Za-z_][\w.]*', scope: Scopes.meta),
      TokenRule(
        r'(?<![\w.])(?:0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+'
        r'|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?[jJ]?)'
        r'(?!\w)',
        scope: Scopes.number,
      ),
      // After a `.`, a name is an attribute: never a keyword (`re.match`),
      // and a function when called.
      TokenRule(
        r'(?<=\.)[A-Za-z_]\w*(?=[ \t]*(?:\r?\n[ \t]*)?\()',
        scope: Scopes.function,
      ),
      TokenRule(r'(?<=\.)[A-Za-z_]\w*'),
      KeywordRule(
        {
          Scopes.keyword: [
            'and', 'as', 'assert', 'async', 'await', 'break', 'case', //
            'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
            'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
            'lambda', 'match', 'nonlocal', 'not', 'or', 'pass', 'raise',
            'return', 'try', 'while', 'with', 'yield',
          ],
          Scopes.literal: [
            'True',
            'False',
            'None',
            'NotImplemented',
            'Ellipsis',
          ],
          Scopes.variableLanguage: ['self', 'cls'],
          Scopes.typeBuiltin: [
            'bool', 'bytearray', 'bytes', 'complex', 'dict', 'Exception', //
            'float', 'frozenset', 'int', 'list', 'object', 'range', 'set',
            'str', 'tuple', 'type',
          ],
        },
        otherwise: [
          TokenRule(r'_*[A-Z]\w*', scope: Scopes.type),
          TokenRule(
            r'[A-Za-z_]\w*(?=[ \t]*(?:\r?\n[ \t]*)?\()',
            scope: Scopes.function,
          ),
        ],
      ),
      TokenRule(
        r'->|:=|\*\*=?|//=?|<<=?|>>=?|[-+*/%&|^~<>=!@]=?',
        scope: Scopes.operator,
      ),
    ],
    'strings': [
      // f-strings and t-strings (template strings, Python 3.14), raw first:
      // in a raw one only a backslash before a quote or backslash is
      // special, so `fr'\{{'` is a backslash and an escaped brace.
      RegionRule(
        begin: r'(?<!\w)(?:[fFtT][rR]|[rR][fFtT])"""',
        end: '"""',
        scope: Scopes.string,
        rules: [IncludeRule('rawFContent')],
      ),
      RegionRule(
        begin: r"(?<!\w)(?:[fFtT][rR]|[rR][fFtT])'''",
        end: "'''",
        scope: Scopes.string,
        rules: [IncludeRule('rawFContent')],
      ),
      RegionRule(
        begin: r'(?<!\w)(?:[fFtT][rR]|[rR][fFtT])"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [IncludeRule('rawFContent')],
      ),
      RegionRule(
        begin: r"(?<!\w)(?:[fFtT][rR]|[rR][fFtT])'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [IncludeRule('rawFContent')],
      ),
      RegionRule(
        begin: r'(?<!\w)[fFtT]"""',
        end: '"""',
        scope: Scopes.string,
        rules: [IncludeRule('fContent')],
      ),
      RegionRule(
        begin: r"(?<!\w)[fFtT]'''",
        end: "'''",
        scope: Scopes.string,
        rules: [IncludeRule('fContent')],
      ),
      RegionRule(
        begin: r'(?<!\w)[fFtT]"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [IncludeRule('fContent')],
      ),
      RegionRule(
        begin: r"(?<!\w)[fFtT]'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [IncludeRule('fContent')],
      ),
      // Raw strings: no escapes, but a backslash still stops the next quote
      // from ending the string.
      RegionRule(
        begin: r'(?<!\w)(?:[rR][bB]?|[bB][rR])"""',
        end: '"""',
        scope: Scopes.string,
        rules: [IncludeRule('rawEscape')],
      ),
      RegionRule(
        begin: r"(?<!\w)(?:[rR][bB]?|[bB][rR])'''",
        end: "'''",
        scope: Scopes.string,
        rules: [IncludeRule('rawEscape')],
      ),
      RegionRule(
        begin: r'(?<!\w)(?:[rR][bB]?|[bB][rR])"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [IncludeRule('rawEscape')],
      ),
      RegionRule(
        begin: r"(?<!\w)(?:[rR][bB]?|[bB][rR])'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [IncludeRule('rawEscape')],
      ),
      // Plain and byte strings.
      RegionRule(
        begin: r'(?<!\w)[bBuU]?"""',
        end: '"""',
        scope: Scopes.string,
        rules: [IncludeRule('escape')],
      ),
      RegionRule(
        begin: r"(?<!\w)[bBuU]?'''",
        end: "'''",
        scope: Scopes.string,
        rules: [IncludeRule('escape')],
      ),
      RegionRule(
        begin: r'(?<!\w)[bBuU]?"',
        end: r'"|$',
        scope: Scopes.string,
        rules: [IncludeRule('escape')],
      ),
      RegionRule(
        begin: r"(?<!\w)[bBuU]?'",
        end: r"'|$",
        scope: Scopes.string,
        rules: [IncludeRule('escape')],
      ),
    ],
    'rawEscape': [TokenRule(r'\\[\s\S]')],
    'escape': [
      TokenRule(
        r'\\(?:x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}'
        r'|N\{[^}]*\}|[0-7]{1,3}|[\s\S])',
        scope: Scopes.stringEscape,
      ),
    ],
    'rawFContent': [TokenRule(r'''\\[\\'"]'''), IncludeRule('fBody')],
    'fContent': [IncludeRule('escape'), IncludeRule('fBody')],
    'fBody': [
      TokenRule(r'\{\{|\}\}', scope: Scopes.stringEscape),
      RegionRule(
        begin: r'\{',
        end: r'\}',
        scope: Scopes.interpolation,
        rules: [
          IncludeRule('fBraces'),
          TokenRule(r'![rsa](?=[:}])', scope: Scopes.operator),
          IncludeRule('expression'),
        ],
      ),
    ],
    'fBraces': [
      RegionRule(
        begin: r'\{',
        end: r'\}',
        rules: [IncludeRule('fBraces'), IncludeRule('expression')],
      ),
    ],
  },
);
