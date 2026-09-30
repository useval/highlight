import '../advanced.dart';

/// x86 assembly in NASM/YASM syntax.
const nasmLanguage = Grammar(
  name: 'nasm',
  aliases: ['asm', 'x86asm', 'assembly'],
  fileExtensions: ['asm', 'nasm', 's'],
  caseInsensitive: true,
  signatures: [
    r'^\s*section\s+\.(?:text|data|bss|rodata)\b',
    r'^\s*global\s+_?\w+',
    r'^\s*(?:mov|push|pop|call|ret|jmp|syscall)\b',
    r'\b[re]?(?:ax|bx|cx|dx|si|di|sp|bp)\b\s*,',
  ],
  rules: [
    LineComment(';'),
    Preprocessor('%'),
    QuotedString('"', escape: null),
    QuotedString("'", escape: null),
    QuotedString('`'),
    // Labels: `_start:`, `.loop:`.
    TokenRule(
      r'^[ \t]*\.?[A-Za-z_$?@][\w.$?@#~]*(?=:)',
      scope: Scopes.function,
    ),
    // Numbers: `0x1F`, `1Fh`, `0b1010`, `1010b`, `777q`, `3.14`.
    TokenRule(
      r'(?<![\w$.])(?:0[xh][0-9a-f_]+|0[by][01_]+|0[oq][0-7_]+|'
      r'[0-9][0-9a-f_]*h|[01][01_]*[by]|[0-7][0-7_]*[oq]|'
      r'\d[\d_]*(?:\.\d+)?(?:e[+-]?\d+)?)(?![\w$])',
      scope: Scopes.number,
    ),
    KeywordRule(
      {
        Scopes.keyword: [
          'section', 'segment', 'global', 'extern', 'bits', 'default', //
          'org', 'align', 'alignb', 'times', 'equ', 'db', 'dw', 'dd', 'dq',
          'dt', 'do', 'dy', 'dz', 'resb', 'resw', 'resd', 'resq', 'rest',
          'reso', 'resy', 'resz', 'incbin', 'istruc', 'iend', 'at', 'struc',
          'endstruc', 'absolute', 'common', 'cpu', 'float', 'use16', 'use32',
          'use64',
        ],
        Scopes.typeBuiltin: [
          'byte', 'word', 'dword', 'qword', 'tword', 'oword', 'yword', //
          'zword', 'ptr', 'near', 'far', 'short', 'rel', 'abs', 'strict',
        ],
        Scopes.variable: [
          'rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'rbp', 'rsp', 'eax', //
          'ebx', 'ecx', 'edx', 'esi', 'edi', 'ebp', 'esp', 'ax', 'bx', 'cx',
          'dx', 'si', 'di', 'bp', 'sp', 'al', 'ah', 'bl', 'bh', 'cl', 'ch',
          'dl', 'dh', 'sil', 'dil', 'bpl', 'spl', 'cs', 'ds', 'es', 'fs',
          'gs', 'ss', 'rip', 'eip', 'ip', 'rflags', 'eflags',
        ],
        Scopes.function: [
          'mov', 'movzx', 'movsx', 'movsxd', 'lea', 'push', 'pop', 'call', //
          'ret', 'jmp', 'loop', 'add', 'adc', 'sub', 'sbb', 'mul', 'imul',
          'div', 'idiv', 'inc', 'dec', 'neg', 'and', 'or', 'xor', 'not',
          'shl', 'shr', 'sal', 'sar', 'rol', 'ror', 'rcl', 'rcr', 'test',
          'cmp', 'int', 'syscall', 'sysenter', 'sysret', 'nop', 'hlt', 'cli',
          'sti', 'leave', 'enter', 'cdq', 'cqo', 'cwd', 'cbw', 'cwde',
          'cdqe', 'movsb', 'movsw', 'movsd', 'movsq', 'stosb', 'stosd',
          'stosq', 'lodsb', 'scasb', 'cmpsb', 'rep', 'repe', 'repne', 'xchg',
          'cmpxchg', 'lock', 'bt', 'bts', 'btr', 'btc', 'bsf', 'bsr',
          'popcnt', 'lzcnt', 'tzcnt', 'bswap', 'cpuid', 'rdtsc', 'pause',
          'fld', 'fst', 'fstp', 'fadd', 'fsub', 'fmul', 'fdiv', 'movaps',
          'movups', 'movapd', 'movdqa', 'movdqu', 'movd', 'movq', 'addps',
          'subps', 'mulps', 'divps', 'addss', 'addsd', 'xorps', 'pxor',
          'paddd', 'psubd', 'pshufd', 'vmovaps', 'vmovups', 'vaddps',
          'vmulps', 'vxorps', 'vpxor', 'vzeroupper',
        ],
      },
      word: r'(?<![\w.$?@#~])[A-Za-z_.?@][\w.$?@#~]*',
      otherwise: [
        // Numbered registers and condition-code families.
        TokenRule(
          r'(?:r(?:[89]|1[0-5])[dwb]?|[xyz]mm(?:[12]?\d|3[01])|cr[0-8]|'
          r'dr[0-7]|st[0-7]|k[0-7])(?![\w.$?@#~])',
          scope: Scopes.variable,
        ),
        TokenRule(
          r'(?:j(?:n?[abcegloprsz]|n?[abgl]e|p[eo]|[er]?cxz)|'
          r'set(?:n?[abcegloprsz]|n?[abgl]e|p[eo])|'
          r'cmov(?:n?[abcegloprsz]|n?[abgl]e|p[eo]))(?![\w.$?@#~])',
          scope: Scopes.function,
        ),
      ],
    ),
    Operators(r'+-*/%<>=&|^~!'),
  ],
);
