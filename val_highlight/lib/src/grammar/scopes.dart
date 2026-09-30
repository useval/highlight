/// Standard scope names used by the built-in grammars and themes.
///
/// Scopes are plain dotted strings, so grammars may use any name. A theme
/// resolves `a.b.c` by trying `a.b.c`, then `a.b`, then `a`, so a custom
/// scope such as `keyword.control.flow` still picks up the `keyword` style.
abstract final class Scopes {
  /// A comment.
  static const comment = 'comment';

  /// A documentation comment.
  static const commentDoc = 'comment.doc';

  /// A string literal, including its delimiters.
  static const string = 'string';

  /// An escape sequence inside a string, such as `\n`.
  static const stringEscape = 'string.escape';

  /// An interpolated expression inside a string, such as `${x}`.
  static const interpolation = 'interpolation';

  /// A numeric literal.
  static const number = 'number';

  /// A reserved word.
  static const keyword = 'keyword';

  /// A literal constant such as `true`, `false` or `null`.
  static const literal = 'literal';

  /// A type name.
  static const type = 'type';

  /// A type provided by the language or its core library.
  static const typeBuiltin = 'type.builtin';

  /// A function or method name.
  static const function = 'function';

  /// A variable reference, such as `$HOME` in a shell script.
  static const variable = 'variable';

  /// A language-defined variable such as `this` or `super`.
  static const variableLanguage = 'variable.language';

  /// Metadata such as annotations, attributes or preprocessor directives.
  static const meta = 'meta';

  /// A property or object key.
  static const property = 'property';

  /// Punctuation such as brackets and separators.
  static const punctuation = 'punctuation';

  /// An operator.
  static const operator = 'operator';

  /// A markup tag name.
  static const tag = 'tag';

  /// A markup attribute name.
  static const attribute = 'attribute';

  /// A regular expression literal.
  static const regexp = 'regexp';

  /// A document heading.
  static const heading = 'heading';

  /// Emphasized (italic) text.
  static const emphasis = 'emphasis';

  /// Strong (bold) text.
  static const strong = 'strong';

  /// A link or URL.
  static const link = 'link';

  /// Inline or block code inside prose.
  static const code = 'code';

  /// A quotation.
  static const quote = 'quote';

  /// An added line in a diff.
  static const addition = 'addition';

  /// A removed line in a diff.
  static const deletion = 'deletion';

  /// Invalid or illegal syntax.
  static const invalid = 'invalid';
}
