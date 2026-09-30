import '../advanced.dart';

/// HCL, including Terraform and OpenTofu configuration.
const hclLanguage = Grammar(
  name: 'hcl',
  aliases: ['terraform', 'tf', 'opentofu'],
  fileExtensions: ['tf', 'tfvars', 'hcl'],
  signatures: [
    r'^resource\s+"\w+"\s+"[\w-]+"\s*\{',
    r'^(?:variable|output|module|provider|data|locals)\s+(?:"[\w-]+"\s*)*\{',
    r'\$\{(?:var|local|module|data)\.',
    r'^terraform\s*\{',
  ],
  rules: [
    IncludeRule('comments'),
    // Block headers: `resource "aws_s3_bucket" "logs" {`.
    TokenRule(
      r'^([ \t]*)([A-Za-z_][\w-]*)(?=(?:[ \t]+(?:"[^"\n]*"|[A-Za-z_][\w-]*))*'
      r'[ \t]*\{)',
      captures: {2: Scopes.keyword},
    ),
    // Attributes: `name = value`.
    TokenRule(
      r'^([ \t]*)([A-Za-z_][\w-]*)(?=[ \t]*=(?!=))',
      captures: {2: Scopes.property},
    ),
    IncludeRule('expression'),
  ],
  repository: {
    'comments': [BlockComment('/*', '*/'), LineComment('#'), LineComment('//')],
    'expression': [
      IncludeRule('comments'),
      // Heredocs: `<<EOT … EOT` and indented `<<-EOT … EOT`.
      RegionRule(
        begin: r'<<-?([A-Za-z_]\w*)',
        end: r'^[ \t]*\1[ \t]*$',
        beginScope: Scopes.operator,
        endScope: Scopes.operator,
        endReferencesBegin: true,
        rules: [
          IncludeRule('templates'),
          TokenRule(r'[^$%\n]+|[$%]', scope: Scopes.string),
        ],
      ),
      QuotedString('"', rules: [IncludeRule('templates')]),
      Numbers(binary: false, octal: false, separator: null),
      CommonRules.memberCall,
      CommonRules.member,
      KeywordRule(
        {
          Scopes.keyword: ['for', 'in', 'if', 'else', 'endif', 'endfor'],
          Scopes.literal: ['true', 'false', 'null'],
          Scopes.variableLanguage: [
            'var', 'local', 'module', 'data', 'each', 'count', 'self', //
            'path', 'terraform',
          ],
          Scopes.typeBuiltin: [
            'string', 'number', 'bool', 'list', 'map', 'set', 'object', //
            'tuple', 'any',
          ],
        },
        word: r'(?<![\w-])[A-Za-z_][\w-]*',
        otherwise: [CommonRules.functionCall],
      ),
      TokenRule(
        r'=>|==|!=|<=|>=|&&|\|\||[-+*/%<>!?:=]',
        scope: Scopes.operator,
      ),
    ],
    'templates': [
      TokenRule(r'\$\$\{|%%\{', scope: Scopes.stringEscape),
      Interpolation(r'${', '}', rules: [IncludeRule('expression')]),
      Interpolation('%{', '}', rules: [IncludeRule('expression')]),
    ],
  },
);
