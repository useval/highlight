import 'package:test/test.dart';
import 'package:val_highlight/src/engine/compiler.dart';
import 'package:val_highlight/advanced.dart';
import 'package:val_highlight/languages/all.dart';

import '../helpers.dart';

void main() {
  test('group B grammars compile with dispatchable top levels', () {
    for (final language in [
      rubyLanguage,
      luaLanguage,
      perlLanguage,
      phpLanguage,
      powershellLanguage,
      rLanguage,
      juliaLanguage,
      elixirLanguage,
    ]) {
      final compiled = CompiledGrammar.of(language)..compileAll();
      expect(compiled.root.dispatch, isNotNull, reason: language.name);
    }
  });

  group('ruby', () {
    HighlightResult hl(String code) => highlightChecked(code, rubyLanguage);

    test('interpolation, symbols, hash keys, variables', () {
      final r = hl('puts "x #{@a + 1}", :sym, key: \$g, @@c');
      expect(scopesAt(r, '@a'), [
        Scopes.string,
        Scopes.interpolation,
        Scopes.variable,
      ]);
      expect(scopeAt(r, ':sym'), 'literal.symbol');
      expect(scopeAt(r, 'key:'), 'literal.symbol');
      expect(scopeAt(r, r'$g'), Scopes.variable);
      expect(scopeAt(r, '@@c'), Scopes.variable);
    });

    test('percent literals nest and only %q-style skip interpolation', () {
      final r = hl(r'%w(a (b) c) + %Q[#{x}] + %q{#{y}} + done');
      expect(scopeAt(r, '(b)'), Scopes.string);
      expect(scopesAt(r, 'x'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, '#{y}'), Scopes.string);
      expect(scopeAt(r, 'done'), isNull);
    });

    test('heredocs: squiggly, quoted, and the rest of the line', () {
      final r = hl(
        "a = <<~EOS.strip\n  it's #{b}\nEOS\nc = <<-'X'\n#{no}\n  X\nd",
      );
      expect(scopeAt(r, "it's"), Scopes.string);
      expect(scopesAt(r, 'b}'), [Scopes.interpolation]);
      expect(scopeAt(r, '.strip'), isNull);
      expect(scopeAt(r, '#{no}'), Scopes.string);
      expect(scopeAt(r, 'd'), isNull);
    });

    test('regex only where an expression starts; division stays', () {
      final r = hl('x = a / b / c\ny = /ab+/i');
      expect(scoped(r).where((t) => t.$2 == Scopes.regexp).single.$1, '/ab+/i');
    });

    test('=begin/=end and __END__', () {
      final r = hl('=begin\ndef x\n=end\ny = 1\n__END__\n"open');
      expect(scopeAt(r, 'def x'), Scopes.comment);
      expect(scopeAt(r, '1'), Scopes.number);
      expect(scopeAt(r, '"open'), Scopes.comment);
    });

    test('methods with ? and ! and members are not keywords', () {
      final r = hl('def valid?; x.end; obj.class; a != b; defined?(z); end');
      expect(scopeAt(r, 'valid?'), Scopes.function);
      expect(scopeAt(r, 'end;'), isNull);
      expect(scopeAt(r, 'class;'), isNull);
      expect(scopeAt(r, 'defined?'), Scopes.keyword);
    });

    test('real-code regressions', () {
      final r = hl(
        "class <<self\n  x = ?( + ?\"\nend\n"
        'def `(cmd); end\n'
        're = / *(a)/\nm = /\n  a # b\n/x\n'
        'a.map(&:first)\nn = 1<<k\ndone',
      );
      expect(scopeAt(r, 'self'), Scopes.variableLanguage);
      expect(scopeAt(r, '?('), Scopes.string);
      expect(scopeAt(r, '`'), Scopes.function);
      expect(scopeAt(r, '/ *(a)/'), Scopes.regexp);
      expect(scopeAt(r, '# b'), Scopes.regexp);
      expect(scopeAt(r, ':first'), 'literal.symbol');
      expect(scopeAt(r, 'k'), isNull);
      expect(scopeAt(r, 'done'), isNull);
    });

    test('Podfile by file name', () {
      final registry = allLanguagesRegistry();
      expect(registry.forFileName('ios/Podfile'), same(rubyLanguage));
      expect(registry.forFileName('fastlane/Fastfile'), same(rubyLanguage));
    });
  });

  group('lua', () {
    test('long brackets need matching levels', () {
      final r = highlightChecked(
        's = [==[ a ]] b ]=] c ]==]\n--[[ c ]] x = 1',
        luaLanguage,
      );
      expect(scopeAt(r, ' b '), Scopes.string);
      expect(scopeAt(r, ' c ]==]'), Scopes.string);
      expect(scopeAt(r, 'x ='), isNull);
      expect(scopeAt(r, '1'), Scopes.number);
    });

    test('methods, length operator and concatenation', () {
      final r = highlightChecked('print(#t, s:upper(), a .. b)', luaLanguage);
      expect(scopeAt(r, 'upper'), Scopes.function);
      expect(scopeAt(r, '#'), Scopes.operator);
      expect(scopeAt(r, '..'), Scopes.operator);
    });
  });

  test('lua: call lookahead stays on its line (incremental)', () {
    const text = 'a = child.id\n\n  return x';
    final doc = IncrementalHighlighter(language: luaLanguage, text: text);
    final edited = text.replaceFirst('\n\n', '\n\n"');
    final incremental = doc.update(edited);
    final full = const Highlighter().highlight(edited, language: luaLanguage);
    expect(
      [
        for (final t in incremental.tokens)
          (t.start, t.end, t.scopes.join('>')),
      ],
      [for (final t in full.tokens) (t.start, t.end, t.scopes.join('>'))],
    );
  });

  group('perl', () {
    HighlightResult hl(String code) => highlightChecked(code, perlLanguage);

    test('sigils, \$# and comments', () {
      final r = hl(r'my @a = (1); print $#a; # note');
      expect(scopeAt(r, '@a'), Scopes.variable);
      expect(scopeAt(r, r'$#a'), Scopes.variable);
      expect(scopeAt(r, '# note'), Scopes.comment);
    });

    test('quote-like operators with nesting and delimiters', () {
      final r = hl(r'my $x = qq{a {b} $c} . q(d) . qw/e f/; $y =~ s/a/b/g; z');
      expect(scopeAt(r, '{b}'), Scopes.string);
      expect(scopesAt(r, r'$c'), [Scopes.string, Scopes.variable]);
      expect(scopeAt(r, 'q(d)'), Scopes.string);
      expect(scopeAt(r, 's/a/b/g'), Scopes.regexp);
      expect(scopeAt(r, 'z'), isNull);
    });

    test('hash keys before => are not quote operators', () {
      final r = hl('my %h = (q => 1, s => 2, y => 3);');
      expect(scopeAt(r, 'q =>'), Scopes.property);
      expect(scopeAt(r, '1'), Scopes.number);
      expect(scopeAt(r, '3'), Scopes.number);
    });

    test('POD and heredocs', () {
      final r = hl('=pod\nmy \$x;\n=cut\nprint <<EOT;\nHi \$name\nEOT\nexit;');
      expect(scopeAt(r, r'my $x'), Scopes.commentDoc);
      expect(scopeAt(r, 'Hi'), Scopes.string);
      expect(scopeAt(r, r'$name'), Scopes.variable);
      expect(scopeAt(r, 'exit'), Scopes.function);
    });
  });

  group('php', () {
    HighlightResult hl(String code) => highlightChecked(code, phpLanguage);

    test('snippets without <?php are PHP', () {
      final r = hl(r'$x = "a $b {$c->d}"; // it');
      expect(scopeAt(r, r'$x'), Scopes.variable);
      expect(scopesAt(r, r'$b'), [Scopes.string, Scopes.variable]);
      expect(scopeAt(r, '// it'), Scopes.comment);
    });

    test('?> switches to HTML, <?php back', () {
      final r = hl('<?php echo 1; ?>\n<p class="a">don\'t</p>\n<?php \$y = 2;');
      expect(scopeAt(r, 'p class'), Scopes.tag);
      expect(scopeAt(r, "don't"), isNull);
      expect(scopeAt(r, r'$y'), Scopes.variable);
    });

    test('a file starting with markup is HTML first', () {
      final r = hl('<div>it\'s <?= \$name ?></div>');
      expect(scopeAt(r, 'div'), Scopes.tag);
      expect(scopeAt(r, "it's"), isNull);
      expect(scopeAt(r, r'$name'), Scopes.variable);
    });

    test('line comments end at ?>', () {
      final r = hl('<?php // note ?><b>x</b>');
      expect(scopeAt(r, 'b>'), Scopes.tag);
    });

    test('heredoc and nowdoc', () {
      final r = hl(
        "\$a = <<<EOT\n  x \$v\n  EOT;\n\$b = <<<'N'\n\$w\nN;\n\$c;",
      );
      expect(scopesAt(r, r'$v'), [Scopes.variable]);
      expect(scopeAt(r, r'$w'), Scopes.string);
      expect(scopeAt(r, r'$c'), Scopes.variable);
    });
  });

  group('powershell', () {
    HighlightResult hl(String code) =>
        highlightChecked(code, powershellLanguage);

    test('cmdlets, parameters, operators and case-insensitive keywords', () {
      final r = hl(r'IF ($a -EQ 1) { Get-Item -Path $p }');
      expect(scopeAt(r, 'IF'), Scopes.keyword);
      expect(scopeAt(r, '-EQ'), Scopes.operator);
      expect(scopeAt(r, 'Get-Item'), Scopes.function);
      expect(scopeAt(r, '-Path'), Scopes.attribute);
    });

    test('backtick escapes, subexpressions and here-strings', () {
      final r = hl('"a`tb \$(\$x.Y) c"\n@\'\n\$no\n\'@\n\$z');
      expect(scopeAt(r, '`t'), Scopes.stringEscape);
      expect(scopesAt(r, r'$x'), [
        Scopes.string,
        Scopes.interpolation,
        Scopes.variable,
      ]);
      expect(scopeAt(r, r'$no'), Scopes.string);
      expect(scopeAt(r, r'$z'), Scopes.variable);
    });
  });

  group('r', () {
    test('raw strings, pipes, dotted names', () {
      final r = highlightChecked(
        r'x <- r"-(a)"b)-" %>% is.na(y) |> f()',
        rLanguage,
      );
      expect(scopeAt(r, 'b)'), Scopes.string);
      expect(scopeAt(r, '%>%'), Scopes.operator);
      expect(scopeAt(r, 'is.na'), Scopes.function);
    });
  });

  group('julia', () {
    HighlightResult hl(String code) => highlightChecked(code, juliaLanguage);

    test('transpose is not a character literal', () {
      final r = hl("B = A' * x'; c = 'q'");
      expect(scopeAt(r, "' * x"), isNull);
      expect(scopeAt(r, "'q'"), Scopes.string);
    });

    test('interpolation, symbols, types and nested comments', () {
      final r = hl('#= a #= b =# c =#\ns = "\$x and \$(f(y))" :: Int; :sym');
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopesAt(r, r'$x'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, 'Int'), Scopes.type);
      expect(scopeAt(r, ':sym'), 'literal.symbol');
    });
  });

  group('elixir', () {
    HighlightResult hl(String code) => highlightChecked(code, elixirLanguage);

    test('sigils, atoms, keyword keys and interpolation', () {
      final r = hl('x = ~r/a+/i; y = ~S(#{no}); f(do: :ok, "#{z}")');
      expect(scopeAt(r, '~r/a+/i'), Scopes.regexp);
      expect(scopeAt(r, '#{no}'), Scopes.string);
      expect(scopeAt(r, 'do:'), 'literal.symbol');
      expect(scopeAt(r, ':ok'), 'literal.symbol');
      expect(scopesAt(r, 'z'), [Scopes.string, Scopes.interpolation]);
    });

    test('def names and predicates', () {
      final r = hl('defp valid?(x), do: x.end?');
      expect(scopeAt(r, 'valid?'), Scopes.function);
      expect(scopeAt(r, 'end?'), isNull);
    });
  });
}
