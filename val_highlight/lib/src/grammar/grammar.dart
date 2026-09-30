import '../engine/compiler.dart';
import 'scopes.dart';

part 'blocks.dart';

/// A language grammar: an ordered list of [Rule]s plus a named repository of
/// reusable rule lists.
///
/// Grammars are immutable and usually `const`, so an unused grammar costs
/// nothing and is tree-shaken away. A grammar is compiled lazily the first
/// time it is used and the compiled form is cached for its lifetime.
///
/// When several rules can match, the one that starts earliest wins. Among
/// rules starting at the same position, the one listed first wins.
final class Grammar {
  /// Creates a grammar.
  const Grammar({
    required this.name,
    required this.rules,
    this.aliases = const [],
    this.fileExtensions = const [],
    this.fileNames = const [],
    this.repository = const {},
    this.caseInsensitive = false,
    this.unicode = false,
    this.shebangs = const [],
    this.signatures = const [],
    this.restartLine,
    this.detectable = true,
  });

  /// Canonical, lower-case language name, such as `dart`.
  final String name;

  /// Other names this language is known by, such as `js` for `javascript`.
  final List<String> aliases;

  /// File extensions without the dot, such as `dart` or `json`.
  final List<String> fileExtensions;

  /// Whole file names, such as `Dockerfile` or `CMakeLists.txt`. These take
  /// priority over [fileExtensions].
  final List<String> fileNames;

  /// Rules active at the top level of a document.
  final List<Rule> rules;

  /// Named rule lists that [IncludeRule] can reference.
  final Map<String, List<Rule>> repository;

  /// Whether patterns and keywords ignore case.
  final bool caseInsensitive;

  /// Whether patterns are compiled in unicode mode.
  final bool unicode;

  /// Interpreter names that identify this language in a `#!` first line,
  /// such as `python` or `bash`. Used by language detection.
  final List<String> shebangs;

  /// Patterns that strongly suggest this language, such as
  /// `^import 'package:`. Used by language detection.
  final List<String> signatures;

  /// Lines that no rule looks past, such as blank lines in Markdown.
  ///
  /// After an edit, `IncrementalHighlighter` normally re-scans from the line
  /// before the edit, which is enough when no rule's pattern reads more
  /// than one line ahead. A grammar whose rules can (a Markdown code span
  /// may wrap across a whole paragraph) sets this, and re-scanning then
  /// starts at the nearest earlier line matching it.
  final String? restartLine;

  /// Whether `LanguageDetector` may pick this grammar. Off for catch-all
  /// grammars such as plain text and the generic fallback.
  final bool detectable;

  /// Returns a new grammar based on this one.
  ///
  /// [rules] are placed *before* the existing top-level rules, so they take
  /// priority. [repository] entries are added, replacing entries with the
  /// same name. This is how you add or override syntax without rewriting a
  /// grammar.
  Grammar extend({
    String? name,
    List<Rule> rules = const [],
    Map<String, List<Rule>> repository = const {},
    List<String>? aliases,
    List<String>? fileExtensions,
    List<String>? fileNames,
  }) {
    return Grammar(
      name: name ?? this.name,
      rules: [...rules, ...this.rules],
      aliases: aliases ?? this.aliases,
      fileExtensions: fileExtensions ?? this.fileExtensions,
      fileNames: fileNames ?? this.fileNames,
      repository: {...this.repository, ...repository},
      caseInsensitive: caseInsensitive,
      unicode: unicode,
      shebangs: shebangs,
      signatures: signatures,
      restartLine: restartLine,
      detectable: detectable,
    );
  }

  /// Returns this grammar with its keyword tables changed.
  ///
  /// [add] maps a scope to words that get it, such as
  /// `{Scopes.keyword: ['defer']}`; a word already in another scope moves.
  /// Words in [remove] are removed from every scope, so they highlight like
  /// any other identifier. Applies to every [KeywordRule] in the grammar,
  /// including those inside regions and the repository.
  ///
  /// ```dart
  /// final myDart = dartLanguage.withKeywords(
  ///   add: {Scopes.typeBuiltin: ['Widget', 'BuildContext']},
  ///   remove: ['get', 'set'],
  /// );
  /// ```
  Grammar withKeywords({
    Map<String, List<String>> add = const {},
    Iterable<String> remove = const [],
  }) {
    final removed = {...remove, for (final words in add.values) ...words};
    Rule change(Rule rule) {
      switch (rule) {
        case KeywordRule():
          return KeywordRule(
            {
              for (final MapEntry(key: scope, value: words)
                  in rule.keywords.entries)
                scope: [
                  for (final word in words)
                    if (!removed.contains(word)) word,
                  ...?add[scope],
                ],
              for (final MapEntry(key: scope, value: words) in add.entries)
                if (!rule.keywords.containsKey(scope)) scope: words,
            },
            word: rule.word,
            otherwise: rule.otherwise,
          );
        case RegionRule():
          return RegionRule(
            begin: rule.begin,
            end: rule.end,
            scope: rule.scope,
            beginScope: rule.beginScope,
            endScope: rule.endScope,
            beginCaptures: rule.beginCaptures,
            endCaptures: rule.endCaptures,
            rules: [for (final inner in rule.rules) change(inner)],
            embed: rule.embed,
            embedCapture: rule.embedCapture,
            endReferencesBegin: rule.endReferencesBegin,
          );
        case TokenRule():
        case IncludeRule():
        case BlockRule():
          return rule;
      }
    }

    return Grammar(
      name: name,
      rules: [for (final rule in rules) change(rule)],
      aliases: aliases,
      fileExtensions: fileExtensions,
      fileNames: fileNames,
      repository: {
        for (final MapEntry(key: key, value: list) in repository.entries)
          key: [for (final rule in list) change(rule)],
      },
      caseInsensitive: caseInsensitive,
      unicode: unicode,
      shebangs: shebangs,
      signatures: signatures,
      restartLine: restartLine,
      detectable: detectable,
    );
  }

  /// Compiles every part of the grammar now, so mistakes surface at once
  /// instead of the first time a region is used.
  ///
  /// Throws [GrammarException] for an invalid pattern, an unknown include or
  /// an include cycle.
  void validate() => CompiledGrammar.of(this).compileAll();

  @override
  String toString() => 'Grammar($name)';
}

/// A single grammar rule.
///
/// Patterns are Dart [RegExp] sources compiled with `multiLine: true`, so `^`
/// and `$` match at line boundaries. Named capture groups are not allowed,
/// because rules are combined into a single expression per state.
sealed class Rule {
  /// Base constructor for rules.
  const Rule();
}

/// Matches [pattern] and marks the match with [scope].
///
/// [captures] maps capture group numbers inside [pattern] to scopes. Captured
/// groups must appear in order and must not overlap.
final class TokenRule extends Rule {
  /// Creates a token rule.
  const TokenRule(this.pattern, {this.scope, this.captures = const {}});

  /// Regular expression source to match.
  final String pattern;

  /// Scope for the whole match, or `null` for no scope.
  final String? scope;

  /// Scopes for capture groups inside [pattern], keyed by group number.
  final Map<int, String> captures;
}

/// A region that starts at [begin] and ends at [end], with its own [rules]
/// active in between.
///
/// Regions nest: strings containing interpolations, comments containing
/// nested comments, and so on. The [end] pattern is tried before [rules] at
/// the same position.
///
/// A region can hand its content to another language: set [embed] to a
/// grammar (for example CSS inside an HTML `<style>` element), or set
/// [embedCapture] to a capture group of [begin] whose text names the
/// language (for example the info string of a Markdown code fence). Named
/// languages are looked up in the `Highlighter`'s registry; when none is
/// found, [rules] apply instead. The [end] of an embedding region closes it
/// from any depth: a code fence ends even inside an unterminated string of
/// the embedded language, just as `</script>` ends a script in a browser.
///
/// Set [endReferencesBegin] when the end depends on what the begin matched,
/// such as a heredoc delimiter: `\1`–`\9` in [end] then stand for the text
/// of those capture groups of [begin].
final class RegionRule extends Rule {
  /// Creates a region rule.
  const RegionRule({
    required this.begin,
    required this.end,
    this.scope,
    this.beginScope,
    this.endScope,
    this.beginCaptures = const {},
    this.endCaptures = const {},
    this.rules = const [],
    this.embed,
    this.embedCapture,
    this.endReferencesBegin = false,
  });

  /// Pattern that opens the region.
  final String begin;

  /// Pattern that closes the region.
  final String end;

  /// Scope for the whole region, including both delimiters.
  final String? scope;

  /// Extra scope for the opening delimiter, nested inside [scope].
  final String? beginScope;

  /// Extra scope for the closing delimiter, nested inside [scope].
  final String? endScope;

  /// Scopes for capture groups inside [begin].
  final Map<int, String> beginCaptures;

  /// Scopes for capture groups inside [end].
  final Map<int, String> endCaptures;

  /// Rules active inside the region.
  final List<Rule> rules;

  /// Language used for the region's content instead of [rules].
  final Grammar? embed;

  /// Capture group of [begin] naming the language for the content.
  final int? embedCapture;

  /// Whether `\1`–`\9` in [end] refer to capture groups of [begin].
  final bool endReferencesBegin;
}

/// Matches words with [word] and scopes them by table lookup.
///
/// A lookup is much faster than one large alternation of every keyword.
/// [keywords] maps a scope to the words that get it. When a matched word is
/// not in the table, each rule in [otherwise] is tried at the same position,
/// which is how heuristics such as "capitalised words are types" work.
final class KeywordRule extends Rule {
  /// Creates a keyword rule.
  const KeywordRule(
    this.keywords, {
    this.word = r'(?<!\w)[A-Za-z_]\w*',
    this.otherwise = const [],
  });

  /// Scope to words, such as `{'keyword': ['if', 'else']}`.
  final Map<String, List<String>> keywords;

  /// Pattern for a single word.
  final String word;

  /// Rules tried, in order, on words that are not keywords.
  final List<TokenRule> otherwise;
}

/// Inserts the rules of a [Grammar.repository] entry in place.
///
/// Use [IncludeRule.self] to include the grammar's top-level rules.
final class IncludeRule extends Rule {
  /// Creates a reference to the repository entry called [name].
  const IncludeRule(this.name);

  /// Includes the grammar's top-level rules.
  static const self = IncludeRule(r'$self');

  /// Repository entry name, or `$self`.
  final String name;
}

/// Thrown when a grammar is invalid: a bad pattern, an unknown include or an
/// include cycle.
final class GrammarException implements Exception {
  /// Creates a grammar exception.
  const GrammarException(this.grammar, this.message);

  /// Name of the grammar that failed.
  final String grammar;

  /// What went wrong.
  final String message;

  @override
  String toString() => 'GrammarException($grammar): $message';
}
