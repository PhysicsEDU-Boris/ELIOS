"""drive_char(): app motor left/right -> codeMotorSlave.ino command char."""
import ast
import unittest
from pathlib import Path


def load():
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body if getattr(n, 'name', None) == 'drive_char'
            or getattr(getattr(n, 'targets', [None])[0], 'id', None) == 'DRIVE_DEADBAND']
    ns = {}
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns['drive_char']


class DriveCharTest(unittest.TestCase):
    def test_mapping(self):
        d = load()
        # Real app values from the robot log (19 Nov): jitter (3,-3) and ramp tails were spins.
        for (l, r), c in {(200, 200): 'F', (-200, -200): 'B', (-150, 150): 'L', (150, -150): 'R',
                          (0, 0): 'S', (3, -3): 'S', (4, -4): 'S', (17, -1): 'S', (27, 8): 'F',
                          (80, 65): 'F', (-16, 16): 'L', (5, 52): 'F', (-12, -21): 'B', (200, 0): 'F'}.items():
            self.assertEqual(d(l, r), c, (l, r))


if __name__ == '__main__':
    unittest.main()
