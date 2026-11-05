#!/usr/bin/env python3
"""Translate the Learn content in Firestore into a reviewable JSON (decision 0185).

  Set GEMINI_API_KEY in the environment; never save it in this file.
  export GOOGLE_APPLICATION_CREDENTIALS=~/path/service-account.json   # read access
  python3 tools/l10n/translate_firestore.py export en              # reads Firestore, writes the review file
  python3 tools/l10n/translate_firestore.py export en --from dump.json   # or translate a saved dump instead
  python3 tools/l10n/translate_firestore.py upload tools/l10n/out/firestore_i18n_en.json   # OWNER ONLY
  python3 tools/l10n/translate_firestore.py --selftest

`export` only reads Firestore. It writes tools/l10n/out/firestore_i18n_<lang>.json
with every translated field per document, marked "machine translation, needs
owner review". Nothing is written if any reply drops a field, changes a
{placeholder} or changes the number of quiz options.

`upload` is a separate step the owner runs after reviewing the file: it merges
`i18n.<lang>` into each document and touches no other field. The app shows
`i18n[appLanguage][field]` and falls back to the original field.
"""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gemini_json import NOTE, api_key, check, selftest as base_selftest, translate

OUT = Path(__file__).parent / 'out'
# Collection (or collection group) -> translated fields. Must match lib/models.
FIELDS = {
    'elearning_modules': ['title', 'description'],
    'video_lessons': ['sectionTitle', 'title', 'description'],
    'guide_lessons': ['moduleTitle', 'title', 'description'],
    'quiz_sets': ['title', 'description'],
    'questions': ['question', 'options', 'explanation'],  # quizzes/{moduleId}/questions
}
BATCH = 20


def texts_of(docs):
    """{path: {field: value}} for the translatable, non-empty fields."""
    out = {}
    for path, data in docs.items():
        fields = FIELDS[path.split('/')[-2]]
        t = {f: data[f] for f in fields if isinstance(data.get(f), (str, list)) and data.get(f)}
        if t:
            out[path] = t
    return out


def read_firestore():
    import firebase_admin
    from firebase_admin import firestore
    firebase_admin.initialize_app()
    db = firestore.client()
    docs = {}
    for name in FIELDS:
        query = db.collection_group(name) if name == 'questions' else db.collection(name)
        for d in query.stream():
            docs[d.reference.path] = d.to_dict()
    return docs


def export(lang, dump):
    key = api_key()
    docs = json.loads(Path(dump).read_text()) if dump else read_firestore()
    texts = texts_of(docs)
    done, paths = {}, list(texts)
    for i in range(0, len(paths), BATCH):
        part = {p: texts[p] for p in paths[i:i + BATCH]}
        out = translate(key, part, lang, 'learning content')
        errs = check(part, out)
        if errs:
            sys.exit(f'unusable reply, nothing saved: {errs[:5]}')
        done.update(out)
    OUT.mkdir(exist_ok=True)
    target = OUT / f'firestore_i18n_{lang}.json'
    target.write_text(json.dumps({'lang': lang, 'translation': NOTE, 'documents': done},
                                 ensure_ascii=False, indent=2) + '\n')
    print(f'{len(done)} documents -> {target} (review it, then run upload yourself)')


def upload(path):
    data = json.loads(Path(path).read_text())
    import firebase_admin
    from firebase_admin import firestore
    firebase_admin.initialize_app()
    db = firestore.client()
    for doc_path, fields in data['documents'].items():
        db.document(doc_path).set({'i18n': {data['lang']: fields}}, merge=True)
    print(f'merged i18n.{data["lang"]} into {len(data["documents"])} documents')


def selftest():
    base_selftest()
    docs = {'elearning_modules/a': {'title': 'Sampah', 'description': '', 'order': 1},
            'quizzes/m/questions/q1': {'question': 'Apa?', 'options': ['x', 'y'], 'correctIndex': 1}}
    assert texts_of(docs) == {'elearning_modules/a': {'title': 'Sampah'},
                              'quizzes/m/questions/q1': {'question': 'Apa?', 'options': ['x', 'y']}}
    print('selftest ok')


if __name__ == '__main__':
    a = sys.argv[1:]
    if a == ['--selftest']:
        selftest()
    elif len(a) >= 2 and a[0] == 'export' and a[1] == 'en' and (len(a) == 2 or (len(a) == 4 and a[2] == '--from')):
        export(a[1], a[3] if len(a) == 4 else None)
    elif len(a) == 2 and a[0] == 'upload':
        upload(a[1])
    else:
        sys.exit(__doc__)
