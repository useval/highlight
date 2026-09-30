import '../advanced.dart';

/// Dockerfile (and Containerfile).
///
/// Each instruction is a region that runs to the end of its logical line,
/// following `\` continuations. Heredocs (`RUN <<EOF … EOF`) are strings.
const dockerfileLanguage = Grammar(
  name: 'dockerfile',
  aliases: ['docker', 'containerfile'],
  fileExtensions: ['dockerfile'],
  fileNames: ['Dockerfile', 'Containerfile'],
  caseInsensitive: true,
  signatures: [
    r'^FROM\s+[\w./:@${}-]+(?:\s+AS\s+\w+)?\s*$',
    r'^(?:RUN|COPY|WORKDIR|ENTRYPOINT|EXPOSE|HEALTHCHECK)\s',
    r'^CMD\s+\[\s*"',
  ],
  rules: [
    // Parser directives such as `# syntax=docker/dockerfile:1`.
    TokenRule(r'^#[ \t]*(?:syntax|escape|check)[ \t]*=.*$', scope: Scopes.meta),
    TokenRule(r'^[ \t]*#.*$', scope: Scopes.comment),
    RegionRule(
      begin:
          r'^[ \t]*(?:ONBUILD[ \t]+)?(?:FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|'
          r'ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|'
          r'STOPSIGNAL|HEALTHCHECK|SHELL)\b',
      // The instruction ends at a line end not preceded by `\`.
      end: r'(?<!\\)$',
      beginScope: Scopes.keyword,
      rules: [IncludeRule('arguments')],
    ),
  ],
  repository: {
    'arguments': [
      // Comment lines inside a continued instruction.
      TokenRule(r'^[ \t]*#.*$', scope: Scopes.comment),
      // Heredocs: `<<EOF`, `<<-EOF`, `<<"EOF"`.
      RegionRule(
        begin: r'''<<-?(["']?)([A-Za-z_]\w*)\1''',
        end: r'^[ \t]*\2$',
        beginScope: Scopes.operator,
        endScope: Scopes.operator,
        endReferencesBegin: true,
        rules: [TokenRule(r'[^\n]+', scope: Scopes.string)],
      ),
      QuotedString('"', rules: [IncludeRule('variables')]),
      QuotedString("'", escape: null),
      IncludeRule('variables'),
      // Flags such as `--from=build` or `--chown=app`.
      TokenRule(r'(?<=\s)--[A-Za-z][\w-]*', scope: Scopes.attribute),
      // `HEALTHCHECK … CMD [...]` and `HEALTHCHECK NONE`.
      TokenRule(
        r'(?<=\s)(?:CMD|NONE)(?=[ \t]+\[|[ \t]*$)',
        scope: Scopes.keyword,
      ),
      // `FROM image AS name`.
      TokenRule(r'(?<=\s)AS(?=[ \t]+[\w.-]+[ \t]*$)', scope: Scopes.keyword),
      TokenRule(r'&&|\|\||[|;=]', scope: Scopes.operator),
      TokenRule(
        r'(?<![\w$.:/-])\d+(?:/(?:tcp|udp))?(?![\w.:/-])',
        scope: Scopes.number,
      ),
      // A trailing `\` continues the instruction.
      TokenRule(r'\\(?=[ \t]*$)', scope: Scopes.operator),
    ],
    'variables': [
      TokenRule(r'\$\{[^}\n]*\}', scope: Scopes.variable),
      TokenRule(r'\$[A-Za-z_]\w*', scope: Scopes.variable),
    ],
  },
);
