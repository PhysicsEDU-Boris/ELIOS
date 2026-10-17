#!/usr/bin/env python3
"""Tests for scripts/validate_bank.py (decision 0015).

    python3 scripts/test_validate_bank.py

Each test breaks one rule on a copy of the real draft bank and expects the
validator to name it.
"""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_bank as vb  # noqa: E402

BANK, CHUNKS, LABELS = vb.load()


def first(bank, kind, pool=None):
    return next(i for i in bank['items'] if i['type'] == kind and (pool is None or i['pool'] == pool))


class DraftBank(unittest.TestCase):
    def errors_after(self, change):
        bank = copy.deepcopy(BANK)
        change(bank)
        return ' | '.join(vb.validate(bank, CHUNKS, LABELS))

    def test_real_bank_is_clean(self):
        self.assertEqual(vb.validate(BANK, CHUNKS, LABELS), [])

    def test_counts_per_pool(self):
        for pool in vb.POOLS:
            items = [i for i in BANK['items'] if i['pool'] == pool]
            self.assertEqual(sum(i['type'] == 'mc' for i in items), 6, pool)
            self.assertEqual(sum(i['type'] == 'essay' for i in items), 2, pool)
        self.assertIn('0 essays', self.errors_after(lambda b: b['items'].__setitem__(
            slice(None), [i for i in b['items'] if not (i['pool'] == 'glass' and i['type'] == 'essay')])))

    def test_quote_must_be_verbatim(self):
        self.assertIn('not verbatim', self.errors_after(
            lambda b: first(b, 'mc').__setitem__('quote', first(b, 'mc')['quote'].replace('makhluk hidup', 'benda hidup'))))

    def test_rubric_quote_must_be_verbatim(self):
        self.assertIn('rubric 1: quote not verbatim', self.errors_after(
            lambda b: first(b, 'essay')['rubricPoints'][0].__setitem__('quote', 'Kalimat yang tidak ada di modul.')))

    def test_exactly_three_distinct_wrong_none_equal_correct(self):
        self.assertIn('exactly 3', self.errors_after(lambda b: first(b, 'mc')['wrong'].pop()))
        self.assertIn('not distinct', self.errors_after(
            lambda b: first(b, 'mc')['wrong'].__setitem__(1, first(b, 'mc')['wrong'][0] + '.')))
        self.assertIn('equals the correct', self.errors_after(
            lambda b: first(b, 'mc')['wrong'].__setitem__(0, first(b, 'mc')['correct'].upper())))

    def test_page_must_be_inside_the_chunk(self):
        self.assertIn('outside chunk', self.errors_after(lambda b: first(b, 'mc').__setitem__('pdfPage', 30)))
        self.assertIn('missing pdfPage', self.errors_after(lambda b: first(b, 'essay').pop('pdfPage')))

    def test_skipped_topics(self):
        self.assertIn('maturing', self.errors_after(
            lambda b: first(b, 'mc').__setitem__('question', 'Berapa lama pematangan kompos aerobik?')))
        self.assertIn('skip list', self.errors_after(lambda b: first(b, 'mc').__setitem__('sourceChunk', '6.6')))
        self.assertIn('robot', self.errors_after(
            lambda b: first(b, 'mc').__setitem__('question', 'Bagaimana robot memilah sampah ini?')))
        self.assertIn('percentages', self.errors_after(
            lambda b: first(b, 'mc', 'tetra_pak').__setitem__('correct', 'Sekitar 75% karton')))
        self.assertIn('flatly', self.errors_after(
            lambda b: first(b, 'mc', 'paper_family').__setitem__('explanation', 'Kertas adalah sampah anorganik.')))
        self.assertIn('all/none', self.errors_after(
            lambda b: first(b, 'mc')['wrong'].__setitem__(0, 'Semua jawaban di atas benar')))

    def test_near_duplicates_and_module_repeats(self):
        def dup(b):
            items = [i for i in b['items'] if i['pool'] == 'metal']
            items[1]['question'] = items[0]['question'] + ' Jelaskan.'
        self.assertIn('near-duplicate', self.errors_after(dup))
        self.assertIn('repeats the module question', self.errors_after(
            lambda b: first(b, 'mc', 'tetra_pak').__setitem__(
                'question', 'Mengapa kemasan karton minuman tidak dimasukkan ke sampah organik padahal sebagian besar kertas?')))


if __name__ == '__main__':
    unittest.main(verbosity=2)
