// The public API of both packages, read with the analyzer, for
// api_completeness_test.dart. It is independent of the docs generator
// (tool/docs/api_reference.dart), which reads the source with its own
// scanner: the export namespaces here are the analyzer's, so `show`, `hide`
// and re-exports are honoured exactly as a user's import sees them.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';

/// A public declaration: a top-level symbol, or a member of a public type.
typedef ApiItem = ({
  /// `Name` for a top-level symbol, `Type.member` for a member, `Type.new`
  /// for an unnamed constructor.
  String id,

  /// The top-level symbol this belongs to (itself, for a top-level one).
  String owner,

  /// The member's name, or null for a top-level symbol.
  String? member,

  /// `library` (a library's own doc comment, when it has one; `id` is its
  /// URI), `class`, `function`, `variable`, `typedef`, `constructor`, `field`,
  /// `getter`, `setter` or `method`.
  String kind,

  /// The raw doc comment, `///` included, or null when there is none.
  String? doc,

  /// A constructor's parameter names; empty otherwise.
  List<String> parameters,

  /// The libraries that export it, as `package:` URIs.
  Set<String> libraries,
});

/// Every public library of both packages: each file of `lib/` outside
/// `lib/src/`. [root] is val_highlight_flutter/.
List<String> publicLibraryUris(Directory root) {
  final out = <String>[];
  for (final (package, dir) in [
    ('val_highlight', '${root.path}/../val_highlight/lib'),
    ('val_highlight_flutter', '${root.path}/lib'),
  ]) {
    final base = Directory(dir).absolute.uri.normalizePath();
    for (final f in Directory(dir).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.absolute.uri.normalizePath().path.substring(
        base.path.length,
      );
      if (rel.startsWith('src/')) continue;
      out.add('package:$package/$rel');
    }
  }
  return out..sort();
}

/// [path] made absolute and normalized, as the analyzer wants it.
String _path(String path) =>
    File(path).absolute.uri.normalizePath().toFilePath();

/// The Dart SDK of the Flutter SDK the workspace resolved against, from the
/// `flutter` package's location in the package config.
String _dartSdk(Directory root) {
  final config = File('${root.path}/../.dart_tool/package_config.json');
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final p in (json['packages']! as List).cast<Map<String, Object?>>()) {
    if (p['name'] == 'flutter') {
      // rootUri is `<flutter>/packages/flutter`, without a trailing slash.
      final flutter = config.uri.resolve('${p['rootUri']! as String}/');
      return _path(flutter.resolve('../../bin/cache/dart-sdk').toFilePath());
    }
  }
  throw StateError('flutter not found in ${config.path}');
}

/// Every public declaration exported by [publicLibraryUris], and every public
/// member declared by an exported type. `@override` members are left out:
/// they implement a supertype's member and carry its documentation.
Future<List<ApiItem>> publicApi(Directory root) async {
  final flutterLib = _path('${root.path}/lib');
  final collection = AnalysisContextCollection(
    includedPaths: [flutterLib, _path('${root.path}/../val_highlight/lib')],
    sdkPath: _dartSdk(root),
  );
  final session = collection.contextFor(flutterLib).currentSession;
  final items = <String, ApiItem>{};

  void add(
    String id,
    String owner,
    String? member,
    String kind,
    Element e,
    String library, [
    List<String> parameters = const [],
  ]) {
    final existing = items[id];
    if (existing != null) {
      existing.libraries.add(library);
      return;
    }
    items[id] = (
      id: id,
      owner: owner,
      member: member,
      kind: kind,
      doc: e.documentationComment,
      parameters: parameters,
      libraries: {library},
    );
  }

  for (final uri in publicLibraryUris(root)) {
    final result = await session.getLibraryByUri(uri);
    if (result is! LibraryElementResult) {
      throw StateError('$uri: ${result.runtimeType}');
    }
    final doc = result.element.documentationComment;
    if (doc != null) add(uri, uri, null, 'library', result.element, uri);
    final names = result.element.exportNamespace.definedNames2;
    for (final MapEntry(key: name, value: e) in names.entries) {
      if (name.startsWith('_')) continue;
      final library = e.library?.uri.toString() ?? '';
      // Only this workspace's API: the Flutter library re-exports the core
      // one, and nothing re-exports a third party's.
      if (!library.startsWith('package:val_highlight')) continue;
      switch (e) {
        case InterfaceElement():
          add(name, name, null, 'class', e, uri);
          _members(e, name, (id, member, kind, m, [params = const []]) {
            add(id, name, member, kind, m, uri, params);
          });
        case TopLevelFunctionElement():
          add(name, name, null, 'function', e, uri);
        case TypeAliasElement():
          add(name, name, null, 'typedef', e, uri);
        case GetterElement(:final variable) || SetterElement(:final variable):
          add(variable.name!, variable.name!, null, 'variable', variable, uri);
        case TopLevelVariableElement():
          add(name, name, null, 'variable', e, uri);
        default:
          throw StateError('$uri: $name is a ${e.runtimeType}, not handled');
      }
    }
  }
  return items.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

void _members(
  InterfaceElement type,
  String owner,
  void Function(
    String id,
    String member,
    String kind,
    Element e, [
    List<String> parameters,
  ])
  add,
) {
  for (final c in type.constructors) {
    if (!c.isPublic || !c.isOriginDeclaration) continue;
    final member = c.name == null || c.name == 'new' ? 'new' : c.name!;
    add('$owner.$member', member, 'constructor', c, [
      for (final p in c.formalParameters) p.name!,
    ]);
  }
  for (final f in type.fields) {
    if (!f.isPublic || !f.isOriginDeclaration || f.metadata.hasOverride) {
      continue;
    }
    add('$owner.${f.name}', f.name!, 'field', f);
  }
  for (final g in type.getters) {
    if (!g.isPublic || !g.isOriginDeclaration || g.metadata.hasOverride) {
      continue;
    }
    add('$owner.${g.name}', g.name!, 'getter', g);
  }
  for (final s in type.setters) {
    if (!s.isPublic || !s.isOriginDeclaration || s.metadata.hasOverride) {
      continue;
    }
    // A setter paired with a getter is documented by the getter.
    final getter = type.getters.any(
      (g) => g.name == s.name && g.isOriginDeclaration,
    );
    if (getter) continue;
    add('$owner.${s.name}=', s.name!, 'setter', s);
  }
  for (final m in type.methods) {
    if (!m.isPublic || m.metadata.hasOverride) continue;
    add('$owner.${m.name}', m.name!, 'method', m);
  }
}

// ─── Completeness ────────────────────────────────────────────────────────

/// What the docs in [docs] (the repository's docs/) leave out of [api], one
/// line per gap; empty when every item is documented:
///
/// * every top-level symbol has a `### \`Name\`` section in docs/api/, or is
///   a row of one of its tables, or (a class) has every member listed there
///   as `Name.member`;
/// * every member of a type with a section is in that section: by name in
///   a table or signature, a named constructor as `Name.member(`, the
///   unnamed one as its `Name(` signature, and each constructor parameter
///   by name;
/// * every item has a doc comment, and every paragraph of it is in the docs
///   (generated or hand-written), compared as plain words.
List<String> undocumented(List<ApiItem> api, Directory docs) {
  final reference = StringBuffer();
  final everything = StringBuffer();
  for (final f in docs.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.mdx')) continue;
    final text = f.readAsStringSync();
    everything.writeln(text);
    if (f.parent.path.endsWith('/api')) reference.writeln(text);
  }
  final ref = reference.toString();
  final corpus = _plain(everything.toString());

  // `### `Name`` → the text up to the next heading.
  final sections = <String, String>{};
  final headings = RegExp(
    r'^### `(\w+)`$',
    multiLine: true,
  ).allMatches(ref).toList();
  for (final (i, h) in headings.indexed) {
    final end = i + 1 < headings.length ? headings[i + 1].start : ref.length;
    final section = ref.substring(h.end, end);
    // A partial's end is followed by the next partial's header.
    sections[h[1]!] = section.split('{/* Generated by').first;
  }

  // A row documents a symbol when one of its cells is the symbol itself,
  // not when a description merely mentions it.
  bool inTable(String code) => RegExp(
    r'^\|(?:.*\|)?\s*`' + RegExp.escape(code) + r'`\s*\|',
    multiLine: true,
  ).hasMatch(ref);

  final gaps = <String>[];
  final owners = <String, List<ApiItem>>{};
  for (final item in api) {
    if (item.member != null) (owners[item.owner] ??= []).add(item);
  }
  for (final item in api.where((i) => i.member == null)) {
    if (item.kind == 'library') continue; // only its doc comment is checked
    if (sections.containsKey(item.id) || inTable(item.id)) continue;
    final members = owners[item.id] ?? const [];
    final listed =
        item.kind == 'class' &&
        members.isNotEmpty &&
        members.every(
          (m) => m.kind == 'constructor' || inTable('${item.id}.${m.member}'),
        );
    if (!listed) gaps.add('${item.id}: no section in docs/api/');
  }

  for (final item in api.where((i) => i.member != null)) {
    final section = sections[item.owner];
    if (section == null) continue; // a class listed member by member
    final name = item.member!;
    final found = switch (item.kind) {
      'constructor' when name == 'new' => RegExp(
        '^(?:const )?${item.owner}\\(',
        multiLine: true,
      ).hasMatch(section),
      'constructor' => section.contains('`${item.owner}.$name('),
      _ => RegExp('`(?:static )?${RegExp.escape(name)}[`(<]').hasMatch(section),
    };
    if (!found) gaps.add('${item.id}: not in the `${item.owner}` section');
    for (final p in item.parameters) {
      if (!RegExp('\\b$p\\b').hasMatch(section)) {
        gaps.add(
          '${item.id}: parameter `$p` not in the `${item.owner}` section',
        );
      }
    }
  }

  for (final item in api) {
    final doc = item.doc;
    if (doc == null) {
      gaps.add('${item.id}: no doc comment');
      continue;
    }
    for (final paragraph in docParagraphs(doc)) {
      if (!corpus.contains(_plain(paragraph))) {
        gaps.add('${item.id}: paragraph not in docs: "$paragraph"');
      }
    }
  }
  return gaps;
}

/// A `///` doc comment's paragraphs: split on blank lines outside code
/// fences, `///` stripped.
List<String> docParagraphs(String comment) {
  final out = <String>[];
  final current = <String>[];
  var fence = false;
  for (final raw in comment.split('\n')) {
    final line = raw.trimLeft().replaceFirst(RegExp(r'^/// ?'), '');
    if (line.trimLeft().startsWith('```')) fence = !fence;
    if (!fence && line.trim().isEmpty) {
      if (current.isNotEmpty) out.add(current.join('\n'));
      current.clear();
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) out.add(current.join('\n'));
  return out;
}

/// [text] as plain words, so a doc comment and the MDX it became compare
/// equal: Markdown and MDX escapes, code ticks, emphasis and `[Ref]`
/// brackets removed; whitespace (line breaks, table cells) collapsed.
String _plain(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'[\\`*\[\]]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');
