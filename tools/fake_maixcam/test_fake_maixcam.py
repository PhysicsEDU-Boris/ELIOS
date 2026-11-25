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


def run(tmp_path, scenario, body, p1=None, fps=20.0, log=None):
    """Starts the fake on a free port, runs `await body(url, fake)`, stops it."""
    path = tmp_path / "s.yaml"
    path.write_text(yaml.safe_dump({"name": "test", **scenario}))
    labels = fm.load_labels()
    sc = fm.load_scenario(path, labels)
    world = fm.SimWorld(SIM, sc, images_dir=tmp_path / "no-images", log=lambda *_: None)  # placeholders only
    fake = fm.FakeMaixCam(world, sc, labels, fps=fps, p1=p1, log=log or (lambda *_: None))

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
            async def heartbeat():
                while True:
                    await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                    await asyncio.sleep(0.2)
            keepalive = asyncio.create_task(heartbeat())
            replies = []
            seq = 0

            async def send(cmd, n):
                nonlocal seq
                seq += 1
                await ws.send(json.dumps({**cmd, "seq": seq}))
                for _ in range(n):
                    replies.append(json.loads(await asyncio.wait_for(ws.recv(), 10)))

            await send({"cmd": "STATUS"}, 1)
            await send({"cmd": "LOCK_DRIVE"}, 1)
            locked = fake.drive_locked
            await ws.send(json.dumps({"cmd": "motor", "left": 50, "right": 50}))
            await asyncio.sleep(0.1)
            assert fake.world.motor == (0, 0)
            await send({"cmd": "UNLOCK_DRIVE"}, 1)
            await send({"cmd": "HOLD"}, 2)
            await send({"cmd": "J1_SWEEP", "to": 6}, 2)  # 6 deg at 40 deg/s: done in ~0.15 s
            await send({"cmd": "STOP"}, 1)
            await send({"cmd": "PICK", "dist_cm": 24.0, "lateral_cm": None}, 2)
            await send({"cmd": "FLY"}, 1)
            keepalive.cancel()
            return replies, locked, fake.drive_locked, fake.held_item

    replies, locked, unlocked_after, j1 = run(tmp_path, {"items": [BOTTLE]}, body)
    assert replies[0]["event"] == "ack" and replies[0]["seq"] == 1
    assert replies[0]["drive_locked"] is False
    assert replies[0]["at_home"] is True
    assert len(replies[0]["ee_mm"]) == 3
    assert replies[1:] == [
        {"event": "ack", "seq": 2},
        {"event": "ack", "seq": 3},
        {"event": "ack", "seq": 4}, {"event": "motion_done", "seq": 4},
        {"event": "ack", "seq": 5}, {"event": "motion_done", "seq": 5},
        {"event": "ack", "seq": 6},
        {"event": "ack", "seq": 7}, {"event": "motion_done", "seq": 7},
        {"event": "error", "seq": 8, "reason": "unknown_cmd"},
    ]
    assert locked and not unlocked_after
    assert j1 == "bottle"


@needs_sim
def test_home_moves_all_joints_to_zero_and_status_reports_pose(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            fake.world.angles[:] = fake.world.target[:] = [0, 8, -10, 2, -4]
            fake.world.set_servo("gripper", 100)
            await ws.send(json.dumps({"cmd": "STATUS", "seq": 1}))
            before = json.loads(await asyncio.wait_for(ws.recv(), 2))
            assert before["at_home"] is False
            assert len(before["ee_mm"]) == 3
            await ws.send(json.dumps({"cmd": "HOME", "seq": 2}))
            replies = [json.loads(await asyncio.wait_for(ws.recv(), 10)) for _ in range(2)]
            assert replies == [{"event": "ack", "seq": 2}, {"event": "motion_done", "seq": 2}]
            await ws.send(json.dumps({"cmd": "STATUS", "seq": 3}))
            status = json.loads(await asyncio.wait_for(ws.recv(), 2))
            return status, fake.world.angles.copy(), fake.world.target.copy(), fake.world.gripper_width

    status, angles, target, grip = run(tmp_path, {"items": []}, body)
    assert status["event"] == "ack" and status["seq"] == 3
    assert status["at_home"] is True
    assert status["ee_mm"] == pytest.approx([0, -42.5, 90], abs=0.1)
    assert angles == pytest.approx(np.zeros(5), abs=0.1)
    assert target == pytest.approx(np.zeros(5), abs=0.1)
    assert grip == 0


@needs_sim
def test_r1_pick_bin_drop_and_drive_servo(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            async def heartbeat():
                while True:
                    await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                    await asyncio.sleep(0.2)
            keepalive = asyncio.create_task(heartbeat())

            async def command(cmd, seq, replies=1):
                await ws.send(json.dumps({**cmd, "seq": seq}))
                # 0240: bin moves take the robot's real time (ramps and holds), ~15 s for organik
                return [json.loads(await asyncio.wait_for(ws.recv(), 40)) for _ in range(replies)]

            async def motion(cmd, seq):
                result = await command(cmd, seq, 2)
                assert result == [{"event": "ack", "seq": seq}, {"event": "motion_done", "seq": seq}]

            dist, lateral = fake.world.distance("bottle")
            await motion({"cmd": "PICK", "dist_cm": dist, "lateral_cm": lateral}, 1)
            assert fake.held_item == "bottle" and fake.world.gripper_closed
            await motion({"cmd": "MOVE_TO_BIN", "bin": "organik"}, 2)
            assert fake.held_bin == "organik"
            assert fake.bin_tags() == [{"id": 3, "dist_mm": fm.BIN_TAG_DIST_MM}]
            fake.bin_tag = "wrong"
            assert fake.bin_tags()[0]["id"] != 3
            fake.bin_tag = "none"
            assert fake.bin_tags() == []
            await motion({"cmd": "DROP"}, 3)
            assert fake.held_item is None and not fake.items["bottle"]["on"]

            await ws.send(json.dumps({"cmd": "servo", "part": "base", "val": 120}))
            await asyncio.sleep(1.5)   # organik's DROP ends with the base at -14.7 deg: 45 deg at 40 deg/s
            assert fake.world.angles[0] == pytest.approx(30, abs=1)
            await ws.send(json.dumps({"cmd": "servo", "part": "elbow", "val": 60}))
            await asyncio.sleep(0.1)
            assert fake.world.target[1] == pytest.approx(30)
            await ws.send(json.dumps({"cmd": "servo", "part": "gripper", "val": 0}))
            await asyncio.sleep(0.1)
            assert not fake.world.gripper_closed
            before = fake.world.robot_xy.copy()
            await ws.send(json.dumps({"cmd": "motor", "left": 50, "right": 50}))
            await asyncio.sleep(0.2)
            fake.world.set_motor(0, 0)
            assert np.linalg.norm(fake.world.robot_xy - before) > 10
            keepalive.cancel()
            return fake.world.angles[0]

    assert run(tmp_path, {"items": [BOTTLE]}, body) == pytest.approx(30, abs=1)


def test_bin_paths_from_owner_sequences():
    """0240: b3 = Left-Tank-New, anorganik = Mid-Tank, organik = Right-Tank-New. MOVE_TO_BIN stops at
    the state point with the gripper closed; DROP opens it and ends at home."""
    paths = fm.bin_paths()
    assert set(paths) == {"b3", "anorganik", "organik"}
    assert [m["Arm Base"] for m in paths["b3"][0]] == [167.01, 243.0]
    assert [m["Arm Base"] for m in paths["anorganik"][0]] == [167.01, 249.0, 270.0]
    assert [m["Arm Base"] for m in paths["organik"][0]] == [12.99, -82.0]
    for name, (move, drop) in paths.items():
        assert all(m["Gripper"] == 75.0 for m in move), name
        assert all(d["Gripper"] == 180.0 for d in drop), name


@needs_sim
def test_b3_sequence_is_tank_safe(tmp_path):
    """Every saved B3 leg, and the HOME after a failed bin check, pass the sim's tank planner as one move."""
    world = fm.SimWorld(SIM, fm.load_scenario(_scenario(tmp_path), fm.load_labels()),
                        images_dir=tmp_path / "x", log=lambda *_: None)
    try:
        move, drop = fm.bin_paths()["b3"]
        poses = [np.zeros(5)] + [world.servo_pose(st) for st in move + drop]
        lims = world.hil_config.joint_limits()
        for a, b in zip(poses, poses[1:]):
            assert all(lo - 1e-6 <= v <= hi + 1e-6 for v, (lo, hi) in zip(b, lims))
            assert world.kinematics.path_unsafe(a, b, step=0.5) is None
        state_point = world.servo_pose(move[-1])
        assert world.kinematics.path_unsafe(state_point, np.zeros(5), step=0.5) is None, "HOME from the state point"
    finally:
        world.close()


def _scenario(tmp_path):
    path = tmp_path / "s.yaml"
    path.write_text(yaml.safe_dump({"name": "test", "items": [BOTTLE]}))
    return path


@needs_sim
def test_r1_b3_bin_sequence_state_point_and_drop(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            async def heartbeat():
                while True:
                    await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                    await asyncio.sleep(0.2)
            keepalive = asyncio.create_task(heartbeat())

            async def motion(cmd, seq):
                await ws.send(json.dumps({**cmd, "seq": seq}))
                got = [json.loads(await asyncio.wait_for(ws.recv(), 40)) for _ in range(2)]
                assert got == [{"event": "ack", "seq": seq}, {"event": "motion_done", "seq": seq}]

            dist, lateral = fake.world.distance("bottle")
            await motion({"cmd": "PICK", "dist_cm": dist, "lateral_cm": lateral}, 1)
            await motion({"cmd": "MOVE_TO_BIN", "bin": "b3"}, 2)
            move, _ = fm.bin_paths()["b3"]
            assert fake.world.angles == pytest.approx(fake.world.servo_pose(move[-1]), abs=0.5)
            assert fake.held_bin == "b3" and fake.held_item == "bottle" and fake.world.gripper_closed
            assert fake.bin_tags() == [{"id": 4, "dist_mm": fm.BIN_TAG_DIST_MM}]
            await motion({"cmd": "DROP"}, 3)
            assert fake.held_item is None and fake.held_bin is None and not fake.items["bottle"]["on"]
            assert fake.world.angles == pytest.approx(np.zeros(5), abs=0.5), "Pose 7 is home"
            keepalive.cancel()

    run(tmp_path, {"items": [BOTTLE]}, body, fps=50.0)


@needs_sim
def test_arm_pose_plays_the_apps_path(tmp_path):
    """0234: ARM_POSE legs in servo degrees end at the last pose; F0 sets the gripper; bad paths are refused."""
    raised = [75.0, 90.0, 30.0, 120.0, 100.0, 90.0]
    turned = [75.0, 90.0, 30.0, 120.0, 100.0, 300.0 - 90.0]

    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            async def heartbeat():
                while True:
                    await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                    await asyncio.sleep(0.2)
            keepalive = asyncio.create_task(heartbeat())
            await ws.send(json.dumps({"cmd": "ARM_POSE", "seq": 1, "path": [raised, turned]}))
            got = [json.loads(await asyncio.wait_for(ws.recv(), 30)) for _ in range(2)]
            assert got == [{"event": "ack", "seq": 1}, {"event": "motion_done", "seq": 1}]
            names = [a.name for a in fake.world.hil_config.AXES]
            assert fake.world.angles == pytest.approx(fake.world.servo_pose(dict(zip(names, turned))), abs=0.5)
            assert fake.world.gripper_closed
            await ws.send(json.dumps({"cmd": "ARM_POSE", "seq": 2, "path": [[1, 2, 3]]}))
            assert json.loads(await asyncio.wait_for(ws.recv(), 5)) == {"event": "error", "seq": 2, "reason": "invalid_path"}
            keepalive.cancel()

    run(tmp_path, {"items": [BOTTLE]}, body, fps=50.0)


@needs_sim
def test_r1_unreachable_pick_is_rejected(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            dist, lateral = fake.world.distance("far")
            await ws.send(json.dumps({"cmd": "PICK", "seq": 1, "dist_cm": dist, "lateral_cm": lateral}))
            return json.loads(await asyncio.wait_for(ws.recv(), 2))

    assert run(tmp_path, {"items": [{**BOTTLE, "id": "far", "pos_mm": [-54, -701]}]}, body) == {
        "event": "error", "seq": 1, "reason": "unreachable"}


def test_labels_match_main_py_and_app():
    assert fm.check_labels() == []


def test_shipped_scenarios_load(tmp_path):
    labels = fm.load_labels()
    paths = sorted((fm.HERE / "scenarios").glob("*.yaml"))
    assert len(paths) >= 15  # L1 scenarios plus the existing shipped ones
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


@needs_sim
def test_fake_uses_robot_sim_effective_joint_limits(tmp_path):
    world = world_for(tmp_path, [])
    try:
        # robotic_hand_sim 75ab797 hil/config.py: stepper base, pitch home at servo 0 (decision 0230).
        assert world.cc.ase.JOINT_LIMITS == [(-180.0, 180.0), (-50.0, 50.0),
                                            (-180.0, 0.0), (0.0, 180.0),
                                            (-90.0, 90.0)]
    finally:
        world.close()


@needs_sim
def test_reach_moves_hand_on_y_without_panning_camera_and_clamps(tmp_path):
    world = world_for(tmp_path, [])
    try:
        ase = world.cc.ase
        camera = world.cc.camera_pose(world.angles[0])
        start = ase.forward_kinematics(world.angles)[2].copy()
        assert world.set_servo("reach", 120)
        plus_y = ase.forward_kinematics(world.target)[2].copy()
        assert plus_y[1] > start[1]
        assert world.angles[0] == world.target[0] == 0
        assert np.allclose(world.cc.camera_pose(world.angles[0]), camera)
        assert world.set_servo("reach", 60)
        minus_y = ase.forward_kinematics(world.target)[2]
        assert minus_y[1] < plus_y[1]
        assert world.set_servo("reach", 1000)
        assert world.hand_values["reach"] == 180
        limits = np.asarray(ase.JOINT_LIMITS)
        assert np.all(world.target >= limits[:, 0])
        assert np.all(world.target <= limits[:, 1])
        assert not world.set_servo("unknown", 90)
    finally:
        world.close()


@needs_sim
def test_height_uses_cartesian_ik_without_panning_camera(tmp_path):
    world = world_for(tmp_path, [])
    try:
        ase = world.cc.ase
        camera = world.cc.camera_pose(world.angles[0])
        start = ase.forward_kinematics(world.target)[2].copy()
        assert world.set_servo("height", 91)
        plus = ase.forward_kinematics(world.target)[2].copy()
        assert plus[2] > start[2]
        assert world.target[0] == 0
        assert world.set_servo("height", 90)
        assert np.allclose(ase.forward_kinematics(world.target)[2], start, atol=0.1)
        assert world.set_servo("height", 89)
        minus = ase.forward_kinematics(world.target)[2].copy()
        assert minus[2] < start[2]
        assert world.set_servo("height", 1000)
        limits = np.asarray(ase.JOINT_LIMITS)
        assert np.all(world.target >= limits[:, 0])
        assert np.all(world.target <= limits[:, 1])
        assert np.allclose(world.cc.camera_pose(world.angles[0]), camera)
    finally:
        world.close()


@needs_sim
def test_lateral_is_disabled_without_moving_j1_or_camera(tmp_path):
    world = world_for(tmp_path, [])
    try:
        target = world.target.copy()
        camera = world.cc.camera_pose(world.angles[0])
        assert not world.set_servo("lateral", 91)
        assert np.array_equal(world.target, target)
        assert np.allclose(world.cc.camera_pose(world.angles[0]), camera)
    finally:
        world.close()


@needs_sim
def test_gripper_width_controls_jaw_gap_and_closed_threshold(tmp_path):
    world = world_for(tmp_path, [])
    try:
        world.set_servo("gripper", 0)
        opened = world.gripper_jaws[0][0].points.copy()
        world.set_servo("gripper", 49)
        almost_closed = world.gripper_jaws[0][0].points.copy()
        assert not world.gripper_closed
        world.set_servo("gripper", 50)
        assert world.gripper_closed
        world.set_servo("gripper", 100)
        closed = world.gripper_jaws[0][0].points.copy()
        assert world.gripper_width == 100
        assert not np.allclose(opened, almost_closed)
        assert not np.allclose(opened, closed)
        assert not world.set_servo("unknown", 90)
    finally:
        world.close()


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


# ── E1: arm_moving, HEARTBEAT, watchdog (decision 0026) ──────────────────────

@needs_sim
def test_arm_moving_while_j1_turns(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "start_stream"}))
            return [m.get("arm_moving") for m in await frames(ws, 30)]

    moving = run(tmp_path, {"items": [BOTTLE], "events": [{"t": 0.3, "do": "arm", "j1": 20}]}, body)
    assert moving[0] is False, "still at first"
    assert True in moving, "true while J1 turns (20 deg at 40 deg/s)"
    assert moving[-1] is False, "false again once it arrived"
    old = run(tmp_path, {"items": [BOTTLE], "events": [{"t": 0.3, "do": "arm", "j1": 20}]}, body, p1=False)
    assert set(old) == {None}, "old firmware: no arm_moving field"


@needs_sim
def test_heartbeat_feeds_the_watchdog_and_gets_no_reply(tmp_path):
    lines = []

    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await asyncio.sleep(1.4)  # the app says nothing
            fired = [l for l in lines if "[Watchdog] no app message" in l]
            replies = []
            for _ in range(8):  # 2 s of heartbeats at 4 Hz
                await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                try:
                    replies.append(json.loads(await asyncio.wait_for(ws.recv(), 0.25)))
                except asyncio.TimeoutError:
                    pass
            return fired, replies, list(lines)

    fired, replies, after = run(tmp_path, {"items": [BOTTLE]}, body, log=lines.append)
    assert fired == ["[Watchdog] no app message for 1 s: wheels 0 / arm hold"]
    assert replies == [], "HEARTBEAT has no reply"
    assert after.count("[Watchdog] app messages again") == 1
    assert sum("[Watchdog] no app message" in l for l in after) == 1, "no new watchdog while heartbeats flow"


def test_new_scenarios_load_without_timing_warnings():
    labels = fm.load_labels()
    for name in ("two_items", "two_same_class", "all_classes"):
        assert fm.load_scenario(fm.HERE / "scenarios" / f"{name}.yaml", labels)["warnings"] == [], name


# ── E1b: every command logs a line ───────────────────────────────────────────

@needs_sim
def test_every_command_logs_a_line(tmp_path):
    lines = []

    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            await ws.send(json.dumps({"cmd": "STOP", "seq": 7}))
            await ws.recv()  # its ack
            await ws.send(json.dumps({"cmd": "motor", "left": 0, "right": 0}))
            await ws.send(json.dumps({"cmd": "LOCK_DRIVE", "seq": 8}))
            await ws.recv()
            await ws.send(json.dumps({"cmd": "FLY", "seq": 9}))
            await ws.recv()
            await ws.send(json.dumps({"cmd": "DANCE"}))
            await ws.send(json.dumps({"cmd": "ping"}))
            await ws.recv()
            for _ in range(10):  # 2.5 s at 4 Hz
                await ws.send(json.dumps({"cmd": "HEARTBEAT"}))
                await asyncio.sleep(0.25)
            return list(lines)

    out = run(tmp_path, {"items": [BOTTLE]}, body, log=lines.append)
    assert "[WS] STOP seq=7 -> wheels 0, arm hold" in out
    assert "[WS] motor left=0 right=0" in out, "motor lines unchanged"
    assert out.index("[WS] STOP seq=7 -> wheels 0, arm hold") < out.index("[WS] motor left=0 right=0")
    assert "[WS] LOCK_DRIVE seq=8" in out
    assert "[WS] unknown cmd 'FLY' seq=9 -> error unknown_cmd" in out
    assert "[WS] unknown cmd 'DANCE' (ignored)" in out
    assert "[WS] ping -> pong" in out
    beats = [l for l in out if l.startswith("[WS] heartbeat")]
    assert 1 <= len(beats) <= 3, "once a second at most"
    assert all(l in ("[WS] heartbeat x4/s", "[WS] heartbeat x3/s", "[WS] heartbeat x5/s") for l in beats), beats


# ── 0240: the fake moves like the robot (arm_bridge's profile maths, pinned to the sim) ──

def _fake(tmp_path):
    labels = fm.load_labels()
    sc = fm.load_scenario(_scenario(tmp_path), labels)
    world = fm.SimWorld(SIM, sc, images_dir=tmp_path / "x", log=lambda *_: None)
    return world, fm.FakeMaixCam(world, sc, labels, log=lambda *_: None)


@needs_sim
def test_legs_take_the_robots_time_with_ramps_and_hold(tmp_path):
    world, _ = _fake(tmp_path)
    try:
        base = {**fm.ab.DEFAULT_PROFILE, "Arm Base": {"vmax": 32.0, "accel": 0.72, "decel": 0.18}}
        goal = world.servo6(np.array([60.0, 0, 0, 0, 0]), 75.0)   # base +60 and the gripper closes together
        want = fm.ab.leg_seconds(world.servo6(), goal, base)
        world.start_leg(goal, base, hold=0.5)
        t, dt, mid = 0.0, 0.01, None
        while not world.step(dt):
            t += dt
            if mid is None and t >= want / 2:
                mid = world.angles[0]
        assert t + dt == pytest.approx(want + 0.5, abs=0.02)
        assert world.angles == pytest.approx([60, 0, 0, 0, 0], abs=1e-6)
        assert world.grip_servo == 75.0 and world.gripper_closed, "the gripper is a timed axis"
        # 72 % speed-up / 18 % slow-down: half way in time is well under half way in angle
        u = 0.5
        assert mid == pytest.approx(60 * fm.ab.ramp(u, 0.72, 0.18), abs=1.0)
    finally:
        world.close()


@needs_sim
def test_closing_the_gripper_at_an_item_grips_it_manually(tmp_path):
    world, fake = _fake(tmp_path)
    try:
        at = world.solve_ik(world.pick_point("bottle"))
        assert at is not None
        world.angles[:] = world.target[:] = at
        names = [a.name for a in world.hil_config.AXES]
        fake._set_grip(dict(zip(names, world.servo6(at, 75.0))))
        assert fake.held_item == "bottle" and world.held_item == "bottle"
        fake._set_grip(dict(zip(names, world.servo6(at, 180.0))))
        assert fake.held_item is None and fake.items["bottle"]["on"], "let go on the floor, not in a bin"
        world.angles[:] = 0
        fake._set_grip(dict(zip(names, world.servo6(np.zeros(5), 75.0))))
        assert fake.held_item is None, "closing far from the item grips nothing"
    finally:
        world.close()


@needs_sim
def test_config_profile_drives_manual_moves(tmp_path):
    async def body(url, fake):
        async with websockets.connect(url) as ws:
            await ws.recv()
            prof = {"Arm Base": {"vmax": 10, "accel": 0.5, "decel": 0.5}}
            await ws.send(json.dumps({"cmd": "CONFIG", "seq": 1, "trims": [0] * 5, "inverted": [False] * 5, "profile": prof}))
            assert json.loads(await ws.recv()) == {"event": "ack", "seq": 1}
            assert fake.profile["Arm Base"] == {"vmax": 10.0, "accel": 0.5, "decel": 0.5}
            await ws.send(json.dumps({"cmd": "ARM_POSE", "seq": 2, "path": [[180, 90, 0, 180, 90, 100]]}))
            assert json.loads(await ws.recv())["event"] == "ack"
            return fake.world.leg["dur"]

    dur = run(tmp_path, {"items": [BOTTLE]}, body)
    assert dur == pytest.approx(10 / (1 - 0.5) / 10)   # 10 deg at 10 deg/s, peak = 2x mean
