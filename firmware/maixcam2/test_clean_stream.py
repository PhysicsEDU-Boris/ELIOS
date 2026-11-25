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

NAMES = {'HOLD_SHIFT', 'HOLD_SIZE', 'SETTLE_CALLS', 'SETTLE', 'GROW_MIN', 'median_box', 'moved', 'hold', 'TRACK_TH', 'TRACK_MAX_GROWTH', 'HAND_GROWTH', 'HAND_MEMORY_MS', 'recent_hands', 'overlaps', 'size_ok', 'TRACK_REFIND_AFTER', 'TRACK_MIN_SIDE', 'HAND_CONF_TH', 'HAND_LABEL',
         'TAG_SIZES_MM', 'CAMERA_FX', 'STREAM_RESOLUTION', 'track', 'parse_track_box', 'box_det', 'track_frame',
         'hand_dets', 'arm_tags', 'find_arm_tags', 'TAG_SCALE', 'tags', 'ws_frame_pusher', 'DET_EVERY_N_FRAMES', 'PREVIEW_QUALITY', 'CLEAN_QUALITY', 'CLEAN_EVERY_MS',
         'DRIVE_DEADBAND', 'drive_char', 'DRIVE_TIMEOUT_MS', 'drive_expired'}


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
        # fx 374 at 640x360 (board solve, 0183); id 1 is a 10 mm print with a 6.17 mm black square
        self.assertEqual(tags[0]['dist_mm'], round(374 * 18.52 / 40, 1))
        self.assertEqual(tags[1]['dist_mm'], round(374 * 6.17 / 20, 1))
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
        t = {'box': (161, 253, 84, 124), 'still': [], 'odd': False}  # the LOCK box
        # The robot's measured noise on a still pack: y +-4 px, height +-7 px, x/w +-1 px.
        noise = [(161, 255, 84, 120), (162, 250, 85, 131), (161, 256, 84, 117), (160, 252, 83, 127),
                 (161, 254, 84, 122), (161, 249, 84, 130), (162, 256, 85, 118), (161, 253, 84, 125)]
        noise += [(161, 253, 79, 124), (161, 253, 80, 124), (161, 253, 79, 125), (161, 253, 80, 124),
                  (161, 253, 79, 124)] * 2  # width 4-5 px off for 2 s, as measured: not worth a jump
        sent = {hold(t, b) for b in noise}
        self.assertEqual(sent, {(161, 253, 84, 124)})  # one box, no jiggle (median within 6 %)
        moved_to = (200, 250, 84, 124)  # slid 39 px
        self.assertEqual(hold(t, moved_to), (161, 253, 84, 124))  # one odd box: not yet
        self.assertEqual(hold(t, moved_to), moved_to)  # twice: a real move, followed
        after = [(201, 242, 85, 133), (200, 241, 84, 134), (201, 242, 84, 135), (200, 243, 84, 133),
                 (201, 242, 85, 134), (200, 241, 84, 135)]
        sent = [hold(t, b) for b in after]
        self.assertEqual(sent[:4], [moved_to] * 4)
        self.assertEqual(sent[4], (201, 242, 84, 134))  # 10 px taller: settled once, then held
        self.assertEqual(sent[5], sent[4])

    def test_a_flipped_item_in_place_does_not_bounce(self):
        hold = load()['hold']
        t = {'box': (160, 250, 90, 130), 'still': [], 'odd': False}
        # Flipped in place: the tracker's box swings 15-40 % in height, with single wild ones.
        flipped = [(160, 260, 90, 110), (158, 240, 92, 150), (160, 300, 90, 60), (161, 255, 89, 118),
                   (160, 245, 90, 140), (159, 258, 91, 112), (160, 248, 90, 145), (160, 310, 90, 40),
                   (161, 252, 90, 125), (160, 256, 90, 115)]
        sent = [hold(t, b) for b in flipped]
        self.assertEqual(len(set(sent)), 2)  # one settle to the flipped size, no bounce
        self.assertEqual(sent[-5:], [sent[-1]] * 5)

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
        tracker = FakeTracker([0.9] * 5 + [0.2] * 50 + [0.9])
        M = load(tracker=tracker, print=lambda *a: None)
        M['track'].update(pending=(5, 6, 20, 30), id=4, label='kardus')
        first = M['track_frame'](None)
        self.assertEqual(tracker.inits, [(5, 6, 20, 30)])
        self.assertEqual(first, {'label': 'kardus', 'score': 1.0, 'x': 15, 'y': 21, 'w': 20, 'h': 30,
                                 'track_id': 4})
        # FakeTracker's box is 2x the LOCK area: a growth, taken once 5 calls in a row agree.
        self.assertEqual([M['track_frame'](None)['x'] for _ in range(5)], [15, 15, 15, 15, 25])
        for _ in range(50):  # lost for ~10 s: nothing sent, but still searching
            self.assertIsNone(M['track_frame'](None))
        self.assertTrue(M['track']['on'])
        self.assertEqual(M['track_frame'](None)['track_id'], 4)  # found again, same id

    def test_a_box_shrinking_under_a_cover_keeps_the_held_box(self):
        hold = load()['hold']
        t = {'box': (300, 150, 60, 160), 'still': [], 'odd': False, 'grow': [], 'size': 9600}  # the bottle
        # A card slides over it: the visible part shrinks every call, each step under 2x, down to a
        # patch of floor (phone video 4 Nov, 170-183 s).
        covered = [(300, 190, 60, 120), (305, 230, 55, 85), (320, 260, 40, 60), (340, 280, 25, 40),
                   (350, 290, 18, 26), (352, 292, 16, 24)]
        self.assertEqual({hold(t, b) for b in covered}, {(300, 150, 60, 160)})
        # Smaller for real (the robot drove away and stopped): taken once 5 calls keep one size.
        far = (310, 170, 40, 107)
        self.assertEqual([hold(t, far) for _ in range(5)], [(300, 150, 60, 160)] * 4 + [far])

    def test_a_box_that_grows_or_shrinks_2x_is_not_sent(self):
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(x=0, y=0, w=W, h=H, score=0.99)))
        M['track'].update(pending=(0, 0, 30, 40), id=1, label='kardus')
        M['track_frame'](None)
        for W, H in [(30, 90), (15, 30), (30, 130)]:  # 1200 -> 2700, 450, 3900 px^2 (a hand at 2.8x)
            self.assertIsNone(M['track_frame'](None))
        W, H = 45, 50  # 1.9x: still the item
        self.assertEqual([M['track_frame'](None)['w'] for _ in range(5)], [30, 30, 30, 30, 45])  # a growth: 5 calls

    def test_after_a_hand_sized_box_the_real_item_is_taken_again(self):
        boxes = iter([(100, 100, 50, 50), (100, 100, 50, 50)])
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(**dict(zip('xywh', next(boxes))), score=0.9)))
        M['track'].update(pending=(100, 100, 50, 50), id=1, label='kardus')  # LOCK: 2500 px^2
        M['track_frame'](None)
        M['track']['area'] = 6500  # the last good box was hand + pack (video 15:21)
        self.assertIsNotNone(M['track_frame'](None))  # 0.38x the last box, but the LOCK size: taken

    def test_a_box_that_balloons_over_a_hand_keeps_the_held_box(self):
        grown = (60, 40, 120, 130)  # pack + hand: 15600 px^2, 3.1x the held box
        M = load(tracker=SimpleNamespace(init=lambda *a: None,
                                         track=lambda f, th: Obj(**dict(zip('xywh', grown)), score=0.9)))
        M['TRACK_MAX_GROWTH'] = 8  # let the box past the size guard: here the hand rule is under test
        M['track'].update(pending=(100, 100, 50, 50), id=1, label='kardus')
        M['track_frame'](None)
        hand = [(150, 30, 60, 60)]
        for _ in range(3):  # two in a row would be a move; with the hand it never is
            self.assertEqual(M['track_frame'](None, hand)['w'], 50)
        self.assertEqual(M['track']['area'], 2500)
        # The hand is gone: the grown box counts again once it keeps one size for 5 calls.
        self.assertEqual([M['track_frame'](None)['w'] for _ in range(5)], [50, 50, 50, 50, 120])

    def test_a_growing_box_is_taken_only_when_it_keeps_one_size(self):
        hold = load()['hold']
        t = {'box': (300, 300, 80, 120), 'still': [], 'odd': False, 'grow': [], 'size': 9600}
        # Hand + pack: taller every call, then a hand-sized jump (log 4 Nov) - never one size.
        for box in [(300, 250, 90, 170), (295, 230, 95, 200), (290, 200, 100, 240), (285, 120, 110, 330),
                    (290, 180, 100, 260), (285, 100, 110, 360), (290, 210, 100, 220)]:
            self.assertEqual(hold(t, box), (300, 300, 80, 120))
        # Small steps (each under 1.3x of the box before) still count as growth against the held size.
        t = {'box': (300, 300, 80, 120), 'still': [], 'odd': False, 'grow': [], 'size': 9600}
        for k in range(1, 6):
            self.assertEqual(hold(t, (300, 300 - 15 * k, 80, 120 + 15 * k)), (300, 300, 80, 120))

    def test_a_hand_counts_for_a_second_through_detector_misses(self):
        recent = load()['recent_hands']
        hand = (300, 40, 150, 150)
        seen = recent([], 0, [hand])
        seen = recent(seen, 200, [])  # missed on the next detection frame (as logged)
        self.assertEqual([b for _, b in seen], [hand])
        seen = recent(seen, 900, [])
        self.assertEqual([b for _, b in seen], [hand])
        self.assertEqual(recent(seen, 1000, []), [])  # gone after HAND_MEMORY_MS

    def test_nothing_locked(self):
        M = load(tracker=FakeTracker([]))
        self.assertIsNone(M['track_frame'](None))


class StreamTest(unittest.TestCase):
    def test_clean_frames_tracked_box_hands_and_tags(self):
        frames, messages, encodes, searched, arm_tags_seen = [], [], [], [], []

        class Frame:
            def __init__(self, number):
                self.number = number

            def to_jpeg(self, quality):
                encodes.append((self.number, quality))
                return SimpleNamespace(to_bytes=lambda: f'{self.number}@{quality}'.encode())

            def resize(self, w, h):
                assert (w, h) == (320, 180)  # a full frame crashes find_apriltags on the camera
                return self

            def width(self):
                return 640

            def height(self):
                return 360

            def find_apriltags(self, families):
                searched.append(self.number)
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
                 arm_lock=threading.Lock(), arm=SimpleNamespace(on_tags=lambda tags, w: arm_tags_seen.append(tags), wants_tags=False),
                 FIRMWARE_SHA256='test-hash',
                 mtime=SimpleNamespace(ticks_ms=lambda: next(ticks)),
                 tracker=FakeTracker([0.9, 0.9, 0.9]),
                 hands=SimpleNamespace(detect=lambda frame, conf_th: [hand] if frame.number == 2 else []),
                 image=SimpleNamespace(Format=SimpleNamespace(FMT_JPEG=1),
                                       ApriltagFamilies=SimpleNamespace(TAG36H11=16)))
        M['hold'] = lambda t, box: box  # hold() is tested on its own; here the raw box
        M['track'].update(pending=(100, 100, 40, 50), id=1, label='kardus')  # FakeTracker's box is 0.6x its area
        M['tags']['on'] = True  # the app turned tags on for a grip
        with self.assertRaises(EndStream):
            asyncio.run(M['ws_frame_pusher']())

        # A quality-60 preview per frame; the quality-80 AI picture only on the first detection frame:
        # the second comes ~0.2 s later, within CLEAN_EVERY_MS.
        self.assertEqual(encodes, [(1, 60), (2, 60), (2, 80), (3, 60), (4, 60)])
        self.assertTrue(arm_tags_seen and all(isinstance(ids, list) for ids in arm_tags_seen),
                        'each detection frame with tags feeds the DROP guard (0235)')
        for m in messages:
            self.assertEqual(m['vision_protocol'], 1)
            self.assertEqual((m['img_w'], m['img_h']), (640, 360))  # the wide 16:9 view (0183)
        self.assertEqual(messages[0]['detections'], [])  # the tracker inits on the next detection frame
        self.assertIsNone(messages[0]['detection_frame_id'])
        self.assertNotIn('clean_image', messages[0])

        fresh = messages[1]
        self.assertEqual(fresh['frame_id'], fresh['detection_frame_id'])
        self.assertEqual([d['label'] for d in fresh['clean_detections']], ['kardus', 'Human_Hand'])
        self.assertEqual(fresh['detections'][0]['x'], 120)
        self.assertEqual(fresh['detections'][0]['track_id'], 1)
        self.assertEqual(fresh['detections'][1], {'label': 'Human_Hand', 'score': 0.8,
                                                  'x': 10, 'y': 190, 'w': 10, 'h': 340})  # y clamped to 360
        self.assertEqual(base64.b64decode(fresh['image']), b'2@60')
        self.assertEqual(base64.b64decode(fresh['clean_image']), b'2@80')  # the AI's picture, unchanged quality
        self.assertEqual(fresh['arm_tags'][0]['id'], 0)

        self.assertEqual(messages[2]['detections'], fresh['detections'])  # held between detection frames
        self.assertEqual(messages[2]['arm_tags'][0]['id'], 0)  # held until the next detection frame
        self.assertEqual([d['label'] for d in messages[3]['clean_detections']], ['kardus'])
        self.assertNotIn('clean_image', messages[3])  # within CLEAN_EVERY_MS of the last one
        self.assertEqual(messages[3]['detections'][0]['x'], 25)  # FakeTracker's box
        self.assertEqual(messages[3]['arm_tags'], [])
        self.assertEqual(searched, [2, 4])  # only on detection frames while on

    def test_no_tag_search_unless_the_app_asks(self):
        searched, messages = [], []

        class Frame:
            def to_jpeg(self, quality):
                return SimpleNamespace(to_bytes=lambda: b'x')

            def resize(self, w, h):
                return self

            def width(self):
                return 640

            def height(self):
                return 360

            def find_apriltags(self, families):
                searched.append(1)
                return []

        class Client:
            async def send(self, payload):
                messages.append(json.loads(payload))
                if len(messages) == 6:
                    raise EndStream()

        ticks = iter(range(0, 10 ** 6, 7))
        M = load(asyncio=asyncio, json=json, base64=base64, print=lambda *a: None,
                 stream_cam=SimpleNamespace(read=Frame), ws_streaming=True, ws_clients={Client()},
                 cam_lock=threading.Lock(), setup={'stage': None},
                 arm_lock=threading.Lock(), arm=SimpleNamespace(on_tags=lambda ids: None),
                 FIRMWARE_SHA256='test-hash',
                 mtime=SimpleNamespace(ticks_ms=lambda: next(ticks)),
                 tracker=None, hands=None,
                 image=SimpleNamespace(ApriltagFamilies=SimpleNamespace(TAG36H11=16)))
        with self.assertRaises(EndStream):
            asyncio.run(M['ws_frame_pusher']())
        self.assertEqual(searched, [])  # tags off by default: ~40 ms saved per detection frame
        self.assertTrue(all(m['arm_tags'] == [] for m in messages))


class DriveTest(unittest.TestCase):
    """Wheels' Arduino on UART2 (codeMotorSlave.ino, owner 25 Nov): app motor -> one char, and a stop."""

    def test_motor_to_char_and_watchdog(self):
        M = load()
        char = M['drive_char']
        self.assertEqual([char(80, 80), char(-80, -80), char(80, -80), char(-80, 80)], ['F', 'B', 'R', 'L'])
        self.assertEqual(char(3, -3), 'S', 'stick jitter under the deadband')
        self.assertEqual(char(60, 20), 'F', 'forward outweighs the turn')
        expired = M['drive_expired']
        self.assertTrue(expired('F', 0, M['DRIVE_TIMEOUT_MS'] + 1))
        self.assertFalse(expired('F', 0, M['DRIVE_TIMEOUT_MS']))
        self.assertFalse(expired('S', 0, 10 ** 6), 'already stopped')


if __name__ == '__main__':
    unittest.main()
