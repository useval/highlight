import '../advanced.dart';
import 'html.dart';

/// PHP 8.
///
/// Code is PHP by default, so snippets without `<?php` highlight correctly.
/// `?>` switches to HTML until the next `<?php` or `<?=`, and a file that
/// starts with markup is HTML until its first PHP tag.
const phpLanguage = Grammar(
  name: 'php',
  aliases: ['php8', 'phtml'],
  fileExtensions: ['php', 'phtml', 'php8', 'php7'],
  shebangs: ['php'],
  signatures: [
    r'<\?php\b',
    r'\$this->\w+',
    r'^\s*(?:namespace|use)\s+[A-Z]\w*(?:\\\w+)+;',
    r'\bfunction\s+\w+\s*\([^)]*\$\w+',
    r'\b(?:echo|require_once)\s',
  ],
  rules: [
    TokenRule(r'^#!.*$', scope: Scopes.meta),
    // A file that starts with markup is HTML until the first PHP tag.
    RegionRule(
      begin: r'(?<![\s\S])(?=[ \t\r\n]*<(?!\?))',
      end: r'<\?(?:php\b|=)?|(?![\s\S])',
      endScope: Scopes.meta,
      embed: htmlLanguage,
    ),
    // `?>` leaves PHP; the text up to the next open tag is HTML.
    RegionRule(
      begin: r'\?>',
      end: r'<\?(?:php\b|=)?|(?![\s\S])',
      beginScope: Scopes.meta,
      endScope: Scopes.meta,
      embed: htmlLanguage,
    ),
    TokenRule(r'<\?(?:php\b|=)?', scope: Scopes.meta),
    IncludeRule('code'),
  ],
  repository: {
    'code': [
      BlockComment('/**', '*/', scope: Scopes.commentDoc),
      BlockComment('/*', '*/'),
      // Line comments end at `?>`, which leaves PHP even inside a comment.
      TokenRule(r'(?://|#(?!\[))(?:[^?\n]|\?(?!>))*', scope: Scopes.comment),
      // Attributes: `#[Route('/x')]`.
      RegionRule(
        begin: r'#\[',
        end: r'\]',
        scope: Scopes.meta,
        rules: [IncludeRule('strings'), IncludeRule('brackets')],
      ),
      IncludeRule('heredocs'),
      IncludeRule('strings'),
      TokenRule(r'\$this\b', scope: Scopes.variableLanguage),
      TokenRule(r'\$+[A-Za-z_]\w*', scope: Scopes.variable),
      Numbers(),
      // Members and static calls: `->name(`, `?->name`, `::name(`.
      TokenRule(r'(?<=->|::)[A-Za-z_]\w*(?=[ \t]*\()', scope: Scopes.function),
      TokenRule(r'(?<=->)[A-Za-z_]\w*'),
      KeywordRule(
        {
          Scopes.keyword: [
            'abstract', 'and', 'array', 'as', 'break', 'callable', 'case', //
            'catch', 'class', 'clone', 'const', 'continue', 'declare',
            'default', 'die', 'do', 'echo', 'else', 'elseif', 'empty',
            'enddeclare', 'endfor', 'endforeach', 'endif', 'endswitch',
            'endwhile', 'enum', 'eval', 'exit', 'extends', 'final',
            'finally', 'fn', 'for', 'foreach', 'from', 'function', 'global',
            'goto', 'if', 'implements', 'include', 'include_once',
            'instanceof', 'insteadof', 'interface', 'isset', 'list', 'match',
            'namespace', 'new', 'or', 'print', 'private', 'protected',
            'public', 'readonly', 'require', 'require_once', 'return',
            'static', 'switch', 'throw', 'trait', 'try', 'unset', 'use',
            'var', 'while', 'xor', 'yield',
          ],
          Scopes.literal: [
            'true', 'false', 'null', 'TRUE', 'FALSE', 'NULL', 'True', //
            'False', 'Null', '__CLASS__', '__DIR__', '__FILE__',
            '__FUNCTION__', '__LINE__', '__METHOD__', '__NAMESPACE__',
            '__TRAIT__', 'PHP_EOL', 'PHP_VERSION',
          ],
          Scopes.variableLanguage: ['self', 'parent'],
          Scopes.typeBuiltin: [
            'bool', 'float', 'int', 'iterable', 'mixed', 'never', 'object', //
            'string', 'void',
          ],
        },
        otherwise: [CommonRules.capitalizedType, _call],
      ),
      Operators('+-*/%=<>!&|^~?:.@\\'),
    ],
    'brackets': [
      RegionRule(
        begin: r'\[',
        end: r'\]',
        rules: [IncludeRule('strings'), IncludeRule('brackets')],
      ),
    ],
    'strings': [
      QuotedString(
        "'",
        multiline: true,
        escape: null,
        rules: [TokenRule(r"\\[\\']", scope: Scopes.stringEscape)],
      ),
      QuotedString('"', multiline: true, rules: [IncludeRule('interpolated')]),
      QuotedString('`', multiline: true, rules: [IncludeRule('interpolated')]),
    ],
    // `$name`, `$obj->prop`, `$arr['k']`, `{$expr}` and `${name}`.
    'interpolated': [
      RegionRule(
        begin: r'\{(?=\$)',
        end: r'\}',
        scope: Scopes.interpolation,
        rules: [IncludeRule('code')],
      ),
      TokenRule(r'\$\{[^}\n]*\}', scope: Scopes.variable),
      TokenRule(
        r'\$[A-Za-z_]\w*(?:->[A-Za-z_]\w*|\[[^\]\n]*\])?',
        scope: Scopes.variable,
      ),
    ],
    // Heredoc `<<<EOT` / `<<<"EOT"` and nowdoc `<<<'EOT'`. The closing
    // marker may be indented and followed by `;`, `,` or `)`.
    'heredocs': [
      RegionRule(
        begin: r"(<<<)[ \t]*'([A-Za-z_]\w*)'",
        end: r'^[ \t]*\2\b',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
      ),
      RegionRule(
        begin: r'(<<<)[ \t]*"?([A-Za-z_]\w*)"?',
        end: r'^[ \t]*\2\b',
        beginCaptures: {1: Scopes.operator, 2: Scopes.meta},
        endScope: Scopes.meta,
        endReferencesBegin: true,
        rules: [
          TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
          IncludeRule('interpolated'),
          TokenRule(r'[^$\\{\n]+|[${]', scope: Scopes.string),
        ],
      ),
    ],
  },
);

/// A name followed by `(` on the same line is a call. (Lookahead stays on
/// the line so incremental re-highlighting never needs to look further.)
const _call = TokenRule(
  r'[A-Za-z_$][\w$]*(?=[ \t]*\()',
  scope: Scopes.function,
);
