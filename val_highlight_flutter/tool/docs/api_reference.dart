// Generates the reference parts of the docs (`../docs/api/`) from the source
// of both packages:
//
// * the API reference at the end of each page: constructors, fields with
//   their defaults, members, typedefs and functions, with their doc comments;
// * the list of languages, read from `allLanguages`;
// * the list of themes and the theme gallery, read from `allThemes`;
// * the table of standard scopes, with the VS Code scopes each one reads;
// * the public libraries, with their own doc comments.
//
// Every paragraph of every public doc comment ends up in the output: a
// table cell holds the first one, and a `<details>` block after the table
// the rest. test/docs/api_completeness_test.dart checks that, against the
// public API as the analyzer sees it.
//
//   dart run tool/docs/api_reference.dart          # write ../docs/api/
//   dart run tool/docs/api_reference.dart --check  # exit 1 if out of date
//
// Run it from val_highlight_flutter/. test/docs/api_reference_test.dart runs
// the check, so a change to a public declaration, a default or a doc comment
// that is not regenerated fails the tests.
//
// Declarations are read with a small scanner that skips strings and
// comments, not with the analyzer. A declaration it cannot read throws rather
// than writing a partial table.
import 'dart:io';

import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/all.dart';
import 'package:val_highlight/val_highlight.dart';

/// What each page's API reference documents, by the partial's name: classes,
/// typedefs, functions and constants, in the order they are listed.
const pages = <String, List<String>>{
  'code-view': [
    'CodeView',
    'CodeToken',
    'CodeLineDetails',
    'CodeGutterBuilder',
    'CodeLineBuilder',
    'CodeSpanBuilder',
    'CodeHighlighter',
  ],
  'code-field': [
    'CodeField',
    'CodeEditing',
    'IndentCodeIntent',
    'OutdentCodeIntent',
    'ToggleCommentIntent',
    'toggleComment',
  ],
  'text-field': ['HighlightTextController', 'CodeEditingFormatter'],
  'rendering': [
    'CodeStyles',
    'textStyleFromStyle',
    'lineSpans',
    'documentSpans',
    'exactSpans',
  ],
  'highlighting': [
    'Highlighter',
    'HighlightResult',
    'HighlightToken',
    'ScopeTable',
  ],
  'incremental': ['IncrementalHighlighter'],
  'html': ['HtmlRenderer', 'cssColor', 'scopeClass'],
  'lookup': [
    'LanguageRegistry',
    'UnknownLanguageException',
    'LanguageDetector',
    'Detection',
    'DetectionReason',
    'allLanguages',
    'allLanguagesRegistry',
  ],
  'themes': ['ValTheme', 'Style', 'CodeTheme', 'CodeThemeData', 'allThemes'],
  'grammar': [
    'Grammar',
    'Rule',
    'TokenRule',
    'RegionRule',
    'KeywordRule',
    'IncludeRule',
    'BlockRule',
    'LineComment',
    'BlockComment',
    'QuotedString',
    'Interpolation',
    'Numbers',
    'Operators',
    'Annotation',
    'Preprocessor',
    'CommonRules',
    'EditingSyntax',
    'GrammarException',
  ],
};

/// Where the generated files go, relative to val_highlight_flutter/.
const outDir = '../docs/api';

/// The docs' images, relative to val_highlight_flutter/.
const imagesDir = '../docs/images';

void main(List<String> args) {
  final check = args.contains('--check');
  final files = generateDocs(Directory.current);
  final stale = <String>[];
  for (final MapEntry(key: path, value: content) in files.entries) {
    final file = File(path);
    if (file.existsSync() && file.readAsStringSync() == content) continue;
    stale.add(path);
    if (!check) {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }
  final extra = Directory(outDir).existsSync()
      ? [
          for (final f in Directory(outDir).listSync().whereType<File>())
            if (!files.containsKey(f.path)) f.path,
        ]
      : <String>[];
  if (check) {
    if (stale.isEmpty && extra.isEmpty) return;
    stderr.writeln(
      'Docs reference out of date: ${[...stale, ...extra].join(', ')}\n'
      'Run `dart run tool/docs/api_reference.dart` in val_highlight_flutter/.',
    );
    exitCode = 1;
    return;
  }
  for (final p in extra) {
    File(p).deleteSync();
  }
  stdout.writeln(
    stale.isEmpty && extra.isEmpty
        ? 'Docs reference up to date.'
        : 'Wrote ${stale.length} file(s), removed ${extra.length}.',
  );
}

/// Path → content of every generated file. [root] is val_highlight_flutter/.
Map<String, String> generateDocs(Directory root) {
  final core = '${root.path}/../val_highlight/lib';
  final sources = <String, String>{
    for (final dir in ['${root.path}/lib', core])
      for (final f in Directory(dir).listSync(recursive: true))
        // The engine's internals are not public API, except the scope table.
        if (f is File &&
            f.path.endsWith('.dart') &&
            (!f.path.contains('/src/engine/') ||
                f.path.endsWith('/scope_table.dart')) &&
            !f.path.contains('/src/languages/'))
          f.path: f.readAsStringSync(),
  };
  if (pages.keys.any(
    (slug) => const [
      'languages',
      'theme-list',
      'theme-gallery',
      'scopes',
      'libraries',
    ].contains(slug),
  )) {
    throw StateError('a page slug clashes with a generated table');
  }
  return {
    for (final MapEntry(key: slug, value: names) in pages.entries)
      '$outDir/_$slug.mdx': _page(names, sources),
    '$outDir/_languages.mdx': _languages(core),
    '$outDir/_theme-list.mdx': _themes(core),
    '$outDir/_theme-gallery.mdx': _themeGallery(),
    '$outDir/_scopes.mdx': _scopes(core),
    '$outDir/_libraries.mdx': _libraries(root),
  };
}

const _header =
    '{/* Generated by `dart run tool/docs/api_reference.dart` in '
    'val_highlight_flutter/. Do not edit. */}';

// ─── API reference ───────────────────────────────────────────────────────

String _page(List<String> names, Map<String, String> sources) {
  final out = StringBuffer()..writeln(_header);
  for (final name in names) {
    out
      ..writeln()
      ..writeln('### `$name`')
      ..writeln();
    final decl = _find(name, sources);
    switch (decl.kind) {
      case 'class':
        _class(out, name, decl.source, decl.start);
      case 'enum':
        _enum(out, name, decl.source, decl.start);
      case 'typedef':
        out
          ..writeln(_mdx(_docAbove(decl.source, decl.start)))
          ..writeln()
          ..writeln('```dart')
          ..writeln(_formatSignature(_headerAt(decl.source, decl.start)))
          ..writeln('```');
      case 'function':
        final header = _flat(_headerAt(decl.source, decl.start));
        out
          ..writeln(_mdx(_docAbove(decl.source, decl.start)))
          ..writeln()
          ..writeln('```dart')
          ..writeln(_formatSignature(header))
          ..writeln('```');
      case 'const':
        final header = _flat(_headerAt(decl.source, decl.start));
        final m = RegExp(
          r'^const (\w+) = (?:<(.+?)>)?\[(.)',
        ).firstMatch(header);
        // Without a type argument, only a list of strings is read.
        final type =
            m?[2] ??
            (m?[3] == "'" || m?[3] == '"'
                ? 'String'
                : throw StateError('$name: cannot read "$header"'));
        out
          ..writeln(_mdx(_docAbove(decl.source, decl.start)))
          ..writeln()
          ..writeln('```dart')
          ..writeln('const List<$type> ${m![1]}')
          ..writeln('```');
    }
  }
  return out.toString();
}

typedef _Decl = ({String kind, String source, int start});

/// The declaration of [name] in [sources]: where it starts, and what it is.
_Decl _find(String name, Map<String, String> sources) {
  final patterns = {
    'class': RegExp(
      '^(?:abstract |final |base |sealed |interface )*class $name\\b',
      multiLine: true,
    ),
    'enum': RegExp('^enum $name\\b', multiLine: true),
    'typedef': RegExp('^typedef $name\\b', multiLine: true),
    'const': RegExp('^const $name = ', multiLine: true),
    'function': RegExp('^[\\w<>?, ()]+ $name\\(', multiLine: true),
  };
  for (final MapEntry(key: kind, value: pattern) in patterns.entries) {
    for (final source in sources.values) {
      final m = pattern.firstMatch(source);
      if (m != null) return (kind: kind, source: source, start: m.start);
    }
  }
  throw StateError('$name not found in lib/');
}

void _class(StringBuffer out, String name, String source, int start) {
  final doc = _docAbove(source, start);
  out.writeln(_mdx(doc));
  final open = _indexOutside(source, '{', start);
  final close = _matching(source, open);
  final members = _membersOf(source.substring(open + 1, close));

  // Types of every field, private ones too, for `this.x` parameters.
  final types = <String, String>{};
  for (final m in members) {
    final field = _field(m.header);
    if (field != null) types[field.name] = field.type;
  }

  final unnamed = members
      .where((m) => RegExp('^(?:const )?$name\\(').hasMatch(m.header))
      .firstOrNull;
  final defaults = <String, String>{};
  final required = <String>{};
  if (unnamed != null) {
    final params = _params(unnamed.header);
    out
      ..writeln()
      ..writeln('```dart')
      ..writeln(_constructor(unnamed.header, params, types))
      ..writeln('```');
    if (unnamed.doc.isNotEmpty) {
      out
        ..writeln()
        ..writeln(_mdx(unnamed.doc));
    }
    for (final p in params) {
      final m = RegExp(
        r'^(required )?this\.(\w+)(?: = (.+))?$',
      ).firstMatch(p.text);
      if (m == null) continue;
      // Required named parameters, and positional ones outside `[…]`.
      if (m[1] != null || p.group.isEmpty) required.add(m[2]!);
      if (m[3] != null) defaults[m[2]!] = m[3]!;
    }
  }

  final fields = <_Row>[];
  final rows = <_Row>[];
  final setters = {
    for (final m in members)
      if (RegExp(r'^set (\w+)\(').firstMatch(m.header) case final s?) s[1]!,
  };
  for (final m in members) {
    if (m.doc.isEmpty || m.overrides) continue;
    final header = m.header;
    if (header.startsWith('set ')) continue;
    // Constructors: the unnamed one is shown above; named ones are members.
    final ctor = RegExp(
      '^(?:const )?(?:factory )?$name(\\.\\w+)?\\(',
    ).firstMatch(header);
    if (ctor != null) {
      if (ctor[1] == null) continue;
      rows.add((
        name: '$name${ctor[1]}${_shortParams(header, header.indexOf('('))}',
        type: name,
        doc: m.doc,
        defaultValue: null,
      ));
      continue;
    }
    final isStatic = header.startsWith('static ');
    final plain = header
        .replaceFirst(RegExp(r'^static '), '')
        .replaceFirst(RegExp(r' (?:async\*?|sync\*)$'), '');
    final getter = RegExp(r'^(.+) get (\w+)$').firstMatch(plain);
    if (getter != null) {
      if (getter[2]!.startsWith('_')) continue;
      rows.add((
        name: '${isStatic ? 'static ' : ''}${getter[2]}',
        type: getter[1]!,
        doc: setters.contains(getter[2]) ? _settable(m.doc) : m.doc,
        defaultValue: null,
      ));
      continue;
    }
    if (plain.endsWith(')') && _topLevelIndex(plain, ' = ') < 0) {
      final method = _method(plain);
      if (method != null) {
        if (method.name.startsWith('_')) continue;
        rows.add((
          name:
              '${isStatic ? 'static ' : ''}${method.name}'
              '${_shortParams(plain, _openingParen(plain, plain.length - 1))}',
          type: method.type,
          doc: m.doc,
          defaultValue: null,
        ));
        continue;
      }
    }
    final field = _field(header);
    if (field == null) throw StateError('$name: cannot read "$header"');
    if (field.name.startsWith('_')) continue;
    if (isStatic) {
      rows.add((
        name: 'static ${field.name}',
        type: field.type,
        doc: m.doc,
        defaultValue: null,
      ));
    } else {
      fields.add((
        name: field.name,
        type: field.type,
        doc: m.doc,
        defaultValue: required.contains(field.name)
            ? '*required*'
            : defaults[field.name] == null
            ? ''
            : '`${defaults[field.name]}`',
      ));
    }
  }

  if (fields.isNotEmpty) {
    final withDefaults = fields.any((f) => f.defaultValue!.isNotEmpty);
    out
      ..writeln()
      ..writeln(
        withDefaults
            ? '| Field | Type | Default | Description |\n|---|---|---|---|'
            : '| Field | Type | Description |\n|---|---|---|',
      );
    for (final f in fields) {
      out.writeln(
        '| `${f.name}` | `${_pipe(f.type)}` | '
        '${withDefaults ? '${_pipe(f.defaultValue!)} | ' : ''}'
        '${_cell(f.doc)} |',
      );
    }
    _more(out, fields);
  }
  if (rows.isNotEmpty) {
    out
      ..writeln()
      ..writeln('| Member | Type | Description |')
      ..writeln('|---|---|---|');
    for (final r in rows) {
      out.writeln(
        '| `${_pipe(r.name)}` | ${r.type.isEmpty ? '' : '`${_pipe(r.type)}`'} '
        '| ${_cell(r.doc)} |',
      );
    }
    _more(out, rows);
  }
}

void _enum(StringBuffer out, String name, String source, int start) {
  out.writeln(_mdx(_docAbove(source, start)));
  final open = _indexOutside(source, '{', start);
  final body = source.substring(open + 1, _matching(source, open));
  final values = <(String, String)>[];
  final doc = <String>[];
  for (final line in body.split('\n').map((l) => l.trim())) {
    if (line.startsWith('///')) {
      doc.add(line.substring(3).trim());
    } else if (RegExp(r'^\w+[,;]?$').firstMatch(line) case final m?) {
      values.add((m[0]!.replaceAll(RegExp('[,;]'), ''), doc.join('\n')));
      doc.clear();
    }
  }
  out
    ..writeln()
    ..writeln('```dart')
    ..writeln('enum $name { ${values.map((v) => v.$1).join(', ')} }')
    ..writeln('```')
    ..writeln()
    ..writeln('| Value | Description |')
    ..writeln('|---|---|');
  for (final (value, doc) in values) {
    out.writeln('| `$value` | ${_cell(doc)} |');
  }
}

/// [doc] with "Settable." at the end of its first paragraph.
String _settable(String doc) {
  final paragraphs = _paragraphs(doc);
  paragraphs[0] = '${paragraphs[0]} *Settable.*';
  return paragraphs.join('\n\n');
}

typedef _Row = ({String name, String type, String doc, String? defaultValue});

typedef _Member = ({String doc, String header, bool overrides});

/// The declarations directly inside a class body, each with its doc comment
/// and whether it is an `@override`.
List<_Member> _membersOf(String body) {
  final out = <_Member>[];
  final doc = <String>[];
  var overrides = false;
  var i = 0;
  while (i < body.length) {
    final c = body[i];
    if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
      i++;
    } else if (body.startsWith('///', i)) {
      final end = body.indexOf('\n', i);
      doc.add(body.substring(i, end < 0 ? body.length : end));
      i = end < 0 ? body.length : end + 1;
    } else if (body.startsWith('//', i) || body.startsWith('/*', i)) {
      i = _skip(body, i);
    } else if (c == '@') {
      final m = RegExp(r'@[\w.]+').matchAsPrefix(body, i)!;
      if (m[0] == '@override') overrides = true;
      i = m.end;
      if (i < body.length && body[i] == '(') i = _matching(body, i) + 1;
    } else if (c == ';') {
      i++;
    } else {
      final start = i;
      final (:end, :header) = _declaration(body, i);
      out.add((
        doc: _docText(doc.join('\n')),
        header: header,
        overrides: overrides,
      ));
      doc.clear();
      overrides = false;
      i = end;
      if (i <= start) throw StateError('stuck at ${body.substring(start)}');
    }
  }
  return out;
}

/// The declaration starting at [i]: its header (up to the body, `=>` or
/// `;`, initializers included for fields), flattened, and where it ends.
({int end, String header}) _declaration(String s, int i) {
  final start = i;
  var depth = 0;
  var assigned = false;
  var called = false;
  while (i < s.length) {
    final next = _skip(s, i);
    if (next != i) {
      i = next;
      continue;
    }
    final c = s[i];
    if (c == '(' && depth == 0) called = true;
    if (c == '(' || c == '[' || (c == '{' && (depth > 0 || assigned))) {
      depth++;
    } else if (c == ')' || c == ']' || (c == '}' && depth > 0)) {
      depth--;
    } else if (depth == 0) {
      if (s.startsWith('=>', i)) {
        final header = _flat(s.substring(start, i));
        var j = i + 2;
        var d = 0;
        while (j < s.length) {
          final n = _skip(s, j);
          if (n != j) {
            j = n;
            continue;
          }
          final x = s[j];
          if ('([{'.contains(x)) d++;
          if (')]}'.contains(x)) d--;
          if (x == ';' && d == 0) break;
          j++;
        }
        return (end: j + 1, header: header);
      }
      // A field's initializer, not a constructor's initializer list (which
      // follows the parameters).
      if (c == '=' && !s.startsWith('==', i) && !called) assigned = true;
      if (c == ';') return (end: i + 1, header: _flat(s.substring(start, i)));
      if (c == '{') {
        final header = _flat(s.substring(start, i));
        return (end: _matching(s, i) + 1, header: header);
      }
    }
    i++;
  }
  throw StateError('unterminated declaration: ${s.substring(start)}');
}

/// A top-level declaration's header, from the start of its line.
String _headerAt(String source, int start) =>
    _declaration(source, start).header;

({String type, String name})? _field(String header) {
  var h = header.replaceFirst(RegExp(r'^static '), '');
  String? init;
  final eq = _topLevelIndex(h, ' = ');
  if (eq >= 0) {
    init = h.substring(eq + 3);
    h = h.substring(0, eq);
  }
  h = h.replaceFirst(RegExp(r'^(?:late )?(?:const |final )?'), '');
  final m = RegExp(r'^(?:(.+) )?(\w+)$').firstMatch(h);
  if (m == null) return null;
  var type = m[1] ?? '';
  if (type.isEmpty && init != null) {
    type = switch (init) {
      _ when init.startsWith("'") => 'String',
      _ when RegExp(r'^-?\d+$').hasMatch(init) => 'int',
      _ => RegExp(r'^(?:const )?([A-Z]\w*)[(.<]').firstMatch(init)?[1] ?? '',
    };
  }
  return (type: type, name: m[2]!);
}

({String type, String name})? _method(String header) {
  final close = header.lastIndexOf(')');
  final open = _openingParen(header, close);
  final before = header.substring(0, open);
  final m = RegExp(r'^(.+?) (\w+)(<[^>]*>)?$').firstMatch(before);
  if (m == null) return null;
  return (type: m[1]!, name: m[2]!);
}

/// Index of the `(` matching the `)` at [close].
int _openingParen(String s, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    if (s[i] == ')') depth++;
    if (s[i] == '(' && --depth == 0) return i;
  }
  throw StateError('unbalanced: $s');
}

/// A member's parameter list as shown in a table: elided when long, as
/// `copyWith`'s, which repeats every field.
String _shortParams(String header, int open) {
  final params = header.substring(open, _matching(header, open) + 1);
  if (params.length <= 60) return params;
  return params.startsWith('({') ? '({…})' : '(…)';
}

typedef _Param = ({String text, String group});

/// The parameters of the first parameter list in [header]; `group` is `{`
/// for named ones, `[` for optional positional ones, or empty.
List<_Param> _params(String header) {
  final open = header.indexOf('(');
  final close = _matching(header, open);
  final inner = header.substring(open + 1, close);
  final out = <_Param>[];
  var group = '';
  var depth = 0;
  var start = 0;
  void add(int end, {bool last = false}) {
    var text = inner.substring(start, end).trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      group = text[0];
      text = text.substring(1).trim();
    }
    if (last &&
        (group == '{' && text.endsWith('}') ||
            group == '[' && text.endsWith(']'))) {
      text = text.substring(0, text.length - 1).trim();
    }
    if (text.isNotEmpty) out.add((text: text, group: group));
  }

  for (var i = 0; i < inner.length; i++) {
    final next = _skip(inner, i);
    if (next != i) {
      i = next - 1;
      continue;
    }
    final c = inner[i];
    if ((c == '{' || c == '[') &&
        depth == 0 &&
        inner.substring(start, i).trim().isEmpty) {
      continue; // a parameter group opening
    }
    if ('([{<'.contains(c)) depth++;
    if (')]}>'.contains(c)) {
      if (depth == 0) continue; // a parameter group closing
      depth--;
    }
    if (c == ',' && depth == 0) {
      add(i);
      start = i + 1;
    }
  }
  add(inner.length, last: true);
  return out;
}

/// The unnamed constructor, one parameter per line, with `this.x` and
/// `super.x` written as the parameter's type and name.
String _constructor(
  String header,
  List<_Param> params,
  Map<String, String> types,
) {
  const superTypes = {'key': 'Key?', 'text': 'String?', 'child': 'Widget'};
  final name = header.substring(0, header.indexOf('('));
  final lines = <String>[];
  var group = '';
  for (final p in params) {
    var text = p.text;
    final this_ = RegExp(r'^(required )?this\.(_?)(\w+)(.*)$').firstMatch(text);
    final super_ = RegExp(r'^(required )?super\.(\w+)(.*)$').firstMatch(text);
    if (this_ != null) {
      final type = types['${this_[2]}${this_[3]}'];
      if (type == null) throw StateError('$name: no field for ${p.text}');
      text = '${this_[1] ?? ''}$type ${this_[3]}${this_[4]}';
    } else if (super_ != null) {
      final type = superTypes[super_[2]];
      if (type == null) throw StateError('$name: unknown ${p.text}');
      text = '${super_[1] ?? ''}$type ${super_[2]}${super_[3]}';
    }
    if (p.group != group) {
      if (lines.isNotEmpty) {
        lines.last =
            '${lines.last.substring(0, lines.last.length - 1)}, ${p.group}';
      } else {
        lines.add(p.group);
      }
      group = p.group;
    }
    lines.add('  $text,');
  }
  if (lines.isEmpty) return '$name()';
  if (params.every((p) => p.group.isEmpty)) {
    final flat =
        '$name(${[for (final l in lines) l.trim().substring(0, l.trim().length - 1)].join(', ')})';
    if (flat.length <= 80) return flat;
  }
  final closer = switch (group) {
    '{' => '})',
    '[' => '])',
    _ => ')',
  };
  if (lines.first == '{' || lines.first == '[') {
    return '$name(${lines.first}\n${lines.skip(1).join('\n')}\n$closer';
  }
  return '$name(\n${lines.join('\n')}\n$closer';
}

/// After a table: the rest of each doc comment the table's one-line cell
/// left out, in a collapsed block, so nothing in the source is dropped.
void _more(StringBuffer out, List<_Row> rows) {
  for (final r in rows) {
    final paragraphs = _paragraphs(r.doc);
    if (paragraphs.length < 2) continue;
    _details(out, r.name.split('(').first, paragraphs.skip(1).join('\n\n'));
  }
}

/// A collapsed block holding [text], the part of [name]'s doc comment a
/// table cell left out.
void _details(StringBuffer out, String name, String text) {
  out
    ..writeln()
    ..writeln('<details>')
    ..writeln('<summary><code>${_html(name)}</code>: more</summary>')
    ..writeln()
    ..writeln(_mdx(text))
    ..writeln()
    ..writeln('</details>');
}

/// A signature on one line, or one parameter per line when longer than 80
/// columns, the way `dart format` writes it.
String _formatSignature(String flat) {
  if (flat.length <= 80) return flat;
  final close = flat.lastIndexOf(')');
  final open = _openingParen(flat, close);
  final params = _params(flat.substring(open));
  final lines = <String>[];
  var group = '';
  for (final p in params) {
    if (p.group != group) {
      lines.last =
          '${lines.last.substring(0, lines.last.length - 1)}, ${p.group}';
      group = p.group;
    }
    lines.add('  ${p.text},');
  }
  final closer = group == '{' ? '}' : (group == '[' ? ']' : '');
  return '${flat.substring(0, open + 1)}\n${lines.join('\n')}\n'
      '$closer${flat.substring(close)}';
}

// ─── Languages, themes and scopes ────────────────────────────────────────

/// The identifiers listed in `const <name> = <…>[ … ];` in [source].
List<String> _listed(String source, String name) {
  final m = RegExp('const $name = <\\w+>\\[([^\\]]*)\\];').firstMatch(source);
  if (m == null) throw StateError('$name not found');
  return [
    for (final item in m[1]!.split(','))
      if (item.trim().isNotEmpty) item.trim(),
  ];
}

/// The file in [dir] that declares `const <identifier> =`, and its doc.
({String file, String doc}) _declaredIn(String dir, String identifier) {
  for (final f in Directory(dir).listSync().whereType<File>()) {
    final source = f.readAsStringSync();
    final m = RegExp(
      '^const $identifier = ',
      multiLine: true,
    ).firstMatch(source);
    if (m != null) {
      return (file: f.uri.pathSegments.last, doc: _docAbove(source, m.start));
    }
  }
  throw StateError('$identifier not found in $dir');
}

String _languages(String core) {
  final identifiers = _listed(
    File('$core/languages/all.dart').readAsStringSync(),
    'allLanguages',
  );
  if (identifiers.length != allLanguages.length) {
    throw StateError('allLanguages: ${identifiers.length} names read');
  }
  final real = [
    for (final g in allLanguages)
      if (!identical(g, genericLanguage) && !identical(g, plainTextLanguage)) g,
  ];
  final out = StringBuffer()
    ..writeln(_header)
    ..writeln()
    ..writeln(
      '**${real.length} languages**, plus the generic fallback and plain '
      'text: the ${allLanguages.length} grammars in `allLanguages`. Import '
      'one from `package:val_highlight/languages/<file>`, or all of them from '
      '`languages/all.dart`.',
    )
    ..writeln()
    ..writeln('| Language | Import | Grammar | Names | Files |')
    ..writeln('|---|---|---|---|---|');
  final more = <(String, String)>[];
  for (var i = 0; i < allLanguages.length; i++) {
    final g = allLanguages[i];
    final (:file, :doc) = _declaredIn('$core/languages', identifiers[i]);
    if (!file.startsWith(RegExp('[a-z]'))) throw StateError(file);
    final names = [g.name, ...g.aliases].map((n) => '`$n`').join(', ');
    final seen = <String>{};
    final files = [
      for (final f in [...g.fileExtensions.map((e) => '.$e'), ...g.fileNames])
        if (seen.add(f.toLowerCase())) '`$f`',
    ].join(', ');
    final first = _firstSentence(doc);
    out.writeln(
      '| ${_cell(first)} | `$file` | `${identifiers[i]}` '
      '| $names | ${files.isEmpty ? '—' : files} |',
    );
    final rest = _beyondFirstSentence(doc);
    if (rest.isNotEmpty) more.add((identifiers[i], rest));
  }
  for (final (identifier, rest) in more) {
    _details(out, identifier, rest);
  }
  return out.toString();
}

String _themes(String core) {
  final identifiers = _listed(
    File('$core/themes/all.dart').readAsStringSync(),
    'allThemes',
  );
  if (identifiers.length != allThemes.length) {
    throw StateError('allThemes: ${identifiers.length} names read');
  }
  final out = StringBuffer()
    ..writeln(_header)
    ..writeln()
    ..writeln(
      '| Theme | Import | Name | Dark | Text on background | Description |',
    )
    ..writeln('|---|---|---|---|---|---|');
  final more = <(String, String)>[];
  for (var i = 0; i < allThemes.length; i++) {
    final t = allThemes[i];
    final (:file, :doc) = _declaredIn('$core/themes', identifiers[i]);
    if (doc.isEmpty) throw StateError('${identifiers[i]}: no doc comment');
    out.writeln(
      '| `${identifiers[i]}` | `themes/$file` | `${t.name}` '
      '| ${t.dark ? 'yes' : 'no'} '
      '| `${cssColor(t.root.color!)}` on `${cssColor(t.root.background!)}` '
      '| ${_cell(doc)} |',
    );
    final paragraphs = _paragraphs(doc);
    if (paragraphs.length > 1) {
      more.add((identifiers[i], paragraphs.skip(1).join('\n\n')));
    }
  }
  for (final (identifier, rest) in more) {
    _details(out, identifier, rest);
  }
  return out.toString();
}

/// One tab per built-in theme, each showing the theme's screenshot.
String _themeGallery() {
  final out = StringBuffer()
    ..writeln(_header)
    ..writeln("import { TabItem, Tabs } from '@astrojs/starlight/components'")
    ..writeln()
    ..writeln('<Tabs>');
  for (final t in allThemes) {
    final image = '$imagesDir/themes/${t.name}.png';
    if (!File(image).existsSync()) {
      throw StateError('$image missing: run `just docs-screenshots`');
    }
    final label = t.name
        .split('-')
        .map((w) => w == 'high' ? 'High' : w)
        .join(' ');
    final title = label[0].toUpperCase() + label.substring(1);
    out
      ..writeln('<TabItem label="$title">')
      ..writeln(
        '![The sample in the ${t.name} theme, drawn by CodeView]'
        '(../images/themes/${t.name}.png)',
      )
      ..writeln('</TabItem>');
  }
  out.writeln('</Tabs>');
  return out.toString();
}

String _scopes(String core) {
  final source = File('$core/src/grammar/scopes.dart').readAsStringSync();
  final open = source.indexOf(
    '{',
    source.indexOf('abstract final class Scopes'),
  );
  final members = _membersOf(
    source.substring(open + 1, _matching(source, open)),
  );
  final vscode = File('$core/src/theme/vscode.dart').readAsStringSync();
  final map = <String, List<String>>{
    for (final m in RegExp(r'Scopes\.(\w+): \[([^\]]*)\]').allMatches(vscode))
      m[1]!: [
        for (final s in m[2]!.split(','))
          if (s.trim().isNotEmpty) s.trim().replaceAll("'", ''),
      ],
  };
  final out = StringBuffer()
    ..writeln(_header)
    ..writeln()
    ..writeln(
      _mdx(_docAbove(source, source.indexOf('abstract final class Scopes'))),
    )
    ..writeln()
    ..writeln('| Constant | Scope | Meaning | From VS Code theme scopes |')
    ..writeln('|---|---|---|---|');
  for (final m in members) {
    final c = RegExp(r"^static const (\w+) = '([^']+)'$").firstMatch(m.header);
    if (c == null) throw StateError('Scopes: cannot read "${m.header}"');
    final textMate = map[c[1]];
    if (textMate == null) throw StateError('Scopes.${c[1]}: no VS Code scopes');
    out.writeln(
      '| `Scopes.${c[1]}` | `${c[2]}` | ${_cell(m.doc)} '
      '| ${textMate.map((s) => '`$s`').join(', ')} |',
    );
  }
  return out.toString();
}

/// Every public library (each file of `lib/` outside `lib/src/`) that has a
/// doc comment of its own, with that comment. [root] is
/// val_highlight_flutter/.
String _libraries(Directory root) {
  final out = StringBuffer()
    ..writeln(_header)
    ..writeln()
    ..writeln('| Library | Description |')
    ..writeln('|---|---|');
  final more = <(String, String)>[];
  for (final (package, dir) in [
    ('val_highlight', '${root.path}/../val_highlight/lib'),
    ('val_highlight_flutter', '${root.path}/lib'),
  ]) {
    final files = [
      for (final f in Directory(dir).listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.path.substring(dir.length + 1),
    ]..sort();
    for (final path in files) {
      if (path.startsWith('src/')) continue;
      final source = File('$dir/$path').readAsStringSync();
      final library = RegExp(r'^library\b', multiLine: true).firstMatch(source);
      if (library == null) continue;
      final doc = _docAbove(source, library.start);
      if (doc.isEmpty) continue;
      final uri = 'package:$package/$path';
      out.writeln('| `$uri` | ${_cell(doc)} |');
      final paragraphs = _paragraphs(doc);
      if (paragraphs.length > 1) {
        more.add((uri, paragraphs.skip(1).join('\n\n')));
      }
    }
  }
  for (final (uri, rest) in more) {
    _details(out, uri, rest);
  }
  return out.toString();
}

// ─── Source scanning ─────────────────────────────────────────────────────

/// If a comment or string literal starts at [i], the index after it;
/// otherwise [i].
int _skip(String s, int i) {
  if (s.startsWith('//', i)) {
    final end = s.indexOf('\n', i);
    return end < 0 ? s.length : end;
  }
  if (s.startsWith('/*', i)) {
    final end = s.indexOf('*/', i + 2);
    return end < 0 ? s.length : end + 2;
  }
  var j = i;
  final raw =
      j < s.length &&
      s[j] == 'r' &&
      j + 1 < s.length &&
      (s[j + 1] == "'" || s[j + 1] == '"') &&
      (j == 0 || !RegExp(r'\w').hasMatch(s[j - 1]));
  if (raw) j++;
  if (j >= s.length || (s[j] != "'" && s[j] != '"')) return i;
  final quote = s.startsWith("'''", j) || s.startsWith('"""', j)
      ? s.substring(j, j + 3)
      : s[j];
  j += quote.length;
  while (j < s.length) {
    if (!raw && s[j] == r'\') {
      j += 2;
      continue;
    }
    if (!raw && s.startsWith(r'${', j)) {
      j = _matching(s, j + 1) + 1;
      continue;
    }
    if (s.startsWith(quote, j)) return j + quote.length;
    j++;
  }
  return s.length;
}

/// Index of the bracket closing the one at [open], skipping strings and
/// comments.
int _matching(String s, int open) {
  const pairs = {'(': ')', '[': ']', '{': '}'};
  final stack = <String>[];
  var i = open;
  while (i < s.length) {
    final next = _skip(s, i);
    if (next != i) {
      i = next;
      continue;
    }
    final c = s[i];
    if (pairs.containsKey(c)) {
      stack.add(pairs[c]!);
    } else if (c == ')' || c == ']' || c == '}') {
      if (stack.removeLast() != c) throw StateError('unbalanced at $i');
      if (stack.isEmpty) return i;
    }
    i++;
  }
  throw StateError('unbalanced: no match for ${s[open]} at $open');
}

/// Index of [target] at or after [from], outside strings and comments.
int _indexOutside(String s, String target, int from) {
  var i = from;
  while (i < s.length) {
    final next = _skip(s, i);
    if (next != i) {
      i = next;
      continue;
    }
    if (s.startsWith(target, i)) return i;
    i++;
  }
  throw StateError('"$target" not found');
}

/// Index of [target] in [s] outside brackets, or -1.
int _topLevelIndex(String s, String target) {
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final next = _skip(s, i);
    if (next != i) {
      i = next - 1;
      continue;
    }
    final c = s[i];
    if ('([{<'.contains(c)) depth++;
    if (')]}>'.contains(c)) depth--;
    if (depth == 0 && s.startsWith(target, i)) return i;
  }
  return -1;
}

/// Whitespace runs to one space, and no space just inside brackets or
/// before a trailing comma's closer. String literals are left as they are.
String _flat(String code) {
  final out = StringBuffer();
  var i = 0;
  var from = 0;
  String squash(String part) => part
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('( ', '(')
      .replaceAll('{ ', '{')
      .replaceAll('[ ', '[')
      .replaceAll(RegExp(r',?\s*\)'), ')')
      .replaceAll(RegExp(r',?\s*\}'), '}')
      .replaceAll(RegExp(r',?\s*\]'), ']');
  while (i < code.length) {
    final next = _skip(code, i);
    if (next != i) {
      out
        ..write(squash(code.substring(from, i)))
        ..write(code.substring(i, next));
      i = from = next;
      continue;
    }
    i++;
  }
  out.write(squash(code.substring(from)));
  return out.toString().trim();
}

/// The doc comment directly above the line holding [start], annotations
/// allowed in between.
String _docAbove(String source, int start) {
  final lines = source.substring(0, start).split('\n')..removeLast();
  var i = lines.length - 1;
  while (i >= 0 && lines[i].trimLeft().startsWith('@')) {
    i--;
  }
  final doc = <String>[];
  while (i >= 0 && lines[i].trimLeft().startsWith('///')) {
    doc.insert(0, lines[i--]);
  }
  return _docText(doc.join('\n'));
}

/// A doc comment's text: `///` stripped, code fences kept, `[Ref]` →
/// `` `Ref` ``.
String _docText(String comment) {
  final text = comment
      .split('\n')
      .map((l) => l.trimLeft())
      .where((l) => l.startsWith('///'))
      .map((l) => l.length > 3 && l[3] == ' ' ? l.substring(4) : l.substring(3))
      .join('\n')
      .trim();
  var inFence = false;
  return text
      .split('\n')
      .map((line) {
        if (line.trimLeft().startsWith('```')) inFence = !inFence;
        if (inFence || line.trimLeft().startsWith('```')) return line;
        final parts = line.split('`');
        for (var i = 0; i < parts.length; i += 2) {
          parts[i] = parts[i].replaceAllMapped(
            RegExp(r'(?<!\[)\[([A-Za-z_][\w.]*)\](?![(\[])'),
            (m) => '`${m[1]}`',
          );
        }
        return parts.join('`');
      })
      .join('\n');
}

List<String> _paragraphs(String doc) {
  // Split on blank lines outside code fences.
  final out = <String>[];
  final current = <String>[];
  var inFence = false;
  for (final line in doc.split('\n')) {
    if (line.trimLeft().startsWith('```')) inFence = !inFence;
    if (!inFence && line.trim().isEmpty) {
      if (current.isNotEmpty) out.add(current.join('\n'));
      current.clear();
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) out.add(current.join('\n'));
  return out;
}

String _firstSentence(String doc) {
  final first = _paragraphs(doc).first.replaceAll('\n', ' ');
  final end = first.indexOf(RegExp(r'\.(\s|$)'));
  return end < 0 ? first : first.substring(0, end + 1);
}

/// What a table cell holding [doc]'s first sentence leaves out: the other
/// paragraphs, and the first one whole when it says more than that
/// sentence, so no paragraph is split between the cell and the block below
/// the table. Empty when the first sentence is the whole comment.
String _beyondFirstSentence(String doc) {
  final paragraphs = _paragraphs(doc);
  final first = paragraphs.first.replaceAll('\n', ' ').trim();
  final whole = first == _firstSentence(doc);
  return (whole ? paragraphs.skip(1) : paragraphs).join('\n\n');
}

/// A table cell: the first paragraph, on one line, pipes escaped.
String _cell(String doc) {
  final paragraphs = _paragraphs(doc);
  if (paragraphs.isEmpty) return '';
  return _pipe(_mdx(paragraphs.first.replaceAll('\n', ' ')));
}

String _pipe(String s) => s.replaceAll('|', r'\|');

String _html(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Prose made safe for MDX: `{`, `}` and `<` escaped outside code spans and
/// fences, so a doc comment cannot open a JSX expression or tag.
String _mdx(String text) {
  final out = StringBuffer();
  var inFence = false;
  for (final line in text.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      out.writeln(line);
      continue;
    }
    if (inFence) {
      out.writeln(line);
      continue;
    }
    final parts = line.split('`');
    for (var i = 0; i < parts.length; i += 2) {
      parts[i] = parts[i]
          .replaceAll('{', r'\{')
          .replaceAll('}', r'\}')
          .replaceAll('<', '&lt;');
    }
    out.writeln(parts.join('`'));
  }
  return out.toString().trimRight();
}
