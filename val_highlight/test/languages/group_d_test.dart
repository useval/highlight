// Edge cases for the config, build and style-sheet grammars.
import 'package:test/test.dart';
import 'package:val_highlight/src/engine/compiler.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';

import '../helpers.dart';

void main() {
  const languages = [
    dockerfileLanguage, makefileLanguage, cmakeLanguage, tomlLanguage, //
    iniLanguage, protobufLanguage, graphqlLanguage, hclLanguage,
    nginxLanguage, latexLanguage, scssLanguage, lessLanguage, batchLanguage,
  ];

  test('every grammar compiles and its top level is dispatchable', () {
    for (final language in languages) {
      final compiled = CompiledGrammar.of(language)..compileAll();
      expect(
        compiled.root.dispatch,
        isNotNull,
        reason: '${language.name} top level',
      );
    }
  });

  test('registry finds files by name and extension', () {
    final registry = allLanguagesRegistry();
    expect(registry.forFileName('app/Dockerfile'), same(dockerfileLanguage));
    expect(registry.forFileName('Makefile'), same(makefileLanguage));
    expect(registry.forFileName('src/CMakeLists.txt'), same(cmakeLanguage));
    expect(registry.forFileName('Cargo.toml'), same(tomlLanguage));
    expect(registry.forFileName('gradle.properties'), same(iniLanguage));
    expect(registry.forFileName('main.tf'), same(hclLanguage));
    expect(registry.forFileName('build.bat'), same(batchLanguage));
  });

  group('dockerfile', () {
    test('instructions continue across backslashes', () {
      final r = highlightChecked(
        'RUN apt-get update && \\\n    apt-get install -y curl\nUSER app\n',
        dockerfileLanguage,
      );
      expect(scopeAt(r, 'RUN'), Scopes.keyword);
      expect(scopeAt(r, '&&'), Scopes.operator);
      expect(scopeAt(r, 'USER'), Scopes.keyword);
    });

    test('heredocs are strings and end at their delimiter', () {
      final r = highlightChecked(
        'RUN <<SCRIPT\nFROM is not an instruction here\nSCRIPT\nCMD ["x"]\n',
        dockerfileLanguage,
      );
      expect(scopeAt(r, 'FROM is'), Scopes.string);
      expect(scopeAt(r, 'CMD'), Scopes.keyword);
    });

    test('lower-case instructions and FROM … AS', () {
      final r = highlightChecked('from node:20 as build\n', dockerfileLanguage);
      expect(scopeAt(r, 'from'), Scopes.keyword);
      expect(scopeAt(r, 'as'), Scopes.keyword);
    });
  });

  group('makefile', () {
    test('variables, targets and recipes', () {
      final r = highlightChecked(
        'OUT := build\n\$(OUT)/app: main.o\n\t@\$(CC) -o \$@ \$^\n',
        makefileLanguage,
      );
      expect(scopeAt(r, 'OUT :='), Scopes.variable);
      expect(scopeAt(r, '/app'), Scopes.function);
      expect(scopeAt(r, '@'), Scopes.operator);
      expect(scopeAt(r, r'$@'), Scopes.variable);
    });

    test(r'$$ escapes a dollar in recipes', () {
      final r = highlightChecked('x:\n\techo \$\$HOME\n', makefileLanguage);
      expect(scopeAt(r, r'$$'), Scopes.stringEscape);
    });
  });

  group('cmake', () {
    test('bracket arguments and comments with = levels', () {
      final r = highlightChecked(
        'set(X [==[ a ]] b ]=] c ]==])\n#[=[ note ]] still ]=]\nmessage(done)\n',
        cmakeLanguage,
      );
      expect(scopeAt(r, ' b '), Scopes.string);
      expect(scopeAt(r, ' still'), Scopes.comment);
      expect(scopeAt(r, 'message'), Scopes.function);
    });

    test('nested variable references and generator expressions', () {
      final r = highlightChecked(
        r'target_link_libraries(a ${LIB_${TYPE}} $<$<CONFIG:Debug>:dbg>)',
        cmakeLanguage,
      );
      expect(scopesAt(r, 'TYPE'), [Scopes.variable, Scopes.variable]);
      expect(scopeAt(r, 'CONFIG'), Scopes.meta);
    });
  });

  group('toml', () {
    test('dotted and quoted keys, literal strings, dates', () {
      final r = highlightChecked(
        "a.\"b c\".d = 'C:\\\\path'\nwhen = 1979-05-27T07:32:00-08:00\n",
        tomlLanguage,
      );
      expect(scopeAt(r, 'a.'), Scopes.property);
      expect(scopeAt(r, 'path'), Scopes.string);
      expect(scopeAt(r, '1979'), Scopes.number);
    });

    test('multi-line basic strings', () {
      final r = highlightChecked('s = """\nline\n"""\nn = 1\n', tomlLanguage);
      expect(scopeAt(r, 'line'), Scopes.string);
      expect(scopeAt(r, '1\n'), Scopes.number);
    });
  });

  group('ini', () {
    test('properties continuation lines stay in the value', () {
      final r = highlightChecked(
        'msg = one \\\n  two = not a key\nnext = 3\n',
        iniLanguage,
      );
      expect(scopeAt(r, '  two'), isNull);
      expect(scopeAt(r, 'next'), Scopes.property);
      expect(scopeAt(r, '3'), Scopes.number);
    });

    test('literals only when they are the whole value', () {
      final r = highlightChecked('a = true\nb = true story\n', iniLanguage);
      expect(scopeAt(r, 'true\n'), Scopes.literal);
      expect(scopeAt(r, 'true story'), isNull);
    });
  });

  test('protobuf: rpc names are functions, enum values plain', () {
    final r = highlightChecked(
      'service S { rpc Get(Req) returns (Res); }\nenum E { E_ONE = 1; }\n',
      protobufLanguage,
    );
    expect(scopeAt(r, 'Get'), Scopes.function);
    expect(scopeAt(r, 'Req'), Scopes.type);
    expect(scopeAt(r, 'E_ONE'), isNull);
  });

  test('graphql: keyword-like argument names are properties', () {
    final r = highlightChecked(
      r'mutation { update(input: $in, type: A) { id } }',
      graphqlLanguage,
    );
    expect(scopeAt(r, 'input'), Scopes.property);
    expect(scopeAt(r, 'type:'), Scopes.property);
    expect(scopeAt(r, r'$in'), Scopes.variable);
  });

  group('hcl', () {
    test('interpolation and heredocs', () {
      final r = highlightChecked(
        'a = "x-\${var.env}"\nb = <<-EOT\n  hi \${local.n}\n  EOT\nc = 1\n',
        hclLanguage,
      );
      expect(scopeAt(r, 'var'), Scopes.variableLanguage);
      expect(scopeAt(r, 'hi'), Scopes.string);
      expect(scopeAt(r, 'c ='), Scopes.property);
    });

    test('block headers with labels', () {
      final r = highlightChecked(
        'resource "aws_instance" "web" {\n  ami = "x"\n}\n',
        hclLanguage,
      );
      expect(scopeAt(r, 'resource'), Scopes.keyword);
      expect(scopeAt(r, 'ami'), Scopes.property);
    });
  });

  test('nginx: directives after { and ; on one line', () {
    final r = highlightChecked(
      r'location / { root /srv; index index.html; }',
      nginxLanguage,
    );
    expect(scopeAt(r, 'location'), Scopes.keyword);
    expect(scopeAt(r, 'root'), Scopes.property);
    expect(scopeAt(r, 'index '), Scopes.property);
  });

  group('latex', () {
    test(r'escaped \% and \$ are not comments or math', () {
      final r = highlightChecked(
        r'50\% off, only \$5'
        '\nnext line',
        latexLanguage,
      );
      expect(scopeAt(r, ' off'), isNull);
      expect(scopeAt(r, 'next'), isNull);
    });

    test('unclosed inline math stops at a blank line', () {
      final r = highlightChecked(
        'costs \$5 today\n\n\\section{Next}\n',
        latexLanguage,
      );
      expect(scopeAt(r, '5 today'), Scopes.code);
      expect(scopeAt(r, r'\section'), Scopes.keyword);
    });
  });

  group('scss and less', () {
    test('declarations with interpolated values', () {
      final r = highlightChecked(
        r'.a { font: #{$s}/1.5 serif; &:hover { color: red; } }',
        scssLanguage,
      );
      expect(scopeAt(r, 'font'), Scopes.property);
      expect(scopeAt(r, 'color'), Scopes.property);
      expect(scopeAt(r, ':hover'), Scopes.keyword);
    });

    test('less variables versus at-rules', () {
      final r = highlightChecked(
        '@w: 10px;\n@media (min-width: @w) { .m(); }\n',
        lessLanguage,
      );
      expect(scopeAt(r, '@w:'), Scopes.variable);
      expect(scopeAt(r, '@media'), Scopes.keyword);
      expect(scopeAt(r, 'min-width'), Scopes.property);
      expect(scopeAt(r, '.m'), Scopes.function);
    });
  });

  group('batch', () {
    test('comments, variables and labels', () {
      final r = highlightChecked(
        '@echo off\nREM note\nset X=%~dp0\necho !X! %%i\ngoto :done\n:done\n',
        batchLanguage,
      );
      expect(scopeAt(r, 'REM'), Scopes.comment);
      expect(scopeAt(r, '%~dp0'), Scopes.variable);
      expect(scopeAt(r, '!X!'), Scopes.variable);
      expect(scopeAt(r, '%%i'), Scopes.variable);
      expect(scopeAt(r, ':done\n:'), Scopes.function);
    });

    test('rem inside a word is not a comment', () {
      final r = highlightChecked('echo premium\n', batchLanguage);
      expect(scopeAt(r, 'premium'), isNull);
    });
  });
}
