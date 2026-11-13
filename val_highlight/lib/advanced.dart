/// Grammar authoring for `val_highlight`: everything in `val_highlight.dart`,
/// plus the rules and building blocks grammars are written with.
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
