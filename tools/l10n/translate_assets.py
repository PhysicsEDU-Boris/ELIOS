#!/usr/bin/env python3
"""Translate the reviewed Indonesian quiz bank or module chunks with Gemini (decision 0185).

  Set GEMINI_API_KEY in the environment; never save it in this file.
  python3 tools/l10n/translate_assets.py bank en     # assets/quiz/*_draft.json -> *_draft.en.json
  python3 tools/l10n/translate_assets.py module en   # assets/module/module_chunks.json -> module_chunks.en.json
  python3 tools/l10n/translate_assets.py --selftest

The Indonesian files stay the source. Ids, statuses, pages, quotes and the
order of options are copied, never translated, so the correct answer cannot
move; every reply is checked and nothing is written if any batch fails.
Output files carry a "translation" note: machine translation, needs owner review.
"""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemini_json import NOTE, api_key, check, selftest as base_selftest, translate

ROOT = Path(__file__).resolve().parents[2]
QUIZ, MODULE = ROOT / 'assets' / 'quiz', ROOT / 'assets' / 'module'
BATCH = 15


def item_texts(item):
    t = {'question': item['question']}
    if 'correct' in item:
        t.update(correct=item['correct'], wrong=item['wrong'], explanation=item.get('explanation', ''))
    if item.get('rubricPoints'):
        t['rubric'] = [p['point'] for p in item['rubricPoints']]
    return t


def apply_item(item, t):
    item['question'] = t['question']
    if 'correct' in item:
        item['correct'], item['wrong'], item['explanation'] = t['correct'], t['wrong'], t['explanation']
        item.pop('wrongWhy', None)  # keyed by Indonesian option text; reviewed per language later
    for p, text in zip(item.get('rubricPoints') or [], t.get('rubric', [])):
        p['point'] = text


def batches(texts, key, lang, what):
    out, ids = {}, list(texts)
    for i in range(0, len(ids), BATCH):
        part = {k: texts[k] for k in ids[i:i + BATCH]}
        out.update(translate(key, part, lang, what))
    return out


def bank(lang, key):
    pool = json.loads((QUIZ / 'question_bank_draft.json').read_text())
    objects = json.loads((QUIZ / 'object_bank_draft.json').read_text())
    items = {i['id']: i for i in pool['items']} | {i['id']: i for o in objects['objects'] for i in o['items']}
    done = batches({k: item_texts(v) for k, v in items.items()}, key, lang, 'quiz questions')
    syn = translate(key, {o['object']: o['synonyms'] for o in objects['objects']}, lang, 'item names')
    for i in pool['items']:
        apply_item(i, done[i['id']])
    for o in objects['objects']:
        o['synonyms'] = syn[o['object']]
        for i in o['items']:
            apply_item(i, done[i['id']])
    for name, data in (('question_bank_draft', pool), ('object_bank_draft', objects)):
        (QUIZ / f'{name}.{lang}.json').write_text(
            json.dumps({'translation': NOTE, **data}, ensure_ascii=False, indent=2) + '\n')
    print(f'bank: {len(items)} items -> *.{lang}.json')


def module(lang, key):
    data = json.loads((MODULE / 'module_chunks.json').read_text())
    texts = {c['id']: {k: c[k] for k in ('chapter', 'subchapter', 'text') if isinstance(c.get(k), str)}
             for c in data['chunks']}
    done = batches(texts, key, lang, 'a course module')
    for c in data['chunks']:
        c.update(done[c['id']])
    (MODULE / f'module_chunks.{lang}.json').write_text(
        json.dumps({'translation': NOTE, **data}, ensure_ascii=False, indent=2) + '\n')
    print(f'module: {len(texts)} chunks -> module_chunks.{lang}.json')


def selftest():
    base_selftest()
    item = {'id': 'x', 'question': 'Q', 'correct': 'C', 'wrong': ['a', 'b', 'c'], 'explanation': 'E',
            'wrongWhy': {'a': 'w'}}
    t = item_texts(item)
    assert check(t, {'question': 'q', 'correct': 'c', 'wrong': ['A', 'B', 'C'], 'explanation': 'e'}) == []
    apply_item(item, {'question': 'q', 'correct': 'c', 'wrong': ['A', 'B', 'C'], 'explanation': 'e'})
    assert item['correct'] == 'c' and item['wrong'] == ['A', 'B', 'C'] and 'wrongWhy' not in item
    print('selftest ok')


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--selftest']:
        selftest()
    elif len(args) == 2 and args[0] in ('bank', 'module') and args[1] in ('en',):
        (bank if args[0] == 'bank' else module)(args[1], api_key())
    else:
        sys.exit(__doc__)
