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

NAMES = {'HOLD_SHIFT', 'HOLD_SIZE', 'SETTLE_CALLS', 'moved', 'median_box', 'place', 'hold', 'TRACK_TH', 'TRACK_MAX_GROWTH', 'TRACK_REFIND_AFTER', 'TRACK_MIN_SIDE', 'HAND_CONF_TH', 'HAND_LABEL',
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
    @staticmethod
    def locked(ai_box):
        """Tracker state right after track_start with the AI's box."""
        return {'box': ai_box, 'base': ai_box, 'ref': None, 'still': [], 'odd': False, 'follow': False}

    def test_a_still_item_keeps_the_ai_box_whatever_the_tracker_draws(self):
        hold = load()['hold']
        ai = (161, 253, 84, 124)
        t = self.locked(ai)
        # The tracker sits on the right half of the pack (owner video 11:23), with the robot's
        # measured noise: y +-4 px, height +-7 px, x/w +-1 px.
        half = [(203, 255, 42, 120), (204, 250, 43, 131), (203, 256, 42, 117), (202, 252, 41, 127),
                (203, 254, 42, 122), (203, 249, 42, 130), (204, 256, 43, 118), (203, 253, 42, 125)]
        self.assertEqual({hold(t, b) for b in half}, {ai})  # the AI box, unchanged
        self.assertEqual(hold(t, (240, 250, 42, 124)), ai)  # one odd box: ignored
        self.assertEqual(hold(t, (203, 254, 42, 123)), ai)

    def test_a_slide_moves_the_ai_box_every_call_then_holds_it(self):
        hold = load()['hold']
        ai = (100, 250, 84, 124)
        t = self.locked(ai)
        hold(t, (142, 250, 42, 124))  # the tracker's half box goes with the AI box
        slide = [(155 + 13 * k, 250, 42, 124) for k in range(8)]  # 13 px a call
        sent = [hold(t, b) for b in slide]
        self.assertEqual(sent[0], ai)  # first odd box: not yet
        for k, box in enumerate(sent[1:], 1):  # then every call: the AI box, moved like the tracker
            self.assertEqual(box, (113 + 13 * k, 250, 84, 124))
        stopped = [(246, 251, 42, 126), (248, 249, 42, 122), (247, 250, 42, 124), (246, 252, 41, 125),
                   (247, 250, 42, 124), (248, 251, 42, 123), (247, 249, 43, 124)]
        sent = [hold(t, b) for b in stopped]
        self.assertEqual(sent[-3:], [sent[-1]] * 3)  # held within ~1 s of stopping
        x, y, w, h = sent[-1]
        self.assertLessEqual(abs(x - 205), 2)  # the whole pack, not the tracker's half
        self.assertEqual((round(w), round(h)), (84, 124))
        self.assertFalse(t['follow'])

    def test_a_flipped_item_in_place_settles_without_bouncing(self):
        hold = load()['hold']
        t = self.locked((160, 250, 90, 130))
        # Flipped in place: the tracker's box swings 15-40 % in height, with single wild ones.
        flipped = [(160, 250, 90, 130), (160, 260, 90, 110), (158, 240, 92, 150), (160, 300, 90, 60),
                   (161, 255, 89, 118), (160, 245, 90, 140), (159, 258, 91, 112), (160, 248, 90, 145),
                   (160, 310, 90, 40), (161, 252, 90, 125), (160, 256, 90, 115)]
        sent = [hold(t, b) for b in flipped]
        self.assertEqual(set(sent), {(160, 250, 90, 130)})  # never moved: the AI box stays

    def test_driving_closer_is_followed(self):
        boxes = iter([(300, 200, 40, 50), (295, 195, 52, 65), (288, 188, 68, 85), (280, 180, 88, 110)]
                     + [(280, 180, 88, 110)] * 6)  # then the robot stops
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(**dict(zip('xywh', next(boxes))), score=0.99)))
        M['track'].update(pending=(300, 200, 40, 50), id=1, label='kardus')
        M['track_frame'](None)
        widths = [M['track_frame'](None)['w'] for _ in range(9)]
        self.assertEqual(widths[-1], 88)  # 4.8x the LOCK area: still the item, settled ~1 s after stopping

    def test_init_follow_lose_and_find_again(self):
        tracker = FakeTracker([0.9] + [0.2] * 50 + [0.9])
        M = load(tracker=tracker, print=lambda *a: None)
        M['track'].update(pending=(5, 6, 20, 30), id=4, label='kardus')
        first = M['track_frame'](None)
        self.assertEqual(tracker.inits, [(5, 6, 20, 30)])
        self.assertEqual(first, {'label': 'kardus', 'score': 1.0, 'x': 15, 'y': 21, 'w': 20, 'h': 30,
                                 'track_id': 4, 'held': True})
        second = M['track_frame'](None)  # the first tracker box goes with the AI box
        self.assertEqual((second['x'], second['w'], second['held']), (15, 20, True))
        for _ in range(50):  # lost for ~10 s: nothing sent, but still searching
            self.assertIsNone(M['track_frame'](None))
        self.assertTrue(M['track']['on'])
        self.assertEqual(M['track_frame'](None)['track_id'], 4)  # found again, same id

    def test_a_box_that_grows_or_shrinks_2x_is_not_sent(self):
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(x=0, y=0, w=W, h=H, score=0.99)))
        M['track'].update(pending=(0, 0, 30, 40), id=1, label='kardus')
        M['track_frame'](None)
        for W, H in [(30, 90), (15, 30), (30, 130)]:  # 1200 -> 2700, 450, 3900 px^2 (a hand at 2.8x)
            self.assertIsNone(M['track_frame'](None))
        W, H = 45, 50  # 1.9x: still the item
        self.assertEqual(M['track_frame'](None)['w'], 30)  # sent: the AI box, placed by the tracker

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
        M['hold'] = lambda t, box: box  # hold() is tested on its own; here the raw box
        M['track'].update(pending=(100, 100, 40, 50), id=1, label='kardus')  # FakeTracker's box is 0.6x its area
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
        self.assertEqual(fresh['detections'][0]['x'], 120)
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
