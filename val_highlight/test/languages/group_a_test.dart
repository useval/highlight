// Edge cases for Kotlin, Java, Swift, Objective-C, C++, C#, Groovy and
// Scala.
import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import '../helpers.dart';

void main() {
  group('kotlin', () {
    HighlightResult hl(String code) => highlightChecked(code, kotlinLanguage);

    test('templates in normal and raw strings', () {
      final r = hl(r'val s = "a $name ${f(1)} \n"; val raw = """x $y \n z"""');
      expect(scopeAt(r, r'$name'), Scopes.interpolation);
      expect(scopesAt(r, 'f('), [
        Scopes.string,
        Scopes.interpolation,
        Scopes.function,
      ]);
      expect(scopeAt(r, r'\n"'), Scopes.stringEscape);
      expect(scopeAt(r, r'$y'), Scopes.interpolation);
      // Raw strings have no escapes.
      expect(scopeAt(r, r'\n z'), Scopes.string);
    });

    test('nested block comments and labels', () {
      final r = hl(
        '/* a /* b */ c */ x\nouter@ for (i in 0 until 3) break@outer',
      );
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, ' x'), isNull);
      expect(scopeAt(r, 'outer@'), Scopes.meta);
      expect(scopeAt(r, '@outer'), Scopes.meta);
    });

    test('numbers with suffixes and plain numbers', () {
      final r = hl('val a = 1; val b = 0xFFL; val c = 2.5f; val d = 1_000u');
      for (final n in ['1;', '0xFFL', '2.5f', '1_000u']) {
        expect(scopeAt(r, n), Scopes.number, reason: n);
      }
    });

    test('names after a dot are members', () {
      final r = hl('list.map { it }.filter { it > 0 }.when');
      expect(scopeAt(r, 'map'), isNull);
      expect(scopeAt(r, 'it }'), Scopes.variableLanguage);
      expect(scopeAt(r, 'when'), isNull);
    });
  });

  group('java', () {
    test('text blocks, records, sealed and non-sealed', () {
      final r = highlightChecked(
        'sealed interface S permits A {}\nnon-sealed class A implements S {}\n'
        'record P(int x) {}\nString t = """\n  a "b" \\t\n  """; int n = 7;',
        javaLanguage,
      );
      expect(scopeAt(r, 'permits'), Scopes.keyword);
      expect(scopeAt(r, 'non-sealed'), Scopes.keyword);
      expect(scopeAt(r, 'record'), Scopes.keyword);
      expect(scopeAt(r, 'a "b"'), Scopes.string);
      expect(scopeAt(r, r'\t'), Scopes.stringEscape);
      expect(scopeAt(r, '7;'), Scopes.number);
    });

    test('annotations and chars', () {
      final r = highlightChecked(
        "@Override @SuppressWarnings(\"x\") char c = '\\u0041';",
        javaLanguage,
      );
      expect(scopeAt(r, '@Override'), Scopes.meta);
      expect(scopeAt(r, "'"), Scopes.string);
    });
  });

  group('swift', () {
    HighlightResult hl(String code) => highlightChecked(code, swiftLanguage);

    test('interpolation with nested parentheses', () {
      final r = hl(r'let s = "a \(f(x) + (y * 2)) b \t"');
      expect(scopesAt(r, 'f('), [
        Scopes.string,
        Scopes.interpolation,
        Scopes.function,
      ]);
      expect(scopeAt(r, ' b '), Scopes.string);
      expect(scopeAt(r, r'\t'), Scopes.stringEscape);
    });

    test('raw strings close only with a matching # count', () {
      final r = hl('let a = #"x " y"#; let b = ##"p "# q"##; let c = 1');
      expect(scopeAt(r, ' y'), Scopes.string);
      expect(scopeAt(r, ' q'), Scopes.string);
      expect(scopeAt(r, 'let c'), Scopes.keyword);
    });

    test('nested comments, directives, attributes, closure args', () {
      final r = hl(
        '/* a /* b */ c */\n#if DEBUG\n@MainActor func f() { xs.map { \$0 } }\n'
        '#endif',
      );
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, '#if'), Scopes.meta);
      expect(scopeAt(r, '@MainActor'), Scopes.meta);
      expect(scopeAt(r, r'$0'), Scopes.variable);
      expect(scopeAt(r, '#endif'), Scopes.meta);
    });
  });

  group('objective-c', () {
    test('@-directives, @"strings", selectors and literals', () {
      final r = highlightChecked(
        '@interface A : NSObject\n@property (nonatomic) BOOL on;\n@end\n'
        '[self addName:@"x\\n" flag:YES]; id n = @42;',
        objectiveCLanguage,
      );
      expect(scopeAt(r, '@interface'), Scopes.keyword);
      expect(scopeAt(r, 'nonatomic'), Scopes.keyword);
      expect(scopeAt(r, 'BOOL'), Scopes.typeBuiltin);
      expect(scopeAt(r, '@end'), Scopes.keyword);
      expect(scopeAt(r, 'addName'), Scopes.function);
      expect(scopeAt(r, '@"x'), Scopes.string);
      expect(scopeAt(r, r'\n'), Scopes.stringEscape);
      expect(scopeAt(r, 'YES'), Scopes.literal);
      expect(scopeAt(r, '42'), Scopes.number);
    });
  });

  group('c++', () {
    test('raw strings with delimiters', () {
      final r = highlightChecked(
        'auto s = R"x(a )" b)x"; int n = 1;',
        cppLanguage,
      );
      expect(scopeAt(r, ' b'), Scopes.string);
      expect(scopeAt(r, 'int'), Scopes.typeBuiltin);
    });

    test('attributes, namespaces, digit separators, templates', () {
      final r = highlightChecked(
        '[[nodiscard]] std::vector<int> f() { return {1\'000}; }\n'
        'template <typename T> concept C = requires { T{}; };',
        cppLanguage,
      );
      expect(scopeAt(r, '[[nodiscard]]'), Scopes.meta);
      expect(scopeAt(r, 'std'), Scopes.type);
      expect(scopeAt(r, "1'000"), Scopes.number);
      expect(scopeAt(r, 'template'), Scopes.keyword);
      expect(scopeAt(r, 'concept'), Scopes.keyword);
      expect(scopeAt(r, 'requires'), Scopes.keyword);
    });
  });

  group('c#', () {
    HighlightResult hl(String code) => highlightChecked(code, csharpLanguage);

    test('verbatim, interpolated and raw strings', () {
      final r = hl(
        'var a = @"C:\\x ""q"" y"; var b = \$"n={n:N2} {{lit}}";\n'
        'var c = """\n raw "text" \\n\n """; var d = 1;',
      );
      expect(scopeAt(r, r'C:\x'), Scopes.string);
      expect(scopeAt(r, '""q'), Scopes.stringEscape);
      expect(scopesAt(r, '{n'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, '{{'), Scopes.stringEscape);
      expect(scopeAt(r, 'raw "text"'), Scopes.string);
      expect(scopeAt(r, 'var d'), Scopes.keyword);
    });

    test(r'$$ raw strings interpolate {{x}} only', () {
      final r = hl('var j = \$\$"""\n{ "id": {{id}} }\n""";');
      expect(scopeAt(r, '{ "id"'), Scopes.string);
      expect(scopeAt(r, '{{id}}'), Scopes.interpolation);
    });

    test('PascalCase calls are functions; attributes; regions', () {
      final r = hl(
        '[Serializable]\nclass A {\n #region X\n void Run() => Console.WriteLine(1);\n'
        ' #endregion\n}',
      );
      expect(scopeAt(r, 'Serializable'), Scopes.meta);
      expect(scopeAt(r, '#region'), Scopes.meta);
      expect(scopeAt(r, 'Run'), Scopes.function);
      expect(scopeAt(r, 'WriteLine'), Scopes.function);
    });
  });

  group('groovy', () {
    test('Gradle blocks and command calls', () {
      final r = highlightChecked(
        "plugins { id 'x' }\ndependencies {\n  implementation \"a:b:\$v\"\n}",
        groovyLanguage,
      );
      expect(scopeAt(r, 'plugins'), Scopes.function);
      expect(scopeAt(r, 'id '), Scopes.function);
      expect(scopeAt(r, 'implementation'), Scopes.function);
      expect(scopeAt(r, r'$v'), Scopes.interpolation);
    });

    test("''' strings do not interpolate", () {
      final r = highlightChecked(
        "def a = '''x \${y}'''; def b = \"\"\"p \${q}\"\"\"",
        groovyLanguage,
      );
      expect(scopeAt(r, r'${y}'), Scopes.string);
      expect(scopeAt(r, r'${q}'), Scopes.interpolation);
    });
  });

  group('scala', () {
    test('interpolators, raw strings and nested comments', () {
      final r = highlightChecked(
        's"a \$x \${y + 1}" + raw"\\n" + f"\$p%.2f" /* a /* b */ c */ val z = 1',
        scalaLanguage,
      );
      expect(scopeAt(r, r'$x'), Scopes.interpolation);
      expect(scopeAt(r, r'\n'), Scopes.string);
      expect(scopeAt(r, r'$p'), Scopes.interpolation);
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, 'val z'), Scopes.keyword);
    });

    test('Scala 3 keywords', () {
      final r = highlightChecked(
        'given Ord[Int] with\n  extension (x: Int) def twice = x * 2\n'
        'enum Color:\n  case Red\nend Color',
        scalaLanguage,
      );
      for (final k in ['given', 'with', 'extension', 'enum', 'end']) {
        expect(scopeAt(r, k), Scopes.keyword, reason: k);
      }
    });
  });

  test('group A signatures detect their languages', () {
    const detector = LanguageDetector();
    final samples = <Grammar, String>{
      kotlinLanguage:
          'package app\n\ndata class User(val name: String)\n'
          'fun main() {\n  val u = User("a")\n  println(u)\n}\n',
      javaLanguage:
          'package app;\n\nimport java.util.List;\n\npublic class Main {\n'
          '  public static void main(String[] args) {\n'
          '    System.out.println("hi");\n  }\n}\n',
      swiftLanguage:
          'import SwiftUI\n\nstruct ContentView: View {\n'
          '  var body: some View { Text("hi") }\n}\n'
          'func load() async throws -> Int { guard let x = y else { return 0 } }\n',
      objectiveCLanguage:
          '#import <Foundation/Foundation.h>\n\n@interface A : NSObject\n'
          '@property (nonatomic) NSString *name;\n@end\n',
      cppLanguage:
          '#include <iostream>\n#include <vector>\n\nnamespace app {\n'
          'template <typename T> T twice(T x) { return x * 2; }\n}\n'
          'int main() { std::cout << app::twice(2); }\n',
      csharpLanguage:
          'using System;\n\nnamespace App;\n\npublic class User {\n'
          '  public string Name { get; set; }\n'
          '  static void Main() => Console.WriteLine("hi");\n}\n',
      groovyLanguage:
          "plugins {\n  id 'java'\n}\n\ndependencies {\n"
          "  implementation 'a:b:1.0'\n}\n",
      scalaLanguage:
          'import scala.util.Try\n\ncase class User(name: String)\n\n'
          'object Main extends App {\n'
          '  def greet(u: User): String = s"hi \${u.name}"\n}\n',
    };
    for (final MapEntry(key: language, value: code) in samples.entries) {
      expect(
        detector.detect(code, allLanguages)?.language.name,
        language.name,
        reason: language.name,
      );
    }
  });
}
