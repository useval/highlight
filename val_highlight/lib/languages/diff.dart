import '../advanced.dart';

/// Unified and git diffs.
const diffLanguage = Grammar(
  name: 'diff',
  aliases: ['patch'],
  fileExtensions: ['diff', 'patch'],
  signatures: [r'^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@', r'^diff --git '],
  rules: [
    TokenRule(
      r'^(?:diff|index|similarity|rename|new|deleted) .*$',
      scope: Scopes.meta,
    ),
    TokenRule(r'^(?:\+\+\+|---) .*$', scope: Scopes.meta),
    TokenRule(r'^@@.*?@@', scope: Scopes.heading),
    TokenRule(r'^\+.*$', scope: Scopes.addition),
    TokenRule(r'^-.*$', scope: Scopes.deletion),
    TokenRule(r'^\\ .*$', scope: Scopes.comment),
  ],
);
