"""Run the actual QR parser and apply_wifi() against a temp /boot; no Maix hardware."""
import ast
import os
import tempfile
import unittest
from pathlib import Path

NAMES = {'BOOT_DIR', 'WIFI_FILES', 'JOIN_TIMEOUT_S', 'parse_wifi_qr', '_read_wifi_files',
         '_write_wifi_files', '_restart_wifi', 'apply_wifi'}


def load():
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body
            if getattr(n, 'name', None) in NAMES
            or getattr(getattr(n, 'targets', [None])[0], 'id', None) in NAMES]
    ns = {'os': os}
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns


M = load()


class ParseTest(unittest.TestCase):
    def test_android_hotspot_share_qr(self):
        self.assertEqual(M['parse_wifi_qr']('WIFI:T:WPA;S:boris;P:secret123;H:false;;'), ('boris', 'secret123'))

    def test_escapes_and_any_field_order(self):
        self.assertEqual(M['parse_wifi_qr'](r'WIFI:P:pa\:ss\;w\\rd;S:my\;net;T:WPA;;'), ('my;net', r'pa:ss;w\rd'))

    def test_rejects(self):
        for text in ('hello', 'WIFI:T:nopass;S:x;;', 'WIFI:T:WPA;S:x;P:short;;',
                     'WIFI:T:WPA;S:;P:secret123;;', 'WIFI:T:WPA;S:{};P:secret123;;'.format('x' * 33)):
            with self.subTest(text=text), self.assertRaises(ValueError):
                M['parse_wifi_qr'](text)


class ApplyTest(unittest.TestCase):
    def setUp(self):
        self.boot = tempfile.mkdtemp()
        for name, data in {'wifi.ap': b'', 'wifi.ssid': b'ELIOS', 'wifi.pass': b'elio12345',
                           'wifi.ipv4_prefix': b'192.168.4'}.items():
            Path(self.boot, name).write_bytes(data)
        self.before = self.files()
        self.cmds, self.waits = [], []

    def files(self):
        return {p.name: p.read_bytes() for p in Path(self.boot).iterdir()}

    def apply(self, *ips):
        ips = list(ips)

        def wait(want_ap, timeout_s):
            self.waits.append(want_ap)
            return ips.pop(0)
        return M['apply_wifi']('boris', 'secret123', boot=self.boot, run=self.cmds.append, wait=wait)

    def test_join_switches_ap_to_sta(self):
        self.assertEqual(self.apply('10.51.200.84'), (True, '10.51.200.84'))
        self.assertEqual(self.files(), {'wifi.sta': b'', 'wifi.ssid': b'boris', 'wifi.pass': b'secret123',
                                        'wifi.ipv4_prefix': b'192.168.4'})
        self.assertEqual(self.waits, [False])
        self.assertIn(['rmmod', 'aic8800_fdrv'], self.cmds)
        self.assertEqual(self.cmds[-2:], [['systemctl', 'start', '--no-block', 'wifi.service'],
                                          ['systemctl', 'restart', 'udhcpc.service']])

    def test_no_ip_restores_the_old_files(self):
        ok, msg = self.apply('', '192.168.4.1')
        self.assertFalse(ok)
        self.assertIn("Couldn't join boris", msg)
        self.assertIn('192.168.4.1', msg)
        self.assertEqual(self.files(), self.before)
        self.assertEqual(self.waits, [False, True])  # then waits for the old AP to come back

    def test_wpa_supplicant_override_is_refused_untouched(self):
        Path(self.boot, 'wpa_supplicant.conf').write_bytes(b'x')
        ok, _ = self.apply()
        self.assertFalse(ok)
        self.assertEqual(self.cmds, [])
        self.assertEqual(self.files(), {**self.before, 'wpa_supplicant.conf': b'x'})


if __name__ == '__main__':
    unittest.main()
