#!/usr/bin/env python3
"""Fail on hard-coded user-visible strings in lib/ (decision 0185).

  python3 tools/l10n/audit_strings.py          # list findings, exit 1 if any
  python3 tools/l10n/audit_strings.py --count  # just the number

A finding is a string literal with at least two letters passed to Text(),
a label/tooltip/hint/semantics/message/title argument, or a SnackBar/dialog
text. Allowed literals are listed with a reason in audit_allow.txt as
`path<TAB>literal<TAB>reason` (literal may be `*` for a debug-only file).
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / 'lib'
SKIP = ('lib/l10n/',)
# literal in a user-visible position: Text('..'), Text.rich(TextSpan(text: '..')), named args
POS = re.compile(
    r"""(?:\bText\(\s*|\bTextSpan\(\s*text:\s*|\b(?:label|labelText|hintText|helperText|tooltip|"""
    r"""semanticsLabel|semanticLabel|message|title|subtitle|content|errorText|counterText|"""
    r"""placeholder|confirmText|cancelText|barrierLabel|text)\s*:\s*(?:const\s+)?(?:Text\(\s*)?)"""
    r"""(?P<q>'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""")
LETTERS = re.compile(r'[A-Za-z].*[A-Za-z]')


def strip_interpolations(lit):
    """Remove ${...} (nested braces too) and $name; what is left is copy."""
    out, i = [], 0
    while i < len(lit):
        if lit.startswith('${', i):
            depth, i = 1, i + 2
            while i < len(lit) and depth:
                depth += {'{': 1, '}': -1}.get(lit[i], 0)
                i += 1
        elif lit[i] == '$' and i + 1 < len(lit) and (lit[i + 1].isalpha() or lit[i + 1] == '_'):
            i += 1
            while i < len(lit) and (lit[i].isalnum() or lit[i] == '_'):
                i += 1
        else:
            out.append(lit[i])
            i += 1
    return ''.join(out)


def allowed():
    rules = []
    for line in (Path(__file__).parent / 'audit_allow.txt').read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            path, lit, _reason = (line.split('\t') + ['', ''])[:3]
            rules.append((path.strip(), lit))
    return rules


def findings():
    rules, out = allowed(), []
    for f in sorted(LIB.rglob('*.dart')):
        rel = f.relative_to(ROOT).as_posix()
        if rel.startswith(SKIP):
            continue
        src = f.read_text()
        for m in POS.finditer(src):
            lit = m.group('q')[1:-1]
            text = strip_interpolations(lit)
            if not LETTERS.search(text):
                continue
            if any(p == rel and (l == '*' or l == lit) for p, l in rules):
                continue
            line = src.count('\n', 0, m.start()) + 1
            out.append(f'{rel}:{line}: {lit}')
    return out


if __name__ == '__main__':
    found = findings()
    if '--count' in sys.argv:
        print(len(found))
    else:
        print('\n'.join(found))
        print(f'{len(found)} hard-coded user-visible strings', file=sys.stderr)
    sys.exit(1 if found else 0)
