"""Run the actual frame-pusher, tracker glue and tag maths with fakes; no Maix hardware imports."""
import ast
import asyncio
import base64
import json
import math
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace

NAMES = {'TRACK_TH', 'TRACK_LOST_FRAMES', 'TRACK_MIN_SIDE', 'HAND_CONF_TH', 'HAND_LABEL',
         'TAG_SIZES_MM', 'NOMINAL_FX', 'track', 'parse_track_box', 'box_det', 'track_frame',
         'hand_dets', 'arm_tags', 'find_arm_tags', 'TAG_SCALE', 'ws_frame_pusher', 'DET_EVERY_N_FRAMES'}


class EndStream(BaseException):
    pass


def load(**ns):
    tree = ast.parse(Path(__file__).with_name('main.py').read_text())
    body = [n for n in tree.body
            if getattr(n, 'name', None) in NAMES
            or getattr(getattr(n, 'targets', [None])[0], 'id', None) in NAMES]
    ns.setdefault('math', math)
    exec(compile(ast.Module(body=body, type_ignores=[]), 'main.py', 'exec'), ns)
    return ns


class Obj(SimpleNamespace):
    pass


class Tag:
    def __init__(self, tag_id, side, cx=100, cy=80):
        self._id, self._cx, self._cy = tag_id, cx, cy
        self._corners = [[cx, cy], [cx + side, cy], [cx + side, cy + side], [cx, cy + side]]

    def id(self):
        return self._id

    def cx(self):
        return self._cx

    def cy(self):
        return self._cy

    def corners(self):
        return self._corners


class TrackBoxTest(unittest.TestCase):
    M = load()

    def test_clips_to_the_frame(self):
        self.assertEqual(self.M['parse_track_box']([-10, 20.7, 100, 50], 640, 480), (0, 20, 90, 50))
        self.assertEqual(self.M['parse_track_box']([600, 400, 100, 100], 640, 480), (600, 400, 40, 80))

    def test_rejects(self):
        for box in [None, [1, 2, 3], [1, 2, 3, 'x'], [1, 2, float('nan'), 4], [True, 2, 30, 40],
                    [0, 0, 4, 100], [700, 0, 50, 50]]:
            with self.assertRaises(ValueError, msg=box):
                self.M['parse_track_box'](box, 640, 480)


class ArmTagsTest(unittest.TestCase):
    M = load()

    def test_only_arm_ids_with_rough_distance(self):
        tags = self.M['arm_tags']([Tag(0, 40), Tag(7, 40), Tag(1, 20)])
        self.assertEqual([t['id'] for t in tags], [0, 1])
        fx = 320 / math.tan(math.radians(40.5))
        self.assertAlmostEqual(tags[0]['dist_mm'], round(fx * 18.52 / 40, 1))
        self.assertAlmostEqual(tags[1]['dist_mm'], round(fx * 10.0 / 20, 1))
        self.assertTrue(all(t['dist_rough'] for t in tags))
        json.dumps(tags, allow_nan=False)  # 0022: never NaN on the wire

    def test_half_size_search_scales_back(self):
        tags = self.M['arm_tags']([Tag(0, 20, cx=50, cy=40)], 2)
        self.assertEqual((tags[0]['cx'], tags[0]['cy']), (100, 80))
        self.assertEqual(tags[0]['dist_mm'], self.M['arm_tags']([Tag(0, 40)])[0]['dist_mm'])

    def test_degenerate_corners_leave_dist_out(self):
        self.assertEqual(self.M['arm_tags']([Tag(0, 0)]), [{'id': 0, 'cx': 100, 'cy': 80}])


class FakeTracker:
    def __init__(self, scores):
        self.scores, self.inits = list(scores), []

    def init(self, frame, x, y, w, h):
        self.inits.append((x, y, w, h))

    def track(self, frame, th):
        return Obj(x=10, y=20, w=30, h=40, score=self.scores.pop(0))


class TrackFrameTest(unittest.TestCase):
    def test_init_follow_and_lose(self):
        tracker = FakeTracker([0.9, 0.2, 0.2, 0.9])
        M = load(tracker=tracker, print=lambda *a: None)
        M['TRACK_LOST_FRAMES'] = 3
        M['track'].update(pending=(5, 6, 20, 30), id=4, label='kardus')
        first = M['track_frame'](None)
        self.assertEqual(tracker.inits, [(5, 6, 20, 30)])
        self.assertEqual(first, {'label': 'kardus', 'score': 1.0, 'x': 15, 'y': 21, 'w': 20, 'h': 30,
                                 'track_id': 4})
        self.assertEqual(M['track_frame'](None)['x'], 25)  # centre of the tracked box
        self.assertIsNone(M['track_frame'](None))  # low score: not sent, still tracking
        self.assertTrue(M['track']['on'])
        self.assertIsNone(M['track_frame'](None))
        self.assertTrue(M['track']['on'])
        M['track']['misses'] = 2
        tracker.scores.insert(0, 0.1)
        self.assertIsNone(M['track_frame'](None))
        self.assertFalse(M['track']['on'])  # lost: stopped, no box until the next track_start
        self.assertIsNone(M['track_frame'](None))

    def test_nothing_locked(self):
        M = load(tracker=FakeTracker([]))
        self.assertIsNone(M['track_frame'](None))


class StreamTest(unittest.TestCase):
    def test_clean_frames_tracked_box_hands_and_tags(self):
        frames, messages, encodes = [], [], []

        class Frame:
            def __init__(self, number):
                self.number = number

            def to_format(self, _format):
                encodes.append(self.number)
                return SimpleNamespace(to_bytes=lambda: str(self.number).encode())

            def resize(self, w, h):
                assert (w, h) == (320, 240)  # 640x480 crashes find_apriltags on the camera
                return self

            def width(self):
                return 640

            def height(self):
                return 480

            def find_apriltags(self, families):
                return [Tag(0, 20)] if self.number == 2 else []

        class Camera:
            def read(self):
                frames.append(Frame(len(frames) + 1))
                return frames[-1]

        class Client:
            async def send(self, payload):
                messages.append(json.loads(payload))
                if len(messages) == 4:
                    raise EndStream()

        hand = Obj(x=0, y=0, w=10, h=10, score=0.8)
        ticks = iter(range(0, 10 ** 6, 7))
        M = load(asyncio=asyncio, json=json, base64=base64, print=lambda *a: None,
                 stream_cam=Camera(), ws_streaming=True, ws_clients={Client()},
                 cam_lock=threading.Lock(), setup={'stage': None},
                 STREAM_RESOLUTION=(640, 480), FIRMWARE_SHA256='test-hash',
                 mtime=SimpleNamespace(ticks_ms=lambda: next(ticks)),
                 tracker=FakeTracker([0.9, 0.9, 0.9]),
                 hands=SimpleNamespace(detect=lambda frame, conf_th: [hand] if frame.number == 2 else []),
                 image=SimpleNamespace(Format=SimpleNamespace(FMT_JPEG=1),
                                       ApriltagFamilies=SimpleNamespace(TAG36H11=16)))
        M['track'].update(pending=(100, 100, 50, 60), id=1, label='kardus')
        with self.assertRaises(EndStream):
            asyncio.run(M['ws_frame_pusher']())

        self.assertEqual(encodes, [1, 2, 3, 4])  # one JPEG per frame, never a second one
        for m in messages:
            self.assertEqual(m['vision_protocol'], 1)
            self.assertEqual((m['img_w'], m['img_h']), (640, 480))
        self.assertEqual(messages[0]['detections'], [])  # the tracker inits on the next detection frame
        self.assertIsNone(messages[0]['detection_frame_id'])
        self.assertNotIn('clean_image', messages[0])

        fresh = messages[1]
        self.assertEqual(fresh['frame_id'], fresh['detection_frame_id'])
        self.assertEqual([d['label'] for d in fresh['clean_detections']], ['kardus', 'Human_Hand'])
        self.assertEqual(fresh['detections'][0]['x'], 125)
        self.assertEqual(fresh['detections'][0]['track_id'], 1)
        self.assertEqual(fresh['clean_image'], fresh['image'])
        self.assertEqual(base64.b64decode(fresh['clean_image']), b'2')
        self.assertEqual(fresh['arm_tags'][0]['id'], 0)

        self.assertEqual(messages[2]['detections'], fresh['detections'])  # held between detection frames
        self.assertEqual(messages[2]['arm_tags'][0]['id'], 0)  # held until the next detection frame
        self.assertEqual([d['label'] for d in messages[3]['clean_detections']], ['kardus'])
        self.assertEqual(messages[3]['detections'][0]['x'], 25)  # FakeTracker's box
        self.assertEqual(messages[3]['arm_tags'], [])


if __name__ == '__main__':
    unittest.main()
