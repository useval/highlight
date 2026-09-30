import 'dart:typed_data';

/// Whether plain-Dart matchers are used. On by default on native
/// platforms; off on the web, where [RegExp] runs as machine code and is
/// faster. Results are identical either way.
bool fastMatchersEnabled = !_isWeb;

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// A pattern matched by plain Dart code instead of the platform's regular
/// expression engine.
///
/// Covers the subset of regular expressions that grammars mostly use:
/// literals, character classes, `.`, `\d \w \s` and their negations,
/// greedy and lazy quantifiers on single characters, optional groups,
/// repeated groups whose repetitions can match only one way, alternation,
/// capture groups, `^`, `$`, `\b`, `\B`, lookaheads, and lookbehinds of
/// bounded length. Matching follows JavaScript semantics
/// exactly, backtracking included, so results are identical to [RegExp];
/// only the speed differs. Patterns outside the subset are not compiled and
/// keep using [RegExp].
///
/// Recursion depth is bounded by the pattern's length, never by the input.
/// On the web, where browsers compile regular expressions to machine code,
/// [RegExp] is faster, so the scanner only uses these on native platforms.
abstract final class FastPattern {
  /// End of the match starting exactly at [pos] in [s], or `-1`.
  int matchAt(String s, int pos);

  /// Number of capture groups tracked (0 unless compiled with captures).
  int get groupCount;

  /// Start of capture [group] (1-based) in the last successful [matchAt],
  /// or `-1` if it did not take part.
  int groupStart(int group);

  /// End of capture [group] in the last successful [matchAt], or `-1`.
  int groupEnd(int group);
}

/// Compiles [pattern] for [FastPattern.matchAt], or returns `null` when it
/// uses anything outside the supported subset. With [needsCaptures], the
/// positions of capture groups are tracked (see [FastPattern.groupStart]);
/// otherwise groups are matched without recording them.
FastPattern? compileFastPattern(
  String pattern, {
  required bool caseInsensitive,
  required bool unicode,
  required bool needsCaptures,
}) {
  if (unicode) return null;
  try {
    final parser = _Parser(pattern, caseInsensitive, needsCaptures);
    final piece = parser.alternation();
    if (parser.i != pattern.length) return null;
    final head = piece.head;
    if (head == null) return null;
    for (final tail in piece.tails) {
      tail.next = null;
    }
    final captures = parser.captures;
    if (!needsCaptures) {
      captures.count = 0;
    } else {
      captures.positions = Int32List(captures.count * 2);
    }
    return _Compiled(head, captures);
  } on _Unsupported {
    return null;
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}

final class _Unsupported implements Exception {
  const _Unsupported();
}

final class _Compiled extends FastPattern {
  _Compiled(this._root, this._captures);

  final _Node _root;
  final _Captures _captures;

  @override
  int matchAt(String s, int pos) {
    final positions = _captures.positions;
    if (positions.isNotEmpty) positions.fillRange(0, positions.length, -1);
    return _root.m(s, pos);
  }

  @override
  int get groupCount => _captures.count;

  @override
  int groupStart(int group) => _captures.positions[group * 2 - 2];

  @override
  int groupEnd(int group) => _captures.positions[group * 2 - 1];
}

/// Capture positions shared by a compiled pattern's nodes: start and end
/// per group, `-1` when unset.
final class _Captures {
  int count = 0;
  Int32List positions = Int32List(0);
}

/// Records where capture [group] starts, undoing it if the rest fails.
final class _CaptureStart extends _Node {
  _CaptureStart(this.captures, this.group);

  final _Captures captures;
  final int group;

  @override
  int m(String s, int p) {
    final positions = captures.positions;
    final index = group * 2 - 2;
    final saved = positions[index];
    positions[index] = p;
    final r = cont(s, p);
    if (r < 0) positions[index] = saved;
    return r;
  }
}

/// Records where capture [group] ends, undoing it if the rest fails.
final class _CaptureEnd extends _Node {
  _CaptureEnd(this.captures, this.group);

  final _Captures captures;
  final int group;

  @override
  int m(String s, int p) {
    final positions = captures.positions;
    final index = group * 2 - 1;
    final saved = positions[index];
    positions[index] = p;
    final r = cont(s, p);
    if (r < 0) positions[index] = saved;
    return r;
  }
}

// ---------------------------------------------------------------------------
// Character sets

/// Non-ASCII members of a set: code units inside [ranges], or outside them
/// when [negated].
final class _Part {
  _Part(this.ranges, this.negated);

  final List<int> ranges; // inclusive pairs
  final bool negated;

  bool has(int c) {
    for (var i = 0; i < ranges.length; i += 2) {
      if (c >= ranges[i] && c <= ranges[i + 1]) return !negated;
    }
    return negated;
  }
}

/// A set of UTF-16 code units: a bitmap for ASCII, parts above.
final class _Set {
  final Uint32List ascii = Uint32List(4);
  final List<_Part> parts = [];
  bool negated = false;

  /// Whether the set names non-ASCII characters that have case.
  bool casedNonAscii = false;

  bool has(int c) {
    if (c < 128) return (ascii[c >> 5] >> (c & 31)) & 1 == 1;
    var inside = false;
    for (final part in parts) {
      if (part.has(c)) {
        inside = true;
        break;
      }
    }
    return inside != negated;
  }

  void addRange(int from, int to, {bool cased = true}) {
    for (var c = from; c <= to && c < 128; c++) {
      ascii[c >> 5] |= 1 << (c & 31);
    }
    if (to >= 128) {
      parts.add(_Part([from < 128 ? 128 : from, to], false));
      if (cased) casedNonAscii = true;
    }
  }

  void add(int c) => addRange(c, c);

  void addSet(_Set other) {
    for (var i = 0; i < 4; i++) {
      ascii[i] |= other.ascii[i];
    }
    if (other.negated) {
      // Non-ASCII of `other` is "not in any of its parts".
      if (other.parts.length > 1) throw const _Unsupported();
      final ranges = other.parts.isEmpty ? <int>[] : other.parts.single.ranges;
      final negatedPart = other.parts.isEmpty
          ? true
          : !other.parts.single.negated;
      parts.add(_Part(ranges, negatedPart));
    } else {
      parts.addAll(other.parts);
    }
    casedNonAscii |= other.casedNonAscii;
  }

  void invert() {
    for (var i = 0; i < 4; i++) {
      ascii[i] = ~ascii[i];
    }
    negated = !negated;
  }

  void foldCase() {
    for (var c = 0x41; c <= 0x5A; c++) {
      final lower = c + 32;
      final hasUpper = (ascii[c >> 5] >> (c & 31)) & 1 == 1;
      final hasLower = (ascii[lower >> 5] >> (lower & 31)) & 1 == 1;
      if (hasUpper || hasLower) {
        ascii[c >> 5] |= 1 << (c & 31);
        ascii[lower >> 5] |= 1 << (lower & 31);
      }
    }
  }
}

_Set _digits() => _Set()..addRange(0x30, 0x39);

_Set _word() => _Set()
  ..addRange(0x30, 0x39)
  ..addRange(0x41, 0x5A)
  ..addRange(0x61, 0x7A)
  ..add(0x5F);

/// JavaScript's `\s`.
_Set _space() {
  final set = _Set()
    ..add(0x20)
    ..addRange(0x09, 0x0D);
  set.parts.add(
    _Part(const [
      0xA0, 0xA0, 0x1680, 0x1680, 0x2000, 0x200A, 0x2028, 0x2029, //
      0x202F, 0x202F, 0x205F, 0x205F, 0x3000, 0x3000, 0xFEFF, 0xFEFF,
    ], false),
  );
  return set;
}

_Set _complement(_Set set) => set..invert();

/// `.`: anything but a line terminator.
_Set _dot() {
  final set = _Set()
    ..addRange(0, 127)
    ..parts.add(_Part(const [0x2028, 0x2029], true));
  set.ascii[0] &= ~((1 << 0x0A) | (1 << 0x0D));
  return set;
}

bool _isWord(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F;

bool _isLineTerminator(int c) =>
    c == 0x0A || c == 0x0D || c == 0x2028 || c == 0x2029;

// ---------------------------------------------------------------------------
// Nodes. Each node matches at a position and then continues with [next];
// `m` returns the end of the whole match or -1. The branches of a group are
// linked to whatever follows the group, so backtracking is recursion.

abstract class _Node {
  _Node? next;

  int m(String s, int p);

  int cont(String s, int p) {
    final n = next;
    return n == null ? p : n.m(s, p);
  }
}

final class _Empty extends _Node {
  @override
  int m(String s, int p) => cont(s, p);
}

/// A character class repeated `min..max` times.
final class _Repeat extends _Node {
  _Repeat(this.set, this.min, this.max, this.lazy);

  final _Set set;
  final int min;
  final int max; // -1: unbounded
  final bool lazy;

  @override
  int m(String s, int p) {
    final length = s.length;
    if (lazy) {
      var n = 0;
      while (true) {
        if (n >= min) {
          final r = cont(s, p + n);
          if (r >= 0) return r;
        }
        if ((max >= 0 && n >= max) ||
            p + n >= length ||
            !set.has(s.codeUnitAt(p + n))) {
          return -1;
        }
        n++;
      }
    }
    var n = 0;
    while ((max < 0 || n < max) &&
        p + n < length &&
        set.has(s.codeUnitAt(p + n))) {
      n++;
    }
    if (n < min) return -1;
    if (next == null) return p + n;
    for (var k = n; k >= min; k--) {
      final r = cont(s, p + k);
      if (r >= 0) return r;
    }
    return -1;
  }
}

/// A character class, exactly once.
final class _One extends _Node {
  _One(this.set);

  final _Set set;

  @override
  int m(String s, int p) {
    if (p >= s.length || !set.has(s.codeUnitAt(p))) return -1;
    return cont(s, p + 1);
  }
}

/// A run of literal characters.
final class _Literal extends _Node {
  _Literal(this.text, this.caseInsensitive);

  final String text;
  final bool caseInsensitive;

  @override
  int m(String s, int p) {
    final n = text.length;
    if (p + n > s.length) return -1;
    if (caseInsensitive) {
      for (var i = 0; i < n; i++) {
        var a = s.codeUnitAt(p + i);
        var b = text.codeUnitAt(i);
        if (a >= 0x41 && a <= 0x5A) a += 32;
        if (b >= 0x41 && b <= 0x5A) b += 32;
        if (a != b) return -1;
      }
    } else {
      for (var i = 0; i < n; i++) {
        if (s.codeUnitAt(p + i) != text.codeUnitAt(i)) return -1;
      }
    }
    return cont(s, p + n);
  }
}

/// Alternatives, tried in order. A `null` branch is empty and continues
/// with this node's own [next].
final class _Alternation extends _Node {
  _Alternation(this.branches);

  final List<_Node?> branches;

  @override
  int m(String s, int p) {
    for (final branch in branches) {
      final r = branch == null ? cont(s, p) : branch.m(s, p);
      if (r >= 0) return r;
    }
    return -1;
  }
}

/// `(…)?`: the body if the rest then matches, otherwise skip it (the
/// reverse order when lazy). The body's ends link to [next].
final class _Optional extends _Node {
  _Optional(this.body, this.lazy);

  final _Node body;
  final bool lazy;

  @override
  int m(String s, int p) {
    if (lazy) {
      final r = cont(s, p);
      return r >= 0 ? r : body.m(s, p);
    }
    final r = body.m(s, p);
    return r >= 0 ? r : cont(s, p);
  }
}

final class _LineStart extends _Node {
  @override
  int m(String s, int p) {
    if (p > 0 && !_isLineTerminator(s.codeUnitAt(p - 1))) return -1;
    return cont(s, p);
  }
}

final class _LineEnd extends _Node {
  @override
  int m(String s, int p) {
    if (p < s.length && !_isLineTerminator(s.codeUnitAt(p))) return -1;
    return cont(s, p);
  }
}

final class _WordBoundary extends _Node {
  _WordBoundary(this.negated);

  final bool negated;

  @override
  int m(String s, int p) {
    final before = p > 0 && _isWord(s.codeUnitAt(p - 1));
    final after = p < s.length && _isWord(s.codeUnitAt(p));
    if ((before != after) == negated) return -1;
    return cont(s, p);
  }
}

final class _Lookahead extends _Node {
  _Lookahead(this.body, this.negated);

  final _Node body;
  final bool negated;

  @override
  int m(String s, int p) {
    if ((body.m(s, p) >= 0) == negated) return -1;
    return cont(s, p);
  }
}

/// A group repeated `min..max` times, where each repetition can match in
/// only one way (see [_Parser._deterministic]). Runs as a loop over
/// repetitions, backtracking only over how many were taken, so its depth
/// does not grow with the input.
final class _GroupRepeat extends _Node {
  _GroupRepeat(this.body, this.min, this.max, this.lazy);

  /// One repetition, matched on its own.
  final _Node body;
  final int min;
  final int max; // -1: unbounded
  final bool lazy;

  @override
  int m(String s, int p) {
    if (lazy) {
      var n = 0;
      var q = p;
      while (true) {
        if (n >= min) {
          final r = cont(s, q);
          if (r >= 0) return r;
        }
        if (max >= 0 && n >= max) return -1;
        final e = body.m(s, q);
        if (e <= q) return -1;
        q = e;
        n++;
      }
    }
    final ends = <int>[p];
    var q = p;
    while (max < 0 || ends.length - 1 < max) {
      final e = body.m(s, q);
      if (e <= q) break;
      q = e;
      ends.add(q);
    }
    if (ends.length - 1 < min) return -1;
    if (next == null) return q;
    for (var k = ends.length - 1; k >= min; k--) {
      final r = cont(s, ends[k]);
      if (r >= 0) return r;
    }
    return -1;
  }
}

/// Succeeds only at [target]; ends the body of a lookbehind.
final class _EndAt extends _Node {
  int target = 0;

  @override
  int m(String s, int p) => p == target ? p : -1;
}

/// A lookbehind whose body matches between [minLength] and [maxLength]
/// characters: tries each start so that the body ends exactly here.
final class _Lookbehind extends _Node {
  _Lookbehind(
    this.body,
    this.end,
    this.minLength,
    this.maxLength,
    this.negated,
  );

  final _Node body;
  final _EndAt end;
  final int minLength;
  final int maxLength;
  final bool negated;

  @override
  int m(String s, int p) {
    var found = false;
    final saved = end.target;
    end.target = p;
    for (var length = minLength; length <= maxLength; length++) {
      final start = p - length;
      if (start < 0) break;
      if (body.m(s, start) >= 0) {
        found = true;
        break;
      }
    }
    end.target = saved;
    if (found == negated) return -1;
    return cont(s, p);
  }
}

// ---------------------------------------------------------------------------
// Parser

/// A parsed piece of pattern: its first node (`null` when empty), the nodes
/// whose [_Node.next] must point at whatever follows, and its length range.
final class _Piece {
  _Piece(this.head, this.tails, this.minLength, this.maxLength);

  final _Node? head;
  final List<_Node> tails;
  final int minLength;
  final int maxLength; // -1: unbounded

  factory _Piece.single(_Node node, int minLength, int maxLength) =>
      _Piece(node, [node], minLength, maxLength);
}

final class _Parser {
  _Parser(this.src, this.caseInsensitive, this.needsCaptures);

  final String src;
  final bool caseInsensitive;
  final bool needsCaptures;
  final _Captures captures = _Captures();
  int i = 0;

  /// Depth of lookarounds being parsed; captures inside them are not
  /// supported.
  int _lookaround = 0;

  int get _c => src.codeUnitAt(i);
  bool _at(String s) => src.startsWith(s, i);

  _Piece alternation() {
    final branches = [_sequence()];
    while (i < src.length && _c == 0x7C) {
      i++;
      branches.add(_sequence());
    }
    if (branches.length == 1) return branches.single;
    final node = _Alternation([for (final b in branches) b.head]);
    var min = branches.first.minLength;
    var max = branches.first.maxLength;
    for (final b in branches.skip(1)) {
      if (b.minLength < min) min = b.minLength;
      if (max >= 0) {
        max = b.maxLength < 0 || b.maxLength > max ? b.maxLength : max;
      }
    }
    return _Piece(
      node,
      [
        for (final b in branches) ...b.tails,
        if (branches.any((b) => b.head == null)) node,
      ],
      min,
      max,
    );
  }

  _Piece _sequence() {
    final pieces = <_Piece>[];
    final literal = StringBuffer();

    void flush() {
      if (literal.isEmpty) return;
      final text = literal.toString();
      literal.clear();
      pieces.add(
        _Piece.single(
          _Literal(text, caseInsensitive),
          text.length,
          text.length,
        ),
      );
    }

    while (i < src.length && _c != 0x7C && _c != 0x29) {
      final term = _term();
      if (term is int) {
        literal.writeCharCode(term);
      } else {
        flush();
        pieces.add(term as _Piece);
      }
    }
    flush();

    // Empty pieces, such as `()`, match nothing and link nowhere.
    pieces.removeWhere((piece) => piece.head == null);
    if (pieces.isEmpty) return _Piece(null, const [], 0, 0);
    for (var k = 0; k < pieces.length - 1; k++) {
      for (final tail in pieces[k].tails) {
        tail.next = pieces[k + 1].head;
      }
    }
    var min = 0;
    var max = 0;
    for (final piece in pieces) {
      min += piece.minLength;
      max = max < 0 || piece.maxLength < 0 ? -1 : max + piece.maxLength;
    }
    return _Piece(pieces.first.head, pieces.last.tails, min, max);
  }

  /// A quantified atom, or the code unit of an unquantified literal (so
  /// runs of literals merge into one node).
  Object _term() {
    final atom = _atom();
    final (min, max, lazy) = _quantifier();
    if (min < 0) {
      if (atom is int) return atom;
      if (atom is _Set) return _Piece.single(_One(atom), 1, 1);
      return atom;
    }
    final _Set set;
    if (atom is int) {
      set = _Set()..add(atom);
      if (caseInsensitive) set.foldCase();
    } else if (atom is _Set) {
      set = atom;
    } else {
      final piece = atom as _Piece;
      if (piece.head == null) throw const _Unsupported();
      if (min == 0 && max == 1) {
        final node = _Optional(piece.head!, lazy);
        return _Piece(node, [...piece.tails, node], 0, piece.maxLength);
      }
      // Other repeats only when each repetition can match one way: then a
      // loop replaces recursion, which would grow with the input.
      if (!_deterministic(piece)) throw const _Unsupported();
      for (final tail in piece.tails) {
        tail.next = null;
      }
      return _Piece.single(
        _GroupRepeat(piece.head!, min, max, lazy),
        min * piece.minLength,
        max < 0 || piece.maxLength < 0 ? -1 : max * piece.maxLength,
      );
    }
    return _Piece.single(_Repeat(set, min, max, lazy), min, max);
  }

  /// Whether [piece] can match in at most one way at any position: it is a
  /// run of single characters and literals, or an alternation of such runs
  /// whose first characters differ.
  bool _deterministic(_Piece piece) {
    final head = piece.head!;
    final branches = head is _Alternation ? head.branches : [head];
    final firsts = <_Set>[];
    for (final branch in branches) {
      if (branch == null) return false;
      _Set? first;
      final tails = piece.tails.toSet();
      _Node? node = branch;
      while (node != null) {
        if (node is _One) {
          first ??= node.set;
        } else if (node is _Literal) {
          first ??= _Set()..add(node.text.codeUnitAt(0));
          if (node.caseInsensitive) first.foldCase();
        } else {
          return false;
        }
        if (tails.contains(node)) break;
        node = node.next;
      }
      firsts.add(first!);
    }
    for (var a = 0; a < firsts.length; a++) {
      for (var b = a + 1; b < firsts.length; b++) {
        if (_overlap(firsts[a], firsts[b])) return false;
      }
    }
    return true;
  }

  static bool _overlap(_Set a, _Set b) {
    for (var i = 0; i < 4; i++) {
      if (a.ascii[i] & b.ascii[i] != 0) return true;
    }
    // Conservatively, two sets that can both match non-ASCII overlap.
    final aNonAscii = a.negated || a.parts.isNotEmpty;
    final bNonAscii = b.negated || b.parts.isNotEmpty;
    return aNonAscii && bNonAscii;
  }

  /// `(min, max, lazy)`, or `min == -1` when there is no quantifier.
  (int, int, bool) _quantifier() {
    if (i >= src.length) return (-1, 0, false);
    int min;
    int max;
    switch (_c) {
      case 0x2A: // *
        i++;
        (min, max) = (0, -1);
      case 0x2B: // +
        i++;
        (min, max) = (1, -1);
      case 0x3F: // ?
        i++;
        (min, max) = (0, 1);
      case 0x7B: // {
        final q = RegExp(r'\{(\d+)(,(\d*))?\}').matchAsPrefix(src, i);
        if (q == null) return (-1, 0, false);
        i = q.end;
        min = int.parse(q[1]!);
        max = q[2] == null ? min : (q[3]!.isEmpty ? -1 : int.parse(q[3]!));
      default:
        return (-1, 0, false);
    }
    var lazy = false;
    if (i < src.length && _c == 0x3F) {
      lazy = true;
      i++;
    }
    return (min, max, lazy);
  }

  /// An `int` literal, a `_Set` for one character, or a `_Piece`.
  Object _atom() {
    final c = _c;
    switch (c) {
      case 0x28: // (
        return _group();
      case 0x5B: // [
        return _class();
      case 0x2E: // .
        i++;
        return _dot();
      case 0x5E: // ^
        i++;
        return _assertion(_LineStart());
      case 0x24: // $
        i++;
        return _assertion(_LineEnd());
      case 0x5C: // backslash
        return _escape();
      case 0x2A:
      case 0x2B:
      case 0x3F:
        throw const _Unsupported();
      default:
        i++;
        return _literal(c);
    }
  }

  /// A literal character. [_Literal] compares ASCII letters
  /// case-insensitively when needed; other cased characters are not
  /// supported case-insensitively.
  Object _literal(int c) {
    if (c >= 128 && caseInsensitive) throw const _Unsupported();
    return c;
  }

  /// An assertion cannot be quantified.
  _Piece _assertion(_Node node) {
    if (i < src.length && (_c == 0x2A || _c == 0x2B || _c == 0x3F)) {
      throw const _Unsupported();
    }
    return _Piece.single(node, 0, 0);
  }

  Object _group() {
    i++; // (
    if (_at('?=') || _at('?!')) {
      final negated = _at('?!');
      i += 2;
      _lookaround++;
      final body = alternation();
      _lookaround--;
      _close();
      final head = body.head ?? _Empty();
      for (final tail in body.tails) {
        tail.next = null;
      }
      return _assertion(_Lookahead(head, negated));
    }
    if (_at('?<=') || _at('?<!')) {
      final negated = _at('?<!');
      i += 3;
      _lookaround++;
      final body = alternation();
      _lookaround--;
      _close();
      if (body.maxLength < 0) throw const _Unsupported();
      final end = _EndAt();
      final head = body.head ?? end;
      for (final tail in body.tails) {
        tail.next = end;
      }
      return _assertion(
        _Lookbehind(head, end, body.minLength, body.maxLength, negated),
      );
    }
    var capturing = true;
    if (_at('?:')) {
      i += 2;
      capturing = false;
    } else if (_at('?<')) {
      final close = src.indexOf('>', i);
      if (close < 0) throw const _Unsupported();
      i = close + 1;
    } else if (_at('?')) {
      throw const _Unsupported();
    }
    // Groups are numbered by their opening parenthesis.
    final group = capturing ? ++captures.count : 0;
    final body = alternation();
    _close();
    if (!capturing || !needsCaptures) return body;
    if (_lookaround > 0) throw const _Unsupported();
    final start = _CaptureStart(captures, group);
    final end = _CaptureEnd(captures, group);
    start.next = body.head ?? end;
    for (final tail in body.tails) {
      tail.next = end;
    }
    return _Piece(start, [end], body.minLength, body.maxLength);
  }

  void _close() {
    if (i >= src.length || _c != 0x29) throw const _Unsupported();
    i++;
  }

  Object _escape() {
    i++; // backslash
    if (i >= src.length) throw const _Unsupported();
    final e = _c;
    i++;
    switch (e) {
      case 0x64: // d
        return _digits();
      case 0x44: // D
        return _complement(_digits());
      case 0x77: // w
        return _word();
      case 0x57: // W
        return _complement(_word());
      case 0x73: // s
        return _space();
      case 0x53: // S
        return _complement(_space());
      case 0x62: // b
        return _assertion(_WordBoundary(false));
      case 0x42: // B
        return _assertion(_WordBoundary(true));
      case 0x6B: // k
      case 0x70: // p
      case 0x50: // P
        throw const _Unsupported();
    }
    if (e >= 0x31 && e <= 0x39) throw const _Unsupported(); // backreference
    return _literal(_escapedCode(e));
  }

  int _escapedCode(int e) {
    switch (e) {
      case 0x6E:
        return 0x0A;
      case 0x72:
        return 0x0D;
      case 0x74:
        return 0x09;
      case 0x66:
        return 0x0C;
      case 0x76:
        return 0x0B;
      case 0x30:
        if (i < src.length && _c >= 0x30 && _c <= 0x39) {
          throw const _Unsupported(); // legacy octal
        }
        return 0x00;
      case 0x63: // cX
        final letter = _c;
        i++;
        return letter % 32;
      case 0x78: // xHH
        final value = int.parse(src.substring(i, i + 2), radix: 16);
        i += 2;
        return value;
      case 0x75: // uHHHH
        if (_c == 0x7B) throw const _Unsupported();
        final value = int.parse(src.substring(i, i + 4), radix: 16);
        i += 4;
        return value;
      default:
        return e;
    }
  }

  _Set _class() {
    i++; // [
    var negated = false;
    if (i < src.length && _c == 0x5E) {
      negated = true;
      i++;
    }
    final set = _Set();
    while (i < src.length && _c != 0x5D) {
      final (low, lowSet) = _classAtom();
      if (lowSet == null &&
          i + 1 < src.length &&
          _c == 0x2D &&
          src.codeUnitAt(i + 1) != 0x5D) {
        i++; // -
        final (high, highSet) = _classAtom();
        if (highSet != null) {
          set
            ..add(low)
            ..add(0x2D)
            ..addSet(highSet);
        } else {
          if (high < low) throw const _Unsupported();
          set.addRange(low, high);
        }
      } else if (lowSet != null) {
        set.addSet(lowSet);
      } else {
        set.add(low);
      }
    }
    if (i >= src.length) throw const _Unsupported();
    i++; // ]
    if (caseInsensitive) {
      if (set.casedNonAscii) throw const _Unsupported();
      set.foldCase();
    }
    if (negated) set.invert();
    return set;
  }

  (int, _Set?) _classAtom() {
    final c = _c;
    i++;
    if (c != 0x5C) return (c, null);
    final e = _c;
    i++;
    switch (e) {
      case 0x64:
        return (0, _digits());
      case 0x44:
        return (0, _complement(_digits()));
      case 0x77:
        return (0, _word());
      case 0x57:
        return (0, _complement(_word()));
      case 0x73:
        return (0, _space());
      case 0x53:
        return (0, _complement(_space()));
      case 0x62:
        return (0x08, null);
      case 0x70:
      case 0x50:
      case 0x6B:
        throw const _Unsupported();
    }
    if (e >= 0x31 && e <= 0x39) throw const _Unsupported();
    return (_escapedCode(e), null);
  }
}
