"""Fake MaixCAM2: a WebSocket server the app connects to exactly like the robot
(decision 0024). Frames are rendered by the owner's simulator
(github.com/3dbore/robotic_hand_sim, passed with --sim-path); detections come
from ground truth, not a model.

The protocol is copied from firmware/maixcam2/main.py (ws_handler,
ws_frame_pusher). Keep the two in step: test_fake_maixcam.py checks the frame
fields against main.py's source.

    python fake_maixcam.py --sim-path ../robotic_hand_sim --scenario scenarios/single_item_60s.yaml
"""
import argparse
import asyncio
import base64
import hashlib
import json
import math
import random
import sys
import time
import zlib
from pathlib import Path

import cv2
import numpy as np
import yaml
import websockets

HERE = Path(__file__).resolve().parent
VERSION = "1"
FIRMWARE_VERSION = f"fake-sim-{VERSION}"
FIRMWARE_SHA256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
WS_PORT = 8765
IMG_W, IMG_H = 640, 480
DET_EVERY_N_FRAMES = 2  # main.py: detections refresh every 2nd frame, held in between
JOINT_SPEED_DPS = 60.0
WATCHDOG_S = 1.0  # decision 0026 b: no app message this long -> wheels 0, arm hold
HIDDEN_FRACTION = 0.6  # a card covered more than this by nearer cards gets no box  # ESP32 firmware limit, per joint (0021e)
P1_KEYS = ("track_id", "dist_cm", "lateral_cm")
# shortcut: fixed wheel speed and track width, calibrate when robot wheel measurements exist.
DRIVE_MM_PER_PWM_S = 2.0
WHEEL_TRACK_MM = 250.0
PICK_MATCH_TOLERANCE_MM = 100.0
IK_TOLERANCE_MM = 5.0
GRIPPER_MAX_GAP_MM = 60.0
BIN_TARGETS = {
    "organik": (0.0, -150.0, 80.0),
    "anorganik": (100.0, -150.0, 80.0),
    "b3": (-100.0, -150.0, 80.0),
}


def load_labels(path=HERE / "labels.yaml"):
    return yaml.safe_load(Path(path).read_text())["names"]


# ── Scenario ─────────────────────────────────────────────────────────────────

EVENTS = ("appear", "leave", "set_label", "noise", "link_drop", "arm")
NOISE_DEFAULTS = dict(score_jitter=0.0, flicker=0.0, dropout_ms=0, dropout_every_s=0.0,
                      label_swap=0.0, swap_to=None)


# The first item locks ~1 s in and its quiz blocks new locks until a tester closes it;
# a swap at one spot needs the 15 s cooldown's tail plus 2 s absence (decision 0020).
TESTED_FROM_S = 25
SWAP_GAP_S = 8
SAME_SPOT_MM = 50


def timing_warnings(s):
    """Scenario timing problems (warnings, not errors): see the README's timing rule."""
    out = [f"event at t={e['t']} s ({e['do']}) is before {TESTED_FROM_S} s: the first quiz may still be open"
           for e in s["events"] if e["t"] < TESTED_FROM_S]
    pos = {it["id"]: np.array(it["pos_mm"], float) for it in s["items"]}
    leaves = [e for e in s["events"] if e["do"] == "leave"]
    for a in (e for e in s["events"] if e["do"] == "appear"):
        for lv in leaves:
            gap = a["t"] - lv["t"]
            if 0 <= gap < SWAP_GAP_S and np.linalg.norm(pos[a["item"]] - pos[lv["item"]]) < SAME_SPOT_MM:
                out.append(f"{a['item']} appears {gap:g} s after {lv['item']} left the same spot (needs {SWAP_GAP_S} s)")
    return out


def load_scenario(path, labels):
    s = yaml.safe_load(Path(path).read_text())
    s.setdefault("p1", True)
    s.setdefault("occlusion", True)
    s["noise"] = {**NOISE_DEFAULTS, **(s.get("noise") or {})}
    s.setdefault("events", [])
    s.setdefault("arm", {"j1": 0.0})
    for it in s["items"]:
        if it["label"] not in labels:
            raise ValueError(f"{path}: item {it['id']} has unknown label {it['label']!r}")
        it.setdefault("size_mm", 120)
        it.setdefault("score", 0.85)
        it.setdefault("visible", True)
    ids = {it["id"] for it in s["items"]}
    for e in s["events"]:
        if e.get("do") not in EVENTS:
            raise ValueError(f"{path}: event at t={e.get('t')} has unknown do {e.get('do')!r} (one of {EVENTS})")
        if "item" in e and e["item"] not in ids:
            raise ValueError(f"{path}: event at t={e['t']} names unknown item {e['item']!r}")
        if e.get("label") is not None and e["label"] not in labels:
            raise ValueError(f"{path}: event at t={e['t']} has unknown label {e['label']!r}")
    s["events"].sort(key=lambda e: e["t"])
    s["warnings"] = timing_warnings(s)
    return s


def placeholder_texture(seed):
    """No photo for the class: a plain colour with neutral diagonal stripes and no
    text, so Gemma has no word to read (24 Oct: "Label plastik")."""
    rng = np.random.default_rng(seed)
    base, stripe = rng.integers(60, 200, 3), rng.integers(60, 200, 3)
    yy, xx = np.mgrid[0:240, 0:180]
    img = np.where(((xx + yy) // 20 % 2 == 0)[..., None], base, stripe).astype(np.uint8)
    return img  # RGB


IMAGE_TYPES = (".jpg", ".jpeg", ".png")


def _images(folder):
    return sorted(p for p in Path(folder).glob("*") if p.suffix.lower() in IMAGE_TYPES)


def choose_photo(item, seed=0, images_dir=HERE / "images"):
    """(path, kind): the item's own `photo`, else a crop from images/<label>/crops/,
    else a whole photo from images/<label>/, else (None, "placeholder"). The pick
    depends only on the seed and the item id, so a run is repeatable."""
    rng = random.Random(f"{seed}:{item['id']}")
    own = item.get("photo")
    if own is not None and (HERE / own).is_file():
        return HERE / own, "photo"
    for kind, folder in (("crop", Path(images_dir) / item["label"] / "crops"), ("whole", Path(images_dir) / item["label"])):
        found = _images(folder)
        if found:
            return rng.choice(found), kind
    return None, "placeholder"


def centre_crop_4_3(img):
    """A whole photo cut to 4:3 (3:4 when portrait), the shape that worked by hand."""
    h, w = img.shape[:2]
    tw, th = (4, 3) if w >= h else (3, 4)
    if w * th > h * tw:
        nw = h * tw // th
        return img[:, (w - nw) // 2:(w - nw) // 2 + nw]
    nh = w * th // tw
    return img[(h - nh) // 2:(h - nh) // 2 + nh]


def texture_for(item, seed=0, images_dir=HERE / "images", log=print):
    """The card's RGB texture, and a log line saying which photo it got."""
    path, kind = choose_photo(item, seed, images_dir)
    if item.get("photo") is not None and kind != "photo":
        log(f"[Photo] WARNING {item['id']}: photo {item['photo']} not found, using a {kind}")
    img = cv2.imread(str(path)) if path is not None else None
    if img is None:
        log(f"[Photo] WARNING {item['id']} ({item['label']}): no photo, plain placeholder card "
            f"(run make_crops.py, or put photos in images/{item['label']}/)")
        return placeholder_texture(zlib.crc32(f"{seed}:{item['id']}".encode()))
    log(f"[Photo] {item['id']} ({item['label']}): {kind} {path.relative_to(HERE) if path.is_relative_to(HERE) else path}")
    img = img[..., ::-1]
    return centre_crop_4_3(img) if kind == "whole" else img


def card_size(size_mm, texture):
    """(w, h) mm: the longer side is size_mm (a [w, h] pair counts as its larger
    value), the other follows the photo's aspect, so nothing is stretched."""
    longer = float(max(size_mm)) if isinstance(size_mm, (list, tuple)) else float(size_mm)
    th, tw = texture.shape[:2]
    return (longer, longer * th / tw) if tw >= th else (longer * tw / th, longer)


# ── Sim world ────────────────────────────────────────────────────────────────

class SimWorld:
    """The sim's offscreen camera plus upright photo cards standing on the floor."""

    def __init__(self, sim_path, scenario, seed=0, images_dir=HERE / "images", log=print):
        sys.path.insert(0, str(Path(sim_path).resolve()))
        import pyvista as pv
        from hil_toolkit import calibration_camera as cc
        from hil_toolkit.tags_toolkit.tag_model import TAGS
        self.cc, self.tags = cc, TAGS
        self.cam = cc.SimCalibrationCamera(IMG_W, IMG_H)
        self.angles = np.zeros(5)
        self.target = np.zeros(5)
        self.actors, self.card_meshes, self.corners, self.world_corners = {}, {}, {}, {}
        self.occlusion = scenario.get("occlusion", True)
        self.robot_xy = np.zeros(2)
        self.robot_yaw = 0.0
        self.motor = (0, 0)
        self.held_item = None
        self.gripper_closed = False
        self.gripper_width = 0
        self.reach_value = 90
        for it in scenario["items"]:
            texture = texture_for(it, seed, images_dir, log)
            (x, y), (w, h) = it["pos_mm"], card_size(it["size_mm"], texture)
            # Upright, facing +Y (towards the lens at J1 = 0), bottom edge on the floor.
            # Image-left is +X (the camera looks along -Y), so the photo's left edge sits at x + w/2.
            corners = np.array([[x + w / 2, y, 0], [x - w / 2, y, 0],
                                [x - w / 2, y, h], [x + w / 2, y, h]], float)
            card = pv.PolyData(corners, faces=[4, 0, 1, 2, 3])
            card.active_texture_coordinates = np.array([[0, 0], [1, 0], [1, 1], [0, 1]], float)
            tex = pv.Texture(np.ascontiguousarray(texture))
            self.actors[it["id"]] = self.cam.plotter.add_mesh(card, texture=tex, lighting=False)
            self.card_meshes[it["id"]] = card
            self.world_corners[it["id"]] = corners.copy()
            self.corners[it["id"]] = corners.copy()
        self.set_j1(scenario["arm"].get("j1", 0.0), now=True)
        self.cam.set_pose(self.angles)  # project() uses the camera's current pose, so pose it before any render
        self.gripper_jaws = []
        self.gripper_jaw_points = []
        for side in (-1, 1):
            jaw = pv.Cube(center=(0, -100, 88.2), x_length=6, y_length=24, z_length=8)
            self.cam.plotter.add_mesh(jaw, color="#3D4943", lighting=False)
            self.gripper_jaws.append((jaw, side))
            self.gripper_jaw_points.append(jaw.points.copy())
        self._sync_gripper()

    def set_j1(self, deg, now=False):
        self.target[0] = deg
        if now:
            self.angles[0] = deg

    def step(self, dt):
        """Advance arm joints and differential-drive motion; return arm arrival state."""
        dt = max(0.0, dt)
        left, right = self.motor
        turn = (left - right) * DRIVE_MM_PER_PWM_S * dt / WHEEL_TRACK_MM
        heading = self.robot_yaw + turn / 2
        distance = (left + right) / 2 * DRIVE_MM_PER_PWM_S * dt
        self.robot_xy += distance * np.array([math.sin(heading), -math.cos(heading)])
        self.robot_yaw += turn
        delta = np.clip(self.target - self.angles, -JOINT_SPEED_DPS * dt, JOINT_SPEED_DPS * dt)
        self.angles += delta
        self._sync_cards()
        self._sync_gripper()
        return bool(np.allclose(self.angles, self.target))

    def set_motor(self, left, right):
        self.motor = (left, right)

    def _world_to_local(self, points):
        points = np.asarray(points, dtype=float)
        delta = points[..., :2] - self.robot_xy
        c, s = math.cos(self.robot_yaw), math.sin(self.robot_yaw)
        return np.concatenate((np.stack((c * delta[..., 0] + s * delta[..., 1],
                                         -s * delta[..., 0] + c * delta[..., 1]), axis=-1),
                               points[..., 2:3]), axis=-1)

    def _local_to_world(self, points):
        points = np.asarray(points, dtype=float)
        c, s = math.cos(self.robot_yaw), math.sin(self.robot_yaw)
        xy = points[..., :2]
        world = np.stack((c * xy[..., 0] - s * xy[..., 1] + self.robot_xy[0],
                          s * xy[..., 0] + c * xy[..., 1] + self.robot_xy[1]), axis=-1)
        return np.concatenate((world, points[..., 2:3]), axis=-1)

    def _sync_cards(self):
        for item_id, points in self.world_corners.items():
            if item_id == self.held_item:
                offsets = self._world_to_local(points) - self._world_to_local(points.mean(axis=0))
                corners = self.cc.grip_marker_base(self.angles) + offsets
            else:
                corners = self._world_to_local(points)
            self.corners[item_id] = corners
            mesh = self.card_meshes[item_id]
            mesh.points[:] = corners
            mesh.Modified()

    def _sync_gripper(self):
        transform = self.cc.ase.link_transforms(self.angles)[5]
        gap = GRIPPER_MAX_GAP_MM * (1 - self.gripper_width / 100)
        for (jaw, side), points in zip(self.gripper_jaws, self.gripper_jaw_points):
            local = points.copy()
            local[:, 0] += side * (gap / 2 + 3)
            jaw.points[:] = (np.c_[local, np.ones(len(local))] @ transform.T)[:, :3]
            jaw.Modified()

    def set_servo(self, part, value):
        if part == "base":
            self.target[0] = value - 90
        elif part == "elbow":
            self.target[1] = 90 - value
        elif part == "reach":
            value = max(0, min(180, int(value)))
            direction = np.sign(value - self.reach_value)
            if direction:
                ase = self.cc.ase
                angles = self.target.copy()
                base = angles[0]
                pitch, roll = ase.desired_global_pitch, ase.desired_global_roll
                ase.desired_global_pitch = float(sum(angles[1:4]))
                ase.desired_global_roll = float(angles[4])
                try:
                    for _ in range(abs(value - self.reach_value)):
                        angles = ase.ik_step(angles, np.array([0, direction * ase.IK_STEP_SIZE, 0]))
                        angles[0] = base  # reach changes the hand position while the camera stays on J1
                        ase.clamp_angles(angles)
                finally:
                    ase.desired_global_pitch, ase.desired_global_roll = pitch, roll
                self.target[:] = angles
            self.reach_value = value
            return True
        elif part == "gripper":
            self.gripper_width = max(0, min(100, int(value)))
            self.gripper_closed = self.gripper_width >= 50
            self._sync_gripper()
            return True
        else:
            return False
        self.cc.ase.clamp_angles(self.target)
        return True

    def pick_point(self, item_id):
        corners = self.corners[item_id]
        normal = np.cross(corners[1] - corners[0], corners[2] - corners[0])
        normal /= np.linalg.norm(normal)
        return corners.mean(axis=0) + normal * 5.0

    def solve_ik(self, point):
        ase = self.cc.ase
        angles = self.angles.copy()
        pitch, roll = ase.desired_global_pitch, ase.desired_global_roll
        ase.desired_global_pitch = float(sum(angles[1:4]))
        ase.desired_global_roll = float(angles[4])
        try:
            target = np.asarray(point, dtype=float)
            for _ in range(30):
                _, _, ee = ase.forward_kinematics(angles)
                if np.linalg.norm(target - ee) <= IK_TOLERANCE_MM:
                    return angles
                next_angles = ase.ik_step(angles, target - ee)
                if np.allclose(next_angles, angles):
                    break
                angles = next_angles
            _, _, ee = ase.forward_kinematics(angles)
            return angles if np.linalg.norm(target - ee) <= IK_TOLERANCE_MM else None
        finally:
            ase.desired_global_pitch, ase.desired_global_roll = pitch, roll

    def hold_item(self, item_id):
        self.held_item = item_id
        self.gripper_closed = True
        self._sync_cards()

    def release_item(self):
        item_id = self.held_item
        if item_id is not None:
            self.world_corners[item_id] = self._local_to_world(self.corners[item_id])
        self.held_item = None
        self.gripper_closed = False
        self._sync_cards()
        return item_id

    def show(self, item_id, visible):
        self.actors[item_id].SetVisibility(visible)

    def render(self):
        self.cam.set_pose(self.angles)
        return self.cam.capture()  # RGB, (480, 640, 3)

    def box(self, item_id):
        """Top-left (x, y, w, h) in pixels of the item's projected card, clipped to
        the image, or None when it is behind the lens or mostly out of view."""
        # ponytail: cards occlude each other (boxes()), the arm does not; add the arm if a scenario needs it.
        rc, depth = self.cam.project(self.corners[item_id])
        if np.any(depth <= 1.0):
            return None
        x0, x1 = rc[:, 1].min() + 0.5, rc[:, 1].max() + 0.5  # pixel centres -> edges
        y0, y1 = rc[:, 0].min() + 0.5, rc[:, 0].max() + 0.5
        full = (x1 - x0) * (y1 - y0)
        cx0, cx1, cy0, cy1 = max(x0, 0), min(x1, IMG_W), max(y0, 0), min(y1, IMG_H)
        if cx1 - cx0 <= 1 or cy1 - cy0 <= 1 or (cx1 - cx0) * (cy1 - cy0) < 0.3 * full:
            return None
        return cx0, cy0, cx1 - cx0, cy1 - cy0

    def boxes(self, item_ids):
        """{id: box or None} for the cards in view. With occlusion, a card hidden
        more than 60 % by nearer cards gets no box, a partly hidden one the box of
        its visible part, so the identify crop shows what the camera sees."""
        out = {i: self.box(i) for i in item_ids}
        if not self.occlusion:
            return out
        shapes = []
        for i in item_ids:
            if out[i] is None:
                continue
            rc, depth = self.cam.project(self.corners[i])
            mask = np.zeros((IMG_H, IMG_W), np.uint8)
            cv2.fillConvexPoly(mask, np.round(rc[:, ::-1] + 0.5).astype(np.int32), 1)
            shapes.append((float(depth.mean()), i, mask.astype(bool)))
        shapes.sort(key=lambda t: t[0])  # nearest first
        nearer = np.zeros((IMG_H, IMG_W), bool)
        for _, i, mask in shapes:
            covered = mask & nearer
            nearer |= mask
            if not covered.any():
                continue
            if covered.sum() > HIDDEN_FRACTION * mask.sum():
                out[i] = None
                continue
            ys, xs = np.nonzero(mask & ~covered)
            out[i] = (float(xs.min()), float(ys.min()), float(xs.max() + 1 - xs.min()), float(ys.max() + 1 - ys.min()))
        return out

    def floor_frame(self):
        """Lens floor point, forward and right unit vectors on the floor (0022)."""
        pos, focal, up = self.cc.camera_pose(self.angles[0])
        fwd = focal - pos
        fwd[2] = 0
        fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 0, 1.0])
        return np.array([pos[0], pos[1], 0.0]), fwd, right

    def distance(self, item_id):
        """(dist_cm, lateral_cm) from true geometry: the box's bottom edge is the
        card's bottom edge; dist is its nearest point along the axis, lateral its centre."""
        o, fwd, right = self.floor_frame()
        bottom = self.corners[item_id][:2] - o
        dist = min(bottom @ fwd)
        lateral = bottom.mean(axis=0) @ right
        return round(float(dist) / 10, 1), round(float(lateral) / 10, 1)

    def arm_tags(self):
        """Tags facing the lens with all corners in the image; dist = lens to tag centre."""
        pos, _, _ = self.cc.camera_pose(self.angles[0])
        seen = []
        for tid, tag in sorted(self.tags.items()):
            R, centre = tag.pose(self.angles)
            if R[:, 2] @ (pos - centre) <= 0:
                continue
            rc, depth = self.cam.project(tag.corners(self.angles))
            if np.any(depth <= 1.0) or not (np.all((rc >= 0) & (rc < [IMG_H, IMG_W]))):
                continue
            seen.append({"id": tid, "dist_mm": round(float(np.linalg.norm(centre - pos)), 1)})
        return seen

    def close(self):
        self.cam.close()


# ── Server ───────────────────────────────────────────────────────────────────

class FakeMaixCam:
    def __init__(self, world, scenario, labels, fps=10.0, p1=None, seed=0, log=print):
        self.world, self.scenario, self.labels = world, scenario, labels
        self.fps = fps
        self.p1 = scenario["p1"] if p1 is None else p1
        self.noise = dict(scenario["noise"])
        self.rng = random.Random(seed)
        self.log = log
        self.clients = set()
        self.streaming = False
        self.t0 = None  # scenario clock starts at the first start_stream
        self.link_down_until = 0.0
        self.items = {it["id"]: dict(it) for it in scenario["items"]}
        self.next_track_id = 1
        for it in self.items.values():
            self._set_visible(it, it["visible"])
        self.pending = list(scenario["events"])
        self.motion = None  # (client, command) waiting for motion_done
        self.drive_locked = False
        self.held_item = None
        self.held_bin = None
        self.last_app_message = time.monotonic()
        self.watchdog_fired = False
        self.heartbeats, self.heartbeat_window = 0, None  # rate-limited "heartbeat xN/s" line
        # Decision 0023's command link. DRIVE is the existing `motor` message (dropped while locked).
        self.handlers = {
            "STATUS": self._cmd_status,
            "LOCK_DRIVE": self._cmd_drive_lock,
            "UNLOCK_DRIVE": self._cmd_drive_lock,
            "HOLD": self._cmd_hold,
            "STOP": self._cmd_stop,
            "J1_SWEEP": self._cmd_j1_sweep,  # fake only (tests, scenarios): not part of 0023
            "PICK": self._cmd_pick,
            "MOVE_TO_BIN": self._cmd_move_to_bin,
            "DROP": self._cmd_drop,
        }

    def _set_visible(self, item, visible):
        if visible and not item.get("on"):
            item["track_id"] = self.next_track_id
            self.next_track_id += 1
        item["on"] = visible
        self.world.show(item["id"], visible)

    def now(self):
        return 0.0 if self.t0 is None else time.monotonic() - self.t0

    def link_down(self):
        return time.monotonic() < self.link_down_until

    # -- scenario timeline --

    def apply_events(self):
        t = self.now()
        while self.pending and self.pending[0]["t"] <= t:
            e = self.pending.pop(0)
            do = e["do"]
            self.log(f"[Scenario] t={t:.1f}s {do} {e.get('item', '')}")
            if do in ("appear", "leave"):
                self._set_visible(self.items[e["item"]], do == "appear")
            elif do == "set_label":
                self.items[e["item"]]["label"] = e["label"]
            elif do == "noise":
                self.noise.update({k: v for k, v in e.items() if k not in ("t", "do")})
            elif do == "link_drop":
                self.link_down_until = time.monotonic() + e["for_s"]
            elif do == "arm":
                self.world.set_j1(e["j1"])

    # -- detections --

    def detect(self):
        """Ground-truth detections in main.py's wire format (centre x/y, ints)."""
        n = self.noise
        t = self.now()
        if n["dropout_ms"] and n["dropout_every_s"] and (t % n["dropout_every_s"]) * 1000 < n["dropout_ms"]:
            return [], []
        dets, boxes = [], []
        visible = self.world.boxes([i for i, it in self.items.items() if it["on"]])
        for it in self.items.values():
            if not it["on"] or self.rng.random() < n["flicker"]:
                continue
            box = visible[it["id"]]
            if box is None:
                continue
            label = it["label"]
            if n["label_swap"] and n["swap_to"] and self.rng.random() < n["label_swap"]:
                label = n["swap_to"]
            score = min(0.99, max(0.26, it["score"] + self.rng.gauss(0, n["score_jitter"])))
            x, y, w, h = (int(v) for v in box)
            d = {"class_id": self.labels.index(label), "label": label, "score": round(score, 3),
                 "x": int(x + w / 2.0), "y": int(y + h / 2.0), "w": w, "h": h}
            if self.p1:
                dist, lateral = self.world.distance(it["id"])
                d.update(track_id=it["track_id"], dist_cm=dist, lateral_cm=lateral)
            dets.append(d)
            boxes.append((x, y, w, h, label, score))
        return dets, boxes

    # -- WebSocket handler (main.py ws_handler) --

    async def handler(self, ws):
        self.clients.add(ws)
        self.last_app_message = time.monotonic()
        self.log(f"[WS] Client connected: {ws.remote_address}")
        await ws.send(json.dumps({"status": "Connected"}))
        try:
            async for message in ws:
                if self.link_down():
                    continue  # lost on the air
                self._app_alive()
                try:
                    data = json.loads(message)
                    cmd = data.get("cmd", "")
                    if cmd == "HEARTBEAT":
                        self._log_heartbeat()  # decision 0026: no seq, no reply; it only feeds the watchdog
                    elif cmd == "ping":
                        await ws.send(json.dumps({"event": "pong", "firmware_version": FIRMWARE_VERSION,
                                                  "firmware_sha256": FIRMWARE_SHA256}))
                        self.log("[WS] ping -> pong")
                    elif cmd == "start_stream":
                        self.streaming = True
                        if self.t0 is None:
                            self.t0 = time.monotonic()
                        self.log("[WS] start_stream — streaming ON")
                    elif cmd == "stop_stream":
                        self.streaming = False
                        self.log("[WS] stop_stream — streaming OFF")
                    elif cmd == "disconnect":
                        self.log("[WS] disconnect -> disconnect_ack")
                        await ws.send(json.dumps({"event": "disconnect_ack"}))
                        await ws.close()
                        break
                    elif cmd == "motor":
                        left, right = data.get("left"), data.get("right")
                        if (not isinstance(left, int) or isinstance(left, bool)
                                or not isinstance(right, int) or isinstance(right, bool)):
                            self.log("[WS] invalid motor command ignored")
                            continue
                        left, right = max(-100, min(100, left)), max(-100, min(100, right))
                        dropped = " dropped (drive locked)" if self.drive_locked else ""
                        self.log(f"[WS] motor left={left} right={right}{dropped}")
                        self.world.set_motor(0, 0) if self.drive_locked else self.world.set_motor(left, right)
                    elif cmd == "servo":
                        part, value = data.get("part"), data.get("val")
                        limit = 100 if part == "gripper" else 180
                        if not isinstance(part, str) or not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= limit:
                            self.log("[WS] invalid servo command ignored")
                            continue
                        moved = self.world.set_servo(part, value)
                        state = "" if moved else " ignored (unknown part)"
                        self.log(f"[WS] servo part={part} val={value}{state}")
                    elif cmd == "set_resolution":
                        self.log(f"[WS] set_resolution received but ignored — resolution is fixed at {IMG_W}x{IMG_H}")
                    elif cmd in self.handlers and isinstance(data.get("seq"), int):
                        if cmd != "STOP":  # STOP logs its own line
                            self.log(f"[WS] {cmd} seq={data['seq']}")
                        await self.handlers[cmd](ws, data)
                    elif isinstance(data.get("seq"), int):
                        self.log(f"[WS] unknown cmd {cmd!r} seq={data['seq']} -> error unknown_cmd")
                        await self._reply(ws, "error", data, reason="unknown_cmd")
                    else:
                        self.log(f"[WS] unknown cmd {cmd!r} (ignored)")
                except Exception as pe:
                    self.log(f"[WS] parse error: {pe}")
        except websockets.ConnectionClosed:
            pass
        finally:
            self.clients.discard(ws)
            if not self.clients:
                self.streaming = False
                self.world.set_motor(0, 0)
                self.world.target[:] = self.world.angles
                self.motion = None
            self.log(f"[WS] clients remaining: {len(self.clients)}")

    # -- MaixCAM2 watchdog (decision 0026 b, simulated: the fake only logs and holds J1) --

    def _app_alive(self):
        self.last_app_message = time.monotonic()
        if self.watchdog_fired:
            self.watchdog_fired = False
            self.log("[Watchdog] app messages again")

    def _watchdog(self, now):
        if self.clients and not self.watchdog_fired and now - self.last_app_message > WATCHDOG_S:
            self.watchdog_fired = True
            self.world.set_motor(0, 0)
            self.world.target[:] = self.world.angles  # arm hold: stop where it is, never detach
            self.motion = None
            self.log(f"[Watchdog] no app message for {WATCHDOG_S:g} s: wheels 0 / arm hold")

    # -- R1 command link (decision 0023: {"cmd": NAME, "seq": n, ...} -> {"event": ..., "seq": n}) --

    async def _reply(self, ws, event, data, **extra):
        await ws.send(json.dumps({"event": event, "seq": data["seq"], **extra}))

    async def _cmd_status(self, ws, data):
        await self._reply(ws, "ack", data, drive_locked=self.drive_locked)

    async def _cmd_drive_lock(self, ws, data):
        self.drive_locked = data["cmd"] == "LOCK_DRIVE"
        if self.drive_locked:
            self.world.set_motor(0, 0)
        await self._reply(ws, "ack", data)

    def _log_heartbeat(self):
        """One line a second at most: "heartbeat x4/s"."""
        now = time.monotonic()
        if self.heartbeat_window is None:
            self.heartbeat_window = now
        self.heartbeats += 1
        if now - self.heartbeat_window >= 1.0:
            self.log(f"[WS] heartbeat x{round(self.heartbeats / (now - self.heartbeat_window))}/s")
            self.heartbeats, self.heartbeat_window = 0, now

    async def _cmd_stop(self, ws, data):
        self.log(f"[WS] STOP seq={data['seq']} -> wheels 0, arm hold")
        self.world.set_motor(0, 0)
        self.world.target[:] = self.world.angles
        self.motion = None
        await self._reply(ws, "ack", data)

    async def _cmd_j1_sweep(self, ws, data):
        value = data.get("to")
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value) or abs(value) > 90:
            await self._reply(ws, "error", data, reason="invalid_target")
            return
        target = self.world.angles.copy()
        target[0] = float(value)
        await self._begin_motion(ws, data, target)

    async def _cmd_hold(self, ws, data):
        self.world.target[:] = self.world.angles
        self.motion = None
        await self._reply(ws, "ack", data)
        await self._reply(ws, "motion_done", data)

    async def _begin_motion(self, ws, data, target, on_arrival=None):
        if self.motion is not None:
            await self._reply(ws, "error", data, reason="busy")
            return False
        self.world.target[:] = target
        await self._reply(ws, "ack", data)
        self.motion = (ws, data, on_arrival)
        return True

    async def _cmd_pick(self, ws, data):
        if self.motion is not None or self.held_item is not None:
            await self._reply(ws, "error", data, reason="busy")
            return
        visible = [item_id for item_id, item in self.items.items()
                   if item["on"] and self.world.box(item_id) is not None]
        if not visible:
            await self._reply(ws, "error", data, reason="no_object")
            return
        dist, lateral = data.get("dist_cm"), data.get("lateral_cm")
        if any(v is not None and (not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v))
               for v in (dist, lateral)):
            await self._reply(ws, "error", data, reason="invalid_target")
            return
        def mismatch(key):
            actual = self.world.distance(key)
            return math.hypot(*[(actual[i] - v) * 10 for i, v in enumerate((dist, lateral)) if v is not None])
        item_id = (min(visible, key=lambda key: self.world.distance(key)[0])
                   if dist is None and lateral is None else min(visible, key=mismatch))
        if any(v is not None for v in (dist, lateral)) and mismatch(item_id) > PICK_MATCH_TOLERANCE_MM:
            await self._reply(ws, "error", data, reason="no_object")
            return
        target = self.world.solve_ik(self.world.pick_point(item_id))
        if target is None:
            await self._reply(ws, "error", data, reason="unreachable")
            return

        def picked():
            self.held_item = item_id
            self.held_bin = None
            self.world.hold_item(item_id)
            self.log(f"[R1] picked {item_id}")

        await self._begin_motion(ws, data, target, picked)

    async def _cmd_move_to_bin(self, ws, data):
        bin_name = data.get("bin")
        if self.motion is not None:
            await self._reply(ws, "error", data, reason="busy")
            return
        if self.held_item is None:
            await self._reply(ws, "error", data, reason="empty_gripper")
            return
        if not isinstance(bin_name, str) or bin_name not in BIN_TARGETS:
            await self._reply(ws, "error", data, reason="invalid_bin")
            return
        target = self.world.solve_ik(BIN_TARGETS[bin_name])
        if target is None:
            await self._reply(ws, "error", data, reason="unreachable")
            return
        await self._begin_motion(ws, data, target, lambda: setattr(self, "held_bin", bin_name))

    async def _cmd_drop(self, ws, data):
        if self.motion is not None:
            await self._reply(ws, "error", data, reason="busy")
            return
        if self.held_item is None or self.held_bin is None:
            await self._reply(ws, "error", data, reason="not_at_bin")
            return
        item_id, bin_name = self.held_item, self.held_bin
        await self._reply(ws, "ack", data)
        self.world.release_item()
        self._set_visible(self.items[item_id], False)
        self.held_item = self.held_bin = None
        self.log(f"[R1] dropped {item_id} in {bin_name}")
        await self._reply(ws, "motion_done", data)

    # -- frame pusher (main.py ws_frame_pusher) --

    async def frame_pusher(self):
        frame_id, det_count, last_dets, last_boxes = 0, 0, [], []
        period = 1.0 / self.fps
        last = time.monotonic()
        while True:
            started = time.monotonic()
            if self.t0 is not None:
                self.apply_events()
            arrived = self.world.step(started - last)
            last = started
            self._watchdog(started)
            if arrived and self.motion is not None:
                ws, data, on_arrival = self.motion
                self.motion = None
                if not self.link_down():
                    if on_arrival is not None:
                        on_arrival()
                    try:
                        await self._reply(ws, "motion_done", data)
                    except websockets.ConnectionClosed:
                        pass
                else:
                    self.world.target[:] = self.world.angles
            if self.streaming and self.clients and not self.link_down():
                frame_id += 1
                det_count += 1
                detection_frame_id = None
                frame = self.world.render()
                clean_dets, clean_b64 = [], None
                if det_count >= DET_EVERY_N_FRAMES:
                    det_count = 0
                    last_dets, last_boxes = self.detect()
                    clean_dets = last_dets
                    detection_frame_id = frame_id
                bgr = np.ascontiguousarray(frame[..., ::-1])
                if detection_frame_id == frame_id and clean_dets:
                    clean_b64 = base64.b64encode(cv2.imencode(".jpg", bgr)[1]).decode()
                for x, y, w, h, label, score in last_boxes:
                    cv2.rectangle(bgr, (x, y), (x + w, y + h), (0, 255, 0), 2)
                    cv2.putText(bgr, f"{label}: {score:.2f}", (x, max(12, y - 4)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
                message = {
                    "vision_protocol": 1,
                    "firmware_sha256": FIRMWARE_SHA256,
                    "frame_id": frame_id,
                    "detection_frame_id": detection_frame_id,
                    "image": base64.b64encode(cv2.imencode(".jpg", bgr)[1]).decode(),
                    "img_w": IMG_W,
                    "img_h": IMG_H,
                    "detections": last_dets,
                }
                if self.p1:
                    tags = self.world.arm_tags()
                    if tags:
                        message["arm_tags"] = tags
                    message["arm_moving"] = not arrived  # decision 0026
                if detection_frame_id == frame_id:
                    message["clean_detections"] = clean_dets
                    if clean_b64 is not None:
                        message["clean_image"] = clean_b64
                payload = json.dumps(message)
                for client in list(self.clients):
                    try:
                        await client.send(payload)
                    except websockets.ConnectionClosed:
                        self.clients.discard(client)
            elif not self.streaming:
                det_count, last_dets, last_boxes = 0, [], []
            await asyncio.sleep(max(0.0, period - (time.monotonic() - started)))

    def refuse_while_down(self, connection, request):
        """No route to the robot during a link drop: the handshake fails."""
        return connection.respond(503, "link down\n") if self.link_down() else None

    async def serve(self, host="0.0.0.0", port=WS_PORT, ready=None):
        async with websockets.serve(self.handler, host, port, process_request=self.refuse_while_down) as server:
            if ready is not None:
                ready.set_result(server.sockets[0].getsockname()[1])
            await self.frame_pusher()


# ── Label check ──────────────────────────────────────────────────────────────

def check_labels(repo=HERE.parents[1]):
    """Mismatches between labels.yaml, main.py's LABELS and the app's detectorLabels."""
    import ast
    import re
    ours = load_labels()
    main_py = ast.parse((repo / "firmware/maixcam2/main.py").read_text())
    firmware = next(ast.literal_eval(n.value) for n in main_py.body
                    if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") == "LABELS")
    dart = (repo / "lib/models/scanned_waste.dart").read_text()
    block = dart[dart.index("detectorLabels"):]
    app = re.findall(r"^\s*'([^']+)':", block[:block.index("};")], re.M)
    problems = []
    if ours != firmware:
        problems.append(f"labels.yaml {ours} != main.py LABELS {firmware}")
    if set(ours) != set(app):
        problems.append(f"app detectorLabels missing {sorted(set(ours) - set(app))}, "
                        f"extra {sorted(set(app) - set(ours))}")
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sim-path", help="checkout of github.com/3dbore/robotic_hand_sim")
    ap.add_argument("--scenario", help="scenario YAML (see scenarios/)")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=WS_PORT)
    ap.add_argument("--fps", type=float, help="frames per second (default: the scenario's, else 10)")
    ap.add_argument("--old-firmware", action="store_true", help="send no P1 fields (track_id, dist_cm, lateral_cm, arm_tags)")
    ap.add_argument("--seed", type=int, default=0, help="photo choice and noise; the same seed repeats a run")
    ap.add_argument("--check-labels", action="store_true", help="compare labels.yaml, main.py and the app, then exit")
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)  # logs show up when piped (tee, CI)
    if args.check_labels:
        problems = check_labels()
        print("\n".join(problems) or "labels: no mismatch")
        sys.exit(1 if problems else 0)
    if not args.sim_path or not args.scenario:
        ap.error("--sim-path and --scenario are required")
    labels = load_labels()
    scenario = load_scenario(args.scenario, labels)
    for w in scenario["warnings"]:
        print(f"[Scenario] WARNING {w}")
    world = SimWorld(args.sim_path, scenario, seed=args.seed)
    fake = FakeMaixCam(world, scenario, labels, fps=args.fps or scenario.get("fps", 10.0),
                       p1=False if args.old_firmware else None, seed=args.seed)
    print(f"[Fake] {FIRMWARE_VERSION} scenario {scenario['name']} on ws://{args.host}:{args.port}")
    try:
        asyncio.run(fake.serve(args.host, args.port))
    except KeyboardInterrupt:
        pass
    finally:
        world.close()


if __name__ == "__main__":
    main()
