import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:val_highlight/val_highlight.dart';

/// Highlights code for widgets, with a result cache and background
/// isolates for large inputs.
///
/// Widgets use [CodeHighlighter.shared] unless given another. Create your
/// own to change the thresholds or to resolve Markdown code fences:
///
/// ```dart
/// final highlighter = CodeHighlighter(registry: allLanguagesRegistry());
/// ```
class CodeHighlighter {
  /// Creates a highlighter.
  CodeHighlighter({
    this.registry,
    this.isolateThreshold = 50000,
    this.cacheSize = 32,
  });

  /// The default highlighter used by widgets.
  static final CodeHighlighter shared = CodeHighlighter();

  /// Resolves languages named inside code, such as Markdown fences.
  final LanguageRegistry? registry;

  /// Inputs with at least this many characters are highlighted in a
  /// background isolate by [highlight]. On the web, which has no isolates,
  /// they are highlighted on the next event-loop turn instead.
  final int isolateThreshold;

  /// Number of results kept in the cache.
  final int cacheSize;

  final LinkedHashMap<(Grammar, String), HighlightResult> _cache =
      LinkedHashMap();

  /// Cached result for [code] in [language], if any.
  HighlightResult? cached(String code, Grammar language) {
    final key = (language, code);
    final result = _cache.remove(key);
    if (result != null) _cache[key] = result;
    return result;
  }

  /// Whether [highlight] would use a background isolate for [code].
  bool usesIsolate(String code) => code.length >= isolateThreshold;

  /// Highlights [code] on the current isolate.
  HighlightResult highlightSync(String code, Grammar language) {
    final hit = cached(code, language);
    if (hit != null) return hit;
    final result = Highlighter(
      registry: registry,
    ).highlight(code, language: language);
    _store(result);
    return result;
  }

  /// Highlights [code], using a background isolate for large inputs.
  Future<HighlightResult> highlight(String code, Grammar language) async {
    final hit = cached(code, language);
    if (hit != null) return hit;
    if (!usesIsolate(code)) return highlightSync(code, language);
    final result = await compute(_highlight, (code, language, registry));
    _store(result);
    return result;
  }

  /// Compiles [languages] ahead of time, one per idle frame, so the first
  /// code shown in each language has no compile delay (about 1–3 ms per
  /// language otherwise).
  Future<void> preload(Iterable<Grammar> languages) async {
    for (final language in languages) {
      await SchedulerBinding.instance.scheduleTask(
        language.validate,
        Priority.idle,
      );
    }
  }

  /// Empties the cache.
  void clearCache() => _cache.clear();

  void _store(HighlightResult result) {
    _cache[(result.language, result.code)] = result;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}

HighlightResult _highlight((String, Grammar, LanguageRegistry?) job) {
  final (code, language, registry) = job;
  return Highlighter(registry: registry).highlight(code, language: language);
}
