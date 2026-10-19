part of 'grammar.dart';

/// How code in a language is edited: its comment markers, brackets and
/// quotes.
///
/// Editors use this to toggle comments, auto-close brackets and quotes and
/// match brackets. Set it on a grammar with [Grammar.editing]; read it with
/// [EditingSyntax.of], which derives one from the grammar's [LineComment],
/// [BlockComment] and [QuotedString] blocks when none is set.
///
/// ```dart
/// const myLanguage = Grammar(
///   name: 'mine',
///   rules: [...],
///   editing: EditingSyntax(lineComment: '--', quotes: '"'),
/// );
/// ```
final class EditingSyntax {
  /// Creates editing conventions for a language.
  const EditingSyntax({
    this.lineComment,
    this.blockComment,
    this.brackets = '()[]{}',
    this.quotes = '"\'',
  });

  /// `//` line comments, `/* */` block comments, and `"` `'` quotes: C, Java,
  /// Kotlin, Swift and most of their relatives.
  static const cStyle = EditingSyntax(
    lineComment: '//',
    blockComment: ('/*', '*/'),
  );

  /// `#` line comments: shells, Python, Ruby, YAML and many config formats.
  static const hashStyle = EditingSyntax(lineComment: '#');

  /// `<!-- -->` block comments: HTML, XML and Markdown.
  static const markupStyle = EditingSyntax(blockComment: ('<!--', '-->'));

  /// No comments, brackets or quotes: plain text.
  static const none = EditingSyntax(brackets: '', quotes: '');

  /// Text that starts a line comment, such as `//` or `#`, or `null` if the
  /// language has none.
  final String? lineComment;

  /// The opening and closing text of a block comment, such as `('/*',
  /// '*/')`, or `null` if the language has none.
  final (String, String)? blockComment;

  /// Bracket pairs, as consecutive opening and closing characters: `'()[]{}'`
  /// stands for `()`, `[]` and `{}`. Used for matching and auto-closing.
  final String brackets;

  /// Characters that open and close a string, such as `"` and `'`.
  /// Auto-closed like brackets, except after a letter or digit, so `don't`
  /// is left alone. Leave out characters with another meaning, such as `'`
  /// in Rust lifetimes or Lisp quoting.
  final String quotes;

  /// Returns a copy with the given fields replaced.
  EditingSyntax copyWith({
    String? lineComment,
    (String, String)? blockComment,
    String? brackets,
    String? quotes,
  }) {
    return EditingSyntax(
      lineComment: lineComment ?? this.lineComment,
      blockComment: blockComment ?? this.blockComment,
      brackets: brackets ?? this.brackets,
      quotes: quotes ?? this.quotes,
    );
  }

  /// The closing character for [open], or `null` if [open] opens nothing.
  ///
  /// Brackets close with their pair and quotes with themselves.
  String? closerOf(String open) {
    for (var i = 0; i + 1 < brackets.length; i += 2) {
      if (brackets[i] == open) return brackets[i + 1];
    }
    return quotes.contains(open) ? open : null;
  }

  static final Expando<EditingSyntax> _derived = Expando('EditingSyntax');

  /// The editing conventions of [grammar]: its [Grammar.editing], or, when
  /// that is unset, conventions derived from its comment and string blocks.
  ///
  /// Derivation looks at the top-level rules and the repository. The
  /// shortest [LineComment] and [BlockComment] markers win, so `//` beats
  /// `///`. Quotes come from single-character [QuotedString]s, and default
  /// to `"` and `'` when there are none. The result is cached per grammar.
  static EditingSyntax of(Grammar grammar) =>
      grammar.editing ?? (_derived[grammar] ??= _derive(grammar));

  static EditingSyntax _derive(Grammar grammar) {
    String? line;
    (String, String)? block;
    final quotes = StringBuffer();
    void visit(Rule rule) {
      switch (rule) {
        case LineComment(:final start, :final scope)
            when scope == Scopes.comment &&
                (line == null || start.length < line!.length):
          line = start;
        case BlockComment(:final open, :final close, :final scope)
            when scope == Scopes.comment &&
                (block == null || open.length < block!.$1.length):
          block = (open, close);
        case QuotedString(:final quote, :final end)
            when quote.length == 1 &&
                (end == null || end == quote) &&
                !quotes.toString().contains(quote):
          quotes.write(quote);
        default:
      }
    }

    grammar.rules.forEach(visit);
    for (final list in grammar.repository.values) {
      list.forEach(visit);
    }
    return EditingSyntax(
      lineComment: line,
      blockComment: block,
      quotes: quotes.isEmpty ? '"\'' : quotes.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditingSyntax &&
      other.lineComment == lineComment &&
      other.blockComment == blockComment &&
      other.brackets == brackets &&
      other.quotes == quotes;

  @override
  int get hashCode => Object.hash(lineComment, blockComment, brackets, quotes);

  @override
  String toString() =>
      'EditingSyntax(lineComment: $lineComment, blockComment: $blockComment, '
      'brackets: $brackets, quotes: $quotes)';
}
