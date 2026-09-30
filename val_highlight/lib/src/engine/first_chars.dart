import 'dart:typed_data';

/// The characters a pattern can start matching at.
///
/// If a pattern matches at offset `p`, then either `p` is the end of input
/// and [eof] is set, or `code[p]` is in this set. The set may be larger than
/// necessary (that only costs speed) but never smaller (that would miss
/// matches). ASCII is tracked exactly; all non-ASCII characters share the
/// single [nonAscii] flag. When [lineStart] is set, a match can also only
/// start at the beginning of a line.
final class FirstChars {
  FirstChars._(this._ascii, this.nonAscii, this.eof);

  /// No characters.
  factory FirstChars.none() => FirstChars._(Uint32List(4), false, false);

  /// Every position, including the end of input.
  factory FirstChars.any() =>
      FirstChars._(Uint32List(4)..fillRange(0, 4, 0xFFFFFFFF), true, true);

  final Uint32List _ascii;

  /// Whether any non-ASCII character may start a match.
  bool nonAscii;

  /// Whether a match may start at the end of input.
  bool eof;

  /// Whether a match can only start at the beginning of a line.
  bool lineStart = false;

  bool get _isEmpty =>
      !nonAscii &&
      !eof &&
      _ascii[0] == 0 &&
      _ascii[1] == 0 &&
      _ascii[2] == 0 &&
      _ascii[3] == 0;

  /// Whether ASCII character [c] may start a match.
  bool hasAscii(int c) => (_ascii[c >> 5] >> (c & 31)) & 1 == 1;

  /// Number of ASCII characters in the set.
  int get asciiCount {
    var count = 0;
    for (var c = 0; c < 128; c++) {
      if (hasAscii(c)) count++;
    }
    return count;
  }

  void _add(int c) {
    if (c < 128) {
      _ascii[c >> 5] |= 1 << (c & 31);
    } else {
      nonAscii = true;
    }
  }

  void _addRange(int from, int to) {
    for (var c = from; c <= to && c < 128; c++) {
      _add(c);
    }
    if (to >= 128) nonAscii = true;
  }

  void _addAll(FirstChars other) {
    // A union is only line-start-bound if both sides are; an empty side
    // does not count.
    if (_isEmpty) {
      lineStart = other.lineStart;
    } else if (!other._isEmpty) {
      lineStart = lineStart && other.lineStart;
    }
    for (var i = 0; i < 4; i++) {
      _ascii[i] |= other._ascii[i];
    }
    nonAscii |= other.nonAscii;
    eof |= other.eof;
  }

  FirstChars _intersect(FirstChars other) {
    final result = FirstChars.none();
    for (var i = 0; i < 4; i++) {
      result._ascii[i] = _ascii[i] & other._ascii[i];
    }
    result.nonAscii = nonAscii && other.nonAscii;
    result.eof = eof && other.eof;
    result.lineStart = lineStart || other.lineStart;
    return result;
  }

  FirstChars _copy() {
    final copy = FirstChars.none().._addAll(this);
    return copy;
  }

  FirstChars _complementAscii() {
    final result = FirstChars.none();
    for (var i = 0; i < 4; i++) {
      result._ascii[i] = ~_ascii[i];
    }
    result.nonAscii = true;
    return result;
  }
}

/// Characters where [pattern] can start a match. Falls back to
/// [FirstChars.any] for anything the analysis does not understand.
FirstChars firstCharsOf(
  String pattern, {
  required bool caseInsensitive,
  required bool unicode,
}) {
  try {
    final parser = _Parser(pattern, caseInsensitive);
    final info = parser.alternation();
    if (parser.i != pattern.length) return FirstChars.any();
    final result = info.consume._copy();
    final empty = info.empty;
    if (empty != null) result._addAll(empty);
    return result;
  } on Object {
    return FirstChars.any();
  }
}

/// What a regex node can do at a position: the first characters it can
/// consume, and, if it can match without consuming, the constraint on the
/// position for that ([empty]; `null` if it always consumes).
final class _Info {
  _Info(this.consume, this.empty);

  final FirstChars consume;
  final FirstChars? empty;
}

FirstChars _chars(Iterable<int> codes) {
  final set = FirstChars.none();
  codes.forEach(set._add);
  return set;
}

FirstChars _digits() => FirstChars.none().._addRange(0x30, 0x39);

FirstChars _word() => FirstChars.none()
  .._addRange(0x30, 0x39)
  .._addRange(0x41, 0x5A)
  .._addRange(0x61, 0x7A)
  .._add(0x5F);

FirstChars _space() =>
    _chars(const [0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D])..nonAscii = true;

FirstChars _lineEnd() => _chars(const [0x0A, 0x0D])
  ..nonAscii = true
  ..eof = true;

final class _Parser {
  _Parser(this.src, this.caseInsensitive);

  final String src;
  final bool caseInsensitive;
  int i = 0;

  int get _c => src.codeUnitAt(i);
  bool _at(String s) => src.startsWith(s, i);

  _Info alternation() {
    var result = sequence();
    while (i < src.length && _c == 0x7C) {
      i++;
      final next = sequence();
      final consume = result.consume._copy().._addAll(next.consume);
      final a = result.empty;
      final b = next.empty;
      final empty = a == null
          ? b
          : b == null
          ? a
          : (a._copy().._addAll(b));
      result = _Info(consume, empty);
    }
    return result;
  }

  _Info sequence() {
    final consume = FirstChars.none();
    FirstChars? constraint = FirstChars.any();
    while (i < src.length && _c != 0x7C && _c != 0x29) {
      final item = term();
      if (constraint == null) continue;
      consume._addAll(item.consume._intersect(constraint));
      final empty = item.empty;
      constraint = empty == null ? null : constraint._intersect(empty);
    }
    return _Info(consume, constraint);
  }

  _Info term() {
    final atom = this.atom();
    if (i >= src.length) return atom;
    var min = -1;
    switch (_c) {
      case 0x2A: // *
      case 0x3F: // ?
        i++;
        min = 0;
      case 0x2B: // +
        i++;
        min = 1;
      case 0x7B: // {
        final quantifier = RegExp(r'\{(\d+)(,\d*)?\}').matchAsPrefix(src, i);
        if (quantifier != null) {
          i = quantifier.end;
          min = int.parse(quantifier[1]!);
        }
    }
    if (min < 0) return atom;
    if (i < src.length && _c == 0x3F) i++; // lazy
    return min == 0 ? _Info(atom.consume, FirstChars.any()) : atom;
  }

  _Info atom() {
    final c = _c;
    switch (c) {
      case 0x28: // (
        return group();
      case 0x5B: // [
        return _Info(characterClass(), null);
      case 0x2E: // .
        i++;
        return _Info(
          FirstChars.none()
            .._addRange(0, 127)
            .._ascii[0] &= ~((1 << 0x0A) | (1 << 0x0D))
            ..nonAscii = true,
          null,
        );
      case 0x5E: // ^
        i++;
        return _Info(FirstChars.none(), FirstChars.any()..lineStart = true);
      case 0x24: // $
        i++;
        return _Info(FirstChars.none(), _lineEnd());
      case 0x5C: // backslash
        return escape();
      default:
        i++;
        return _Info(_literal(c), null);
    }
  }

  FirstChars _literal(int c) {
    final set = FirstChars.none().._add(c);
    if (caseInsensitive) {
      if (c >= 0x41 && c <= 0x5A) set._add(c + 32);
      if (c >= 0x61 && c <= 0x7A) set._add(c - 32);
      set.nonAscii = true;
    }
    return set;
  }

  _Info group() {
    i++; // (
    if (_at('?:')) {
      i += 2;
    } else if (_at('?=')) {
      i += 2;
      final inner = alternation();
      _close();
      final position = inner.consume._copy();
      if (inner.empty != null) position._addAll(inner.empty!);
      return _Info(FirstChars.none(), position);
    } else if (_at('?!') || _at('?<=') || _at('?<!')) {
      i += _at('?!') ? 2 : 3;
      alternation();
      _close();
      return _Info(FirstChars.none(), FirstChars.any());
    } else if (_at('?<')) {
      final close = src.indexOf('>', i);
      if (close < 0) throw const FormatException('bad group name');
      i = close + 1;
    } else if (_at('?')) {
      throw const FormatException('unsupported group');
    }
    final inner = alternation();
    _close();
    return inner;
  }

  void _close() {
    if (i >= src.length || _c != 0x29) throw const FormatException('no )');
    i++;
  }

  _Info escape() {
    i++; // backslash
    final e = _c;
    i++;
    switch (e) {
      case 0x64: // d
        return _Info(_digits(), null);
      case 0x44: // D
        return _Info(_digits()._complementAscii(), null);
      case 0x77: // w
        return _Info(_word()..nonAscii = caseInsensitive, null);
      case 0x57: // W
        return _Info(_word()._complementAscii(), null);
      case 0x73: // s
        return _Info(_space(), null);
      case 0x53: // S
        return _Info(_space()._complementAscii(), null);
      case 0x62: // b
      case 0x42: // B
        return _Info(FirstChars.none(), FirstChars.any());
      case 0x6B: // k<name>
      case 0x70: // p{…}
      case 0x50: // P{…}
        throw const FormatException('unsupported escape');
    }
    if (e >= 0x31 && e <= 0x39) {
      while (i < src.length && _c >= 0x30 && _c <= 0x39) {
        i++;
      }
      // A backreference can match anything, including nothing.
      return _Info(FirstChars.any(), FirstChars.any());
    }
    return _Info(_literal(_escapedCode(e)), null);
  }

  /// The character an escape like `\n`, `\x41` or `\u{1F600}` stands for.
  /// [e] has already been consumed.
  int _escapedCode(int e) {
    switch (e) {
      case 0x6E:
        return 0x0A; // n
      case 0x72:
        return 0x0D; // r
      case 0x74:
        return 0x09; // t
      case 0x66:
        return 0x0C; // f
      case 0x76:
        return 0x0B; // v
      case 0x30:
        return 0x00; // 0
      case 0x63: // cX
        final letter = _c;
        i++;
        return letter % 32;
      case 0x78: // xHH
        final value = int.parse(src.substring(i, i + 2), radix: 16);
        i += 2;
        return value;
      case 0x75: // uHHHH or u{…}
        if (_c == 0x7B) {
          final close = src.indexOf('}', i);
          final value = int.parse(src.substring(i + 1, close), radix: 16);
          i = close + 1;
          return value;
        }
        final value = int.parse(src.substring(i, i + 4), radix: 16);
        i += 4;
        return value;
      default:
        return e;
    }
  }

  FirstChars characterClass() {
    i++; // [
    var negated = false;
    if (i < src.length && _c == 0x5E) {
      negated = true;
      i++;
    }
    final set = FirstChars.none();
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
            .._add(low)
            .._add(0x2D)
            .._addAll(highSet);
        } else {
          set._addRange(low, high);
          if (caseInsensitive) _foldRange(set, low, high);
        }
      } else if (lowSet != null) {
        set._addAll(lowSet);
      } else {
        set._addAll(_literal(low));
      }
    }
    if (i >= src.length) throw const FormatException('no ]');
    i++; // ]
    if (caseInsensitive) set.nonAscii = true;
    return negated ? set._complementAscii() : set;
  }

  void _foldRange(FirstChars set, int low, int high) {
    for (var c = low; c <= high && c < 128; c++) {
      set._addAll(_literal(c));
    }
  }

  /// One class member: a single character, or a set for `\d`, `\w`, `\s`
  /// and their negations.
  (int, FirstChars?) _classAtom() {
    final c = _c;
    i++;
    if (c != 0x5C) return (c, null);
    final e = _c;
    i++;
    switch (e) {
      case 0x64:
        return (0, _digits());
      case 0x44:
        return (0, _digits()._complementAscii());
      case 0x77:
        return (0, _word()..nonAscii = caseInsensitive);
      case 0x57:
        return (0, _word()._complementAscii());
      case 0x73:
        return (0, _space());
      case 0x53:
        return (0, _space()._complementAscii());
      case 0x62:
        return (0x08, null); // backspace inside a class
      case 0x70:
      case 0x50:
        throw const FormatException('unsupported escape');
    }
    return (_escapedCode(e), null);
  }
}
