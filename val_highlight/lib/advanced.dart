/// Grammar authoring and engine access for `val_highlight`.
///
/// Import this to write or extend a grammar; validate one eagerly with
/// `Grammar.validate`. The built-in grammars use exactly this API.
library;

export 'val_highlight.dart';
export 'src/grammar/grammar.dart'
    show
        Annotation,
        BlockComment,
        BlockRule,
        CommonRules,
        IncludeRule,
        Interpolation,
        KeywordRule,
        LineComment,
        Numbers,
        Operators,
        Preprocessor,
        QuotedString,
        RegionRule,
        Rule,
        TokenRule;
