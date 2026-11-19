"""drive_char(): app motor left/right -> codeMotorSlave.ino command char."""
import ast
import unittest
from pathlib import Path


def load():
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body if getattr(n, 'name', None) == 'drive_char']
    ns = {}
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns['drive_char']


class DriveCharTest(unittest.TestCase):
    def test_mapping(self):
        d = load()
        for (l, r), c in {(200, 200): 'F', (-200, -200): 'B', (-150, 150): 'L', (150, -150): 'R',
                          (0, 0): 'S', (200, 0): 'S', (0, -200): 'S'}.items():
            self.assertEqual(d(l, r), c, (l, r))


if __name__ == '__main__':
    unittest.main()
