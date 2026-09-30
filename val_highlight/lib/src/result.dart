import 'dart:typed_data';

import 'engine/scanner.dart' show computeLineStarts;
import 'engine/scope_table.dart';
import 'grammar/grammar.dart';
import 'render/html.dart';

/// The output of highlighting: [code] split into contiguous tokens.
///
/// Tokens are stored flat, as two parallel integer lists, rather than as a
/// tree of objects. Token `i` covers `code[tokenStart(i), tokenEnd(i))` and
/// carries a scope stack id from [scopes]. Tokens always cover all of [code]
/// with no gaps, and neighbouring tokens never share a stack.
final class HighlightResult {
  /// Creates a result from raw token buffers.
  ///
  /// Engines use this, and so can code that moves results between isolates.
  /// [ends] and [stacks] must have at least [tokenCount] entries. Pass
  /// [lineStarts] if they are already known.
  HighlightResult.fromBuffers({
    required this.code,
    required this.language,
    required this.scopes,
    required Int32List ends,
    required Int32List stacks,
    required this.tokenCount,
    Int32List? lineStarts,
  }) : _ends = ends,
       _stacks = stacks,
       _knownLineStarts = lineStarts;

  final Int32List? _knownLineStarts;

  /// The highlighted source.
  final String code;

  /// Grammar used to highlight [code].
  final Grammar language;

  /// Scope names and stacks referenced by the tokens.
  final ScopeTable scopes;

  /// Number of tokens.
  final int tokenCount;

  final Int32List _ends;
  final Int32List _stacks;

  /// Start offset of token [index].
  int tokenStart(int index) => index == 0 ? 0 : _ends[index - 1];

  /// End offset (exclusive) of token [index].
  int tokenEnd(int index) => _ends[index];

  /// Scope stack id of token [index]. See [scopes].
  int tokenStack(int index) => _stacks[index];

  /// The raw token end offsets, for engines that copy tokens in bulk.
  /// Only the first [tokenCount] entries are valid.
  Int32List get rawEnds => _ends;

  /// The raw token stack ids, alongside [rawEnds].
  Int32List get rawStacks => _stacks;

  /// All tokens, in order.
  Iterable<HighlightToken> get tokens =>
      Iterable.generate(tokenCount, (i) => HighlightToken._(this, i));

  /// Index of the token covering [offset], or [tokenCount] if [offset] is at
  /// or past the end.
  int tokenAt(int offset) {
    var low = 0;
    var high = tokenCount;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_ends[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  late final Int32List _lineStarts =
      _knownLineStarts ?? computeLineStarts(code);

  /// Number of lines. Empty code has one empty line, and a trailing `\n`
  /// starts a final empty line.
  int get lineCount => _lineStarts.length;

  /// Start offset of line [line].
  int lineStart(int line) => _lineStarts[line];

  /// End offset of line [line], excluding its `\n` or `\r\n`.
  int lineEnd(int line) {
    var end = line + 1 < _lineStarts.length
        ? _lineStarts[line + 1] - 1
        : code.length;
    if (end > _lineStarts[line] && code.codeUnitAt(end - 1) == 0x0D) end--;
    return end;
  }

  /// Calls [segment] for each piece of line [line], in order, with the
  /// piece's offsets and scope stack. Pieces never include the line break.
  void forEachSegment(
    int line,
    void Function(int start, int end, int stack) segment,
  ) {
    final start = lineStart(line);
    final end = lineEnd(line);
    if (start == end) return;
    for (var i = tokenAt(start); i < tokenCount; i++) {
      final tokenStart = this.tokenStart(i);
      if (tokenStart >= end) break;
      final tokenEnd = _ends[i];
      segment(
        tokenStart < start ? start : tokenStart,
        tokenEnd > end ? end : tokenEnd,
        _stacks[i],
      );
    }
  }

  /// Renders the result as HTML. See [HtmlRenderer] for options.
  String toHtml([HtmlRenderer renderer = const HtmlRenderer()]) =>
      renderer.render(this);
}

/// A lightweight view of one token in a [HighlightResult].
final class HighlightToken {
  const HighlightToken._(this._result, this.index);

  final HighlightResult _result;

  /// Position of this token in the result.
  final int index;

  /// Start offset in the source.
  int get start => _result.tokenStart(index);

  /// End offset (exclusive) in the source.
  int get end => _result.tokenEnd(index);

  /// Scope stack id.
  int get stack => _result.tokenStack(index);

  /// Source text covered by this token.
  String get text => _result.code.substring(start, end);

  /// Innermost scope, or `null` for plain text.
  String? get scope => _result.scopes.scopeOf(stack);

  /// Scopes from the outermost to the innermost.
  List<String> get scopes => _result.scopes.scopesOf(stack);

  @override
  String toString() => 'HighlightToken(${scopes.join(' > ')}: "$text")';
}
