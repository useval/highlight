import '../advanced.dart';

/// Windows batch files (`.bat`, `.cmd`).
const batchLanguage = Grammar(
  name: 'batch',
  aliases: ['bat', 'cmd', 'dos'],
  fileExtensions: ['bat', 'cmd'],
  caseInsensitive: true,
  signatures: [
    r'^@echo\s+off\s*$',
    r'^\s*(?:setlocal|endlocal)\b',
    r'%~dp0',
    r'^\s*goto\s+:?\w+',
    r'^\s*rem\s',
  ],
  rules: [
    // `REM …` and `:: …` comments, at the start of a statement.
    TokenRule(r'^[ \t]*@?rem(?:[ \t].*)?$', scope: Scopes.comment),
    TokenRule(r'(?<=&)[ \t]*rem(?:[ \t].*)?$', scope: Scopes.comment),
    TokenRule(r'^[ \t]*::.*$', scope: Scopes.comment),
    // Labels: `:loop`.
    TokenRule(r'^[ \t]*:[A-Za-z_][\w.-]*', scope: Scopes.function),
    TokenRule(r'^[ \t]*@', scope: Scopes.operator),
    // Label targets: `goto :done`, `call :sub`.
    TokenRule(
      r'(?<=\b(?:goto|call)[ \t]{1,4}):?(?!eof\b)[A-Za-z_][\w.-]*',
      scope: Scopes.function,
    ),
    QuotedString('"', escape: null, rules: [IncludeRule('variables')]),
    IncludeRule('variables'),
    TokenRule(r'\^[\s\S]', scope: Scopes.stringEscape),
    // Switches: `/b`, `/i`, `/?`.
    TokenRule(r'(?<=\s)/[A-Za-z?][\w:-]*', scope: Scopes.attribute),
    TokenRule(r'(?<![\w%!.])\d+(?![\w.])', scope: Scopes.number),
    KeywordRule({
      Scopes.keyword: [
        'if', 'else', 'goto', 'call', 'exit', 'for', 'in', 'do', 'not', //
        'exist', 'defined', 'errorlevel', 'equ', 'neq', 'lss', 'leq',
        'gtr', 'geq', 'setlocal', 'endlocal', 'shift', 'enabledelayedexpansion',
        'enableextensions', 'disabledelayedexpansion', 'eof',
      ],
      Scopes.function: [
        'echo', 'set', 'cd', 'chdir', 'pushd', 'popd', 'md', 'mkdir', 'rd', //
        'rmdir', 'del', 'erase', 'copy', 'xcopy', 'robocopy', 'move', 'ren',
        'rename', 'type', 'start', 'pause', 'cls', 'title', 'color',
        'choice', 'timeout', 'find', 'findstr', 'where', 'tasklist',
        'taskkill', 'dir', 'path', 'prompt', 'ver', 'vol', 'assoc',
        'mklink', 'attrib', 'powershell',
      ],
      Scopes.literal: ['nul', 'con', 'on', 'off'],
    }, word: r'(?<![\w%!.\\/-])[A-Za-z_][\w-]*'),
    TokenRule(r'==|&&|\|\||[<>]{1,2}|[|&=]', scope: Scopes.operator),
  ],
  repository: {
    'variables': [
      // `%%i` loop variables and `%~dp0`-style parameters.
      TokenRule(r'%%~?[a-z]*[A-Za-z]', scope: Scopes.variable),
      TokenRule(r'%~[a-z$:]*[0-9]|%[0-9*]', scope: Scopes.variable),
      // `%NAME%`, `%NAME:~0,5%`, `%NAME:a=b%`, and delayed `!NAME!`.
      TokenRule(
        r'%[A-Za-z_][\w#$@.()-]*(?::[^%\n]*)?%',
        scope: Scopes.variable,
      ),
      TokenRule(
        r'![A-Za-z_][\w#$@.()-]*(?::[^!\n]*)?!',
        scope: Scopes.variable,
      ),
    ],
  },
);
