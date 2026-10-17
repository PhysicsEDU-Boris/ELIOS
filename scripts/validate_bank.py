#!/usr/bin/env python3
"""Validates assets/quiz/question_bank_draft.json against the module chunks (decision 0015).

    python3 scripts/validate_bank.py

Exits 1 and lists every problem. No PDF needed: quotes are checked against
assets/module/module_chunks.json, which is itself checked against the PDF
(scripts/test_extract_module.py).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / 'assets/quiz/question_bank_draft.json'
CHUNKS = ROOT / 'assets/module/module_chunks.json'
LABELS = ROOT / 'assets/module/label_to_chunks.json'

POOLS = {'organik', 'paper_family', 'plastic', 'glass', 'metal', 'tetra_pak', 'e_waste_b3'}
DIFFICULTIES = ('Mudah', 'Sedang', 'Sulit')
MC_PER_DIFFICULTY, ESSAYS_PER_POOL = 2, 2
MAX_QUOTE_WORDS = 40
# Skipped until the owner fixes the PDF (M3.2 results): composting steps and
# maturing time, decomposition times, 7.3, 6.6 numbers, the LKPD key.
BANNED_CHUNKS = {'1.5', '3.5', '3.qa', '6.6', '7.3', '8.4'}
BANNED = [
    (r'\bpematangan\b|\bmatang\b', 'composting maturing time'),
    (r'\bbulan\b|\bminggu\b', 'durations in months/weeks (composting, decomposition)'),
    (r'waktu terurai|lama terurai|terurai dalam', 'decomposition time'),
    (r'langkah pengomposan|urutan (langkah|pengomposan)|berapa langkah', 'composting step count/order'),
    (r'\bELIO\b|\brobot\b|\baplikasi\b|\bperangkat keras\b', 'robot/app/hardware'),
    (r'10−|\b105\b|\bpOH\b|\bpH\b', 'section 6.6 numbers'),
    (r'semua (jawaban|pilihan)? ?(di atas )?benar|tidak ada (jawaban )?yang benar|semua di atas', 'all/none of the above'),
]
TETRA_BANNED = (r'\d+\s*%', 'Tetra Pak percentages (approximate, company-sourced)')
PAPER_FLAT = (r'\b(kertas|karton|kardus)\b (adalah|termasuk|merupakan) (sampah )?anorganik',
              'paper/cardboard stated flatly as anorganik')


def flat(text):
    return ' '.join(text.split())


def norm(text):
    return re.sub(r'[^a-z0-9 ]', ' ', text.lower()).split()


def jaccard(a, b):
    a, b = set(norm(a)), set(norm(b))
    return len(a & b) / max(1, len(a | b))


def texts(item):
    """Everything a student or grader reads, for the keyword rules."""
    out = [item['question'], item.get('explanation', ''), item.get('quote', ''), item.get('correct', ''), *item.get('wrong', [])]
    for p in item.get('rubricPoints', []):
        out += [p['point'], p['quote']]
    return out


def check_quote(where, quote, chunk_id, page, chunks):
    errors = []
    chunk = chunks.get(chunk_id)
    if chunk is None:
        return [f'{where}: unknown chunk {chunk_id}']
    if chunk_id in BANNED_CHUNKS:
        errors.append(f'{where}: chunk {chunk_id} is on the skip list')
    if not quote or flat(quote) not in flat(chunk['text']):
        errors.append(f'{where}: quote not verbatim in chunk {chunk_id}')
    if len(quote.split()) > MAX_QUOTE_WORDS:
        errors.append(f'{where}: quote over {MAX_QUOTE_WORDS} words')
    if not isinstance(page, int) or not chunk['pdfPage'] <= page <= chunk['pdfPageEnd']:
        errors.append(f'{where}: pdfPage {page} outside chunk {chunk_id} pages {chunk["pdfPage"]}-{chunk["pdfPageEnd"]}')
    return errors


def check_mc(item):
    errors = []
    wrong = item.get('wrong')
    correct = item.get('correct')
    if not isinstance(correct, str) or not norm(correct):
        errors.append(f'{item["id"]}: needs exactly one non-empty correct answer')
    if not isinstance(wrong, list) or len(wrong) != 3 or not all(isinstance(w, str) and norm(w) for w in wrong):
        return errors + [f'{item["id"]}: needs exactly 3 non-empty wrong options']
    keys = [tuple(norm(w)) for w in wrong]
    if len(set(keys)) != 3:
        errors.append(f'{item["id"]}: wrong options are not distinct')
    if isinstance(correct, str) and tuple(norm(correct)) in keys:
        errors.append(f'{item["id"]}: a wrong option equals the correct answer')
    if len(re.split(r'(?<=[.!?])\s+', item.get('explanation', '').strip())) > 2 or not item.get('explanation'):
        errors.append(f'{item["id"]}: explanation must be 1-2 sentences')
    return errors


def check_essay(item, chunks):
    points = item.get('rubricPoints') or []
    errors = [] if 2 <= len(points) <= 4 else [f'{item["id"]}: needs 2-4 rubric points']
    for n, p in enumerate(points, 1):
        errors += check_quote(f'{item["id"]} rubric {n}', p.get('quote', ''), p.get('sourceChunk'), p.get('pdfPage'), chunks)
    return errors


def validate(bank, chunks, labels):
    errors = []
    items = bank['items']
    module_questions = [m for c in chunks.values() for m in re.findall(r'T: (.+?\?)', flat(c['text']))]
    seen = set()
    for item in items:
        iid = item.get('id')
        if iid in seen:
            errors.append(f'{iid}: duplicate id')
        seen.add(iid)
        if item.get('pool') not in POOLS or item.get('difficulty') not in DIFFICULTIES or item.get('status') != 'draft':
            errors.append(f'{iid}: bad pool, difficulty or status')
        if item.get('type') == 'mc':
            errors += check_mc(item)
            errors += check_quote(iid, item.get('quote', ''), item.get('sourceChunk'), item.get('pdfPage'), chunks)
        elif item.get('type') == 'essay':
            errors += check_essay(item, chunks)
            if not isinstance(item.get('pdfPage'), int):
                errors.append(f'{iid}: missing pdfPage')
        else:
            errors.append(f'{iid}: type must be mc or essay')
        body = ' | '.join(texts(item))
        rules = BANNED + ([TETRA_BANNED] if item.get('pool') == 'tetra_pak' else []) \
            + ([PAPER_FLAT] if item.get('pool') == 'paper_family' else [])
        for pattern, why in rules:
            if re.search(pattern, body, re.IGNORECASE if why != 'section 6.6 numbers' else 0):
                errors.append(f'{iid}: skipped topic ({why})')
        for mq in module_questions:
            if jaccard(item['question'], mq) >= 0.8:
                errors.append(f'{iid}: repeats the module question "{mq}"')

    for pool in POOLS:
        in_pool = [i for i in items if i.get('pool') == pool]
        for d in DIFFICULTIES:
            n = sum(1 for i in in_pool if i.get('type') == 'mc' and i.get('difficulty') == d)
            if n != MC_PER_DIFFICULTY:
                errors.append(f'{pool}: {n} mc at {d}, want {MC_PER_DIFFICULTY}')
        n = sum(1 for i in in_pool if i.get('type') == 'essay')
        if n != ESSAYS_PER_POOL:
            errors.append(f'{pool}: {n} essays, want {ESSAYS_PER_POOL}')
        for a in range(len(in_pool)):
            for b in range(a + 1, len(in_pool)):
                if jaccard(in_pool[a]['question'], in_pool[b]['question']) >= 0.6:
                    errors.append(f'{in_pool[a]["id"]} / {in_pool[b]["id"]}: near-duplicate questions')

    mapped = {label for names in bank['pools'].values() for label in names}
    expected = {k for k, v in labels.items() if v['bin'] is not None}
    if set(bank['pools']) != POOLS or mapped != expected:
        errors.append(f'pools must cover exactly the waste labels {sorted(expected)}, got {sorted(mapped)}')
    return errors


def load():
    chunks = {c['id']: c for c in json.loads(CHUNKS.read_text(encoding='utf-8'))['chunks']}
    labels = json.loads(LABELS.read_text(encoding='utf-8'))['labels']
    return json.loads(BANK.read_text(encoding='utf-8')), chunks, labels


if __name__ == '__main__':
    errors = validate(*load())
    for e in errors:
        print(e)
    bank = load()[0]
    print(f'{len(bank["items"])} items, {len(errors)} problems')
    sys.exit(1 if errors else 0)
