import '../advanced.dart';

/// Markdown (CommonMark plus GitHub extensions).
///
/// Fenced code blocks are highlighted in the language named after the fence
/// (```` ```dart ````) when that language is in the `Highlighter`'s
/// registry; otherwise their content is scoped as [Scopes.code].
const markdownLanguage = Grammar(
  name: 'markdown',
  aliases: ['md', 'mkdown', 'mkd'],
  fileExtensions: ['md', 'markdown', 'mkd'],
  // Inline code can wrap across lines, but never across a blank line.
  restartLine: r'[ \t]*$',
  signatures: [
    r'^#{1,6} \S',
    r'^```',
    r'\[[^\]\n]+\]\([^)\n]+\)',
    r'^\s*[-*+] \S',
  ],
  rules: [
    // Fenced code. A backtick fence's info string cannot contain
    // backticks, and a fence closes only on a fence of the same character
    // that is at least as long.
    RegionRule(
      begin: r'^[ \t]*(`{3,})[ \t]*([\w#+.-]*)[^`\n]*$',
      end: r'^[ \t]*\1`*[ \t]*$',
      beginScope: Scopes.code,
      endScope: Scopes.code,
      embedCapture: 2,
      endReferencesBegin: true,
      rules: [TokenRule(r'[^\n]+', scope: Scopes.code)],
    ),
    RegionRule(
      begin: r'^[ \t]*(~{3,})[ \t]*([\w#+.-]*)[^\n]*$',
      end: r'^[ \t]*\1~*[ \t]*$',
      beginScope: Scopes.code,
      endScope: Scopes.code,
      embedCapture: 2,
      endReferencesBegin: true,
      rules: [TokenRule(r'[^\n]+', scope: Scopes.code)],
    ),
    TokenRule(r'^#{1,6}(?=[ \t]|$).*$', scope: Scopes.heading),
    TokenRule(r'^.+\n(?:=+|-+)[ \t]*$', scope: Scopes.heading),
    TokenRule(r'^[ \t]*(?:[-*_][ \t]*){3,}$', scope: Scopes.meta),
    TokenRule(r'^[ \t]*>.*$', scope: Scopes.quote),
    TokenRule(
      r'^[ \t]*(?:[-*+]|\d{1,9}[.)])(?=[ \t])',
      scope: Scopes.punctuation,
    ),
    // Inline code may wrap lines but not cross a blank line.
    TokenRule(
      r'(`+)[^`\n](?:[^\n]|\n(?![ \t]*(?:\n|$)))*?\1(?!`)',
      scope: Scopes.code,
    ),
    TokenRule(
      r'!?\[[^\]\n]*\](?:\([^)\n]*\)|\[[^\]\n]*\])',
      scope: Scopes.link,
    ),
    TokenRule(r'<(?:https?://|mailto:)[^>\s]+>', scope: Scopes.link),
    TokenRule(r'\*\*[^*\n]+\*\*|__[^_\n]+__', scope: Scopes.strong),
    TokenRule(
      r'(?<![*\w])\*[^*\s](?:[^*\n]*[^*\s])?\*(?!\*)'
      r'|(?<![_\w])_[^_\s](?:[^_\n]*[^_\s])?_(?![_\w])',
      scope: Scopes.emphasis,
    ),
    TokenRule(r'~~[^~\n]+~~', scope: Scopes.deletion),
    TokenRule(r'</?[A-Za-z][^>\n]*>', scope: Scopes.tag),
    TokenRule(r'\\[\\`*_{}\[\]()#+\-.!|~>]', scope: Scopes.stringEscape),
  ],
);
