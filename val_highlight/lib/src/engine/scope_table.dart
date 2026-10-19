import 'dart:typed_data';

/// Interned scope names and scope stacks for one highlight result.
///
/// Every token records a single stack id. A stack is a chain of scopes from
/// the outside in, such as `string > interpolation > keyword`. Stack `0` is
/// the root and has no scope. A parent always has a smaller id than its
/// children, so renderers can resolve styles in a single forward pass.
final class ScopeTable {
  /// Creates an empty table containing only the root stack.
  ScopeTable();

  /// Id of the root stack, which has no scope.
  static const int root = 0;

  final List<String> _names = [];
  final Map<String, int> _nameIds = {};
  final List<int> _parents = [-1];
  final List<int> _scopes = [-1];
  final Map<int, int> _stackIds = {};
  List<List<int>?>? _paths;

  // Per stack: bit 0 = inside a string, comment or regexp; bit 1 = inside a
  // comment. Grown lazily, since stacks are only ever appended.
  Uint8List _kinds = Uint8List(0);
  int _kindCount = 0;

  /// Number of stacks, including the root.
  int get stackCount => _parents.length;

  /// Returns the id of scope [name], adding it if needed.
  int nameId(String name) {
    final existing = _nameIds[name];
    if (existing != null) return existing;
    final id = _names.length;
    _names.add(name);
    _nameIds[name] = id;
    return id;
  }

  /// Returns the stack made of [stack] with scope [name] pushed on top.
  int push(int stack, String name) {
    final scope = nameId(name);
    final key = stack * 65536 + scope;
    final existing = _stackIds[key];
    if (existing != null) return existing;
    final id = _parents.length;
    _parents.add(stack);
    _scopes.add(scope);
    _stackIds[key] = id;
    _paths = null;
    return id;
  }

  /// Parent of [stack], or `-1` for the root.
  int parentOf(int stack) => _parents[stack];

  /// Innermost scope of [stack], or `null` for the root.
  String? scopeOf(int stack) {
    final scope = _scopes[stack];
    return scope < 0 ? null : _names[scope];
  }

  /// Scopes of [stack] from the outermost to the innermost.
  List<String> scopesOf(int stack) => [
    for (final id in pathOf(stack)) _names[_scopes[id]],
  ];

  /// Stack ids from the outermost to [stack], excluding the root.
  List<int> pathOf(int stack) {
    final paths = _paths ??= List<List<int>?>.filled(stackCount, null);
    final cached = paths[stack];
    if (cached != null) return cached;
    final List<int> path;
    if (stack == root) {
      path = const [];
    } else {
      path = [...pathOf(_parents[stack]), stack];
    }
    paths[stack] = path;
    return path;
  }

  /// Whether [stack] is inside a string, comment or regular expression.
  ///
  /// An interpolation inside a string, such as `${x}`, is code again: its
  /// stacks are not.
  bool isStringOrComment(int stack) => _kind(stack) & 1 != 0;

  /// Whether [stack] is inside a comment.
  bool isComment(int stack) => _kind(stack) & 2 != 0;

  int _kind(int stack) {
    if (stack >= _kindCount) _classify();
    return _kinds[stack];
  }

  void _classify() {
    final count = stackCount;
    if (_kinds.length < count) {
      _kinds = Uint8List(count < 64 ? 64 : count * 2)
        ..setRange(0, _kindCount, _kinds);
    }
    for (var id = _kindCount == 0 ? 1 : _kindCount; id < count; id++) {
      final name = _names[_scopes[id]];
      final dot = name.indexOf('.');
      final head = dot < 0 ? name : name.substring(0, dot);
      _kinds[id] = switch (head) {
        'comment' => 3,
        'string' || 'regexp' => _kinds[_parents[id]] | 1,
        'interpolation' => 0,
        _ => _kinds[_parents[id]],
      };
    }
    _kindCount = count;
  }
}
