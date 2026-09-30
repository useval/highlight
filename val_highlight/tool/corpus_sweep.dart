// Runs every grammar over real source files and reports problems.
//
//   dart run tool/corpus_sweep.dart [--per-language=N] [--verbose]
//       [--language=NAME] DIR...
//
// --language=NAME highlights every file under DIR as that language, for
// formats whose files do not have a telling extension (nginx `.conf`).
//
// For each file whose extension maps to a built-in language it checks:
//   * no crash, and tokens cover the file exactly;
//   * the fast (dispatch) scanner and the combined-expression scanner agree;
//   * incremental updates after random edits match a full highlight;
//   * speed: files slower than 2 MB/s are reported;
//   * the scan ends at the top level. A region still open at the end of a
//     complete source file (an unclosed string or comment) almost always
//     means the grammar misread something earlier, so these are listed with
//     the position where the region opened.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/src/engine/compiler.dart';
import 'package:val_highlight/src/engine/scanner.dart';
import 'package:val_highlight/val_highlight.dart';

const _maxBytes = 2 * 1024 * 1024;

final class _Stats {
  int files = 0;
  int bytes = 0;
  int micros = 0;
  int errors = 0;
  int mismatches = 0;
  int incrementalMismatches = 0;
  final slow = <String>[];
  final unclosed = <String>[];
  final unclosedPatterns = <String, int>{};
}

Future<void> main(List<String> args) async {
  var perLanguage = 400;
  var verbose = false;
  String? forced;
  final roots = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--per-language=')) {
      perLanguage = int.parse(arg.split('=')[1]);
    } else if (arg.startsWith('--language=')) {
      forced = arg.split('=')[1];
    } else if (arg == '--verbose') {
      verbose = true;
    } else {
      roots.add(arg);
    }
  }
  if (roots.isEmpty) {
    stderr.writeln('usage: corpus_sweep.dart [--per-language=N] DIR...');
    exit(64);
  }

  final registry = allLanguagesRegistry();
  final byLanguage = <Grammar, List<File>>{};
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final language = forced != null
          ? registry.lookup(forced)
          : registry.forFileName(entity.path);
      if (language == null || identical(language, plainTextLanguage)) continue;
      byLanguage.putIfAbsent(language, () => []).add(entity);
    }
  }

  final random = Random(1);
  final highlighter = Highlighter(registry: registry);
  final stats = <Grammar, _Stats>{};

  for (final MapEntry(key: language, value: files) in byLanguage.entries) {
    files.shuffle(random);
    final stat = stats[language] = _Stats();
    for (final file in files.take(perLanguage)) {
      final int size;
      try {
        size = file.lengthSync();
      } on FileSystemException {
        continue;
      }
      if (size == 0 || size > _maxBytes) continue;
      final bytes = file.readAsBytesSync();
      // Skip binary files that merely share an extension, such as MPEG
      // transport streams named `.ts`.
      if (bytes.take(8000).contains(0)) continue;
      final code = utf8.decode(bytes, allowMalformed: true);
      if ('\uFFFD'.allMatches(code).length > code.length ~/ 100) continue;
      stat.files++;
      stat.bytes += code.length;
      try {
        _check(file.path, code, language, highlighter, stat, random);
      } on Object catch (error, trace) {
        stat.errors++;
        stdout.writeln('ERROR ${language.name} ${file.path}: $error');
        if (verbose) stdout.writeln(trace);
      }
    }
  }

  stdout.writeln(
    '\nlanguage     files      MB    MB/s  errors  mismatch  incr  slow  '
    'unclosed',
  );
  for (final MapEntry(key: language, value: s) in stats.entries) {
    stdout.writeln(
      '${language.name.padRight(12)}'
      '${s.files.toString().padLeft(6)}'
      '${(s.bytes / 1e6).toStringAsFixed(1).padLeft(8)}'
      '${(s.micros == 0 ? 0 : s.bytes / s.micros).toStringAsFixed(1).padLeft(8)}'
      '${s.errors.toString().padLeft(8)}'
      '${s.mismatches.toString().padLeft(10)}'
      '${s.incrementalMismatches.toString().padLeft(6)}'
      '${s.slow.length.toString().padLeft(6)}'
      '${s.unclosed.length.toString().padLeft(10)}',
    );
  }
  for (final MapEntry(key: language, value: s) in stats.entries) {
    if (s.slow.isNotEmpty) {
      stdout.writeln('\n${language.name}: slow files');
      for (final line in s.slow.take(10)) {
        stdout.writeln('  $line');
      }
    }
    if (s.unclosed.isNotEmpty) {
      stdout.writeln('\n${language.name}: unclosed regions by opening text');
      final top = s.unclosedPatterns.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in top.take(12)) {
        stdout.writeln('  ${e.value.toString().padLeft(4)}× ${e.key}');
      }
      for (final line in verbose ? s.unclosed : s.unclosed.take(8)) {
        stdout.writeln('  $line');
      }
    }
  }
}

List<(int, int, String)> _shape(HighlightResult r) => [
  for (final t in r.tokens) (t.start, t.end, t.scopes.join('>')),
];

void _check(
  String path,
  String code,
  Grammar language,
  Highlighter highlighter,
  _Stats stat,
  Random random,
) {
  // Speed and the final state, from a direct scan.
  final compiled = CompiledGrammar.of(language);
  final table = ScopeTable();
  final out = TokenBuffer(code.length ~/ 6);
  final scanner = Scanner(
    code: code,
    table: table,
    out: out,
    embeds: highlighter.registry,
  );
  final watch = Stopwatch()..start();
  scanner.scan(ScanFrame(compiled.root, ScopeTable.root, null), 0);
  final micros = watch.elapsedMicroseconds;
  stat.micros += micros;
  if (code.length > 20000 && code.length / max(micros, 1) < 2) {
    stat.slow.add(
      '$path (${(code.length / 1024).round()} KB, ${micros ~/ 1000} ms)',
    );
  }

  final last = scanner.lastFrame!;
  // A region whose end matches at the end of input (such as a YAML block
  // scalar that ends the file) is closed, not left open.
  final endsAtEof =
      last.depth > 0 &&
      last.state.alternatives.first.alone.matchAsPrefix(code, code.length) !=
          null;
  if (last.depth > 0 && !endsAtEof) {
    var frame = last;
    while (frame.parent!.depth > 0) {
      frame = frame.parent!;
    }
    final opened = frame.start;
    final line = '\n'.allMatches(code.substring(0, opened)).length + 1;
    final snippet = code
        .substring(opened, min(code.length, opened + 30))
        .replaceAll('\n', r'\n');
    stat.unclosed.add('$path:$line  "$snippet"');
    final key = code
        .substring(opened, min(code.length, opened + 6))
        .replaceAll('\n', r'\n');
    stat.unclosedPatterns[key] = (stat.unclosedPatterns[key] ?? 0) + 1;
  }

  // Coverage, and dispatch against the combined expression.
  final dispatched = highlighter.highlight(code, language: language);
  var cursor = 0;
  for (var i = 0; i < dispatched.tokenCount; i++) {
    if (dispatched.tokenStart(i) != cursor ||
        dispatched.tokenEnd(i) <= cursor) {
      throw StateError('bad coverage at token $i');
    }
    cursor = dispatched.tokenEnd(i);
  }
  if (cursor != code.length) throw StateError('tokens end at $cursor');
  dispatched.toHtml();

  // Comparing token shapes is expensive; do it on smaller files.
  if (code.length > 200000) return;
  Scanner.useDispatch = false;
  final combined = highlighter.highlight(code, language: language);
  Scanner.useDispatch = true;
  if (!_same(_shape(dispatched), _shape(combined))) {
    stat.mismatches++;
    stdout.writeln('MISMATCH dispatch/combined ${language.name} $path');
  }

  // Incremental: three random edits.
  final document = IncrementalHighlighter(
    language: language,
    text: code,
    registry: highlighter.registry,
  );
  var text = code;
  for (var i = 0; i < 3; i++) {
    final at = random.nextInt(text.length + 1);
    final end = min(text.length, at + random.nextInt(8));
    const inserts = ['"', "'", '/*', '*/', '\n', '{', '}', '`', 'x', ''];
    text = text.replaceRange(at, end, inserts[random.nextInt(inserts.length)]);
    final incremental = document.update(text);
    final full = highlighter.highlight(text, language: language);
    if (!_same(_shape(incremental), _shape(full))) {
      stat.incrementalMismatches++;
      stdout.writeln('MISMATCH incremental ${language.name} $path edit $i');
      break;
    }
  }
}

bool _same(List<(int, int, String)> a, List<(int, int, String)> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
