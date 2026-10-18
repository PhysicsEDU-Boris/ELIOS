#!/usr/bin/env python3
"""Checks assets/module/module_chunks.json against the module PDF (decision 0014).

    python3 scripts/test_extract_module.py

Needs pypdf and the PDF at docs/module/ (not committed); skips without them.
"""
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / 'docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf'
CHUNKS = ROOT / 'assets/module/module_chunks.json'
LABELS = ROOT / 'assets/module/label_to_chunks.json'
MAX_WORDS = 700
# Numbered sub-chapters per chapter, counted by hand from the PDF.
SUBCHAPTERS = {1: 6, 2: 10, 3: 5, 4: 8, 5: 3, 6: 8, 7: 6, 8: 4, 9: 0}
BINS = {'Organic': 'organik', 'Paper': 'anorganik', 'Paperboard': 'anorganik', 'Cardboard': 'anorganik',
        'Plastic': 'anorganik', 'Glass': 'anorganik', 'Metal': 'anorganik', 'Tetra_Pak': 'anorganik',
        'E_Waste': 'B3', 'Human_Hand': None}

try:
    import pypdf
except ImportError:
    pypdf = None


def flat(text):
    return ' '.join(text.split())


@unittest.skipUnless(pypdf and PDF.exists(), 'needs pypdf and the module PDF in docs/module/')
class ChunksMatchPdf(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reader = pypdf.PdfReader(PDF)
        # Page text as pypdf gives it, without its first 3 lines (the running header) on pp.2+.
        cls.pages = {}
        for n, page in enumerate(reader.pages, 1):
            lines = page.extract_text().replace('\x7f', '•').split('\n')
            cls.pages[n] = lines if n == 1 else lines[3:]
            if n > 1:
                assert lines[2].strip() == f'Halaman {n}', (n, lines[:3])
        cls.data = json.loads(CHUNKS.read_text(encoding='utf-8'))
        cls.chunks = cls.data['chunks']

    def test_every_chunk_is_verbatim_in_its_pages(self):
        for c in self.chunks:
            pages = '\n'.join('\n'.join(self.pages[p]) for p in range(c['pdfPage'], c['pdfPageEnd'] + 1))
            self.assertTrue(flat(c['text']) in flat(pages), f"chunk {c['id']} not found on pp.{c['pdfPage']}-{c['pdfPageEnd']}")

    def test_no_running_header_or_footer_left(self):
        for c in self.chunks:
            self.assertNotRegex(c['text'], r'Halaman \d+|UNJ · Media ELIO|Modul Pendidikan Fisika Lingkungan –', c['id'])

    def test_printed_page_equals_pdf_page(self):
        for c in self.chunks:
            self.assertEqual(c['printedPage'], c['pdfPage'], c['id'])

    def test_chapters_match_contents_page(self):
        toc = {}
        lines = [l.strip() for l in self.pages[2]]
        for i, line in enumerate(lines[1:], 1):
            if re.fullmatch(r'\d+', lines[i - 1]) and (line.startswith('Bab ') or line in ('Glosarium', 'Daftar Pustaka')):
                toc[line] = int(lines[i - 1])
        chapters = {}
        for c in self.chunks:
            chapters.setdefault(c['chapter'], c['pdfPage'])
        content = {k: v for k, v in toc.items() if v >= 6}
        self.assertEqual(chapters, content)

    def test_subchapters_per_chapter(self):
        for chapter, count in SUBCHAPTERS.items():
            ids = [c['id'] for c in self.chunks if re.fullmatch(rf'{chapter}\.\d+', c['id'])]
            self.assertEqual(ids, [f'{chapter}.{n}' for n in range(1, count + 1)], chapter)
        qa = sorted(c['id'] for c in self.chunks if c['type'] == 'qa')
        self.assertEqual(qa, ['1.qa', '2.qa', '3.qa', '4.qa', '5.qa', '6.qa', '7.qa', '9.qa'])

    def test_table_rows_are_verbatim_cells_from_their_page(self):
        import extract_module
        reader = pypdf.PdfReader(PDF)
        expected = {'1.6': 3, '2.6': 10, '2.7': 6, '2.9': 5, '4.7': 4}
        chunks = {c['id']: c for c in self.chunks}
        for cid, (page, first) in extract_module.ROW_TABLES.items():
            rows = extract_module.table_rows(reader, page, first)
            self.assertEqual(len(rows) - 1, expected[cid], cid)
            page_text = flat('\n'.join(self.pages[page]))
            for row in rows:
                for cell in row:
                    self.assertTrue(flat(cell) in page_text, f'{cid}: cell not on p.{page}: {cell}')
            self.assertEqual(chunks[cid]['rows'], extract_module.row_sentences(rows), cid)
            # The original text is kept unchanged next to the rows.
            self.assertTrue(flat(chunks[cid]['text']) in flat('\n'.join(self.pages[chunks[cid]['pdfPage']])), cid)

    def test_no_chunk_too_long(self):
        for c in self.chunks:
            self.assertLessEqual(len(c['text'].split()), MAX_WORDS, c['id'])

    def test_reproducible_and_asset_up_to_date(self):
        import extract_module
        first = extract_module.dump(extract_module.build(PDF))
        self.assertEqual(first, extract_module.dump(extract_module.build(PDF)))
        self.assertEqual(first, CHUNKS.read_text(encoding='utf-8'), 'asset is stale: re-run extract_module.py')


class LabelMap(unittest.TestCase):
    def test_labels_bins_and_chunk_ids(self):
        labels = json.loads(LABELS.read_text(encoding='utf-8'))['labels']
        ids = {c['id'] for c in json.loads(CHUNKS.read_text(encoding='utf-8'))['chunks']}
        self.assertEqual({k: v['bin'] for k, v in labels.items()}, BINS)
        for name, entry in labels.items():
            self.assertTrue(set(entry['chunks']) <= ids, name)
            if name != 'Human_Hand':
                self.assertIn(entry['coverage'], ('covered', 'partial', 'not_covered'), name)
                for e in entry['evidence']:
                    self.assertTrue(e['pdfPage'] and e['heading'], name)
        self.assertFalse(labels['Human_Hand']['sendToGemma'])
        for name in ('Paper', 'Paperboard', 'Cardboard'):
            self.assertIn('never state flatly', labels[name]['note'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
