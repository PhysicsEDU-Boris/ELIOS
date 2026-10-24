"""Fake MaixCAM2 tests (decision 0024). No robot needed, but the simulator is:
ROBOTIC_HAND_SIM=<checkout of github.com/3dbore/robotic_hand_sim> (default: next to this repo).

    cd tools/fake_maixcam && python -m pytest -q
"""
import ast
import asyncio
import json
import os
import time
from pathlib import Path

import cv2
import numpy as np
import pytest
import websockets
import yaml

import fake_maixcam as fm

REPO = fm.HERE.parents[1]
SIM = Path(os.environ.get("ROBOTIC_HAND_SIM", REPO.parent / "robotic_hand_sim"))
needs_sim = pytest.mark.skipif(not (SIM / "hil_toolkit").is_dir(), reason=f"simulator not found at {SIM}")

BOTTLE = {"id": "bottle", "label": "Plastic", "pos_mm": [-54, -301], "size_mm": 120, "score": 0.88}
F_Y = (fm.IMG_H / 2) / 0.4769755  # 0022: (H/2) / tan(V/2), V = 51 deg
LENS_H_MM = 86.2


def main_py_fields():
    """Frame and detection keys exactly as firmware/maixcam2/main.py builds them."""
    tree = ast.parse((REPO / "firmware/maixcam2/main.py").read_text())
    push = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "ws_frame_pusher")
    frame, det = set(), set()
    for n in ast.walk(push):
        if isinstance(n, ast.Assign) and isinstance(n.value, ast.Dict) and getattr(n.targets[0], "id", "") == "message":
            frame |= {k.value for k in n.value.keys}
        if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Subscript) and getattr(n.targets[0].value, "id", "") == "message":
            frame.add(n.targets[0].slice.value)
        if (isinstance(n, ast.Call) and getattr(n.func, "attr", "") == "append" and getattr(n.func.value, "id", "") == "dets"):
            det |= {k.value for k in n.args[0].keys}
    return frame, det


def run(tmp_path, scenario, body, p1=None, fps=20.0):
    """Starts the fake on a free port, runs `await body(url, fake)`, stops it."""
    path = tmp_path / "s.yaml"
    path.write_text(yaml.safe_dump({"name": "test", **scenario}))
    labels = fm.load_labels()
    sc = fm.load_scenario(path, labels)
    world = fm.SimWorld(SIM, sc, images_dir=tmp_path / "no-images", log=lambda *_: None)  # placeholders only
    fake = fm.FakeMaixCam(world, sc, labels, fps=fps, p1=p1, log=lambda *_: None)

    async def main():
        ready = asyncio.get_running_loop().create_future()
        server = asyncio.create_task(fake.serve("127.0.0.1", 0, ready))
        port = await ready
        try:
            return await body(f"ws://127.0.0.1:{port}", fake)
        finally:
            server.cancel()

    try:
        return asyncio.run(main())
    finally:
        world.close()


async def frames(ws, n, timeout=5.0):
    out = []
    while len(out) < n:
        msg = json.loads(await asyncio.wait_for(ws.recv(), timeout))
        if "frame_id" in msg:
            out.append(msg)
    return out


async def detection_frame(ws):
    while True:
        (msg,) = await frames(ws, 1)
        if msg["detection_frame_id"] == msg["frame_id"]:
            return msg


@needs_sim
def test_connect_ping_pong_and_disconnect(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            assert json.loads(await ws.recv()) == {"status": "Connected"}
            await ws.send(json.dumps({"cmd": "ping"}))
            pong = json.loads(await ws.recv())
            assert pong["event"] == "pong" and pong["firmware_version"].startswith("fake-sim-")
            for cmd in ({"cmd": "motor", "left": 1, "right": 1}, {"cmd": "servo", "part": "base", "val": 90},
                        {"cmd": "set_resolution", "width": 1920, "height": 1080}):
                await ws.send(json.dumps(cmd))  # logged / ignored, never answered
            await ws.send(json.dumps({"cmd": "disconnect"}))
            assert json.loads(await ws.recv()) == {"event": "disconnect_ack"}
            with pytest.raises(websockets.ConnectionClosed):
                await asyncio.wait_for(ws.recv(), 2)
    run(tmp_path, {"items": [BOTTLE]}, body)


@needs_sim
def test_start_and_stop_stream(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            with pytest.raises(asyncio.TimeoutError):
                await frames(ws, 1, timeout=0.5)  # nothing before start_stream
            await ws.send(json.dumps({"cmd": "start_stream"}))
            ids = [m["frame_id"] for m in await frames(ws, 4)]
            assert ids == sorted(ids) and len(set(ids)) == 4
            await ws.send(json.dumps({"cmd": "stop_stream"}))
            await asyncio.sleep(0.3)
            while True:  # drain what was in flight
                try:
                    await asyncio.wait_for(ws.recv(), 0.05)
                except asyncio.TimeoutError:
                    break
            with pytest.raises(asyncio.TimeoutError):
                await frames(ws, 1, timeout=0.6)
    run(tmp_path, {"items": [BOTTLE]}, body)


@needs_sim
def test_frame_fields_match_main_py_old_firmware(tmp_path):
    frame_keys, det_keys = main_py_fields()
    assert {"vision_protocol", "frame_id", "detection_frame_id", "image", "img_w", "img_h", "detections",
            "clean_detections", "clean_image"} <= frame_keys

    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "start_stream"}))
            msgs = await frames(ws, 4)
            det = next(m for m in msgs if m["detection_frame_id"] == m["frame_id"])
            held = next(m for m in msgs if m["frame_id"] == det["frame_id"] + 1)
            return det, held

    det, held = run(tmp_path, {"items": [BOTTLE]}, body, p1=False)
    assert set(det) == frame_keys
    assert set(held) == frame_keys - {"clean_detections", "clean_image"}
    assert held["detections"] == det["detections"]  # held between inference frames, like main.py
    assert (det["img_w"], det["img_h"]) == (640, 480)
    (d,) = det["detections"]
    assert set(d) == det_keys
    assert d["label"] == "Plastic" and d["class_id"] == 8 and det["clean_detections"] == [d]
    # main.py's convention: integer centre x/y and w/h of the box.
    assert all(isinstance(d[k], int) for k in "xywh") and abs(d["x"] - 320) <= 2


@needs_sim
def test_p1_fields_on_and_off(tmp_path):
    tag_pose = [0.0, 50.0, -148.0, 192.0, -71.0]  # wrist turned so tag 0 faces the lens

    async def body(url, fake):
        fake.world.angles[:] = fake.world.target[:] = tag_pose
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "start_stream"}))
            return await detection_frame(ws)

    on = run(tmp_path, {"items": [BOTTLE]}, body)
    (d,) = on["detections"]
    assert isinstance(d["track_id"], int) and isinstance(d["dist_cm"], float) and isinstance(d["lateral_cm"], float)
    assert [t["id"] for t in on["arm_tags"]] == [0] and 200 < on["arm_tags"][0]["dist_mm"] < 330
    off = run(tmp_path, {"items": [BOTTLE]}, body, p1=False)
    assert "arm_tags" not in off
    assert not set(fm.P1_KEYS) & set(off["detections"][0])


@needs_sim
@pytest.mark.parametrize("pos, j1", [((-54, -301), 0), ((-54, -331), 0), ((-124, -281), 0), ((6, -251), 0),
                                     ((-54, -301), 12)])
def test_dist_cm_matches_0022_formula(tmp_path, pos, j1):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "start_stream"}))
            return (await detection_frame(ws))["detections"][0]

    d = run(tmp_path, {"items": [{**BOTTLE, "pos_mm": list(pos)}], "arm": {"j1": j1}}, body)
    v_bottom = d["y"] + d["h"] / 2
    dist = F_Y * LENS_H_MM / (v_bottom - fm.IMG_H / 2) / 10
    assert abs(d["dist_cm"] - dist) < 1.0, (d, dist)
    if j1 == 0:
        assert abs(d["dist_cm"] - (-pos[1] - 51.1) / 10) < 0.2  # ground truth from the scenario
        lateral = dist * (d["x"] - fm.IMG_W / 2) / F_Y  # square pixels: f_x == f_y
        assert abs(d["lateral_cm"] - lateral) < 1.0, (d, lateral)


@needs_sim
def test_link_drop_goes_silent_refuses_then_recovers(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "start_stream"}))
            times = []
            refused = None
            start = time.monotonic()
            while time.monotonic() - start < 2.6:
                try:
                    await asyncio.wait_for(ws.recv(), 0.1)
                    times.append(time.monotonic() - start)
                except asyncio.TimeoutError:
                    pass
                if refused is None and 0.7 < time.monotonic() - start:
                    try:
                        async with websockets.connect(url, open_timeout=0.5):
                            refused = False
                    except Exception:
                        refused = True
            return times, refused

    times, refused = run(tmp_path, {"items": [BOTTLE], "events": [{"t": 0.3, "do": "link_drop", "for_s": 1.2}]}, body)
    gaps = [b - a for a, b in zip(times, times[1:])]
    assert max(gaps) >= 1.0, gaps  # silent during the drop
    assert times[-1] > 1.8  # frames again on the same connection afterwards
    assert refused


@needs_sim
def test_command_link_0023_shape(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            replies = []
            seq = 0

            async def send(cmd, n):
                nonlocal seq
                seq += 1
                await ws.send(json.dumps({**cmd, "seq": seq}))
                for _ in range(n):
                    replies.append(json.loads(await asyncio.wait_for(ws.recv(), 2)))

            await send({"cmd": "STATUS"}, 1)
            await send({"cmd": "LOCK_DRIVE"}, 1)
            locked = fake.drive_locked
            await send({"cmd": "UNLOCK_DRIVE"}, 1)
            await send({"cmd": "HOLD"}, 2)
            await send({"cmd": "J1_SWEEP", "to": 6}, 2)  # 6 deg at 60 deg/s: done in ~0.1 s
            await send({"cmd": "STOP"}, 1)
            await send({"cmd": "PICK", "dist_cm": 24.0, "lateral_cm": None}, 1)
            await send({"cmd": "FLY"}, 1)
            return replies, locked, fake.drive_locked, fake.world.angles[0]

    replies, locked, unlocked_after, j1 = run(tmp_path, {"items": [BOTTLE]}, body)
    assert replies == [
        {"event": "ack", "seq": 1, "drive_locked": False},
        {"event": "ack", "seq": 2},
        {"event": "ack", "seq": 3},
        {"event": "ack", "seq": 4}, {"event": "motion_done", "seq": 4},
        {"event": "ack", "seq": 5}, {"event": "motion_done", "seq": 5},
        {"event": "ack", "seq": 6},
        {"event": "error", "seq": 7, "reason": "not_implemented"},
        {"event": "error", "seq": 8, "reason": "unknown_cmd"},
    ]
    assert locked and not unlocked_after
    assert j1 == pytest.approx(6)


def test_labels_match_main_py_and_app():
    assert fm.check_labels() == []


def test_shipped_scenarios_load(tmp_path):
    labels = fm.load_labels()
    paths = sorted((fm.HERE / "scenarios").glob("*.yaml"))
    assert len(paths) >= 10  # the 10 shipped ones, plus any local scenarios
    for p in paths:
        fm.load_scenario(p, labels)
    s = yaml.safe_load(paths[0].read_text())
    for bad in ({"items": [{**s["items"][0], "label": "Bottle"}]},  # not a detector class
                {"events": [{"t": 1, "do": "explode"}]}):
        (tmp_path / "bad.yaml").write_text(yaml.safe_dump({**s, **bad}))
        with pytest.raises(ValueError):
            fm.load_scenario(tmp_path / "bad.yaml", labels)


# ── Photo cards, occlusion, timing (T1b) ─────────────────────────────────────

def world_for(tmp_path, items, images_dir=None, occlusion=True, log=None):
    path = tmp_path / "w.yaml"
    path.write_text(yaml.safe_dump({"name": "w", "items": items, "occlusion": occlusion}))
    sc = fm.load_scenario(path, fm.load_labels())
    return fm.SimWorld(SIM, sc, images_dir=images_dir or tmp_path / "no-images", log=log or (lambda *_: None))


def write_photo(path, w, h, colour=(40, 160, 220)):
    path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(path), np.full((h, w, 3), colour, np.uint8))
    return path


def test_card_aspect_follows_the_photo():
    assert fm.card_size(120, np.zeros((100, 200, 3))) == (120, 60)
    assert fm.card_size(120, np.zeros((300, 150, 3))) == (60, 120)
    assert fm.card_size([70, 120], np.zeros((300, 150, 3))) == (60, 120), "a [w, h] pair counts as its larger side"


def test_whole_photos_are_centre_cropped_to_4_3():
    assert fm.centre_crop_4_3(np.zeros((300, 1000, 3))).shape[:2] == (300, 400)
    assert fm.centre_crop_4_3(np.zeros((1000, 300, 3))).shape[:2] == (400, 300)


def test_whole_photo_texture_is_4_3_and_logged(tmp_path):
    images = tmp_path / "images"
    write_photo(images / "Glass" / "wide.jpg", 1000, 300)
    lines = []
    tex = fm.texture_for({"id": "jar", "label": "Glass"}, 0, images, lines.append)
    assert tex.shape[:2] == (300, 400)
    assert any("[Photo] jar (Glass): whole" in l for l in lines)


def test_placeholder_has_no_text():
    for seed in range(5):
        img = fm.placeholder_texture(seed)
        colours = np.unique(img.reshape(-1, 3), axis=0)
        assert len(colours) <= 2, "two flat colours only: any text would add more"


def test_photo_choice_order_and_seed(tmp_path):
    images = tmp_path / "images"
    item = {"id": "bottle", "label": "Plastic"}
    assert fm.choose_photo(item, 0, images) == (None, "placeholder")
    whole = write_photo(images / "Plastic" / "whole.jpg", 400, 300)
    assert fm.choose_photo(item, 0, images) == (whole, "whole")
    crops = [write_photo(images / "Plastic" / "crops" / f"c{k}.jpg", 100, 150) for k in range(6)]
    path, kind = fm.choose_photo(item, 0, images)
    assert kind == "crop" and path in crops
    own = write_photo(fm.HERE / "images" / "_test_own.jpg", 50, 50)
    try:
        assert fm.choose_photo({**item, "photo": "images/_test_own.jpg"}, 0, images) == (own, "photo")
    finally:
        own.unlink()
    assert fm.choose_photo({**item, "photo": "images/missing.jpg"}, 0, images)[1] == "crop", "missing own photo: next in order"
    picks = lambda seed: [fm.choose_photo({"id": f"i{k}", "label": "Plastic"}, seed, images)[0] for k in range(8)]
    assert picks(3) == picks(3), "the same seed repeats a run"
    assert picks(3) != picks(4), "another seed picks other crops"


@needs_sim
def test_photo_card_logged_and_rendered_box_matches_the_card(tmp_path):
    images = tmp_path / "images"
    write_photo(images / "Plastic" / "crops" / "tall.jpg", 100, 200, colour=(0, 0, 255))
    lines = []
    world = world_for(tmp_path, [BOTTLE], images, log=lines.append)
    try:
        assert any("[Photo] bottle (Plastic): crop" in l and "tall.jpg" in l for l in lines)
        w, h = (lambda c: (abs(c[0, 0] - c[1, 0]), c[2, 2]))(world.corners["bottle"])
        assert (w, h) == (60, 120), "photo aspect 1:2, longer side 120 mm"
        img = world.render()
        red = (img[..., 0] > 200) & (img[..., 1] < 60) & (img[..., 2] < 60)
        ys, xs = np.nonzero(red)
        x, y, bw, bh = world.box("bottle")
        assert abs(xs.min() - x) <= 1.5 and abs(xs.max() + 1 - (x + bw)) <= 1.5
        assert abs(ys.min() - y) <= 1.5 and abs(ys.max() + 1 - (y + bh)) <= 1.5
    finally:
        world.close()


@needs_sim
def test_placeholder_is_logged_as_a_warning(tmp_path):
    lines = []
    world = world_for(tmp_path, [BOTTLE], log=lines.append)
    world.close()
    assert any("WARNING bottle" in l and "placeholder" in l for l in lines)


@needs_sim
def test_occlusion_hidden_half_hidden_and_off(tmp_path):
    front = {"id": "front", "label": "Human_Hand", "pos_mm": [-54, -260], "size_mm": 170, "score": 0.97}
    # A tall card whose image-left edge sits on the optical axis (x = -54): it hides the bottle's image-right half.
    half = {**front, "pos_mm": [-54 - 170 * 3 / 4 / 2, -260]}
    world = world_for(tmp_path, [BOTTLE, front])
    try:
        boxes = world.boxes(["bottle", "front"])
        assert boxes["bottle"] is None, "more than 60 % hidden: no box"
        assert boxes["front"] == world.box("front")
    finally:
        world.close()
    world = world_for(tmp_path, [BOTTLE, half])
    try:
        full, part = world.box("bottle"), world.boxes(["bottle", "front"])["bottle"]
        assert part is not None and abs(part[2] - full[2] / 2) <= 3, "half hidden: the visible half only"
        assert abs(part[0] - full[0]) <= 1.5, "the visible part is the bottle's own (image-left) side"
        assert abs(part[3] - full[3]) <= 1.5
    finally:
        world.close()
    world = world_for(tmp_path, [BOTTLE, front], occlusion=False)
    try:
        assert world.boxes(["bottle", "front"])["bottle"] == world.box("bottle"), "occlusion: false"
    finally:
        world.close()


def test_timing_warnings(tmp_path):
    def warnings(events, items=None):
        path = tmp_path / "t.yaml"
        path.write_text(yaml.safe_dump({"name": "t", "events": events, "items": items or [
            BOTTLE, {**BOTTLE, "id": "can", "label": "Metal", "visible": False}]}))
        return fm.load_scenario(path, fm.load_labels())["warnings"]

    assert warnings([{"t": 30, "do": "leave", "item": "bottle"}, {"t": 38, "do": "appear", "item": "can"}]) == []
    early = warnings([{"t": 10, "do": "leave", "item": "bottle"}])
    assert len(early) == 1 and "before 25 s" in early[0]
    swap = warnings([{"t": 30, "do": "leave", "item": "bottle"}, {"t": 35, "do": "appear", "item": "can"}])
    assert len(swap) == 1 and "needs 8 s" in swap[0]
    far = {**BOTTLE, "id": "can", "label": "Metal", "pos_mm": [100, -350], "visible": False}
    assert warnings([{"t": 30, "do": "leave", "item": "bottle"}, {"t": 31, "do": "appear", "item": "can"}],
                    [BOTTLE, far]) == [], "another spot: no gap needed"


def test_shipped_scenarios_follow_the_timing_rule():
    labels = fm.load_labels()
    for p in sorted((fm.HERE / "scenarios").glob("*.yaml")):
        assert fm.load_scenario(p, labels)["warnings"] == [], p.name
