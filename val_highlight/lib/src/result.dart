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

  /// Whether the character at [offset] is inside a string, comment or
  /// regular expression. Interpolations inside strings count as code.
  bool isStringOrCommentAt(int offset) {
    if (offset < 0 || offset >= code.length) return false;
    return scopes.isStringOrComment(_stacks[tokenAt(offset)]);
  }

  /// Whether the character at [offset] is inside a comment.
  bool isCommentAt(int offset) {
    if (offset < 0 || offset >= code.length) return false;
    return scopes.isComment(_stacks[tokenAt(offset)]);
  }

  /// Whether text typed at caret position [offset], between
  /// `code[offset - 1]` and `code[offset]`, would land inside a string or
  /// comment.
  ///
  /// Unlike [isStringOrCommentAt], this answers for a position between
  /// characters: right after a closing quote is outside the string, while
  /// the end of a line comment or of an unterminated string is inside.
  /// [syntax] supplies the block comment marker; it defaults to
  /// [EditingSyntax.of] the [language].
  bool isInsideStringOrComment(int offset, [EditingSyntax? syntax]) {
    if (offset <= 0 || offset > code.length) return false;
    final before = tokenAt(offset - 1);
    final stack = _stacks[before];
    if (!scopes.isStringOrComment(stack)) return false;
    if (_ends[before] > offset) return true;
    if (offset < code.length) {
      if (scopes.isStringOrComment(_stacks[before + 1])) return true;
      final next = code.codeUnitAt(offset);
      if (next != 0x0A && next != 0x0D) return false;
    }
    // At the end of a line, right after a string or comment: still inside
    // unless it was closed there.
    if (scopes.isComment(stack)) {
      final close = (syntax ?? EditingSyntax.of(language)).blockComment?.$2;
      return close == null ||
          offset - close.length <= tokenStart(before) ||
          !code.startsWith(close, offset - close.length);
    }
    final last = code.codeUnitAt(offset - 1);
    final quote = last == 0x22 || last == 0x27 || last == 0x60;
    final opened =
        tokenStart(before) < offset - 1 ||
        (before > 0 && scopes.isStringOrComment(_stacks[before - 1]));
    return !(quote && opened);
  }

  /// Offset of the bracket matching the one at [offset], or `-1` if the
  /// character at [offset] is not a bracket in code, or has no match within
  /// [limit] characters.
  ///
  /// [brackets] lists pairs as consecutive opening and closing characters,
  /// as in [EditingSyntax.brackets]. Brackets inside strings and comments
  /// are skipped, so `f(")")` matches correctly. The search walks tokens,
  /// jumping over a whole string or comment at once.
  int matchingBracket(
    int offset, {
    String brackets = '()[]{}',
    int limit = 1 << 20,
  }) {
    if (offset < 0 || offset >= code.length) return -1;
    final unit = code.codeUnitAt(offset);
    var pair = -1;
    for (var i = 0; i + 1 < brackets.length; i += 2) {
      if (brackets.codeUnitAt(i) == unit) {
        pair = i;
        break;
      }
      if (brackets.codeUnitAt(i + 1) == unit) {
        pair = i + 1;
        break;
      }
    }
    if (pair < 0) return -1;
    final open = brackets.codeUnitAt(pair & ~1);
    final close = brackets.codeUnitAt(pair | 1);
    if (open == close) return -1;
    var token = tokenAt(offset);
    if (scopes.isStringOrComment(_stacks[token])) return -1;
    var depth = 0;
    var i = offset;
    if (pair.isEven) {
      final stop = code.length - offset > limit ? offset + limit : code.length;
      while (i < stop) {
        final end = _ends[token];
        if (!scopes.isStringOrComment(_stacks[token])) {
          final until = end < stop ? end : stop;
          for (; i < until; i++) {
            final c = code.codeUnitAt(i);
            if (c == open) {
              depth++;
            } else if (c == close && --depth == 0) {
              return i;
            }
          }
        }
        i = end;
        token++;
      }
    } else {
      final stop = offset > limit ? offset - limit : 0;
      while (i >= stop) {
        final start = tokenStart(token);
        if (!scopes.isStringOrComment(_stacks[token])) {
          final until = start > stop ? start : stop;
          for (; i >= until; i--) {
            final c = code.codeUnitAt(i);
            if (c == close) {
              depth++;
            } else if (c == open && --depth == 0) {
              return i;
            }
          }
        }
        i = start - 1;
        token--;
      }
    }
    return -1;
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
