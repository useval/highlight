import '../advanced.dart';
import '../src/languages/markup.dart';

/// XML, including SVG, plist and similar formats.
const xmlLanguage = Grammar(
  name: 'xml',
  aliases: ['svg', 'plist', 'xsd', 'xsl', 'rss', 'atom'],
  fileExtensions: ['xml', 'svg', 'plist', 'xsd', 'xsl', 'xslt', 'rss'],
  signatures: [r'^\s*<\?xml\b', r'\bxmlns(?::\w+)?='],
  rules: markupRules,
  repository: {
    ...markupRepository,
    'tag': [markupTag],
  },
);
