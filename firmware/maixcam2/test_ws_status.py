"""Run the actual ws_handler with fake clients: the dashboard pill after a client leaves."""
import ast
import asyncio
import json
import unittest
from pathlib import Path


def load():
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body if getattr(n, 'name', None) == 'ws_handler']
    ns = {'json': json, 'ws_status': 'Serving', 'ws_streaming': False, 'ws_clients': set(), 'stream_cam': None}
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns


class Client:
    remote_address = ('10.0.0.2', 1234)

    def __init__(self, messages=()):
        self.messages = list(messages)

    async def send(self, _):
        pass

    def __aiter__(self):
        return self

    async def __anext__(self):
        if not self.messages:
            raise StopAsyncIteration
        return self.messages.pop(0)


class WsStatusTest(unittest.TestCase):
    def test_last_client_leaving_shows_waiting_not_offline(self):
        ns = load()
        asyncio.run(ns['ws_handler'](Client()))
        self.assertEqual(ns['ws_status'], 'Serving')
        self.assertEqual(ns['ws_clients'], set())

    def test_one_of_two_clients_leaving_stays_connected(self):
        ns = load()
        ns['ws_clients'].add(Client())
        asyncio.run(ns['ws_handler'](Client([json.dumps({'cmd': 'start_stream'})])))
        self.assertEqual(ns['ws_status'], 'Client connected')
        self.assertTrue(ns['ws_streaming'])


if __name__ == '__main__':
    unittest.main()
