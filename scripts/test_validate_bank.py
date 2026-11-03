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


OBJECTS = vb.load_objects()


def first_object_mc(obank, name=None):
    o = next(o for o in obank['objects'] if name is None or o['object'] == name)
    return o, next(i for i in o['items'] if i['type'] == 'mc')


class ObjectBank(unittest.TestCase):
    def errors_after(self, change):
        obank = copy.deepcopy(OBJECTS)
        change(obank)
        return ' | '.join(vb.validate_objects(obank, CHUNKS))

    def test_real_object_bank_is_clean_and_complete(self):
        self.assertEqual(vb.validate_objects(OBJECTS, CHUNKS), [])
        names = {o['object'] for o in OBJECTS['objects']}
        for must in ('ponsel', 'laptop', 'baterai', 'lampu_tl_cfl', 'botol_plastik', 'gelas_plastik', 'toples_kaca',
                     'kaleng_aluminium', 'kardus', 'kertas', 'kulit_pisang', 'kotak_susu'):
            self.assertIn(must, names)

    def test_source_wording_is_rejected(self):
        self.assertIn('refers to the source text', self.errors_after(
            lambda b: first_object_mc(b)[1].__setitem__('question', 'Berdasarkan kutipan, ponsel termasuk apa?')))
        self.assertIn('refers to the source text', self.errors_after(
            lambda b: first_object_mc(b)[1].__setitem__('question', 'Menurut modul kuliah, ponsel termasuk apa?')))

    def test_mixed_units_are_rejected(self):
        def mix(b):
            item = first_object_mc(b, 'kaleng_aluminium')[1]  # options in %
            item['wrong'][0] = 'Sekitar 660°C'
        self.assertIn('mix units', self.errors_after(mix))

    def test_row_sentence_quotes_count_as_verbatim(self):
        o, item = first_object_mc(OBJECTS, 'perangkat_elektronik')
        self.assertNotIn(vb.flat(item['quote']), vb.flat(CHUNKS[item['sourceChunk']]['text']),
                         'this quote only exists in a table row sentence')
        self.assertEqual(vb.check_quote('x', item['quote'], item['sourceChunk'], item['pdfPage'], CHUNKS), [])

    def test_per_object_counts_and_shared_synonyms(self):
        self.assertIn('at least 3 mc', self.errors_after(
            lambda b: b['objects'][0].__setitem__('items', [i for i in b['objects'][0]['items'] if i['difficulty'] != 'Sulit'])))
        self.assertIn('exactly 1 essay', self.errors_after(
            lambda b: b['objects'][0].__setitem__('items', [i for i in b['objects'][0]['items'] if i['type'] != 'essay'])))
        self.assertIn('belongs to both', self.errors_after(lambda b: b['objects'][1]['synonyms'].append('ponsel')))

    def test_true_wrong_option_is_only_a_warning(self):
        obank = copy.deepcopy(OBJECTS)
        kertas = next(o for o in obank['objects'] if o['object'] == 'kertas')
        item = next(i for i in kertas['items'] if i['type'] == 'mc' and i['sourceChunk'] == '4.3')
        item['wrong'][0] = 'Serat selulosa kertas memendek setiap kali didaur ulang'
        warnings = vb.warnings_of([item], CHUNKS)
        self.assertTrue(any('check it is false' in w for w in warnings), warnings)
        self.assertEqual(vb.validate_objects(obank, CHUNKS), [], 'a warning, not an error')


if __name__ == '__main__':
    unittest.main(verbosity=2)
