import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import 'samples.g.dart';

/// A sample for every built-in language, plus the generic fallback and plain
/// text, sorted by name.
final Map<Grammar, String> samples = () {
  final registry = allLanguagesRegistry();
  final entries = [
    for (final MapEntry(key: name, value: code) in generatedSamples.entries)
      MapEntry(registry.lookup(name)!, code),
  ]..sort((a, b) => a.key.name.compareTo(b.key.name));
  return {
    ...Map.fromEntries(entries),
    genericLanguage:
        '// Code in a language val_highlight does not know.\n'
        'fn main() -> Result<(), Error> {\n'
        '    let items = vec![1, 2, 3];\n'
        '    for item in items { println!("{item}"); } # note\n'
        '    return Ok(());\n'
        '}\n',
    plainTextLanguage: 'Just plain text.\nNo highlighting here.',
  };
}();

/// A large Dart file for the lazy-rendering demo.
String largeSample(int copies) =>
    List.filled(copies, generatedSamples['dart']!).join();
