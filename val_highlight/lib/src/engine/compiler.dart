import 'dart:typed_data';

import '../grammar/grammar.dart';
import 'fast_match.dart';
import 'first_chars.dart';
import 'regex_util.dart';

/// An alternative whose first-character set covers at least this many ASCII
/// characters can start almost anywhere. A state containing one is scanned
/// with its combined expression instead of first-character dispatch.
const _broadAlternative = 96;

/// What kind of rule an [Alternative] came from.
enum AlternativeKind {
  /// The end pattern of the enclosing region.
  end,

  /// A [TokenRule].
  token,

  /// The begin pattern of a [RegionRule].
  region,

  /// The word pattern of a [KeywordRule].
  keyword,
}

/// One branch of a state's combined expression.
final class Alternative {
  Alternative._(
    this._owner,
    this.kind,
    this.group,
    this.pattern, {
    this.token,
    this.region,
    this.keywords,
  }) : captureOrder = _captureOrder(kind, token, region);

  final CompiledGrammar _owner;

  /// Source pattern of this branch.
  final String pattern;

  /// Capture group numbers to scope, in ascending order.
  final List<int> captureOrder;

  /// This branch alone, for matching at a known position or searching.
  late final RegExp alone = _owner.regExp(pattern);

  /// This branch as a plain-Dart matcher, or `null` when the pattern is
  /// outside the supported subset or its capture groups are needed.
  late final FastPattern? fast = compileFastPattern(
    pattern,
    caseInsensitive: _owner.grammar.caseInsensitive,
    unicode: _owner.grammar.unicode,
    needsCaptures: _needsCaptures,
  );

  bool get _needsCaptures => switch (kind) {
    AlternativeKind.token => token!.captures.isNotEmpty,
    AlternativeKind.region =>
      region!.beginCaptures.isNotEmpty ||
          region!.embedCapture != null ||
          region!.endReferencesBegin,
    AlternativeKind.end => region!.endCaptures.isNotEmpty,
    AlternativeKind.keyword => false,
  };

  static List<int> _captureOrder(
    AlternativeKind kind,
    TokenRule? token,
    RegionRule? region,
  ) {
    final captures = switch (kind) {
      AlternativeKind.token => token!.captures,
      AlternativeKind.region => region!.beginCaptures,
      AlternativeKind.end => region!.endCaptures,
      AlternativeKind.keyword => const <int, String>{},
    };
    if (captures.isEmpty) return const [];
    return captures.keys.toList()..sort();
  }

  /// Rule kind.
  final AlternativeKind kind;

  /// Capture group that wraps this branch in the combined expression.
  final int group;

  /// Source rule when [kind] is [AlternativeKind.token].
  final TokenRule? token;

  /// Source rule when [kind] is [AlternativeKind.region] or
  /// [AlternativeKind.end].
  final RegionRule? region;

  /// Compiled keywords when [kind] is [AlternativeKind.keyword].
  final CompiledKeywords? keywords;

  CompiledState? _inner;
}

/// A [KeywordRule] prepared for scanning.
final class CompiledKeywords {
  CompiledKeywords._(this.lookup, this.otherwise, this.caseInsensitive) {
    for (final MapEntry(key: word, value: scope) in lookup.entries) {
      final hash = _hash(word, 0, word.length, false);
      (_byHash[hash] ??= []).add((word, scope));
    }
  }

  /// Word to scope.
  final Map<String, String> lookup;

  final Map<int, List<(String, String)>> _byHash = {};

  /// Scope of the word `code[start, end)`, or `null`. Reads the characters
  /// in place, without creating a string.
  String? scopeOf(String code, int start, int end) {
    final entries = _byHash[_hash(code, start, end, caseInsensitive)];
    if (entries == null) return null;
    final length = end - start;
    for (final (word, scope) in entries) {
      if (word.length != length) continue;
      var equal = true;
      for (var i = 0; i < length; i++) {
        var c = code.codeUnitAt(start + i);
        if (caseInsensitive && c >= 0x41 && c <= 0x5A) c += 32;
        if (c != word.codeUnitAt(i)) {
          equal = false;
          break;
        }
      }
      if (equal) return scope;
    }
    return null;
  }

  /// FNV-1a over the code units, lower-casing ASCII letters if [fold].
  static int _hash(String s, int start, int end, bool fold) {
    var hash = 0x811C9DC5;
    for (var i = start; i < end; i++) {
      var c = s.codeUnitAt(i);
      if (fold && c >= 0x41 && c <= 0x5A) c += 32;
      hash = ((hash ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Fallback rules with their compiled expressions and, where possible,
  /// plain-Dart matchers.
  final List<(TokenRule, RegExp, FastPattern?)> otherwise;

  /// Whether words are compared in lower case.
  final bool caseInsensitive;
}

/// The rules active at one nesting level, joined into a single expression.
final class CompiledState {
  CompiledState._(
    this.owner,
    this.regex,
    this.alternatives,
    this.region,
    this.dispatch,
    this.embedded,
  );

  /// Whether this state is another grammar's top level running inside an
  /// embedding region. Its end branch closes it from any nested depth.
  final bool embedded;

  /// Grammar that compiled this state. Regions entered from this state are
  /// resolved against its rules and repository.
  final CompiledGrammar owner;

  /// Combined expression, or `null` when no rule is active.
  final RegExp? regex;

  /// Branches of [regex] in priority order.
  final List<Alternative> alternatives;

  /// Region this state belongs to, or `null` for the top level.
  final RegionRule? region;

  /// First-character dispatch table, or `null` when this state is scanned
  /// with [regex].
  final Dispatch? dispatch;

  /// Per first character of a match, the index of the branch that last
  /// matched there. Checked first, since the same character usually starts
  /// the same kind of token.
  final Int16List _hints = Int16List(129);

  /// The branch that produced [match], a match of [regex] in [code].
  Alternative matched(RegExpMatch match, String code) {
    final start = match.start;
    var key = 128;
    if (start < code.length) {
      final c = code.codeUnitAt(start);
      if (c < 128) key = c;
    }
    final hint = _hints[key];
    if (match.group(alternatives[hint].group) != null) {
      return alternatives[hint];
    }
    for (var i = 0; i < alternatives.length; i++) {
      if (match.group(alternatives[i].group) != null) {
        _hints[key] = i;
        return alternatives[i];
      }
    }
    throw StateError('match did not come from any alternative');
  }
}

/// For each possible first character, the branches that can match there,
/// in priority order. Lets the scanner skip positions where no rule can
/// start and try only the rules that can.
final class Dispatch {
  Dispatch._(
    this.ascii,
    this.nonAscii,
    this.lineAscii,
    this.lineNonAscii,
    this.eof,
  );

  /// Candidates per ASCII character; `null` where no branch can start.
  final List<List<Alternative>?> ascii;

  /// Candidates for any non-ASCII character, or `null`.
  final List<Alternative>? nonAscii;

  /// Like [ascii], at the start of a line, where branches anchored with
  /// `^` can match too.
  final List<List<Alternative>?> lineAscii;

  /// Like [nonAscii], at the start of a line.
  final List<Alternative>? lineNonAscii;

  /// Candidates at the end of input.
  final List<Alternative> eof;

  /// Builds a dispatch table, or returns `null` if some branch can start
  /// almost anywhere, which makes dispatch slower than one combined search.
  static Dispatch? build(List<Alternative> alternatives, CompiledGrammar g) {
    if (alternatives.isEmpty) return null;
    final firsts = [
      for (final alternative in alternatives)
        firstCharsOf(
          alternative.pattern,
          caseInsensitive: g.grammar.caseInsensitive,
          unicode: g.grammar.unicode,
        ),
    ];
    for (var i = 0; i < firsts.length; i++) {
      final first = firsts[i];
      // Line-anchored branches are only tried at line starts, so they may
      // be broad. A broad branch with a plain-Dart matcher is fine too: a
      // failed attempt costs a character check. Only a broad branch that
      // needs RegExp at almost every position makes dispatch slower than
      // one combined search.
      if (!first.lineStart &&
          first.asciiCount >= _broadAlternative &&
          !(fastMatchersEnabled && alternatives[i].fast != null)) {
        return null;
      }
    }
    List<Alternative>? where(bool Function(FirstChars) test) {
      final list = [
        for (var i = 0; i < alternatives.length; i++)
          if (test(firsts[i])) alternatives[i],
      ];
      return list.isEmpty ? null : list;
    }

    return Dispatch._(
      [
        for (var c = 0; c < 128; c++)
          where((f) => !f.lineStart && f.hasAscii(c)),
      ],
      where((f) => !f.lineStart && f.nonAscii),
      [for (var c = 0; c < 128; c++) where((f) => f.hasAscii(c))],
      where((f) => f.nonAscii),
      where((f) => f.eof) ?? const [],
    );
  }
}

/// A [Grammar] prepared for scanning.
///
/// Compilation is lazy: the top-level state is built on first use and each
/// region's state is built the first time that region is entered.
final class CompiledGrammar {
  CompiledGrammar._(this.grammar);

  static final Expando<CompiledGrammar> _cache = Expando('CompiledGrammar');

  /// Compiled form of [grammar], cached for the grammar's lifetime.
  static CompiledGrammar of(Grammar grammar) =>
      _cache[grammar] ??= CompiledGrammar._(grammar);

  /// Source grammar.
  final Grammar grammar;

  final Map<(RegionRule, String?), CompiledState> _regionStates = {};
  final Map<(RegionRule, String?), CompiledState> _embeddedStates = {};
  final Map<KeywordRule, CompiledKeywords> _keywords = Map.identity();

  /// State for the top level of a document.
  late final CompiledState root = _compileState(grammar.rules, null);

  /// State entered when [alternative]'s region begins, using the region's
  /// own rules or static [RegionRule.embed]. Regions whose end depends on
  /// the begin match get an end with the references left empty; the scanner
  /// uses [stateFor] with the real text.
  CompiledState inner(Alternative alternative) {
    final region = alternative.region!;
    if (region.endReferencesBegin) {
      return stateFor(
        region,
        end: substituteBeginRefs(region.end, (_) => ''),
        embed: region.embed,
      );
    }
    return alternative._inner ??= stateFor(region, embed: region.embed);
  }

  /// State for the content of [region]: its own rules, or the top level of
  /// [embed]. [end] replaces the region's end pattern.
  CompiledState stateFor(RegionRule region, {String? end, Grammar? embed}) {
    if (embed != null) {
      final target = CompiledGrammar.of(embed);
      return target._embeddedStates.putIfAbsent((
        region,
        end,
      ), () => target._compileState(embed.rules, region, end, true));
    }
    return _regionStates.putIfAbsent((
      region,
      end,
    ), () => _compileState(region.rules, region, end));
  }

  /// Compiles every reachable state now, so grammar errors surface
  /// immediately instead of the first time a region is entered.
  ///
  /// Throws [GrammarException] if the grammar is invalid.
  void compileAll() {
    final seen = Set<CompiledState>.identity();
    final pending = [root];
    while (pending.isNotEmpty) {
      final state = pending.removeLast();
      if (!seen.add(state)) continue;
      for (final alternative in state.alternatives) {
        // Build plain-Dart matchers now too, so nothing compiles later.
        if (fastMatchersEnabled) alternative.fast;
        if (alternative.kind == AlternativeKind.region) {
          pending.add(state.owner.inner(alternative));
        }
      }
    }
  }

  /// Compiles [pattern] with the grammar's flags.
  RegExp regExp(String pattern) => RegExp(
    pattern,
    multiLine: true,
    caseSensitive: !grammar.caseInsensitive,
    unicode: grammar.unicode,
  );

  CompiledState _compileState(
    List<Rule> rules,
    RegionRule? region, [
    String? end,
    bool embedded = false,
  ]) {
    final alternatives = <Alternative>[];
    final parts = <String>[];
    var group = 1;

    void add(
      AlternativeKind kind,
      String pattern, {
      TokenRule? token,
      RegionRule? region,
      CompiledKeywords? keywords,
    }) {
      final count = _countGroups(pattern);
      parts.add('(${shiftBackrefs(pattern, group)})');
      alternatives.add(
        Alternative._(
          this,
          kind,
          group,
          pattern,
          token: token,
          region: region,
          keywords: keywords,
        ),
      );
      group += count + 1;
    }

    if (region != null) {
      add(AlternativeKind.end, end ?? region.end, region: region);
    }
    for (final rule in _flatten(rules, <String>{})) {
      switch (rule) {
        case TokenRule():
          add(AlternativeKind.token, rule.pattern, token: rule);
        case RegionRule():
          add(AlternativeKind.region, rule.begin, region: rule);
        case KeywordRule():
          add(
            AlternativeKind.keyword,
            rule.word,
            keywords: _compileKeywords(rule),
          );
        case IncludeRule():
        case BlockRule():
          throw StateError('includes and blocks are flattened first');
      }
    }

    final regex = parts.isEmpty ? null : regExp(parts.join('|'));
    return CompiledState._(
      this,
      regex,
      alternatives,
      region,
      Dispatch.build(alternatives, this),
      embedded,
    );
  }

  int _countGroups(String pattern) {
    try {
      return countGroups(
        pattern,
        caseSensitive: !grammar.caseInsensitive,
        unicode: grammar.unicode,
      );
    } on FormatException catch (e) {
      throw GrammarException(
        grammar.name,
        'invalid pattern /$pattern/: ${e.message}',
      );
    }
  }

  static final Expando<List<Rule>> _expansions = Expando('BlockRule');

  List<Rule> _flatten(List<Rule> rules, Set<String> visiting) {
    final out = <Rule>[];
    for (final rule in rules) {
      if (rule is BlockRule) {
        // Expanded once per block, so regions keep a stable identity.
        final expanded = _expansions[rule] ??= rule.expand();
        out.addAll(_flatten(expanded, visiting));
        continue;
      }
      if (rule is! IncludeRule) {
        out.add(rule);
        continue;
      }
      final name = rule.name;
      final target = name == IncludeRule.self.name
          ? grammar.rules
          : grammar.repository[name];
      if (target == null) {
        throw GrammarException(grammar.name, 'unknown include "$name"');
      }
      if (!visiting.add(name)) {
        throw GrammarException(grammar.name, 'include cycle through "$name"');
      }
      out.addAll(_flatten(target, visiting));
      visiting.remove(name);
    }
    return out;
  }

  CompiledKeywords _compileKeywords(KeywordRule rule) {
    return _keywords.putIfAbsent(rule, () {
      final insensitive = grammar.caseInsensitive;
      final lookup = <String, String>{};
      for (final MapEntry(key: scope, value: words) in rule.keywords.entries) {
        for (final word in words) {
          lookup[insensitive ? word.toLowerCase() : word] = scope;
        }
      }
      final otherwise = [
        for (final fallback in rule.otherwise)
          (
            fallback,
            _checkedRegExp(fallback.pattern),
            compileFastPattern(
              fallback.pattern,
              caseInsensitive: insensitive,
              unicode: grammar.unicode,
              needsCaptures: fallback.captures.isNotEmpty,
            ),
          ),
      ];
      return CompiledKeywords._(lookup, otherwise, insensitive);
    });
  }

  RegExp _checkedRegExp(String pattern) {
    _countGroups(pattern);
    return regExp(pattern);
  }
}
