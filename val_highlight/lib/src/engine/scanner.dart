import 'dart:typed_data';

import '../grammar/grammar.dart';
import '../registry.dart';
import 'compiler.dart';
import 'fast_match.dart';
import 'regex_util.dart';
import 'scope_table.dart';

/// Zero-width matches allowed at one position before forcing progress.
const _maxZeroWidth = 32;

/// Deepest region nesting before new regions are treated as plain text.
const _maxDepth = 512;

/// Scanner state at one point: the active region states, innermost first.
///
/// Frames are immutable and share their parents, so saving the state at
/// every line start costs one pointer per line.
final class ScanFrame {
  /// Creates a frame for [state] with scope [stack] inside [parent], opened
  /// at offset [start].
  ScanFrame(this.state, this.stack, this.parent, [this.start = 0])
    : depth = parent == null ? 0 : parent.depth + 1;

  /// Offset where this frame's region began. Diagnostic only; not part of
  /// the scanner state compared by [sameAs].
  final int start;

  /// Rules active in this frame.
  final CompiledState state;

  /// Scope stack id for plain text in this frame.
  final int stack;

  /// Enclosing frame, or `null` at the top level.
  final ScanFrame? parent;

  /// Nesting depth; the top level is `0`.
  final int depth;

  /// The innermost enclosing frame (possibly this one) that runs an
  /// embedded language, or `null`. Its end closes it from any depth.
  late final ScanFrame? embedOwner = state.embedded ? this : parent?.embedOwner;

  /// Whether [other] describes the same scanner state.
  bool sameAs(ScanFrame? other) {
    ScanFrame? a = this;
    var b = other;
    while (a != null && b != null) {
      if (identical(a, b)) return true;
      if (!identical(a.state, b.state) || a.stack != b.stack) return false;
      a = a.parent;
      b = b.parent;
    }
    return a == null && b == null;
  }
}

/// Offsets where each line starts. Line `0` starts at `0`; every `\n`
/// starts a new line.
Int32List computeLineStarts(String code) {
  var count = 1;
  for (var i = 0; i < code.length; i++) {
    if (code.codeUnitAt(i) == 0x0A) count++;
  }
  final starts = Int32List(count);
  var line = 1;
  for (var i = 0; i < code.length; i++) {
    if (code.codeUnitAt(i) == 0x0A) starts[line++] = i + 1;
  }
  return starts;
}

/// Growable pair of `end` and `stack` buffers.
///
/// Consecutive emits with the same stack are merged into one token.
final class TokenBuffer {
  /// Creates a buffer with room for [capacity] tokens.
  TokenBuffer(int capacity)
    : ends = Int32List(capacity < 16 ? 16 : capacity),
      stacks = Int32List(capacity < 16 ? 16 : capacity);

  /// Token end offsets.
  Int32List ends;

  /// Token scope stacks.
  Int32List stacks;

  /// Number of tokens.
  int count = 0;

  int _last = 0;

  /// Offset covered so far.
  int get covered => _last;

  /// Extends coverage to [end] with [stack].
  void emit(int end, int stack) {
    if (end <= _last) return;
    if (count > 0 && stacks[count - 1] == stack) {
      ends[count - 1] = end;
    } else {
      if (count == ends.length) _grow();
      ends[count] = end;
      stacks[count] = stack;
      count++;
    }
    _last = end;
  }

  /// Appends tokens `from..to` of [ends] and [stacks], shifting their ends by
  /// [delta]. The first one merges with the last token when their stacks
  /// match, as [emit] would.
  void appendShifted(
    Int32List ends,
    Int32List stacks,
    int from,
    int to,
    int delta,
  ) {
    if (from >= to) return;
    emit(ends[from] + delta, stacks[from]);
    final count = to - from - 1;
    if (count <= 0) return;
    while (this.count + count > this.ends.length) {
      _grow();
    }
    this.ends.setRange(this.count, this.count + count, ends, from + 1);
    this.stacks.setRange(this.count, this.count + count, stacks, from + 1);
    if (delta != 0) {
      final target = this.ends;
      for (var i = this.count; i < this.count + count; i++) {
        target[i] += delta;
      }
    }
    this.count += count;
    _last = this.ends[this.count - 1];
  }

  void _grow() {
    final capacity = ends.length * 2;
    ends = Int32List(capacity)..setRange(0, count, ends);
    stacks = Int32List(capacity)..setRange(0, count, stacks);
  }
}

/// Decides whether scanning may stop at the start of [line], whose state is
/// [frame]. Used by incremental highlighting to stop once the new scan has
/// converged with the old one.
typedef StopAtLine = bool Function(int line, ScanFrame frame);

/// Splits source code into tokens.
///
/// Runs in time proportional to the input: the source is never copied, and
/// every match is searched from the current offset.
final class Scanner {
  /// Creates a scanner writing tokens for [code] into [out], interning
  /// scopes in [table].
  ///
  /// When [lineStarts] and [checkpoints] are given, the state at the start of
  /// every line is saved to [checkpoints], or `null` when a token spans the
  /// line start. [embeds] resolves [RegionRule.embedCapture] names.
  Scanner({
    required this.code,
    required this.table,
    required this.out,
    this.embeds,
    this.lineStarts,
    this.checkpoints,
  });

  /// Source being scanned.
  final String code;

  /// Scope table for the result.
  final ScopeTable table;

  /// Destination for tokens.
  final TokenBuffer out;

  /// Languages for embedded regions named by a capture.
  final LanguageRegistry? embeds;

  /// Line start offsets, for checkpointing.
  final Int32List? lineStarts;

  /// Per-line states, written while scanning.
  final List<ScanFrame?>? checkpoints;

  /// Whether states with a dispatch table use it. Turning this off scans
  /// every state with its combined expression; results are identical.
  /// For tests and benchmarks.
  static bool useDispatch = true;

  /// Whether branches use plain-Dart matchers where available instead of
  /// [RegExp]; results are identical. See [fastMatchersEnabled].
  static bool get useFastMatchers => fastMatchersEnabled;
  static set useFastMatchers(bool value) => fastMatchersEnabled = value;

  /// The frame the last [scan] finished in. Not the top level when a region
  /// was still open at the end of the input.
  ScanFrame? lastFrame;

  int _nextLine = 0;
  StopAtLine? _stop;
  int? _stoppedAt;

  // Next end match per embedding frame: (searched from, match or null).
  final Map<ScanFrame, (int, Match?)> _embedEnds = Map.identity();

  /// The first match of [owner]'s end at or after [pos].
  Match? _embedEnd(ScanFrame owner, int pos) {
    final cached = _embedEnds[owner];
    if (cached != null) {
      final (from, match) = cached;
      if (pos >= from && (match == null || pos <= match.start)) return match;
    }
    final it = owner.state.alternatives.first.alone
        .allMatches(code, pos)
        .iterator;
    final match = it.moveNext() ? it.current : null;
    _embedEnds[owner] = (pos, match);
    return match;
  }

  // Result of [_find].
  Match? _match;
  Alternative? _alternative;
  int _base = 0;

  /// Finds the leftmost match at or after [pos] in [state]; among matches
  /// at the same position, the earliest-listed branch wins. Sets [_match],
  /// [_alternative] and [_base] (the group offset of the branch's captures
  /// within [_match]).
  bool _find(CompiledState state, int pos) {
    final dispatch = useDispatch ? state.dispatch : null;
    if (dispatch == null) {
      final regex = state.regex;
      if (regex == null) return false;
      final it = regex.allMatches(code, pos).iterator;
      if (!it.moveNext()) return false;
      final match = it.current;
      final alternative = state.matched(match, code);
      _match = match;
      _alternative = alternative;
      _base = alternative.group;
      return true;
    }
    // First-character dispatch: skip positions where no branch can start,
    // and try only the branches that can.
    final ascii = dispatch.ascii;
    final nonAscii = dispatch.nonAscii;
    final lineAscii = dispatch.lineAscii;
    final lineNonAscii = dispatch.lineNonAscii;
    final length = code.length;
    var previous = pos == 0 ? 0x0A : code.codeUnitAt(pos - 1);
    for (var p = pos; p < length; p++) {
      final c = code.codeUnitAt(p);
      // `^` in multi-line mode matches after any line terminator.
      final atLineStart =
          previous == 0x0A ||
          previous == 0x0D ||
          previous == 0x2028 ||
          previous == 0x2029;
      previous = c;
      final candidates = atLineStart
          ? (c < 128 ? lineAscii[c] : lineNonAscii)
          : (c < 128 ? ascii[c] : nonAscii);
      if (candidates == null) continue;
      for (final alternative in candidates) {
        final fast = useFastMatchers ? alternative.fast : null;
        final Match? match;
        if (fast != null) {
          final end = fast.matchAt(code, p);
          match = end < 0 ? null : _PlainMatch.of(fast, code, p, end);
        } else {
          match = alternative.alone.matchAsPrefix(code, p);
        }
        if (match != null) {
          _match = match;
          _alternative = alternative;
          _base = 0;
          return true;
        }
      }
    }
    for (final alternative in dispatch.eof) {
      final match = alternative.alone.matchAsPrefix(code, length);
      if (match != null) {
        _match = match;
        _alternative = alternative;
        _base = 0;
        return true;
      }
    }
    return false;
  }

  /// Scans from [pos] in state [frame] to the end of the source, or until
  /// [stop] accepts a line start.
  ///
  /// [firstLine] is the first line whose start is at or after [pos]. Returns
  /// the offset where scanning stopped.
  int scan(ScanFrame frame, int pos, {int firstLine = 0, StopAtLine? stop}) {
    _nextLine = firstLine;
    _stop = stop;
    _stoppedAt = null;
    final length = code.length;
    var zeroWidthPos = -1;
    var zeroWidthCount = 0;

    _embedEnds.clear();
    while (pos < length) {
      final state = frame.state;
      var found = _find(state, pos);
      // Inside an embedded language, the embedding region's end wins over
      // anything that starts at or after it, and cuts short a token that
      // would run past it, as `</script>` ends a script even inside a
      // comment.
      ScanFrame? closing;
      final owner = frame.embedOwner;
      if (owner != null) {
        final embedEnd = _embedEnd(owner, pos);
        if (embedEnd != null) {
          final cut = embedEnd.start;
          final nested = !identical(owner, frame);
          final wins =
              !found ||
              (nested && cut <= _match!.start) ||
              (cut > _match!.start && cut < _match!.end) ||
              (cut == _match!.start && _match!.end > cut);
          if (wins && !(found && identical(_match, embedEnd))) {
            if (found && _match!.start < cut) {
              // Keep the part of the token before the end.
              final head = _match!.start;
              if (_lines(head, cut, frame)) return _stoppedAt!;
              out.emit(head, frame.stack);
              final token = _alternative!.token;
              out.emit(
                cut,
                token == null ? frame.stack : _scoped(frame.stack, token.scope),
              );
            }
            _match = embedEnd;
            _alternative = owner.state.alternatives.first;
            _base = 0;
            closing = owner;
            found = true;
          }
        }
      }
      if (!found) break;
      final match = _match!;
      final alternative = _alternative!;
      final base = _base;
      final start = match.start;
      final end = match.end;

      var forced = false;
      if (start == end) {
        if (start == zeroWidthPos) {
          forced = ++zeroWidthCount > _maxZeroWidth;
        } else {
          zeroWidthPos = start;
          zeroWidthCount = 1;
        }
      }
      // Zero-width tokens and keywords, and runaway loops, consume one char.
      final consumesOneChar =
          forced ||
          (start == end &&
              (alternative.kind == AlternativeKind.token ||
                  alternative.kind == AlternativeKind.keyword));
      final stepEnd = consumesOneChar ? start + 1 : end;

      if (_lines(start, stepEnd, frame)) return _stoppedAt!;
      out.emit(start, frame.stack);

      if (consumesOneChar) {
        out.emit(start + 1, frame.stack);
        pos = start + 1;
        zeroWidthCount = 0;
        continue;
      }

      switch (alternative.kind) {
        case AlternativeKind.end:
          final region = alternative.region!;
          final closed = closing ?? frame;
          _emitCaptured(
            match,
            base,
            _scoped(closed.stack, region.endScope),
            region.endCaptures,
            alternative.captureOrder,
          );
          frame = closed.parent!;

        case AlternativeKind.token:
          final token = alternative.token!;
          _emitCaptured(
            match,
            base,
            _scoped(frame.stack, token.scope),
            token.captures,
            alternative.captureOrder,
          );

        case AlternativeKind.region:
          final region = alternative.region!;
          if (frame.depth >= _maxDepth) {
            out.emit(end, frame.stack);
            break;
          }
          final stack = _scoped(frame.stack, region.scope);
          _emitCaptured(
            match,
            base,
            _scoped(stack, region.beginScope),
            region.beginCaptures,
            alternative.captureOrder,
          );
          frame = ScanFrame(
            _enter(state, alternative, match, base),
            stack,
            frame,
            start,
          );

        case AlternativeKind.keyword:
          _keyword(alternative.keywords!, match, frame.stack);
      }
      pos = out.covered > end ? out.covered : end;
    }

    lastFrame = frame;
    if (_lines(length, length, frame)) return _stoppedAt!;
    out.emit(length, frame.stack);
    return length;
  }

  /// Records checkpoints for line starts up to [start] (state [frame]) and
  /// marks line starts inside `(start, stepEnd)` as unusable. Returns `true`
  /// if [_stop] accepted a line, after emitting plain text up to it.
  bool _lines(int start, int stepEnd, ScanFrame frame) {
    final starts = lineStarts;
    final saved = checkpoints;
    if (starts == null || saved == null) return false;
    final count = starts.length;
    while (_nextLine < count && starts[_nextLine] <= start) {
      final line = _nextLine;
      saved[line] = frame;
      _nextLine++;
      final stop = _stop;
      if (stop != null && stop(line, frame)) {
        out.emit(starts[line], frame.stack);
        _stoppedAt = starts[line];
        return true;
      }
    }
    while (_nextLine < count && starts[_nextLine] < stepEnd) {
      saved[_nextLine++] = null;
    }
    return false;
  }

  int _scoped(int stack, String? scope) =>
      scope == null ? stack : table.push(stack, scope);

  CompiledState _enter(
    CompiledState state,
    Alternative alternative,
    Match match,
    int base,
  ) {
    final region = alternative.region!;
    final end = region.endReferencesBegin
        ? substituteBeginRefs(region.end, (n) => match.group(base + n))
        : null;
    Grammar? embed = region.embed;
    final capture = region.embedCapture;
    final embeds = this.embeds;
    if (capture != null && embeds != null) {
      final name = match.group(base + capture)?.trim();
      if (name != null && name.isNotEmpty) {
        embed = embeds.resolve(name) ?? embed;
      }
    }
    if (end == null && identical(embed, region.embed)) {
      return state.owner.inner(alternative);
    }
    return state.owner.stateFor(region, end: end, embed: embed);
  }

  void _keyword(CompiledKeywords keywords, Match match, int stack) {
    final start = match.start;
    final end = match.end;
    final scope = keywords.scopeOf(code, start, end);
    if (scope != null) {
      out.emit(end, table.push(stack, scope));
      return;
    }
    for (final (rule, regex, fast) in keywords.otherwise) {
      final Match? fallback;
      if (fast != null && useFastMatchers) {
        final end = fast.matchAt(code, start);
        fallback = end < 0 ? null : _PlainMatch.of(fast, code, start, end);
      } else {
        fallback = regex.matchAsPrefix(code, start);
      }
      if (fallback == null || fallback.end == start) continue;
      _emitCaptured(
        fallback,
        0,
        _scoped(stack, rule.scope),
        rule.captures,
        rule.captures.keys.toList()..sort(),
      );
      return;
    }
    out.emit(end, stack);
  }

  /// Emits `match` as [stack], with [captures] (relative to [group]) scoped
  /// on top, visiting group numbers in [order]. Captured groups must be in
  /// order and must not overlap.
  void _emitCaptured(
    Match match,
    int group,
    int stack,
    Map<int, String> captures,
    List<int> order,
  ) {
    final end = match.end;
    if (captures.isEmpty) {
      out.emit(end, stack);
      return;
    }
    var cursor = match.start;
    for (final number in order) {
      final text = match.group(group + number);
      if (text == null || text.isEmpty) continue;
      final at = code.indexOf(text, cursor);
      if (at < 0 || at + text.length > end) continue;
      out.emit(at, stack);
      out.emit(at + text.length, table.push(stack, captures[number]!));
      cursor = at + text.length;
    }
    out.emit(end, stack);
  }
}

/// A match produced by a plain-Dart matcher. Capture groups are read from
/// the matcher itself, so they are valid until its next match; the scanner
/// uses them before matching again.
final class _PlainMatch implements Match {
  _PlainMatch(this.input, this.start, this.end, this._fast);

  /// A match from [fast].
  factory _PlainMatch.of(FastPattern fast, String input, int start, int end) =>
      _PlainMatch(input, start, end, fast.groupCount == 0 ? null : fast);

  @override
  final String input;

  @override
  final int start;

  @override
  final int end;

  final FastPattern? _fast;

  @override
  Pattern get pattern => throw UnsupportedError('no pattern');

  @override
  int get groupCount => _fast?.groupCount ?? 0;

  @override
  String? group(int group) {
    if (group == 0) return input.substring(start, end);
    final fast = _fast;
    if (fast == null || group < 0 || group > fast.groupCount) {
      throw RangeError.value(group, 'group');
    }
    final from = fast.groupStart(group);
    final to = fast.groupEnd(group);
    return from < 0 || to < 0 ? null : input.substring(from, to);
  }

  @override
  String? operator [](int group) => this.group(group);

  @override
  List<String?> groups(List<int> groupIndices) => [
    for (final index in groupIndices) group(index),
  ];
}
