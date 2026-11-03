#!/usr/bin/env python3
"""Cloud AI benchmark spike: Gemini identify (+ one MC question) on ELIOS scan crops.

  python3 bench.py run <photo_dir> [id,id]   # needs GEMINI_API_KEY; optional explicit model IDs
  python3 bench.py models              # list model IDs and display names (also raw/models.txt)
  python3 bench.py report              # results.csv -> report.md, no key needed
  python3 bench.py selftest

Stdlib + Pillow only. The key is read from the env and sent as a header; it is never printed or saved.
"""
import base64, csv, io, itertools, json, os, random, sys, time, urllib.error, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = HERE / 'results.csv'
RAW = HERE / 'raw'  # gitignored: raw model replies
API = 'https://generativelanguage.googleapis.com/v1beta'
# Every text-out model with a nonzero free-tier limit on the owner's AI Studio page (3 Nov 2026):
# display name -> (IDs from the pricing page, free RPM). Resolved only against models.list, never guessed.
WANTED = {
    'Gemini 2.5 Flash': (['gemini-2.5-flash'], 5),
    'Gemini 2.5 Flash Lite': (['gemini-2.5-flash-lite'], 10),
    'Gemini 3 Flash': (['gemini-3-flash-preview'], 5),
    'Gemini 3.1 Flash Lite': (['gemini-3.1-flash-lite'], 15),
    'Gemini 3.5 Flash Lite': (['gemini-3.5-flash-lite'], 15),
    'Gemini 3.6 Flash': (['gemini-3.6-flash'], 5),
    'Gemini 3.8 Flash': (['gemini-3.8-flash'], 5),
    'Gemma 4 26B': (['gemma-4-26b-a4b-it'], 30),  # IDs as models.list printed them on 3 Nov
    'Gemma 4 31B': (['gemma-4-31b-it'], 30),
    'Gemini Robotics ER 2 Preview': (['gemini-robotics-er-2-preview'], 5),
}
# Tried in order until a model accepts it (HTTP 400 moves on); the label is recorded per call.
MODES = [
    ('minimal', {'thinkingConfig': {'thinkingLevel': 'minimal'}}),
    ('budget0', {'thinkingConfig': {'thinkingBudget': 0}}),
    ('default', {}),
    ('default, no schema', None),  # JSON asked for in the prompt only
]
BACKOFF_S = [5, 10, 20, 40, 60]  # 429 retries; after these the model is treated as blocked
# USD per 1M tokens (input, output), verified on aistudio.google.com/docs/pricing 2026-11-03.
PRICES = {
    'gemini-3.1-flash-lite': [('', 0.25, 1.50)],
    'gemini-3.5-flash-lite': [('', 0.30, 2.50)],
    'gemini-3.6-flash': [('to 31 Dec 2026', 0.75, 3.75), ('from 1 Jan 2027', 1.50, 7.50)],
    'gemini-2.5-flash': [('', 0.30, 2.50)],  # deprecated: routes to 3.5 Flash-Lite from 1 Dec 2026
    'gemini-2.5-flash-lite': [('', 0.10, 0.40)],
    'gemini-3-flash-preview': [('', 0.50, 3.00)],
    'gemini-3.8-flash': [('to 31 Dec 2026', 0.75, 3.75), ('from 1 Jan 2027', 1.50, 7.50)],
    'gemini-robotics-er-2-preview': [('to 31 Dec 2026', 1.00, 5.00), ('from 1 Jan 2027', 2.00, 10.00)],
}  # Gemma 4: free tier only, no paid price
BINS = ['Organik', 'Anorganik', 'B3']
# Detector classes (decisions 0012/0025), Human_Hand left out: it is never a waste object.
CLASSES = ['Cardboard', 'E_Waste', 'Glass', 'Metal', 'Organic', 'Paper', 'Paperboard', 'Plastic', 'Tetra_Pak']

IDENTIFY = {
    'type': 'OBJECT',
    'properties': {
        'object_name': {'type': 'STRING', 'description': 'Nama benda dalam bahasa Indonesia, singkat'},
        'bin_category': {'type': 'STRING', 'enum': BINS},
        'bank_class': {'type': 'STRING', 'enum': CLASSES},
        'confidence': {'type': 'NUMBER'},
        'hazard': {'type': 'BOOLEAN'},
    },
    'required': ['object_name', 'bin_category', 'bank_class', 'confidence', 'hazard'],
}
# Same shape as an mc item in assets/quiz/question_bank_draft.json (0019: correct + wrong[3]).
QUESTION = {
    'type': 'OBJECT',
    'properties': {
        'question': {'type': 'STRING'},
        'correct': {'type': 'STRING'},
        'wrong': {'type': 'ARRAY', 'items': {'type': 'STRING'}, 'minItems': 3, 'maxItems': 3},
        'explanation': {'type': 'STRING'},
    },
    'required': ['question', 'correct', 'wrong', 'explanation'],
}
SCHEMA = {
    'A': IDENTIFY,
    'B': {**IDENTIFY, 'properties': {**IDENTIFY['properties'], 'question': QUESTION},
          'required': IDENTIFY['required'] + ['question']},
}
PROMPT_A = ('Foto ini potongan satu benda sampah dari kamera robot pemilah. Kenali bendanya. '
            'bin_category: Organik, Anorganik, atau B3 (bahan berbahaya dan beracun, termasuk sampah elektronik dan baterai). '
            'bank_class: kelas detektor yang paling cocok. confidence: 0 sampai 1. hazard: true jika berbahaya (B3).')
PROMPT_B = PROMPT_A + (' Lalu buat SATU soal pilihan ganda Fisika Lingkungan tingkat Mudah dalam bahasa Indonesia '
                       'tentang benda ini: satu jawaban benar, tiga jawaban salah, dan penjelasan singkat. '
                       'Tanyakan konsep fisikanya secara kualitatif, tanpa angka atau data untuk dihafal.')
FIELDS = ['run', 'model', 'call', 'file', 'label_bin', 'object_name', 'bin_category', 'bank_class', 'confidence',
          'hazard', 'question', 'wall_s', 'input_tokens', 'output_tokens', 'thinking_tokens', 'thinking',
          'json_valid', 'blocked', 'rate_limited', 'n_429', 'http_status', 'error']


def http(method, url, key, body=None):
    req = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={'x-goog-api-key': key, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:  # timeout, reset, DNS: recorded as 599 and retried like a 5xx
        return 599, f'network error: {type(e).__name__}: {e}'.encode()


def list_models(key):
    out, token = [], ''
    while True:
        st, body = http('GET', f'{API}/models?pageSize=1000' + (f'&pageToken={token}' if token else ''), key)
        if st != 200:
            sys.exit(f'models.list failed: HTTP {st}')
        d = json.loads(body)
        out += d.get('models', [])
        token = d.get('nextPageToken')
        if not token:
            return out


def norm(name):
    return name.lower().replace('-', ' ').removesuffix(' preview').removesuffix(' it').strip()


def resolve(models):
    """A wanted model matches a models.list entry by known ID or by display name (case and hyphens ignored)."""
    found = {}
    for name, (ids, _) in WANTED.items():
        found[name] = [m['name'].removeprefix('models/') for m in models
                       if 'generateContent' in m.get('supportedGenerationMethods', [])
                       and (m['name'].removeprefix('models/') in ids or norm(m.get('displayName', '')) == norm(name))]
    return found


def crop_jpeg(path):
    from PIL import Image, ImageOps
    im = ImageOps.exif_transpose(Image.open(path)).convert('RGB')
    im.thumbnail((512, 512))  # 512 px long side, as the app's E1 identify resize
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=85)
    return buf.getvalue()


def call(key, model, kind, jpeg, mode):
    extra = MODES[mode][1]
    prompt = PROMPT_A if kind == 'A' else PROMPT_B
    if extra is None:
        prompt += ' Jawab HANYA dengan satu objek JSON yang cocok dengan skema ini: ' + json.dumps(SCHEMA[kind])
    body = {
        'contents': [{'role': 'user', 'parts': [
            {'inlineData': {'mimeType': 'image/jpeg', 'data': base64.b64encode(jpeg).decode()}},
            {'text': prompt}]}],
        'generationConfig': {} if extra is None else
        {'responseMimeType': 'application/json', 'responseSchema': SCHEMA[kind], **extra},
    }
    url = f'{API}/models/{model}:generateContent'
    n429, retried5xx = 0, False
    while True:
        t0 = time.monotonic()
        st, raw = http('POST', url, key, body)
        if st == 200:
            d = json.loads(raw)
            text = ''.join(p.get('text', '') for c in d.get('candidates', [])[:1]
                           for p in c.get('content', {}).get('parts', []) if not p.get('thought'))
            try:
                parsed = json.loads(text.strip().removeprefix('```json').removeprefix('```').removesuffix('```'))
            except ValueError:
                parsed = None
            return time.monotonic() - t0, st, n429, d, parsed
        if st == 429:
            if n429 >= len(BACKOFF_S) or b'PerDay' in raw:  # daily cap: retrying today cannot help
                return None, st, n429 + 1, raw.decode(errors='replace'), None
            time.sleep(BACKOFF_S[n429] + random.random())
            n429 += 1
        elif st >= 500 and not retried5xx:
            retried5xx = True
            time.sleep(2)
        else:
            return None, st, n429, raw.decode(errors='replace'), None


def env_key():
    key = os.environ.get('GEMINI_API_KEY')
    if not key:
        sys.exit('GEMINI_API_KEY is not set in this shell.')
    return key


def show_models():
    """Write every generateContent model (ID, display name) to raw/models.txt."""
    write_models(list_models(env_key()))


def write_models(listed):
    lines = [f"{m['name'].removeprefix('models/')}\t{m.get('displayName', '')}" for m in listed
             if 'generateContent' in m.get('supportedGenerationMethods', [])]
    RAW.mkdir(exist_ok=True)
    (RAW / 'models.txt').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))


def run(photo_dir, only=None):
    key = env_key()
    photo_dir = Path(photo_dir).expanduser()
    labels = list(csv.DictReader(open(photo_dir / 'labels.csv', newline='')))
    for r in labels:
        assert r['correct_bin'] in BINS, f"{r['file']}: bin {r['correct_bin']!r} not one of {BINS}"
        assert (photo_dir / r['file']).is_file(), f"missing photo {r['file']}"
    listed = list_models(key)
    write_models(listed)
    if only:  # explicit IDs, still checked against models.list
        ids = {m['name'].removeprefix('models/') for m in listed}
        missing = [m for m in only if m not in ids]
        if missing:
            sys.exit(f'Not in models.list: {missing}')
        found = {m: [m] for m in only}
    else:
        found = resolve(listed)
    models, rpm = [], {}
    for name, ids in found.items():
        print(f'{name}: {ids or "MISSING"}')
        if len(ids) > 1:
            print(f'  ambiguous, using the shortest: {min(ids, key=len)}')
        if ids:
            models.append(min(ids, key=len))
            rpm[models[-1]] = WANTED.get(name, ([], 5))[1]
    if not models:
        sys.exit('None of the wanted models is available to this key.')
    RAW.mkdir(exist_ok=True)
    jpegs = {r['file']: crop_jpeg(photo_dir / r['file']) for r in labels}
    order = labels[:]
    random.Random(0).shuffle(order)  # a run cut short by a daily cap still covers all bins
    per_model = [[('main', m, k, r) for r in order for k in 'AB']
                 + [(f'repeat{i}', m, 'A', r) for i in (1, 2, 3) for r in labels[:5]] for m in models]
    # Round-robin across models, so each model's own RPM pacing overlaps the others.
    plan = [p for group in itertools.zip_longest(*per_model) for p in group if p]
    mode = {m: 0 for m in models}
    last = {m: 0.0 for m in models}
    blocked_models = set()
    new = not RESULTS.exists()
    done = set() if new else {(r['run'], r['model'], r['call'], r['file'])
                              for r in csv.DictReader(open(RESULTS, newline='')) if r['http_status'] == '200'}
    plan = [p for p in plan if (p[0], p[1], p[2], p[3]['file']) not in done]  # rerun resumes, e.g. next free-tier day
    with open(RESULTS, 'a', newline='') as f:
        w = csv.DictWriter(f, FIELDS)
        if new:
            w.writeheader()
        for i, (runname, m, kind, r) in enumerate(plan, 1):
            if m in blocked_models:
                continue
            time.sleep(max(0.0, 60 / rpm[m] * 1.1 - (time.monotonic() - last[m])))
            last[m] = time.monotonic()
            wall, st, n429, resp, parsed = call(key, m, kind, jpegs[r['file']], mode[m])
            while st == 400 and mode[m] < len(MODES) - 1:
                mode[m] += 1
                print(f'{m}: HTTP 400, trying mode {MODES[mode[m]][0]!r}')
                wall, st, n429, resp, parsed = call(key, m, kind, jpegs[r['file']], mode[m])
            if st == 400:
                blocked_models.add(m)
                print(f'{m}: rejected in every mode, skipping it: {str(resp)[:200]}')
            (RAW / f'{m}_{runname}_{kind}_{r["file"]}.json').write_text(
                json.dumps(resp, ensure_ascii=False, indent=1) if isinstance(resp, dict) else str(resp))
            ok = st == 200
            u = resp.get('usageMetadata', {}) if ok else {}
            cand = (resp.get('candidates') or [{}])[0] if ok else {}
            blocked = ok and (not resp.get('candidates') or 'promptFeedback' in resp and resp['promptFeedback'].get('blockReason')
                              or cand.get('finishReason') in ('SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'RECITATION'))
            p = parsed if isinstance(parsed, dict) else {}
            q = p.get('question')
            row = dict(run=runname, model=m, call=kind, file=r['file'], label_bin=r['correct_bin'],
                       object_name=p.get('object_name', ''), bin_category=p.get('bin_category', ''),
                       bank_class=p.get('bank_class', ''), confidence=p.get('confidence', ''),
                       hazard=p.get('hazard', ''), question=q.get('question', '') if isinstance(q, dict) else '',
                       wall_s=f'{wall:.3f}' if wall is not None else '',
                       input_tokens=u.get('promptTokenCount', ''), output_tokens=u.get('candidatesTokenCount', ''),
                       thinking_tokens=u.get('thoughtsTokenCount', 0) if ok else '', thinking=MODES[mode[m]][0],
                       json_valid='y' if parsed is not None and all(k in p for k in SCHEMA[kind]['required']) else 'n',
                       blocked='y' if blocked else 'n', rate_limited='y' if n429 else 'n', n_429=n429,
                       http_status=st, error='' if ok else str(resp)[:200].replace('\n', ' '))
            w.writerow(row)
            f.flush()
            print(f'[{i}/{len(plan)}] {m} {runname} {kind} {r["file"]}: HTTP {st} {row["wall_s"]}s '
                  f'{row["bin_category"]} {row["object_name"]!r} 429x{n429}')
            if st == 404:
                blocked_models.add(m)
                print(f'{m}: HTTP 404 (not available to this key), skipping it.')
            if st == 429:
                blocked_models.add(m)
                print(f'{m}: still rate-limited after {n429} retries; stopping this model.')
    if blocked_models:
        print('Rate limits stopped:', ', '.join(sorted(blocked_models)))


def pct(xs, p):
    """Nearest-rank percentile."""
    xs = sorted(xs)
    return xs[max(0, -(-p * len(xs) // 100) - 1)] if xs else None


def cost(tin, tout, pin, pout):
    return tin / 1e6 * pin + tout / 1e6 * pout


def report():
    all_rows = list(csv.DictReader(open(RESULTS, newline='')))
    latest = {}  # a resumed call keeps only its latest attempt; 429 totals still count every row
    for r in all_rows:
        k = (r['run'], r['model'], r['call'], r['file'])
        if r['http_status'] == '200' or latest.get(k, {}).get('http_status') != '200':
            latest[k] = r
    rows = list(latest.values())
    models = list(dict.fromkeys(r['model'] for r in rows))
    f = lambda x: f'{x:.1f}' if x is not None else '-'
    out = ['# Cloud AI benchmark: Gemini identify on ELIOS scan crops', '',
           f'Photos: {len({r["file"] for r in rows})}. Calls: {len(rows)} ({len(all_rows)} attempts). Thinking: '
           f'{", ".join(sorted({r["model"] + "=" + r["thinking"] for r in rows}))}. Free-tier key: timings are an upper bound. '
           'Latency uses unthrottled, successful calls only. A = identify; B = identify + one MC question (one call = one scan).', '',
           '| Model | Bin acc A | Bin acc B | B3 hazard recall (A) | A p50/p95 s | B p50/p95 s | avg tokens A in/out (think) | avg tokens B in/out (think) | $/scan (B) | $/1k scans | JSON ok | blocked | 429 |',
           '|---|---|---|---|---|---|---|---|---|---|---|---|---|']
    for m in models:
        mr = [r for r in rows if r['model'] == m]
        ok = [r for r in mr if r['http_status'] == '200']
        main = lambda k: [r for r in ok if r['run'] == 'main' and r['call'] == k]
        acc = lambda k: f'{sum(r["bin_category"] == r["label_bin"] for r in main(k))}/{len(main(k))}'
        b3 = [r for r in main('A') if r['label_bin'] == 'B3']
        lat = lambda k: [float(r['wall_s']) for r in ok if r['call'] == k and r['rate_limited'] == 'n']
        def toks(k):
            rs = main(k)
            if not rs:
                return None
            n = len(rs)
            i = sum(int(r['input_tokens'] or 0) for r in rs) / n
            o = sum(int(r['output_tokens'] or 0) for r in rs) / n
            t = sum(int(r['thinking_tokens'] or 0) for r in rs) / n
            return i, o, t
        ta, tb = toks('A'), toks('B')
        costs = [(lbl, cost(tb[0], tb[1] + tb[2], pi, po)) for lbl, pi, po in PRICES.get(m, [])] if tb else []
        cs = ' / '.join(f'${c:.5f}{" " + l if l else ""}' for l, c in costs) or ('free only' if m.startswith('gemma') else '-')
        ck = ' / '.join(f'${c * 1000:.2f}{" " + l if l else ""}' for l, c in costs) or '-'
        tk = lambda t: f'{t[0]:.0f}/{t[1]:.0f} ({t[2]:.0f})' if t else '-'
        out.append(f'| {m} | {acc("A")} | {acc("B")} | {sum(r["hazard"] == "True" for r in b3)}/{len(b3)} | '
                   f'{f(pct(lat("A"), 50))}/{f(pct(lat("A"), 95))} | {f(pct(lat("B"), 50))}/{f(pct(lat("B"), 95))} | '
                   f'{tk(ta)} | {tk(tb)} | {cs} | {ck} | {sum(r["json_valid"] == "y" for r in mr)}/{len(mr)} | '
                   f'{sum(r["blocked"] == "y" for r in mr)} | {sum(int(r["n_429"]) for r in all_rows if r["model"] == m)} |')
    n_ok = {m: len({r['file'] for r in rows if r['model'] == m and r['http_status'] == '200'}) for m in models}
    out += ['', 'Photos with at least one answer: ' + ', '.join(f'{m} {n}' for m, n in n_ok.items()) + '. '
            + ('**Too small to separate models**: fewer than 20 photos for ' + ', '.join(m for m, n in n_ok.items() if n < 20)
               + '. The run was stopped early (free-tier daily caps and 503 "high demand" errors).'
               if any(n < 20 for n in n_ok.values()) else '')]
    out += ['', 'Cost counts thinking tokens as output. Gemma on-device baseline (docs/handoff/lane-a.md, not re-measured): '
            'identify 20-27 s, questions 20-41 s.', '', '## Wrong bin or failed calls (judge names by eye)', '',
            '| Model | Call | File | Label | Got bin | object_name | Note |', '|---|---|---|---|---|---|---|']
    for r in rows:
        if r['run'] == 'main' and (r['bin_category'] != r['label_bin'] or r['json_valid'] == 'n'):
            note = f'HTTP {r["http_status"]}' if r['http_status'] != '200' else ('bad JSON' if r['json_valid'] == 'n' else '')
            out.append(f'| {r["model"]} | {r["call"]} | {r["file"]} | {r["label_bin"]} | {r["bin_category"]} | {r["object_name"]} | {note} |')
    out += ['', '## All object names (call A, main run)', '', '| File | Label | ' + ' | '.join(models) + ' |',
            '|---|---|' + '---|' * len(models)]
    for fn in dict.fromkeys(r['file'] for r in rows):
        lb = next(r['label_bin'] for r in rows if r['file'] == fn)
        names = [next((r['object_name'] for r in rows if r['file'] == fn and r['model'] == m
                       and r['run'] == 'main' and r['call'] == 'A'), '-') for m in models]
        out.append(f'| {fn} | {lb} | ' + ' | '.join(names) + ' |')
    (HERE / 'report.md').write_text('\n'.join(out) + '\n')
    print('\n'.join(out[:6 + len(models)]))


def selftest():
    assert pct([1, 2, 3, 4], 50) == 2 and pct([1, 2, 3, 4], 95) == 4 and pct([5], 95) == 5 and pct([], 50) is None
    assert abs(cost(1_000_000, 1_000_000, 0.25, 1.50) - 1.75) < 1e-9
    assert len(SCHEMA['B']['required']) == 6 and 'Human_Hand' not in CLASSES
    print('selftest ok')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'run' and len(sys.argv) in (3, 4):
        run(sys.argv[2], sys.argv[3].split(',') if len(sys.argv) == 4 else None)
    elif cmd == 'models':
        show_models()
    elif cmd == 'report':
        report()
    elif cmd == 'selftest':
        selftest()
    else:
        sys.exit(__doc__)
