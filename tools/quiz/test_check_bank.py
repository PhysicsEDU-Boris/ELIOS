import contextlib
import copy
import io
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch

checker = runpy.run_path(str(Path(__file__).with_name('check_bank')))
vb = checker['vb']
BANK, CHUNKS, LABELS = vb.load()
OBJECTS = vb.load_objects()


class BankIntegrity(unittest.TestCase):
    def test_current_bank_and_cli(self):
        self.assertEqual(checker['check'](BANK, OBJECTS, CHUNKS, LABELS), [])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(checker['main'](), 0)

    def test_each_broken_requirement_fails_cli(self):
        for field, value in [('correct', ''), ('wrong', []), ('explanation', ' '),
                             ('sourceChunk', 'missing'), ('pdfPage', -1), ('status', 'acccepted'),
                             ('question', 'Menurut modul, apa ciri sampah ini?')]:
            with self.subTest(field=field):
                bank = copy.deepcopy(BANK)
                bank['items'][0][field] = value
                with patch.object(vb, 'load', return_value=(bank, CHUNKS, LABELS)), \
                        contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(checker['main'](), 1)

    def test_duplicates_across_banks_are_rejected(self):
        objects = copy.deepcopy(OBJECTS)
        objects['objects'][0]['items'][0]['question'] = '  ' + BANK['items'][0]['question'].upper()
        errors = checker['check'](BANK, objects, CHUNKS, LABELS)
        self.assertTrue(any('duplicate question text' in e for e in errors), errors)

    def test_essay_needs_explanation_and_sources(self):
        for field in ('point', 'quote', 'sourceChunk'):
            objects = copy.deepcopy(OBJECTS)
            essay = next(i for i in objects['objects'][0]['items'] if i['type'] == 'essay')
            essay['rubricPoints'][0][field] = ''
            self.assertTrue(checker['check'](BANK, objects, CHUNKS, LABELS), field)


if __name__ == '__main__':
    unittest.main()
