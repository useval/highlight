import '../advanced.dart';
import 'c.dart';

/// Objective-C and Objective-C++.
const objectiveCLanguage = Grammar(
  name: 'objectivec',
  aliases: ['objc', 'objective-c', 'obj-c', 'objectivecpp', 'objc++'],
  fileExtensions: ['m', 'mm'],
  signatures: [
    r'^@(?:interface|implementation|protocol)\s+\w+',
    r'^#import\s*[<"]',
    r'@property\s*\(',
    r'@"',
    r'^[-+]\s*\([\w\s*]+\)\s*\w+',
  ],
  rules: [
    // `@"strings"` before the C string rules.
    QuotedString('"', prefix: '@'),
    ...cCommonRules,
    // Compiler directives: @interface, @end, @property, @selector, …
    TokenRule(r'@[A-Za-z_]\w*', scope: Scopes.keyword),
    // Boxed literals: @[ ], @{ }, @( ), @42.
    TokenRule(r'@(?=[\[{(\d-])', scope: Scopes.keyword),
    CommonRules.memberCall,
    CommonRules.member,
    KeywordRule(
      {
        Scopes.keyword: [
          ...cKeywords,
          '__block', '__bridge', '__bridge_retained', '__bridge_transfer', //
          '__kindof', '__strong', '__typeof__', '__unsafe_unretained',
          '__weak', 'assign', 'atomic', 'in', 'nonatomic', 'nonnull',
          'null_resettable', 'nullable', 'readonly', 'readwrite', 'retain',
          'strong', 'unsafe_unretained', 'weak',
        ],
        Scopes.typeBuiltin: [
          ...cTypes,
          'BOOL', 'Class', 'IMP', 'NSInteger', 'NSUInteger', 'SEL', 'id', //
          'instancetype', 'CGFloat',
        ],
        Scopes.literal: [...cLiterals, 'YES', 'NO', 'nil', 'Nil'],
        Scopes.variableLanguage: ['self', 'super', '_cmd'],
      },
      otherwise: [
        CommonRules.capitalizedType,
        CommonRules.functionCall,
        // Selector parts: `initWithCapacity:` in declarations and sends.
        TokenRule(r'[A-Za-z_]\w*(?=:(?!:))', scope: Scopes.function),
      ],
    ),
    Operators('+-*/%=<>!&|^~?:'),
  ],
);
