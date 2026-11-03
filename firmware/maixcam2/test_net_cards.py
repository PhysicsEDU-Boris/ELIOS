"""Run the actual net_cards() with a fake maix.network; no Maix hardware imports."""
import ast
import unittest
from pathlib import Path
from types import SimpleNamespace

NAMES = {'NET_REFRESH_MS', '_wifi', '_net', 'net_cards'}


def load(wifi):
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body
            if getattr(n, 'name', None) in NAMES
            or getattr(getattr(n, 'targets', [None])[0], 'id', None) in NAMES]
    ns = {'network': SimpleNamespace(wifi=SimpleNamespace(Wifi=lambda: wifi))}
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns['net_cards']


class FakeWifi:
    def __init__(self, ip, ssid='boris', ap=False):
        self.ip, self.ssid, self.ap, self.reads = ip, ssid, ap, 0

    def get_ip(self):
        self.reads += 1
        return self.ip

    def get_ssid(self):
        return self.ssid

    def is_ap_mode(self):
        return self.ap


class NetCardsTest(unittest.TestCase):
    def test_sta_shows_live_ip_and_refreshes_every_few_seconds(self):
        wifi = FakeWifi('10.51.200.84')
        net_cards = load(wifi)
        self.assertEqual(net_cards(0), ('boris (STA)', '10.51.200.84'))
        wifi.ip = '10.7.1.20'  # hotspot restarted on a new subnet
        self.assertEqual(net_cards(2999), ('boris (STA)', '10.51.200.84'))
        self.assertEqual(wifi.reads, 1)
        self.assertEqual(net_cards(3000), ('boris (STA)', '10.7.1.20'))

    def test_ap_mode_label(self):
        self.assertEqual(load(FakeWifi('192.168.4.1', 'ELIOS', ap=True))(0), ('ELIOS (AP)', '192.168.4.1'))

    def test_no_ip_shows_dashes(self):
        self.assertEqual(load(FakeWifi(''))(0), ('--', '--'))

    def test_read_error_shows_dashes(self):
        wifi = FakeWifi('10.0.0.2')
        wifi.get_ip = lambda: (_ for _ in ()).throw(RuntimeError('no wlan0'))
        self.assertEqual(load(wifi)(0), ('--', '--'))


if __name__ == '__main__':
    unittest.main()
