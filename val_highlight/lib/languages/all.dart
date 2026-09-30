/// Every built-in language, for apps that want them all.
///
/// Importing this ships every grammar. To keep an app small, import only
/// the languages you use from `package:val_highlight/languages/<name>.dart`.
library;

import '../val_highlight.dart';
import 'bash.dart';
import 'batch.dart';
import 'c.dart';
import 'clojure.dart';
import 'cmake.dart';
import 'cpp.dart';
import 'csharp.dart';
import 'css.dart';
import 'dart.dart';
import 'diff.dart';
import 'dockerfile.dart';
import 'elixir.dart';
import 'erlang.dart';
import 'fsharp.dart';
import 'generic.dart';
import 'go.dart';
import 'graphql.dart';
import 'groovy.dart';
import 'haskell.dart';
import 'hcl.dart';
import 'html.dart';
import 'ini.dart';
import 'java.dart';
import 'javascript.dart';
import 'json.dart';
import 'jsx.dart';
import 'julia.dart';
import 'kotlin.dart';
import 'latex.dart';
import 'less.dart';
import 'lua.dart';
import 'makefile.dart';
import 'markdown.dart';
import 'nasm.dart';
import 'nginx.dart';
import 'objectivec.dart';
import 'ocaml.dart';
import 'perl.dart';
import 'php.dart';
import 'plaintext.dart';
import 'powershell.dart';
import 'protobuf.dart';
import 'python.dart';
import 'r.dart';
import 'ruby.dart';
import 'rust.dart';
import 'scala.dart';
import 'scss.dart';
import 'solidity.dart';
import 'sql.dart';
import 'swift.dart';
import 'toml.dart';
import 'tsx.dart';
import 'typescript.dart';
import 'xml.dart';
import 'yaml.dart';
import 'zig.dart';

export 'bash.dart';
export 'batch.dart';
export 'c.dart';
export 'clojure.dart';
export 'cmake.dart';
export 'cpp.dart';
export 'csharp.dart';
export 'css.dart';
export 'dart.dart';
export 'diff.dart';
export 'dockerfile.dart';
export 'elixir.dart';
export 'erlang.dart';
export 'fsharp.dart';
export 'generic.dart';
export 'go.dart';
export 'graphql.dart';
export 'groovy.dart';
export 'haskell.dart';
export 'hcl.dart';
export 'html.dart';
export 'ini.dart';
export 'java.dart';
export 'javascript.dart';
export 'json.dart';
export 'jsx.dart';
export 'julia.dart';
export 'kotlin.dart';
export 'latex.dart';
export 'less.dart';
export 'lua.dart';
export 'makefile.dart';
export 'markdown.dart';
export 'nasm.dart';
export 'nginx.dart';
export 'objectivec.dart';
export 'ocaml.dart';
export 'perl.dart';
export 'php.dart';
export 'plaintext.dart';
export 'powershell.dart';
export 'protobuf.dart';
export 'python.dart';
export 'r.dart';
export 'ruby.dart';
export 'rust.dart';
export 'scala.dart';
export 'scss.dart';
export 'solidity.dart';
export 'sql.dart';
export 'swift.dart';
export 'toml.dart';
export 'tsx.dart';
export 'typescript.dart';
export 'xml.dart';
export 'yaml.dart';
export 'zig.dart';

/// Every built-in language.
const allLanguages = <Grammar>[
  bashLanguage,
  batchLanguage,
  cLanguage,
  clojureLanguage,
  cmakeLanguage,
  cppLanguage,
  csharpLanguage,
  cssLanguage,
  dartLanguage,
  diffLanguage,
  dockerfileLanguage,
  elixirLanguage,
  erlangLanguage,
  fsharpLanguage,
  genericLanguage,
  goLanguage,
  graphqlLanguage,
  groovyLanguage,
  haskellLanguage,
  hclLanguage,
  htmlLanguage,
  iniLanguage,
  javaLanguage,
  javascriptLanguage,
  jsonLanguage,
  jsxLanguage,
  juliaLanguage,
  kotlinLanguage,
  latexLanguage,
  lessLanguage,
  luaLanguage,
  makefileLanguage,
  markdownLanguage,
  nasmLanguage,
  nginxLanguage,
  objectiveCLanguage,
  ocamlLanguage,
  perlLanguage,
  phpLanguage,
  plainTextLanguage,
  powershellLanguage,
  protobufLanguage,
  pythonLanguage,
  rLanguage,
  rubyLanguage,
  rustLanguage,
  scalaLanguage,
  scssLanguage,
  solidityLanguage,
  sqlLanguage,
  swiftLanguage,
  tomlLanguage,
  tsxLanguage,
  typescriptLanguage,
  xmlLanguage,
  yamlLanguage,
  zigLanguage,
];

/// A registry of every built-in language, for lookup by name, alias or file
/// name, and for Markdown code fences. Unknown names fall back to
/// [genericLanguage].
LanguageRegistry allLanguagesRegistry() =>
    LanguageRegistry(allLanguages, genericLanguage);
