import '../val_highlight.dart';

/// Plain text: no highlighting. Highlighting with it is nearly free, so it
/// is used for placeholders and for code in an unknown language.
const plainTextLanguage = Grammar(
  name: 'plaintext',
  detectable: false,
  aliases: ['text', 'txt', 'plain'],
  fileExtensions: ['txt'],
  rules: [],
);
