import '../advanced.dart';

/// INI files and Java `.properties` files.
const iniLanguage = Grammar(
  name: 'ini',
  aliases: ['properties', 'conf', 'cfg', 'editorconfig', 'gitconfig'],
  fileExtensions: ['ini', 'cfg', 'conf', 'properties', 'editorconfig'],
  fileNames: ['.editorconfig', '.gitconfig', 'gradle.properties'],
  signatures: [
    r'^\[[\w .:"-]+\]\s*$',
    r'^[\w.-]+\s*=\s*\S',
    r'^root\s*=\s*true\s*$',
  ],
  rules: [
    TokenRule(r'^[ \t]*[;#!].*$', scope: Scopes.comment),
    TokenRule(r'^[ \t]*\[[^\]\n]*\]', scope: Scopes.heading),
    // A key before `=` or `:`.
    TokenRule(
      r'^[ \t]*[^\s=:;#!\[][^=:\n]*?(?=[ \t]*[=:])',
      scope: Scopes.property,
    ),
    // The value after `=` or `:`. A trailing `\` continues it (properties).
    RegionRule(
      begin: '[=:]',
      end: r'$',
      beginScope: Scopes.operator,
      rules: [
        TokenRule(r'\\u[0-9a-fA-F]{4}|\\[\s\S]', scope: Scopes.stringEscape),
        QuotedString('"'),
        TokenRule(r'\$\{[^}\n]*\}|%\([\w.-]+\)[sdrf]', scope: Scopes.variable),
        // A value that is entirely a literal or a number.
        TokenRule(
          r'(?<=[=:][ \t]{0,8})(?:true|false|yes|no|on|off|null|none|'
          r'True|False|Yes|No|On|Off|TRUE|FALSE|YES|NO|ON|OFF)(?=[ \t]*$)',
          scope: Scopes.literal,
        ),
        TokenRule(
          r'(?<=[=:][ \t]{0,8})[+-]?(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?)'
          r'(?=[ \t]*$)',
          scope: Scopes.number,
        ),
      ],
    ),
  ],
);
