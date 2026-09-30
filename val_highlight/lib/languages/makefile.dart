import '../advanced.dart';

/// Make (GNU make syntax).
const makefileLanguage = Grammar(
  name: 'makefile',
  aliases: ['make', 'mk', 'mak'],
  fileExtensions: ['mk', 'mak'],
  fileNames: ['Makefile', 'GNUmakefile', 'makefile'],
  signatures: [
    r'^\.PHONY\s*:',
    r'^[A-Za-z_][\w.-]*\s*(?::=|\?=|\+=)',
    r'\$\((?:CC|CFLAGS|MAKE|shell|wildcard|patsubst)\b',
    r'^\t\$\((?:CC|MAKE)\)',
  ],
  rules: [
    // Recipe lines start with a tab and run to the end of the logical line.
    RegionRule(
      begin: r'^\t',
      end: r'(?<!\\)$',
      rules: [
        TokenRule(r'(?<=^\t)[@+-]+', scope: Scopes.operator),
        LineComment('#', afterSpace: true),
        QuotedString('"', rules: [IncludeRule('variables')]),
        QuotedString("'", escape: null),
        IncludeRule('variables'),
        TokenRule(r'\\[\s\S]', scope: Scopes.stringEscape),
      ],
    ),
    LineComment('#'),
    TokenRule(
      r'^[ \t]*-?(?:include|sinclude|ifeq|ifneq|ifdef|ifndef|else|endif|'
      r'define|endef|override|export|unexport|undefine|vpath)\b',
      scope: Scopes.keyword,
    ),
    // `NAME := value` and friends.
    TokenRule(
      r'^[ \t]*[A-Za-z_][\w.-]*(?=[ \t]*(?:::=|:::=|[:?+!]?=))',
      scope: Scopes.variable,
    ),
    // The name after `export` or `override`.
    TokenRule(
      r'(?<=\b(?:export|override|unexport)[ \t])[ \t]*[A-Za-z_][\w.-]*'
      r'(?=[ \t]*(?:::=|:::=|[:?+!]?=|$))',
      scope: Scopes.variable,
    ),
    // Targets: `name other: prerequisites`.
    TokenRule(
      r'^[A-Za-z0-9_.%/$(){}~-][^:#=\n]*?(?=[ \t]*::?(?!=))',
      scope: Scopes.function,
    ),
    IncludeRule('variables'),
    TokenRule(r'::?=|:::=|[?+!]?=|::?|\|', scope: Scopes.operator),
    TokenRule(r'\\$', scope: Scopes.operator),
  ],
  repository: {
    'variables': [
      // `$(VAR)`, `$(call f,x)`, `${VAR}`; nested references allowed.
      RegionRule(
        begin: r'\$\(',
        end: r'\)',
        scope: Scopes.variable,
        rules: [IncludeRule('reference')],
      ),
      RegionRule(
        begin: r'\$\{',
        end: r'\}',
        scope: Scopes.variable,
        rules: [IncludeRule('reference')],
      ),
      TokenRule(r'\$\$', scope: Scopes.stringEscape),
      // Automatic variables and one-letter references: `$@ $< $^ $x`.
      TokenRule(r'\$[@<^?*%+|A-Za-z0-9_]', scope: Scopes.variable),
    ],
    'reference': [
      // A make function such as `$(patsubst …)` or `$(call …)`.
      TokenRule(
        r'(?<=\$[({])(?:subst|patsubst|strip|findstring|filter|filter-out|'
        r'sort|word|words|wordlist|firstword|lastword|dir|notdir|suffix|'
        r'basename|addsuffix|addprefix|join|wildcard|realpath|abspath|error|'
        r'warning|info|shell|origin|flavor|foreach|if|or|and|call|eval|file|'
        r'value|let|intcmp)(?=[ \t])',
        scope: Scopes.function,
      ),
      RegionRule(begin: r'\(', end: r'\)', rules: [IncludeRule('reference')]),
      IncludeRule('variables'),
    ],
  },
);
