"""Exercise the actual WebSocket handler without MaixPy or hardware imports."""

import asyncio
import ast
import json
import unittest
from pathlib import Path

from arm_commands import ArmCommandLink


class FakeWebSocket:
    remote_address = ("mock", 1)

    def __init__(self, messages):
        self.messages = iter(messages)
        self.sent = []

    async def recv(self):
        try:
            return next(self.messages)
        except StopIteration as error:
            raise RuntimeError("mock disconnect") from error

    async def send(self, message):
        self.sent.append(json.loads(message))

    async def close(self):
        pass


class ArmWebSocketTest(unittest.TestCase):
    def test_status_stop_and_unknown_home_replies(self):
        source = Path(__file__).with_name("main.py").read_text()
        tree = ast.parse(source)
        handler = next(node for node in tree.body
                       if isinstance(node, ast.AsyncFunctionDef) and node.name == "ws_handler")
        namespace = {
            "asyncio": asyncio, "json": json, "ArmCommandLink": ArmCommandLink,
            "arm_command_link": ArmCommandLink(), "ws_status": "Idle",
            "ws_streaming": False, "ws_clients": set(), "stream_cam": None,
            "FIRMWARE_VERSION": "mock", "FIRMWARE_SHA256": "mock",
            "STREAM_RESOLUTION": (640, 480),
        }
        exec(compile(ast.Module(body=[handler], type_ignores=[]), "main.py", "exec"), namespace)
        websocket = FakeWebSocket([
            '{"cmd":"STATUS","seq":1}',
            '{"cmd":"HEARTBEAT"}',
            '{"cmd":"STOP","seq":2}',
            '{"cmd":"HOME","seq":3}',
        ])
        asyncio.run(namespace["ws_handler"](websocket))
        replies = [message for message in websocket.sent if "seq" in message]
        self.assertEqual(replies, [
            {"event": "ack", "seq": 1, "ee_mm": None, "at_home": None},
            {"event": "ack", "seq": 2},
            {"event": "error", "seq": 3, "reason": "stopped"},
        ])
        self.assertFalse(namespace["arm_command_link"].pose_known)


if __name__ == "__main__":
    unittest.main()
