"""Run the actual frame-pusher with fake camera/inference; no Maix hardware imports."""
import ast
import asyncio
import base64
import json
import unittest
from pathlib import Path
from types import SimpleNamespace


class EndStream(BaseException):
    pass


class CleanStreamTest(unittest.TestCase):
    def test_original_pixels_and_fresh_geometry_only(self):
        source = Path(__file__).with_name('main.py').read_text()
        tree = ast.parse(source)
        push = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == 'ws_frame_pusher')
        frames, messages, encodes = [], [], []

        class Frame:
            def __init__(self, number):
                self.number, self.annotations = number, []

            def to_format(self, _format):
                # Snapshot at encoding time, so drawing later cannot change it.
                encoded = json.dumps([self.number, list(self.annotations)]).encode()
                encodes.append((self.number, list(self.annotations)))
                return SimpleNamespace(to_bytes=lambda: encoded)

            def draw_rect(self, *args, **kwargs):
                self.annotations.append('box')

            def draw_string(self, *args, **kwargs):
                self.annotations.append('label')

        class Camera:
            def read(self):
                frame = Frame(len(frames) + 1)
                frames.append(frame)
                return frame

        class Client:
            async def send(self, payload):
                messages.append(json.loads(payload))
                if len(messages) == 6:
                    raise EndStream()

        obj = {'class_id': 0, 'x': 10, 'y': 20, 'w': 30, 'h': 40,
               'score': .9, 'seg_mask': True, 'misses': 0}

        def infer(frame, *args):
            # Fresh object, then a grace-held old box, then a truly empty scene.
            return {2: [obj], 4: [{**obj, 'misses': 1}], 6: []}[frame.number]

        ns = dict(asyncio=asyncio, json=json, base64=base64,
                  stream_cam=Camera(), ws_streaming=True, ws_clients={Client()},
                  STREAM_RESOLUTION=(640, 640), DET_EVERY_N_FRAMES=2,
                  model_loaded=True, model=SimpleNamespace(forward_image=infer),
                  mean=None, scale=None, RAW_CONF_TH=.25, DET_IOU_TH=.45,
                  decode_seg=lambda outputs, **kwargs: outputs, _update_lock=lambda objs: objs,
                  LABELS=['E_Waste'], FIRMWARE_SHA256='test-hash',
                  image=SimpleNamespace(Format=SimpleNamespace(FMT_JPEG=1),
                                        Fit=SimpleNamespace(FIT_CONTAIN=1), COLOR_GREEN=1),
                  detector=SimpleNamespace(draw_seg_mask=lambda frame, *a, **kw: frame.annotations.append('mask')))
        exec(compile(ast.Module(body=[push], type_ignores=[]), 'main.py', 'exec'), ns)
        with self.assertRaises(EndStream):
            asyncio.run(ns['ws_frame_pusher']())
        self.assertEqual(len(messages), 6)  # preview never paused
        self.assertEqual(len(encodes), 7)  # six previews, one necessary clean JPEG
        fresh = messages[1]
        self.assertEqual(fresh['frame_id'], fresh['detection_frame_id'])
        self.assertEqual(fresh['vision_protocol'], 1)
        self.assertEqual(json.loads(base64.b64decode(fresh['clean_image'])), [2, []])
        self.assertEqual(json.loads(base64.b64decode(fresh['image'])), [2, ['mask', 'box', 'label']])
        self.assertEqual(fresh['clean_detections'][0]['x'], 25)
        self.assertEqual(fresh['clean_detections'][0]['y'], 40)
        for index in [0, 2, 4]:
            self.assertNotIn('clean_image', messages[index])
            self.assertNotIn('clean_detections', messages[index])
            self.assertIsNone(messages[index]['detection_frame_id'])
        self.assertTrue(messages[3]['detections'])  # held box still in preview
        for index in [3, 5]:
            self.assertEqual(messages[index]['clean_detections'], [])
            self.assertNotIn('clean_image', messages[index])


if __name__ == '__main__':
    unittest.main()
