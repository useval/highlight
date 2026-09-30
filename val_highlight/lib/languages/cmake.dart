import '../advanced.dart';

/// Control-flow commands, in the two cases people write them in.
const _controlCommands = [
  'if', 'elseif', 'else', 'endif', 'foreach', 'endforeach', 'while', //
  'endwhile', 'function', 'endfunction', 'macro', 'endmacro', 'return',
  'break', 'continue', 'block', 'endblock',
];

/// CMake.
const cmakeLanguage = Grammar(
  name: 'cmake',
  aliases: ['cmakelists'],
  fileExtensions: ['cmake'],
  fileNames: ['CMakeLists.txt'],
  signatures: [
    r'^\s*cmake_minimum_required\s*\(',
    r'^\s*(?:add_executable|add_library|target_link_libraries)\s*\(',
    r'\$\{CMAKE_[A-Z_]+\}',
    r'^\s*project\s*\(\s*[\w-]+',
  ],
  rules: [
    // Bracket comments `#[[ … ]]` and `#[==[ … ]==]`.
    RegionRule(
      begin: r'#\[(=*)\[',
      end: r'\]\1\]',
      scope: Scopes.comment,
      endReferencesBegin: true,
    ),
    LineComment('#'),
    // Bracket arguments `[[ … ]]`, `[=[ … ]=]`.
    RegionRule(
      begin: r'\[(=*)\[',
      end: r'\]\1\]',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    QuotedString('"', multiline: true, rules: [IncludeRule('references')]),
    IncludeRule('references'),
    KeywordRule(
      {
        Scopes.keyword: [
          ..._controlCommands,
          'IF', 'ELSEIF', 'ELSE', 'ENDIF', 'FOREACH', 'ENDFOREACH', 'WHILE', //
          'ENDWHILE', 'FUNCTION', 'ENDFUNCTION', 'MACRO', 'ENDMACRO',
          'RETURN', 'BREAK', 'CONTINUE', 'BLOCK', 'ENDBLOCK',
        ],
        Scopes.literal: [
          'ON', 'OFF', 'TRUE', 'FALSE', 'YES', 'NO', 'Y', 'N', 'IGNORE', //
          'NOTFOUND',
        ],
      },
      word: r'(?<![\w.-])[A-Za-z_][\w]*',
      otherwise: [
        // Any other command is called like a function.
        TokenRule(r'[A-Za-z_]\w*(?=[ \t]*\()', scope: Scopes.function),
        // Upper-case keyword arguments: PUBLIC, REQUIRED, COMPONENTS, …
        TokenRule(r'[A-Z][A-Z0-9_]*[A-Z0-9](?![\w-])', scope: Scopes.attribute),
      ],
    ),
    // Versions such as `1.4.0`, then plain numbers.
    TokenRule(r'(?<![\w.-])\d+(?:\.\d+)+(?![\w.-])', scope: Scopes.number),
    Numbers(hex: false, binary: false, octal: false, separator: null),
  ],
  repository: {
    'references': [
      // `${VAR}`, `$ENV{VAR}`, `$CACHE{VAR}`, nested allowed.
      RegionRule(
        begin: r'\$(?:ENV|CACHE)?\{',
        end: r'\}',
        scope: Scopes.variable,
        rules: [IncludeRule('references')],
      ),
      // Generator expressions `$<TARGET_FILE:app>`, nested allowed.
      RegionRule(
        begin: r'\$<',
        end: r'>',
        scope: Scopes.meta,
        rules: [IncludeRule('references')],
      ),
      TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
    ],
  },
);
