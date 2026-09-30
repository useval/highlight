import '../advanced.dart';

/// LaTeX and TeX.
const latexLanguage = Grammar(
  name: 'latex',
  aliases: ['tex'],
  fileExtensions: ['tex', 'sty', 'cls', 'ltx', 'bib'],
  // Inline math can wrap across lines, but never across a blank line.
  restartLine: r'[ \t]*$',
  signatures: [
    r'\\documentclass(?:\[[^\]]*\])?\{',
    r'\\begin\{(?:document|itemize|equation|figure|table|align)\}',
    r'\\usepackage(?:\[[^\]]*\])?\{',
    r'\\(?:section|subsection|chapter)\*?\{',
  ],
  rules: [
    // Escaped characters come first so `\%` and `\$` are not comments or
    // math.
    TokenRule(r'\\[%$&#_{}~^\\]', scope: Scopes.stringEscape),
    LineComment('%'),
    // `\begin{name}` and `\end{name}`.
    TokenRule(
      r'(\\(?:begin|end))(\{)([^}\n]*)(\})',
      captures: {1: Scopes.keyword, 3: Scopes.type},
    ),
    // Display math, then inline math. Inline math ends at a blank line if
    // it is never closed.
    RegionRule(
      begin: r'\$\$',
      end: r'\$\$|^(?=[ \t]*$)',
      scope: Scopes.code,
      rules: [IncludeRule('math')],
    ),
    RegionRule(
      begin: r'\\\[',
      end: r'\\\]',
      scope: Scopes.code,
      rules: [IncludeRule('math')],
    ),
    RegionRule(
      begin: r'\\\(',
      end: r'\\\)',
      scope: Scopes.code,
      rules: [IncludeRule('math')],
    ),
    RegionRule(
      begin: r'\$',
      end: r'\$|^(?=[ \t]*$)',
      scope: Scopes.code,
      rules: [IncludeRule('math')],
    ),
    IncludeRule('commands'),
    TokenRule(r'[{}\[\]]', scope: Scopes.punctuation),
    TokenRule(r'[&~]', scope: Scopes.operator),
  ],
  repository: {
    'commands': [
      // Sectioning and structure.
      TokenRule(
        r'\\(?:documentclass|usepackage|part|chapter|section|subsection|'
        r'subsubsection|paragraph|subparagraph|item|label|ref|cite|input|'
        r'include|newcommand|renewcommand|providecommand|newenvironment|'
        r'def|let|if|else|fi|title|author|date|maketitle|caption)\*?'
        r'(?![A-Za-z@])',
        scope: Scopes.keyword,
      ),
      TokenRule(r'\\[A-Za-z@]+\*?', scope: Scopes.function),
      // Control symbols such as `\\` or `\,`.
      TokenRule(r'\\[^A-Za-z@\s]', scope: Scopes.stringEscape),
      TokenRule(r'#\d', scope: Scopes.variable),
    ],
    'math': [
      TokenRule(r'\\[%$&#_{}~^\\]', scope: Scopes.stringEscape),
      LineComment('%'),
      IncludeRule('commands'),
    ],
  },
);
