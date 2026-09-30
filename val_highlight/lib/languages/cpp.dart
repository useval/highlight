import '../advanced.dart';
import 'c.dart';

/// C++ (C++23).
const cppLanguage = Grammar(
  name: 'cpp',
  aliases: ['c++', 'cxx', 'hpp', 'cc', 'hh'],
  fileExtensions: ['cpp', 'cc', 'cxx', 'hpp', 'hh', 'hxx', 'ipp', 'ixx'],
  signatures: [
    r'^#include\s*<(?:iostream|vector|string|memory|map|algorithm)>',
    r'\bstd::\w+',
    r'\btemplate\s*<',
    r'\bnamespace\s+\w+\s*\{',
    r'\b(?:public|private|protected):\s*$',
  ],
  rules: [
    // Raw strings: R"delim( … )delim".
    RegionRule(
      begin: r'(?:u8|[uUL])?R"([^()\\\s]{0,16})\(',
      end: r'\)\1"',
      scope: Scopes.string,
      endReferencesBegin: true,
    ),
    ...cCommonRules,
    // Attributes: [[nodiscard]], [[likely]].
    TokenRule(r'\[\[[^\]\n]*\]\]', scope: Scopes.meta),
    CommonRules.memberCall,
    CommonRules.member,
    // `std::`, `detail::` — qualifiers are namespaces or types.
    TokenRule(r'[A-Za-z_]\w*(?=::)', scope: Scopes.type),
    KeywordRule(
      {
        Scopes.keyword: [
          ...cKeywords,
          'and', 'and_eq', 'asm', 'bitand', 'bitor', 'catch', 'class', //
          'co_await', 'co_return', 'co_yield', 'compl', 'concept',
          'consteval', 'constinit', 'const_cast', 'decltype', 'delete',
          'dynamic_cast', 'explicit', 'export', 'final', 'friend', 'import',
          'module', 'mutable', 'namespace', 'new', 'noexcept', 'not',
          'not_eq', 'operator', 'or', 'or_eq', 'override', 'private',
          'protected', 'public', 'reinterpret_cast', 'requires',
          'static_cast', 'template', 'throw', 'try', 'typeid', 'typename',
          'using', 'virtual', 'xor', 'xor_eq',
        ],
        Scopes.typeBuiltin: [
          ...cTypes,
          'char8_t', 'char16_t', 'char32_t', //
        ],
        Scopes.literal: cLiterals,
        Scopes.variableLanguage: ['this'],
      },
      otherwise: [CommonRules.capitalizedType, CommonRules.functionCall],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
