/// Number of capture groups in [pattern].
///
/// Throws a [FormatException] if [pattern] is not a valid expression.
int countGroups(
  String pattern, {
  required bool caseSensitive,
  required bool unicode,
}) {
  // `p|` always matches the empty string, so the match exposes the count.
  final re = RegExp(
    '(?:$pattern)|',
    multiLine: true,
    caseSensitive: caseSensitive,
    unicode: unicode,
  );
  return re.firstMatch('')!.groupCount;
}

/// Rewrites numeric backreferences in [pattern] by adding [offset], so the
/// pattern still works after being wrapped into a larger expression.
String shiftBackrefs(String pattern, int offset) {
  if (offset == 0 || !pattern.contains(r'\')) return pattern;
  final out = StringBuffer();
  var inClass = false;
  final length = pattern.length;
  for (var i = 0; i < length; i++) {
    final c = pattern.codeUnitAt(i);
    if (c == 0x5C && i + 1 < length) {
      final next = pattern.codeUnitAt(i + 1);
      if (!inClass && next >= 0x31 && next <= 0x39) {
        var j = i + 1;
        while (j < length && _isDigit(pattern.codeUnitAt(j))) {
          j++;
        }
        final number = int.parse(pattern.substring(i + 1, j));
        out.write('\\${number + offset}');
        i = j - 1;
        continue;
      }
      out.writeCharCode(c);
      out.writeCharCode(next);
      i++;
      continue;
    }
    if (c == 0x5B) {
      inClass = true;
    } else if (c == 0x5D) {
      inClass = false;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// [end] with each backreference `\1`–`\9` replaced by the escaped text
/// of that group, as returned by [group] (`null` becomes empty).
String substituteBeginRefs(String end, String? Function(int group) group) {
  if (!end.contains(r'\')) return end;
  final out = StringBuffer();
  for (var i = 0; i < end.length; i++) {
    final c = end.codeUnitAt(i);
    if (c == 0x5C && i + 1 < end.length) {
      final next = end.codeUnitAt(i + 1);
      if (next >= 0x31 && next <= 0x39) {
        out.write(RegExp.escape(group(next - 0x30) ?? ''));
      } else {
        out
          ..writeCharCode(c)
          ..writeCharCode(next);
      }
      i++;
      continue;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}
