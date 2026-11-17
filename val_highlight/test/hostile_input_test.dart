// Input an attacker, a broken generator or a looping language model could
// produce. Highlighting must stay fast and must not throw.
import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import 'helpers.dart';

/// Every ASCII punctuation character, a letter, a digit and whitespace, plus
/// runs that used to take time quadratic in their length.
final _units = <String>[
  for (var c = 0x21; c < 0x7F; c++)
    if (!RegExp('[A-Za-z0-9]').hasMatch(String.fromCharCode(c)))
      String.fromCharCode(c),
  'a',
  '0',
  ' ',
  '\t',
  '\n',
  r'$a',
  '0x',
  '1e',
  '[a',
  '<a',
  r'${',
  '[[',
  r"'\",
  '[/',
  '[/]',
  r'/[\',
];

double _bestMillis(Highlighter highlighter, String code, Grammar language) {
  var best = double.infinity;
  for (var i = 0; i < 3; i++) {
    final watch = Stopwatch()..start();
    highlighter.highlight(code, language: language);
    final ms = watch.elapsedMicroseconds / 1000;
    if (ms < best) best = ms;
  }
  return best;
}

void main() {
  final registry = allLanguagesRegistry();
  final highlighter = Highlighter(registry: registry);

  test('long runs of one pattern take linear time', () {
    final slow = <String>[];
    for (final language in registry.languages) {
      for (final unit in _units) {
        String run(int length) => unit * (length ~/ unit.length);
        // Quadratic time grows 16 times from 1,000 to 4,000 characters;
        // linear time grows 4 times. Fast runs are skipped as noise, and a
        // slow one is measured again before it counts.
        bool quadratic() {
          final small = _bestMillis(highlighter, run(1000), language);
          final large = _bestMillis(highlighter, run(4000), language);
          return large > 10 && large > small * 10;
        }

        if (quadratic() && quadratic()) slow.add('${language.name} "$unit"');
      }
    }
    expect(slow, isEmpty);
  });

  test('huge delimiters are plain text, not an error', () {
    for (final (name, unit) in [
      ('csharp', '"'),
      ('markdown', '`'),
      ('markdown', '~'),
      ('swift', '#'),
      ('rust', 'r#'),
    ]) {
      final code = '${unit * 100000}\nx\n';
      final result = highlightChecked(code, registry.lookup(name)!);
      expect(result.code, code, reason: name);
    }
  });

  test('many distinct delimiters still highlight correctly', () {
    final bash = registry.lookup('bash')!;
    final code = [
      for (var i = 0; i < 300; i++) 'cat <<EOF_$i\nbody $i\nEOF_$i\necho $i',
    ].join('\n');
    final result = highlightChecked(code, bash);
    for (final i in [0, 150, 299]) {
      expect(scopeAt(result, 'body $i'), startsWith('string'), reason: '$i');
      expect(scopeAt(result, 'echo $i'), isNot(startsWith('string')));
    }
  });
}
