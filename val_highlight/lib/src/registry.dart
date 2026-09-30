import 'grammar/grammar.dart';

/// Languages addressable by name, alias or file extension.
final class LanguageRegistry {
  /// Creates a registry containing [languages].
  ///
  /// [fallback] is used by [resolve] and [resolveFileName] when nothing
  /// matches, and for embedded code (such as Markdown fences) in a language
  /// the registry does not have.
  LanguageRegistry([Iterable<Grammar> languages = const [], this.fallback]) {
    languages.forEach(add);
  }

  /// Language used when nothing matches, or `null`.
  final Grammar? fallback;

  final Map<String, Grammar> _byName = {};
  final Map<String, Grammar> _byExtension = {};
  final Map<String, Grammar> _byFileName = {};
  final List<Grammar> _languages = [];

  /// Registered languages, in registration order.
  List<Grammar> get languages => List.unmodifiable(_languages);

  /// Registers [language] under its name, its aliases and any extra
  /// [aliases]. Later registrations replace earlier ones for the same key.
  void add(Grammar language, {List<String> aliases = const []}) {
    _languages.add(language);
    for (final key in [language.name, ...language.aliases, ...aliases]) {
      _byName[key.toLowerCase()] = language;
    }
    for (final extension in language.fileExtensions) {
      _byExtension[extension.toLowerCase()] = language;
    }
    for (final fileName in language.fileNames) {
      _byFileName[fileName.toLowerCase()] = language;
    }
  }

  /// Language registered as [nameOrAlias], or `null`.
  Grammar? lookup(String nameOrAlias) => _byName[nameOrAlias.toLowerCase()];

  /// Language registered as [nameOrAlias], else [fallback].
  Grammar? resolve(String nameOrAlias) => lookup(nameOrAlias) ?? fallback;

  /// Language for [fileName]'s extension, else [fallback].
  Grammar? resolveFileName(String fileName) =>
      forFileName(fileName) ?? fallback;

  /// Language for [fileName] (a path is fine), matched by whole name, such
  /// as `Dockerfile`, then by extension, such as `main.dart`; or `null`.
  Grammar? forFileName(String fileName) {
    final slash = fileName.lastIndexOf(RegExp(r'[/\\]'));
    final base = fileName.substring(slash + 1).toLowerCase();
    final byName = _byFileName[base];
    if (byName != null) return byName;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return _byExtension[fileName.substring(dot + 1).toLowerCase()];
  }
}

/// Thrown when a language name is not registered.
final class UnknownLanguageException implements Exception {
  /// Creates the exception for [name].
  const UnknownLanguageException(this.name);

  /// The name that was not found.
  final String name;

  @override
  String toString() => 'UnknownLanguageException: no language named "$name"';
}
