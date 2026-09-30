import 'package:test/test.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

import '../helpers.dart';

void main() {
  group('rust', () {
    HighlightResult hl(String code) => highlightChecked(code, rustLanguage);

    test('lifetimes are not strings; char literals are', () {
      final r = hl("fn f<'a>(x: &'a str) -> char { 'x' }\nlet y = 1;");
      expect(scopeAt(r, "'a>"), Scopes.variable);
      expect(scopeAt(r, "'x'"), Scopes.string);
      expect(scopeAt(r, 'let'), Scopes.keyword);
    });

    test('escaped quote and byte chars', () {
      final r = hl(r"let a = '\''; let b = b'\n'; let c = '\u{1F600}'; 42");
      expect(scopeAt(r, r"'\''"), Scopes.string);
      expect(scopeAt(r, r"b'\n'"), Scopes.string);
      expect(scopeAt(r, r"'\u{1F600}'"), Scopes.string);
      expect(scopeAt(r, '42'), Scopes.number);
    });

    test('raw strings close only on the matching hashes', () {
      final r = hl('let s = r##"a "# b"##; let t = 2;');
      expect(scopeAt(r, '"# b'), Scopes.string);
      expect(scopeAt(r, 'let t'), Scopes.keyword);
    });

    test('nested block comments and doc comments', () {
      final r = hl('/* a /* b */ c */ fn\n//! crate doc\n/// item doc\n');
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, 'fn'), Scopes.keyword);
      expect(scopeAt(r, 'crate doc'), Scopes.commentDoc);
      expect(scopeAt(r, 'item doc'), Scopes.commentDoc);
    });

    test('attributes, macros, numbers with suffixes', () {
      final r = hl('#[cfg(test)]\nvec![1u8, 0xFFi32, 2.5f64]; x != y;');
      expect(scopeAt(r, '#[cfg'), Scopes.meta);
      expect(scopeAt(r, 'vec!'), Scopes.function);
      expect(scopeAt(r, '1u8'), Scopes.number);
      expect(scopeAt(r, '0xFFi32'), Scopes.number);
      expect(scopeAt(r, '2.5f64'), Scopes.number);
      expect(scopeAt(r, 'x !='), isNull);
    });

    test('members are never keywords; constants are not types', () {
      final r = hl('a.match_x(); b.type; const MAX_LEN: usize = 3;');
      expect(scopeAt(r, 'match_x'), Scopes.function);
      expect(scopeAt(r, 'type;'), isNull);
      expect(scopeAt(r, 'MAX_LEN'), isNull);
    });
  });

  group('zig', () {
    test('multiline strings, builtins, quoted identifiers, int types', () {
      final r = highlightChecked(
        'const s =\n    \\\\line "one"\n;\nconst x: u7 = @intCast(y);\n'
        'var @"odd name" = 0;',
        zigLanguage,
      );
      expect(scopeAt(r, r'\\line'), Scopes.string);
      expect(scopeAt(r, 'u7'), Scopes.typeBuiltin);
      expect(scopeAt(r, '@intCast'), Scopes.function);
      expect(scopeAt(r, '@"odd'), Scopes.variable);
    });

    test('doc comments', () {
      final r = highlightChecked('//! top\n/// item\n// plain\n', zigLanguage);
      expect(scopeAt(r, 'top'), Scopes.commentDoc);
      expect(scopeAt(r, 'item'), Scopes.commentDoc);
      expect(scopeAt(r, 'plain'), Scopes.comment);
    });
  });

  group('haskell', () {
    HighlightResult hl(String code) => highlightChecked(code, haskellLanguage);

    test('comments versus dash operators', () {
      final r = hl('a --> b -- note\n|-- x\nc --- d');
      expect(scopeAt(r, '-->'), Scopes.operator);
      expect(scopeAt(r, '-- note'), Scopes.comment);
      expect(scopeAt(r, '|--'), Scopes.operator);
      expect(scopeAt(r, '--- d'), Scopes.comment);
    });

    test('primes in names are not character literals', () {
      final r = hl("f x' y'' = 'a' : x'\nmain = 1");
      expect(scopeAt(r, "x'"), isNull);
      expect(scopeAt(r, "'a'"), Scopes.string);
      expect(scopeAt(r, '1'), Scopes.number);
    });

    test('nested comments and pragmas', () {
      final r = hl('{-# INLINE f #-}\n{- a {- b -} c -} data T = T');
      expect(scopeAt(r, 'INLINE'), Scopes.meta);
      expect(scopeAt(r, ' c '), Scopes.comment);
      expect(scopeAt(r, 'data'), Scopes.keyword);
      expect(scopeAt(r, 'T ='), Scopes.type);
    });

    test('signatures name functions', () {
      final r = hl('lookup :: Int -> Maybe String');
      expect(scopeAt(r, 'lookup'), Scopes.function);
      expect(scopeAt(r, 'Maybe'), Scopes.typeBuiltin);
    });
  });

  group('ocaml', () {
    HighlightResult hl(String code) => highlightChecked(code, ocamlLanguage);

    test('type variables versus characters', () {
      final r = hl("type 'a t = 'a list\nlet c = 'x' and d = '\\n' in 1");
      expect(scopeAt(r, "'a t"), Scopes.type);
      expect(scopeAt(r, "'x'"), Scopes.string);
      expect(scopeAt(r, r"'\n'"), Scopes.string);
      expect(scopeAt(r, '1'), Scopes.number);
    });

    test('quoted strings and nested comments', () {
      final r = hl('let s = {id|a |} b|id} (* x (* y *) z *) let');
      expect(scopeAt(r, 'a |} b'), Scopes.string);
      expect(scopeAt(r, ' z '), Scopes.comment);
      expect(scopeAt(r, 'let'), Scopes.keyword);
    });
  });

  group('fsharp', () {
    HighlightResult hl(String code) => highlightChecked(code, fsharpLanguage);

    test('verbatim, triple-quoted and interpolated strings', () {
      final r = hl(
        r'let a = @"C:\x ""q""" in let b = $"n={n + 1} {{x}}" in '
        '"""raw "text" \\n"""',
      );
      expect(scopeAt(r, r'C:\x'), Scopes.string);
      expect(scopeAt(r, '""q'), Scopes.stringEscape);
      expect(scopesAt(r, 'n + 1'), [Scopes.string, Scopes.interpolation]);
      expect(scopeAt(r, '{{'), Scopes.stringEscape);
      expect(scopeAt(r, 'raw "text"'), Scopes.string);
    });

    test('computation expressions, attributes, generics', () {
      final r = hl("[<Literal>]\nlet! x = f ()\nlet g (v: 'T) = v");
      expect(scopeAt(r, 'Literal'), Scopes.meta);
      expect(scopeAt(r, 'let!'), Scopes.keyword);
      expect(scopeAt(r, "'T"), Scopes.type);
    });
  });

  group('clojure', () {
    HighlightResult hl(String code) => highlightChecked(code, clojureLanguage);

    test('keywords, regexes, characters and ratios', () {
      final r = hl(r'(re-find #"\d+" s) {:a 1 ::b 22/7} [\a \newline]');
      expect(scopeAt(r, 're-find'), Scopes.function);
      expect(scopeAt(r, '#"'), Scopes.regexp);
      expect(scopeAt(r, ':a'), Scopes.literal);
      expect(scopeAt(r, '::b'), Scopes.literal);
      expect(scopeAt(r, '22/7'), Scopes.number);
      expect(scopeAt(r, r'\newline'), Scopes.string);
    });

    test('special forms and comments', () {
      final r = hl('(defn f [x] (when-let [y x] y)) ; done');
      expect(scopeAt(r, 'defn'), Scopes.keyword);
      expect(scopeAt(r, 'when-let'), Scopes.keyword);
      expect(scopeAt(r, '; done'), Scopes.comment);
    });
  });

  group('erlang', () {
    HighlightResult hl(String code) => highlightChecked(code, erlangLanguage);

    test('atoms, variables, chars, bases, attributes', () {
      final r = hl(
        "-module(m).\nf(X) -> {'odd atom', X, \$a, 16#FF, ?MODULE}. % c",
      );
      expect(scopeAt(r, '-module'), Scopes.meta);
      expect(scopeAt(r, 'f('), Scopes.function);
      expect(scopeAt(r, 'X)'), Scopes.variable);
      expect(scopeAt(r, "'odd atom'"), Scopes.literal);
      expect(scopeAt(r, r'$a'), Scopes.string);
      expect(scopeAt(r, '16#FF'), Scopes.number);
      expect(scopeAt(r, '?MODULE'), Scopes.meta);
      expect(scopeAt(r, '% c'), Scopes.comment);
    });

    test('a quote in a char literal does not open an atom', () {
      final r = hl("f() -> \$'.\ng() -> ok.");
      expect(scopeAt(r, 'g('), Scopes.function);
    });
  });

  group('solidity', () {
    HighlightResult hl(String code) => highlightChecked(code, solidityLanguage);

    test('pragmas, natspec, sized types and units', () {
      final r = hl(
        'pragma solidity ^0.8.0;\n/// @notice hi\n'
        'uint256 x = 1 ether; bytes32 h = hex"ab"; int8 y;',
      );
      expect(scopeAt(r, 'solidity'), Scopes.meta);
      expect(scopeAt(r, '@notice'), Scopes.commentDoc);
      expect(scopeAt(r, 'uint256'), Scopes.typeBuiltin);
      expect(scopeAt(r, 'bytes32'), Scopes.typeBuiltin);
      expect(scopeAt(r, 'int8'), Scopes.typeBuiltin);
      expect(scopeAt(r, 'ether'), Scopes.number);
      expect(scopeAt(r, 'hex"ab"'), Scopes.string);
    });

    test('globals and members', () {
      final r = hl('msg.sender.transfer(1); abi.encode(x);');
      expect(scopeAt(r, 'msg'), Scopes.variableLanguage);
      expect(scopeAt(r, 'transfer'), Scopes.function);
      expect(scopeAt(r, 'abi'), Scopes.variableLanguage);
    });
  });

  group('nasm', () {
    HighlightResult hl(String code) => highlightChecked(code, nasmLanguage);

    test('labels, instructions, registers, numbers, case-insensitive', () {
      final r = hl(
        '_start:\n  MOV RAX, 0x3C ; exit\n  jnz .loop\n  add r10d, 1Fh\n'
        '  db 1010b, 17q\n',
      );
      expect(scopeAt(r, '_start'), Scopes.function);
      expect(scopeAt(r, 'MOV'), Scopes.function);
      expect(scopeAt(r, 'RAX'), Scopes.variable);
      expect(scopeAt(r, '0x3C'), Scopes.number);
      expect(scopeAt(r, '; exit'), Scopes.comment);
      expect(scopeAt(r, 'jnz'), Scopes.function);
      expect(scopeAt(r, 'r10d'), Scopes.variable);
      expect(scopeAt(r, '1Fh'), Scopes.number);
      expect(scopeAt(r, 'db'), Scopes.keyword);
      expect(scopeAt(r, '1010b'), Scopes.number);
      expect(scopeAt(r, '17q'), Scopes.number);
    });

    test('preprocessor and size keywords', () {
      final r = hl('%macro print 1\n  mov dword [rsp], eax\n%endmacro');
      expect(scopeAt(r, '%macro'), Scopes.meta);
      expect(scopeAt(r, 'dword'), Scopes.typeBuiltin);
      expect(scopeAt(r, '%endmacro'), Scopes.meta);
    });
  });

  test('detection finds each language from typical code', () {
    const detector = LanguageDetector();
    final samples = <Grammar, String>{
      rustLanguage:
          'use std::io;\n#[derive(Debug)]\nstruct P { x: i32 }\n'
          'fn main() {\n    let mut v = vec![1, 2];\n    println!("{:?}", v);\n}\n',
      zigLanguage:
          'const std = @import("std");\n\npub fn main() !void {\n'
          '    const x: u32 = 1;\n    _ = x;\n}\n',
      haskellLanguage:
          'module Main where\n\nimport Data.List (sort)\n\n'
          'main :: IO ()\nmain = print (sort [3, 1, 2])\n',
      clojureLanguage:
          '(ns app.core\n  (:require [clojure.string :as str]))\n\n'
          '(defn greet [name]\n  (str "Hello, " name))\n',
      erlangLanguage:
          '-module(hello).\n-export([start/0]).\n\n'
          'start() ->\n    io:format("hello~n").\n',
      solidityLanguage:
          '// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\n'
          'contract C {\n    uint256 public x;\n}\n',
      nasmLanguage:
          'section .text\n    global _start\n_start:\n    mov rax, 60\n'
          '    xor rdi, rdi\n    syscall\n',
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
