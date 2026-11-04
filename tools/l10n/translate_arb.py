#!/usr/bin/env python3
"""Fill lib/l10n/app_<lang>.arb from app_en.arb with the Gemini free tier.

  python3 tools/l10n/translate_arb.py fr ja   # add or update languages (export GEMINI_API_KEY first)
  python3 tools/l10n/translate_arb.py --selftest

Only keys missing from app_<lang>.arb are sent, so hand fixes are kept; delete a
key to have it translated again. Keys gone from app_en.arb are dropped. Then run
`flutter gen-l10n` (or any build) and add the language code to
CFBundleLocalizations in ios/Runner/Info.plist. The key comes only from the
environment and is never written to disk.
"""
import json, os, re, sys, urllib.error, urllib.request
from pathlib import Path

ARB_DIR = Path(__file__).resolve().parents[2] / 'lib' / 'l10n'
MODEL = 'gemini-3.5-flash-lite'  # decision 0176 primary
URL = f'https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent'
BATCH = 60  # keys per request, keeps replies well under the output limit


def placeholders(text):
    return set(re.findall(r'\{(\w+)\}', text))


def check(src, out):
    """Return the problems in a translated {key: text} batch; empty list = usable."""
    errs = [f'missing {k}' for k in src if not isinstance(out.get(k), str) or not out[k].strip()]
    errs += [f'extra {k}' for k in out if k not in src]
    errs += [f'placeholders changed in {k}' for k in src
             if isinstance(out.get(k), str) and placeholders(out[k]) != placeholders(src[k])]
    return errs


def ask_gemini(key, lang, batch, notes):
    prompt = (
        f'Translate the values of this JSON object from English into the language with code "{lang}" for the '
        'UI of ELIOS, a waste-sorting robot app for school students. Keep every key. Keep {placeholders}, '
        'numbers, units, symbols and the names ELIOS, ELIO, MaixCAM2, Gemini, ESP32, NIR, B3 unchanged. '
        'Keep the length close to the English (buttons are small). Reply with the JSON object only.\n'
        f'Notes per key: {json.dumps(notes, ensure_ascii=False)}\n'
        f'{json.dumps(batch, ensure_ascii=False)}')
    body = {'contents': [{'parts': [{'text': prompt}]}],
            'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.2}}
    req = urllib.request.Request(URL, json.dumps(body).encode(), method='POST',
                                 headers={'Content-Type': 'application/json', 'x-goog-api-key': key})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            reply = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'Gemini HTTP {e.code}: {e.read()[:300]!r}')
    return json.loads(reply['candidates'][0]['content']['parts'][0]['text'])


def translate(lang, key):
    en = json.loads((ARB_DIR / 'app_en.arb').read_text())
    src = {k: v for k, v in en.items() if not k.startswith('@')}
    path = ARB_DIR / f'app_{lang}.arb'
    old = json.loads(path.read_text()) if path.exists() else {}
    todo = {k: v for k, v in src.items() if k not in old}
    done = {k: old[k] for k in src if k in old}
    keys = list(todo)
    for i in range(0, len(keys), BATCH):
        batch = {k: todo[k] for k in keys[i:i + BATCH]}
        notes = {k: en[f'@{k}']['description'] for k in batch if en.get(f'@{k}', {}).get('description')}
        out = ask_gemini(key, lang, batch, notes)
        errs = check(batch, out)
        if errs:  # nothing is written, so a bad reply never half-fills the file
            sys.exit(f'{lang}: unusable reply, nothing saved: {"; ".join(errs[:10])}')
        done.update(out)
    result = {'@@locale': lang, **{k: done[k] for k in src}}  # template order, stale keys dropped
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'{path.name}: {len(todo)} translated, {len(src) - len(todo)} kept')


def selftest():
    src = {'a': 'Hi {name}', 'b': 'Bye'}
    assert check(src, {'a': 'Salut {name}', 'b': 'Au revoir'}) == []
    assert check(src, {'a': 'Salut {nom}', 'b': 'Au revoir'}) == ['placeholders changed in a']
    assert check(src, {'a': 'Salut {name}'}) == ['missing b']
    assert check(src, {'a': 'Salut {name}', 'b': ' ', 'c': 'x'}) == ['missing b', 'extra c']
    print('selftest ok')


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--selftest']:
        selftest()
    elif not args or any(not re.fullmatch(r'[a-z]{2,3}(_[A-Z]{2})?', a) for a in args):
        sys.exit(__doc__)
    else:
        api_key = os.environ.get('GEMINI_API_KEY') or sys.exit('Set GEMINI_API_KEY first.')
        for lang in args:
            translate(lang, api_key)
