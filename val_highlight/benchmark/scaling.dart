// How highlighting time grows with input size, and the cost of one
// keystroke with incremental highlighting. Run: just bench
import 'package:val_highlight/languages/dart.dart';
import 'package:val_highlight/val_highlight.dart';

const _unit = r'''
/// Doc comment
class Foo<T> extends Bar implements Baz {
  final int x = 0x1F; // trailing
  String greet(String name) => "Hello $name ${x + 1}";
  Future<void> run() async { await Future.delayed(const Duration(seconds: 1)); }
}
''';

const _repeats = [100, 200, 400, 800, 1600];
const _runs = 5;

void main() {
  const highlighter = Highlighter();
  for (var i = 0; i < 3; i++) {
    highlighter.highlight(_unit * 50, language: dartLanguage).toHtml();
  }

  print('lines    chars   highlight + HTML    MB/s');
  for (final n in _repeats) {
    final code = _unit * n;
    final micros = _best(
      () => highlighter.highlight(code, language: dartLanguage).toHtml(),
    );
    print(
      '${(n * 6).toString().padLeft(5)}  '
      '${code.length.toString().padLeft(7)}  '
      '${_ms(micros).padLeft(17)}  '
      '${(code.length / micros).toStringAsFixed(1).padLeft(6)}',
    );
  }

  // One keystroke in the middle of the largest document.
  final code = _unit * _repeats.last;
  final document = IncrementalHighlighter(language: dartLanguage, text: code);
  final middle = code.length ~/ 2;
  var typed = code;
  final keystroke = _best(() {
    typed = '${typed.substring(0, middle)}x${typed.substring(middle)}';
    document.update(typed);
  });
  print(
    '\nIncremental: one keystroke in ${_repeats.last * 6} lines took '
    '${_ms(keystroke)} (re-scanned ${document.lastRescannedLines} lines).',
  );
}

int _best(void Function() body) {
  var best = -1;
  for (var i = 0; i < _runs; i++) {
    final watch = Stopwatch()..start();
    body();
    final us = watch.elapsedMicroseconds;
    if (best < 0 || us < best) best = us;
  }
  return best;
}

String _ms(int us) => '${(us / 1000).toStringAsFixed(1)} ms';
