import 'engine/compiler.dart';
import 'grammar/grammar.dart';
import 'highlighter.dart';
import 'registry.dart';

/// A detected language and how confident the detector is.
final class Detection {
  /// Creates a detection result.
  const Detection(this.language, this.score, {this.reason = 'content'});

  /// The detected language.
  final Grammar language;

  /// Detection score. Higher is more confident; only useful for comparing
  /// candidates for the same input.
  final double score;

  /// Why this language won: `file name`, `shebang` or `content`.
  final String reason;

  @override
  String toString() => 'Detection(${language.name}, $score, $reason)';
}

/// Guesses the language of a piece of code.
///
/// Checks run from cheapest and surest to most expensive:
///
/// 1. the file name's extension, when given;
/// 2. a `#!` first line against [Grammar.shebangs];
/// 3. a content score over the first [sampleSize] characters: each
///    [Grammar.signatures] pattern that matches adds [signatureWeight], and
///    each keyword, literal or built-in type found by highlighting the
///    sample adds [keywordWeight]. Invalid tokens subtract
///    [invalidPenalty].
///
/// This is a heuristic. When you know the language, pass it instead.
final class LanguageDetector {
  /// Creates a detector.
  const LanguageDetector({
    this.sampleSize = 4096,
    this.signatureWeight = 10,
    this.keywordWeight = 1,
    this.invalidPenalty = 5,
    this.minimumScore = 3,
  });

  /// Characters of input examined for the content score.
  final int sampleSize;

  /// Score added per matching signature pattern.
  final double signatureWeight;

  /// Score added per keyword-like token.
  final double keywordWeight;

  /// Score subtracted per invalid token.
  final double invalidPenalty;

  /// Content scores below this are treated as "unknown".
  final double minimumScore;

  /// Detects the language of [code] among [candidates], or returns `null`
  /// when nothing scores at least [minimumScore].
  Detection? detect(
    String code,
    Iterable<Grammar> candidates, {
    String? fileName,
  }) {
    final languages = [
      for (final language in candidates)
        if (language.detectable) language,
    ];
    if (fileName != null) {
      final byFile = LanguageRegistry(languages).forFileName(fileName);
      if (byFile != null) {
        return Detection(byFile, double.infinity, reason: 'file name');
      }
    }

    if (code.startsWith('#!')) {
      final lineEnd = code.indexOf('\n');
      final shebang = code.substring(2, lineEnd < 0 ? code.length : lineEnd);
      for (final language in languages) {
        for (final name in language.shebangs) {
          if (RegExp(
            '(^|[/\\s])${RegExp.escape(name)}(\\s|\$|[0-9.])',
          ).hasMatch(shebang)) {
            return Detection(language, double.infinity, reason: 'shebang');
          }
        }
      }
    }

    var sample = code;
    if (sample.length > sampleSize) {
      final cut = sample.lastIndexOf('\n', sampleSize);
      sample = sample.substring(0, cut > 0 ? cut : sampleSize);
    }

    Detection? best;
    for (final language in languages) {
      final score = _score(sample, language);
      if (score >= minimumScore && (best == null || score > best.score)) {
        best = Detection(language, score);
      }
    }
    return best;
  }

  double _score(String sample, Grammar language) {
    var score = 0.0;
    final compiled = CompiledGrammar.of(language);
    for (final signature in language.signatures) {
      if (compiled.regExp(signature).hasMatch(sample)) {
        score += signatureWeight;
      }
    }
    final result = const Highlighter().highlight(sample, language: language);
    final table = result.scopes;
    for (var i = 0; i < result.tokenCount; i++) {
      final scope = table.scopeOf(result.tokenStack(i));
      if (scope == null) continue;
      if (scope.startsWith('keyword') ||
          scope.startsWith('literal') ||
          scope.startsWith('type.builtin')) {
        score += keywordWeight;
      } else if (scope.startsWith('invalid')) {
        score -= invalidPenalty;
      }
    }
    return score;
  }
}
