import '../../advanced.dart';

// Building blocks shared by the XML and HTML grammars.

/// Rules shared by XML and HTML. The including grammar must define a `tag`
/// entry.
const markupRepository = <String, List<Rule>>{
  'comment': [RegionRule(begin: '<!--', end: '-->', scope: Scopes.comment)],
  'cdata': [
    RegionRule(
      begin: r'<!\[CDATA\[',
      end: r'\]\]>',
      scope: Scopes.string,
      beginScope: Scopes.meta,
      endScope: Scopes.meta,
    ),
  ],
  'declaration': [
    RegionRule(
      begin: r'<!',
      end: '>',
      scope: Scopes.meta,
      rules: [IncludeRule('attributeValue')],
    ),
    RegionRule(
      begin: r'<\?',
      end: r'\?>',
      scope: Scopes.meta,
      rules: [IncludeRule('attributeValue')],
    ),
  ],
  'entity': [
    TokenRule(
      r'&(?:[A-Za-z][\w]*|#\d+|#[xX][\da-fA-F]+);',
      scope: Scopes.stringEscape,
    ),
  ],
  'attributes': [
    TokenRule(r'''[^\s"'<>/=]+''', scope: Scopes.attribute),
    TokenRule('=', scope: Scopes.punctuation),
    IncludeRule('attributeValue'),
  ],
  'attributeValue': [
    RegionRule(
      begin: '"',
      end: '"',
      scope: Scopes.string,
      rules: [IncludeRule('entity')],
    ),
    RegionRule(
      begin: "'",
      end: "'",
      scope: Scopes.string,
      rules: [IncludeRule('entity')],
    ),
  ],
};

/// Top-level rules shared by XML and HTML.
const markupRules = [
  IncludeRule('comment'),
  IncludeRule('cdata'),
  IncludeRule('declaration'),
  IncludeRule('tag'),
  IncludeRule('entity'),
];

/// A generic start or end tag: `<name attr="v">`, `</name>`, `<name/>`.
const markupTag = RegionRule(
  begin: r'(</?)([^\s/>]+)',
  end: '/?>',
  beginCaptures: {1: Scopes.punctuation, 2: Scopes.tag},
  endScope: Scopes.punctuation,
  rules: [IncludeRule('attributes')],
);
