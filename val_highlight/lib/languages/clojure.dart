import '../advanced.dart';

/// Clojure, ClojureScript and EDN.
const clojureLanguage = Grammar(
  name: 'clojure',
  aliases: ['clj', 'cljs', 'cljc', 'edn'],
  fileExtensions: ['clj', 'cljs', 'cljc', 'edn'],
  signatures: [
    r'^\(ns\s+[\w.-]+',
    r'\(defn-?\s+[\w*+!?<>=-]+',
    r'\(let\s+\[',
    r'\(require\s+\[',
  ],
  rules: [
    LineComment(';'),
    // Regex literals: `#"\d+"`.
    QuotedString('"', prefix: '#', multiline: true, scope: Scopes.regexp),
    QuotedString('"', multiline: true),
    // Character literals: `\a`, `\newline`, and unicode escapes.
    TokenRule(
      r'\\(?:newline|space|tab|formfeed|backspace|return|u[0-9a-fA-F]{4}|'
      r'o[0-7]{1,3}|[\s\S])',
      scope: Scopes.string,
    ),
    // Keywords: `:name`, `::alias/name`.
    TokenRule(r"::?[\w*+!?<>=/.'-]+", scope: Scopes.literal),
    // Ratios: `22/7`.
    TokenRule(r'(?<![\w.])\d+/\d+(?![\w.])', scope: Scopes.number),
    Numbers(binary: false, octal: false, separator: null, suffix: '[NM]?'),
    // Java method calls: `(.toUpperCase s)`.
    TokenRule(r'(?<=\()\.[A-Za-z_][\w-]*', scope: Scopes.function),
    // Reader macros and quoting: `#{`, `#(`, `#'`, `#_`, `@`, `^`, `` ` ``,
    // `~@`.
    TokenRule(r"#[{(?'_:]|~@|[~@^`']", scope: Scopes.operator),
    KeywordRule(
      {
        Scopes.keyword: [
          'def', 'defn', 'defn-', 'defmacro', 'defmulti', 'defmethod', //
          'defprotocol', 'defrecord', 'deftype', 'defonce', 'definterface',
          'defstruct', 'fn', 'fn*', 'if', 'if-not', 'if-let', 'if-some', 'do',
          'let', 'let*', 'letfn', 'loop', 'recur', 'quote', 'var', 'throw',
          'try', 'catch', 'finally', 'new', 'set!', 'ns', 'import', 'require',
          'use', 'refer', 'when', 'when-not', 'when-let', 'when-some',
          'when-first', 'cond', 'condp', 'cond->', 'cond->>', 'case', 'and',
          'or', 'not', 'doseq', 'dotimes', 'for', 'while', 'binding',
          'locking', 'delay', 'future', 'reify', 'proxy', 'extend-type',
          'extend-protocol', '->', '->>', 'as->', 'some->', 'some->>', 'doto',
          'declare', 'comment', 'monitor-enter', 'monitor-exit',
        ],
        Scopes.literal: ['true', 'false', 'nil'],
      },
      word: r"(?<![\w*+!?<>=/.'#-])[A-Za-z*+!_?<>=-][\w*+!?<>=/.'-]*",
      otherwise: [
        // The symbol right after `(` is the function being called.
        TokenRule(
          r"(?<=\()[A-Za-z*+!_?<>=-][\w*+!?<>=/.'-]*",
          scope: Scopes.function,
        ),
        TokenRule(r'[A-Z][\w.]*(?![\w/])', scope: Scopes.type),
      ],
    ),
  ],
);
