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
import random
import sys
import time
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
JOINT_SPEED_DPS = 60.0  # ESP32 firmware limit, per joint (0021e)
P1_KEYS = ("track_id", "dist_cm", "lateral_cm")


def load_labels(path=HERE / "labels.yaml"):
    return yaml.safe_load(Path(path).read_text())["names"]


# ── Scenario ─────────────────────────────────────────────────────────────────

EVENTS = ("appear", "leave", "set_label", "noise", "link_drop", "arm")
NOISE_DEFAULTS = dict(score_jitter=0.0, flicker=0.0, dropout_ms=0, dropout_every_s=0.0,
                      label_swap=0.0, swap_to=None)


def load_scenario(path, labels):
    s = yaml.safe_load(Path(path).read_text())
    s.setdefault("p1", True)
    s["noise"] = {**NOISE_DEFAULTS, **(s.get("noise") or {})}
    s.setdefault("events", [])
    s.setdefault("arm", {"j1": 0.0})
    for it in s["items"]:
        if it["label"] not in labels:
            raise ValueError(f"{path}: item {it['id']} has unknown label {it['label']!r}")
        it.setdefault("size_mm", [70, 120])
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
    return s


def placeholder_texture(label, seed):
    """A flat card with the label written on it, when images/<label>/ is empty."""
    rng = np.random.default_rng(seed)
    img = np.full((240, 160, 3), rng.integers(60, 200, 3), np.uint8)
    cv2.rectangle(img, (6, 6), (153, 233), (255, 255, 255), 3)
    cv2.putText(img, label[:10], (10, 125), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2)
    return img[..., ::-1]  # RGB


def texture_for(item, index):
    photo = item.get("photo")
    if photo is None:
        folder = HERE / "images" / item["label"]
        photos = sorted(p for p in folder.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png"))
        photo = photos[0] if photos else None
    if photo is not None:
        img = cv2.imread(str(HERE / photo))
        if img is not None:
            return img[..., ::-1]
    return placeholder_texture(item["label"], index)


# ── Sim world ────────────────────────────────────────────────────────────────

class SimWorld:
    """The sim's offscreen camera plus upright photo cards standing on the floor."""

    def __init__(self, sim_path, scenario):
        sys.path.insert(0, str(Path(sim_path).resolve()))
        import pyvista as pv
        from hil_toolkit import calibration_camera as cc
        from hil_toolkit.tags_toolkit.tag_model import TAGS
        self.cc, self.tags = cc, TAGS
        self.cam = cc.SimCalibrationCamera(IMG_W, IMG_H)
        self.angles = np.zeros(5)
        self.target = np.zeros(5)
        self.actors, self.corners = {}, {}
        for i, it in enumerate(scenario["items"]):
            (x, y), (w, h) = it["pos_mm"], it["size_mm"]
            # Upright, facing +Y (towards the lens at J1 = 0), bottom edge on the floor.
            # Image-left is +X (the camera looks along -Y), so the photo's left edge sits at x + w/2.
            corners = np.array([[x + w / 2, y, 0], [x - w / 2, y, 0],
                                [x - w / 2, y, h], [x + w / 2, y, h]], float)
            card = pv.PolyData(corners, faces=[4, 0, 1, 2, 3])
            card.active_texture_coordinates = np.array([[0, 0], [1, 0], [1, 1], [0, 1]], float)
            tex = pv.Texture(np.ascontiguousarray(texture_for(it, i)))
            self.actors[it["id"]] = self.cam.plotter.add_mesh(card, texture=tex, lighting=False)
            self.corners[it["id"]] = corners
        self.set_j1(scenario["arm"].get("j1", 0.0), now=True)

    def set_j1(self, deg, now=False):
        self.target[0] = deg
        if now:
            self.angles[0] = deg

    def step(self, dt):
        """Moves every joint towards its target at JOINT_SPEED_DPS; True when arrived."""
        delta = np.clip(self.target - self.angles, -JOINT_SPEED_DPS * dt, JOINT_SPEED_DPS * dt)
        self.angles += delta
        return bool(np.allclose(self.angles, self.target))

    def show(self, item_id, visible):
        self.actors[item_id].SetVisibility(visible)

    def render(self):
        self.cam.set_pose(self.angles)
        return self.cam.capture()  # RGB, (480, 640, 3)

    def box(self, item_id):
        """Top-left (x, y, w, h) in pixels of the item's projected card, clipped to
        the image, or None when it is behind the lens or mostly out of view."""
        # ponytail: no occlusion (cards, arm); add a depth-buffer check if a scenario needs hidden items.
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
        self.motion = None  # (client, cmd, id) waiting for motion_done
        self.handlers = {
            "J1_SWEEP": self._cmd_j1_sweep,
            "HOLD": self._cmd_hold,
            # TODO(R1, 0023): PICK -> IK to the item's floor spot, 60 deg/s per joint, then
            # close the gripper; ack now, motion_done when the arm arrives, error if unreachable.
            "PICK": self._cmd_todo,
            # TODO(R1, 0023): MOVE_TO_BIN -> fixed joint pose per bin (organik/anorganik/B3).
            "MOVE_TO_BIN": self._cmd_todo,
            # TODO(R1, 0023): DROP -> open the gripper, hide the carried item.
            "DROP": self._cmd_todo,
            # TODO(R1, 0023): STOP -> freeze every joint (target = current angles).
            "STOP": self._cmd_todo,
            # TODO(R1, 0023): DRIVE -> move every item by -(dx, dy) to fake the robot driving.
            "DRIVE": self._cmd_todo,
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
        for it in self.items.values():
            if not it["on"] or self.rng.random() < n["flicker"]:
                continue
            box = self.world.box(it["id"])
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
        self.log(f"[WS] Client connected: {ws.remote_address}")
        await ws.send(json.dumps({"status": "Connected"}))
        try:
            async for message in ws:
                if self.link_down():
                    continue  # lost on the air
                try:
                    data = json.loads(message)
                    cmd = data.get("cmd", "")
                    if cmd == "ping":
                        await ws.send(json.dumps({"event": "pong", "firmware_version": FIRMWARE_VERSION,
                                                  "firmware_sha256": FIRMWARE_SHA256}))
                    elif cmd == "start_stream":
                        self.streaming = True
                        if self.t0 is None:
                            self.t0 = time.monotonic()
                        self.log("[WS] start_stream — streaming ON")
                    elif cmd == "stop_stream":
                        self.streaming = False
                        self.log("[WS] stop_stream — streaming OFF")
                    elif cmd == "disconnect":
                        await ws.send(json.dumps({"event": "disconnect_ack"}))
                        await ws.close()
                        break
                    elif cmd == "motor":
                        self.log("[WS] motor left={} right={}".format(data.get("left", 0), data.get("right", 0)))
                    elif cmd == "servo":
                        self.log("[WS] servo part={} val={}".format(data.get("part", ""), data.get("val", 0)))
                    elif cmd == "set_resolution":
                        self.log(f"[WS] set_resolution received but ignored — resolution is fixed at {IMG_W}x{IMG_H}")
                    elif cmd in self.handlers:
                        await self.handlers[cmd](ws, data)
                except Exception as pe:
                    self.log(f"[WS] parse error: {pe}")
        except websockets.ConnectionClosed:
            pass
        finally:
            self.clients.discard(ws)
            if not self.clients:
                self.streaming = False
            self.log(f"[WS] clients remaining: {len(self.clients)}")

    # -- R1 command link (0023, provisional shape: {"cmd": NAME, "id": n, ...}) --

    async def _reply(self, ws, event, data, **extra):
        await ws.send(json.dumps({"event": event, "cmd": data["cmd"], "id": data.get("id"), **extra}))

    async def _cmd_j1_sweep(self, ws, data):
        self.world.set_j1(float(data["to"]))
        self.motion = (ws, data)
        await self._reply(ws, "ack", data)

    async def _cmd_hold(self, ws, data):
        self.world.target[:] = self.world.angles
        await self._reply(ws, "ack", data)
        await self._reply(ws, "motion_done", data)

    async def _cmd_todo(self, ws, data):
        await self._reply(ws, "error", data, reason="not_implemented")

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
            if arrived and self.motion is not None:
                ws, data = self.motion
                self.motion = None
                if not self.link_down():
                    try:
                        await self._reply(ws, "motion_done", data)
                    except websockets.ConnectionClosed:
                        pass
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
    ap.add_argument("--seed", type=int, default=0)
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
    world = SimWorld(args.sim_path, scenario)
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
