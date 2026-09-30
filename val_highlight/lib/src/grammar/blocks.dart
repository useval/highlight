part of 'grammar.dart';

/// A reusable rule that expands into basic rules when the grammar is
/// compiled.
///
/// The built-in blocks cover what most languages repeat: comments, strings,
/// numbers, operators and annotations, so most grammars need no regular
/// expressions. Extend this class to make your own blocks.
abstract class BlockRule extends Rule {
  /// Base constructor for blocks.
  const BlockRule();

  /// The basic rules this block stands for. Called once per block.
  List<Rule> expand();
}

String _escape(String text) => RegExp.escape(text);

/// Escapes characters that are special inside a `[...]` class.
String _escapeClass(String chars) =>
    chars.replaceAllMapped(RegExp(r'[\\\]\[^-]'), (m) => '\\${m[0]}');

/// A comment from [start] to the end of the line, such as `//` or `#`.
///
/// With [afterSpace], the comment only starts at the beginning of a line or
/// after whitespace, so `#` inside words (`a#b`, `$#`) is left alone.
final class LineComment extends BlockRule {
  /// Creates a line comment block.
  const LineComment(
    this.start, {
    this.scope = Scopes.comment,
    this.afterSpace = false,
  });

  /// Text that starts the comment.
  final String start;

  /// Scope of the comment.
  final String scope;

  /// Whether the comment must follow whitespace or start a line.
  final bool afterSpace;

  @override
  List<Rule> expand() => [
    TokenRule(
      '${afterSpace ? r'(?<=^|\s)' : ''}${_escape(start)}.*\$',
      scope: scope,
    ),
  ];
}

/// A comment between [open] and [close], such as `/*` and `*/`.
///
/// With [nested], inner `open … close` pairs nest, as in Dart, Rust, Swift
/// and Haskell.
final class BlockComment extends BlockRule {
  /// Creates a block comment block.
  const BlockComment(
    this.open,
    this.close, {
    this.nested = false,
    this.scope = Scopes.comment,
    this.rules = const [],
  });

  /// Text that opens the comment.
  final String open;

  /// Text that closes the comment.
  final String close;

  /// Whether comments nest.
  final bool nested;

  /// Scope of the comment.
  final String scope;

  /// Extra rules inside the comment, such as doc tags.
  final List<Rule> rules;

  @override
  List<Rule> expand() {
    final begin = _escape(open);
    final end = _escape(close);
    if (!nested) {
      return [RegionRule(begin: begin, end: end, scope: scope, rules: rules)];
    }
    // The inner region lists itself among its rules.
    final inner = <Rule>[...rules];
    final region = RegionRule(begin: begin, end: end, rules: inner);
    inner.add(region);
    return [
      RegionRule(
        begin: begin,
        end: end,
        scope: scope,
        rules: [...rules, region],
      ),
    ];
  }
}

/// A string between [quote] and [end] (default: [quote]).
///
/// - [prefix] is a pattern allowed before the quote, such as `[rRbB]?`.
/// - [escape] starts an escape sequence (default `\`); `null` for none.
/// - [doubled] treats a doubled quote as an escaped quote (SQL, Pascal,
///   VB, CSV).
/// - [multiline] lets the string span lines; otherwise it also ends at the
///   end of the line, so an unclosed quote cannot swallow the file.
/// - [lastInRun] closes on the last delimiter of a run of quote
///   characters, as Scala and Kotlin `"""` strings do: `""""x""""`
///   holds `"x"`.
/// - [rules] adds rules inside, such as interpolation.
final class QuotedString extends BlockRule {
  /// Creates a string block.
  const QuotedString(
    this.quote, {
    this.end,
    this.prefix,
    this.escape = r'\',
    this.doubled = false,
    this.multiline = false,
    this.lastInRun = false,
    this.rules = const [],
    this.scope = Scopes.string,
  });

  /// Opening quote.
  final String quote;

  /// Closing quote, when different from [quote].
  final String? end;

  /// Pattern allowed immediately before the quote.
  final String? prefix;

  /// Escape character, or `null` for none.
  final String? escape;

  /// Whether a doubled closing quote is an escape.
  final bool doubled;

  /// Whether the string may span lines.
  final bool multiline;

  /// Whether the string closes on the last delimiter of a run of quotes.
  final bool lastInRun;

  /// Extra rules inside the string.
  final List<Rule> rules;

  /// Scope of the string.
  final String scope;

  @override
  List<Rule> expand() {
    final closeText = end ?? quote;
    final close = _escape(closeText);
    final closing = doubled
        ? '$close(?!$close)'
        : lastInRun
        ? '$close(?!${_escape(closeText[closeText.length - 1])})'
        : close;
    final escape = this.escape;
    return [
      RegionRule(
        begin: '${prefix ?? ''}${_escape(quote)}',
        end: multiline ? closing : '$closing|\$',
        scope: scope,
        rules: [
          if (doubled) TokenRule('$close$close', scope: Scopes.stringEscape),
          if (escape != null)
            TokenRule('${_escape(escape)}[\\s\\S]', scope: Scopes.stringEscape),
          ...rules,
        ],
      ),
    ];
  }
}

/// An interpolated expression inside a string, such as `${…}` or `#{…}`.
///
/// Braces inside the expression are balanced before [close] ends it.
/// [rules] default to the grammar's top level.
final class Interpolation extends BlockRule {
  /// Creates an interpolation block.
  const Interpolation(
    this.open,
    this.close, {
    this.rules = const [IncludeRule.self],
    this.scope = Scopes.interpolation,
  });

  /// Text that opens the expression.
  final String open;

  /// Text that closes the expression.
  final String close;

  /// Rules inside the expression.
  final List<Rule> rules;

  /// Scope of the expression.
  final String scope;

  @override
  List<Rule> expand() {
    final inner = <Rule>[...rules];
    if (close == '}') {
      final braces = RegionRule(begin: r'\{', end: r'\}', rules: inner);
      inner.insert(0, braces);
    }
    return [
      RegionRule(
        begin: _escape(open),
        end: _escape(close),
        scope: scope,
        rules: inner,
      ),
    ];
  }
}

/// Numeric literals: decimals, floats with exponents, and hexadecimal,
/// binary and octal forms.
///
/// [separator] is the digit separator (`_`, or `'` in C++), or `null`.
/// [suffix] is a pattern for type suffixes, such as `[uUlLfF]*` or `n?`.
final class Numbers extends BlockRule {
  /// Creates a number block.
  const Numbers({
    this.hex = true,
    this.binary = true,
    this.octal = true,
    this.separator = '_',
    this.suffix = '',
    this.scope = Scopes.number,
  });

  /// Whether `0x…` is a number.
  final bool hex;

  /// Whether `0b…` is a number.
  final bool binary;

  /// Whether `0o…` is a number.
  final bool octal;

  /// Digit separator, or `null`.
  final String? separator;

  /// Pattern for a suffix after the number.
  final String suffix;

  /// Scope of numbers.
  final String scope;

  @override
  List<Rule> expand() {
    final separator = this.separator;
    String run(String digits) {
      if (separator == null) return '[$digits]+';
      final withSeparator = '$digits${_escapeClass(separator)}';
      return '[$digits](?:[$withSeparator]*[$digits])?';
    }

    final decimal =
        '(?:${run('0-9')}(?:\\.${run('0-9')})?|\\.${run('0-9')})'
        '(?:[eE][+-]?${run('0-9')})?';
    final forms = [
      if (hex) '0[xX]${run('0-9a-fA-F')}',
      if (binary) '0[bB]${run('01')}',
      if (octal) '0[oO]${run('0-7')}',
      decimal,
    ];
    final suffix = this.suffix.isEmpty ? '' : '(?:${this.suffix})';
    return [
      TokenRule(
        '(?<![\\w\$.])(?:${forms.join('|')})$suffix(?![\\w\$])',
        scope: scope,
      ),
    ];
  }
}

/// Runs of operator characters, such as `+`, `==` or `>>=`.
final class Operators extends BlockRule {
  /// Creates an operator block matching runs of [chars].
  const Operators([
    this.chars = '+-*/%=<>!&|^~?:',
    this.scope = Scopes.operator,
  ]);

  /// Characters that make up operators.
  final String chars;

  /// Scope of operators.
  final String scope;

  @override
  List<Rule> expand() => [TokenRule('[${_escapeClass(chars)}]+', scope: scope)];
}

/// Annotations, attributes and decorators, such as `@override` or
/// `@app.route`.
final class Annotation extends BlockRule {
  /// Creates an annotation block starting with [sigil].
  const Annotation([this.sigil = '@', this.scope = Scopes.meta]);

  /// Character that starts an annotation.
  final String sigil;

  /// Scope of annotations.
  final String scope;

  @override
  List<Rule> expand() => [
    TokenRule('${_escape(sigil)}[A-Za-z_][\\w.]*', scope: scope),
  ];
}

/// Preprocessor lines such as `#include <x>` or `#define X 1`, including
/// lines continued with a trailing backslash.
final class Preprocessor extends BlockRule {
  /// Creates a preprocessor block starting with [sigil].
  const Preprocessor([this.sigil = '#', this.scope = Scopes.meta]);

  /// Character that starts a directive.
  final String sigil;

  /// Scope of directives.
  final String scope;

  @override
  List<Rule> expand() => [
    TokenRule(
      '^[ \\t]*${_escape(sigil)}[ \\t]*[A-Za-z_]\\w*(?:[^\\n\\\\]|\\\\[\\s\\S])*',
      scope: scope,
    ),
  ];
}

/// Common heuristics for identifiers that are not keywords, for use in
/// [KeywordRule.otherwise].
abstract final class CommonRules {
  /// A capitalised identifier is a type (`Foo`, `_Bar`).
  static const capitalizedType = TokenRule(
    r'_*[A-Z][\w$]*',
    scope: Scopes.type,
  );

  /// An identifier followed by `(` or `<T>(` is a function.
  static const functionCall = TokenRule(
    r'[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
    scope: Scopes.function,
  );

  /// After a `.`, a called name is a function (`list.add(`).
  static const memberCall = TokenRule(
    r'(?<=\.)[A-Za-z_$][\w$]*(?=[ \t]*(?:<[^<>()\n]*>)?[ \t]*(?:\r?\n[ \t]*)?\()',
    scope: Scopes.function,
  );

  /// After a `.`, any other name is a plain member, never a keyword.
  static const member = TokenRule(r'(?<=\.)[A-Za-z_$][\w$]*');
}
