// Highlighting speed per language, on ~256 KB of realistic source each.
//
// Runs anywhere Dart runs:
//   dart run benchmark/languages.dart                     (VM, JIT)
//   dart compile exe benchmark/languages.dart && ./…      (VM, AOT)
//   dart compile js benchmark/languages.dart -o b.js && node b.js   (web)
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import 'samples.dart';

const _size = 256 * 1024;
const _runs = 7;

void main() {
  final highlighter = Highlighter(registry: allLanguagesRegistry());
  print('language      KB    tokens     ms    MB/s');
  var totalChars = 0;
  var totalMicros = 0;
  for (final MapEntry(key: language, value: sample)
      in benchmarkSamples.entries) {
    final code = repeatTo(sample, _size);
    for (var i = 0; i < 3; i++) {
      highlighter.highlight(code, language: language);
    }
    var best = -1;
    var tokens = 0;
    for (var i = 0; i < _runs; i++) {
      final watch = Stopwatch()..start();
      tokens = highlighter.highlight(code, language: language).tokenCount;
      final us = watch.elapsedMicroseconds;
      if (best < 0 || us < best) best = us;
    }
    totalChars += code.length;
    totalMicros += best;
    print(
      '${language.name.padRight(12)}'
      '${(code.length / 1024).round().toString().padLeft(5)}'
      '${tokens.toString().padLeft(10)}'
      '${(best / 1000).toStringAsFixed(1).padLeft(7)}'
      '${(code.length / best).toStringAsFixed(1).padLeft(8)}',
    );
  }
  print(
    '${'total'.padRight(12)}${(totalChars / 1024).round().toString().padLeft(5)}'
    '${''.padLeft(10)}${(totalMicros / 1000).toStringAsFixed(1).padLeft(7)}'
    '${(totalChars / totalMicros).toStringAsFixed(1).padLeft(8)}',
  );
}
