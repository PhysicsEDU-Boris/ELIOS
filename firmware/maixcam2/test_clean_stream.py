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

NAMES = {'HOLD_SHIFT', 'HOLD_SIZE', 'SETTLE_CALLS', 'SETTLE', 'moved', 'hold', 'TRACK_TH', 'TRACK_MAX_GROWTH', 'TRACK_REFIND_AFTER', 'TRACK_MIN_SIDE', 'HAND_CONF_TH', 'HAND_LABEL',
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
    def test_a_still_item_keeps_one_box_a_move_is_followed_then_held(self):
        hold = load()['hold']
        t = {'box': (161, 253, 84, 124), 'still': []}  # the LOCK box
        # The robot's measured noise on a still pack: y +-4 px, height +-7 px, x/w +-1 px.
        noise = [(161, 255, 84, 120), (162, 250, 85, 131), (161, 256, 84, 117), (160, 252, 83, 127),
                 (161, 254, 84, 122), (161, 249, 84, 130), (162, 256, 85, 118), (161, 253, 84, 125)]
        noise += [(161, 253, 79, 124), (161, 253, 80, 124), (161, 253, 79, 125), (161, 253, 80, 124),
                  (161, 253, 79, 124)] * 2  # width 4-5 px off for 2 s, as measured: not worth a jump
        sent = {hold(t, b) for b in noise}
        self.assertEqual(sent, {(161, 253, 84, 124)})  # one box, no jiggle (median within 6 %)
        moved_to = (200, 250, 84, 124)  # slid 39 px: followed at once
        self.assertEqual(hold(t, moved_to), moved_to)
        after = [(201, 242, 85, 133), (200, 241, 84, 134), (201, 242, 84, 135), (200, 243, 84, 133),
                 (201, 242, 85, 134), (200, 241, 84, 135)]
        sent = [hold(t, b) for b in after]
        self.assertEqual(sent[:4], [moved_to] * 4)
        self.assertEqual(sent[4], (201, 242, 84, 134))  # 10 px taller: settled once, then held
        self.assertEqual(sent[5], sent[4])

    def test_driving_closer_is_followed(self):
        boxes = iter([(300, 200, 40, 50), (295, 195, 52, 65), (288, 188, 68, 85), (280, 180, 88, 110)])
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(**dict(zip('xywh', next(boxes))), score=0.99)))
        M['track'].update(pending=(300, 200, 40, 50), id=1, label='kardus')
        M['track_frame'](None)
        widths = [M['track_frame'](None)['w'] for _ in range(4)]
        self.assertEqual(widths[-1], 88)  # 4.8x the LOCK area, ~1.7x per call: still the item

    def test_init_follow_lose_and_find_again(self):
        tracker = FakeTracker([0.9] + [0.2] * 50 + [0.9])
        M = load(tracker=tracker, print=lambda *a: None)
        M['track'].update(pending=(5, 6, 20, 30), id=4, label='kardus')
        first = M['track_frame'](None)
        self.assertEqual(tracker.inits, [(5, 6, 20, 30)])
        self.assertEqual(first, {'label': 'kardus', 'score': 1.0, 'x': 15, 'y': 21, 'w': 20, 'h': 30,
                                 'track_id': 4})
        self.assertEqual(M['track_frame'](None)['x'], 25)  # centre of the tracked box
        for _ in range(50):  # lost for ~10 s: nothing sent, but still searching
            self.assertIsNone(M['track_frame'](None))
        self.assertTrue(M['track']['on'])
        self.assertEqual(M['track_frame'](None)['track_id'], 4)  # found again, same id

    def test_a_box_that_grows_or_shrinks_3x_is_not_sent(self):
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(x=0, y=0, w=W, h=H, score=0.99)))
        M['track'].update(pending=(0, 0, 30, 40), id=1, label='kardus')
        M['track_frame'](None)
        for W, H in [(30, 130), (10, 30)]:  # 1200 -> 3900 and 300 px^2
            self.assertIsNone(M['track_frame'](None))
        W, H = 50, 60  # 2.5x: still the item
        self.assertEqual(M['track_frame'](None)['w'], 50)

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

        # Square crop 0..300, landmarks spanning x 5..15, y 20..60 (one past the frame edge).
        hand = Obj(x=0, y=0, w=300, h=300, score=0.8,
                   points=[0] * 8 + [5, 20, 0, 15, 60, 0] + [10, 500, 0] * 19)
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
        self.assertEqual(fresh['detections'][1], {'label': 'Human_Hand', 'score': 0.8,
                                                  'x': 10, 'y': 250, 'w': 10, 'h': 460})
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
