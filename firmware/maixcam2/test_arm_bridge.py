"""arm_bridge.py off the board (decision 0235): frames, kinematics vs the sim's golden values,
ARM_POSE, HOME, bin sequences, the DROP guard, the watchdog and an ESP32 reset."""
import json
import math
import tempfile
import unittest
from pathlib import Path

import arm_bridge as ab

HERE = Path(__file__).resolve().parent
GOLDEN = json.loads((HERE.parents[1] / "test/fixtures/arm_kinematics_golden.json").read_text())


class Clock:
    def __init__(self):
        self.t = 100.0

    def __call__(self):
        return self.t


def rig(**kw):
    clock, frames, logs = Clock(), [], []
    arm = ab.ArmBridge(frames.append, clock=clock, log=logs.append,
                       sequences=kw.get("sequences", ab.load_sequences(HERE / "bin_sequences.json")),
                       config_path=kw.get("config_path"))
    return arm, clock, frames, logs


def run(arm, clock, seconds, heartbeat=True):
    """Ticks for [seconds] with app heartbeats; returns the (owner, reply) the ticks gave."""
    out = []
    for _ in range(int(round(seconds / ab.TICK_S))):
        clock.t += ab.TICK_S
        if heartbeat:
            arm.handle({"cmd": "HEARTBEAT"})
        out += arm.tick()
    return out


def wire(frame):
    payload, crc = frame.rstrip("\n").rsplit(",", 1)
    assert int(crc, 16) == ab.crc8(payload), frame
    return [float(v) for v in payload.split(",")]


RAISED = [75.0, 90.0, 30.0, 120.0, 100.0, 90.0]


class Frames(unittest.TestCase):
    def test_frame_text_and_crc(self):
        self.assertEqual(ab.make_frame(ab.HOME), "180,90,0,180,90,90,{:02X}\n".format(ab.crc8("180,90,0,180,90,90")))
        self.assertEqual(ab.make_frame([75.04, 90, 12.36, 180, 90, -90]).split(",")[:6], ["75", "90", "12.4", "180", "90", "-90"])
        self.assertEqual(ab.crc8("123456789"), 0xF4, "CRC-8 poly 0x07 init 0 check value")

    def test_trim_invert_and_wire_clamp(self):
        trims = [0, 0, 0, 0, 2.5, -3]
        inverted = [False, False, False, True, False, False]
        self.assertEqual(ab.to_wire(ab.HOME, trims, inverted), [180, 90, 0, 0, 92.5, 87])
        self.assertEqual(ab.to_wire([180, 90, 0, 180, 90, 300], [0] * 6, [False] * 6)[5], 270)


class Kinematics(unittest.TestCase):
    """The same golden values the app's Dart port is tested against (sim 75ab797)."""

    def test_joint_points_and_tank(self):
        for c in GOLDEN["fk"]:
            pts = ab.joint_points(c["angles"])
            for p, q in zip(pts, c["points"]):
                for a, b in zip(p, q):
                    self.assertAlmostEqual(a, b, places=4)
            self.assertEqual(ab.unsafe(c["angles"]), c["unsafe"])

    def test_planner(self):
        for c in GOLDEN["plan"]:
            got = ab.plan(c["from"], c["to"])
            if c["path"] is None:
                self.assertIsNone(got)
            else:
                self.assertEqual(len(got), len(c["path"]))
                for w, v in zip(got, c["path"]):
                    for a, b in zip(w, v):
                        self.assertAlmostEqual(a, b, places=6)

    def test_limits_match(self):
        self.assertEqual([list(l) for l in ab.SIM_LIMITS], GOLDEN["limits"])
        self.assertEqual(ab.TANK_Z_MM, GOLDEN["tank_z_mm"])


class ArmPose(unittest.TestCase):
    def test_nothing_is_sent_before_the_first_move(self):
        arm, clock, frames, _ = rig()
        run(arm, clock, 1)
        self.assertEqual(frames, [], "the servos stay as they booted until the app moves the arm")

    def test_plays_the_path_together_and_answers_motion_done_with_the_pose(self):
        arm, clock, frames, _ = rig()
        self.assertEqual(arm.handle({"cmd": "ARM_POSE", "seq": 7, "path": [RAISED]}, "app"),
                         [{"event": "ack", "seq": 7}])
        dur = ab.leg_seconds(ab.HOME, RAISED)
        out = run(arm, clock, dur / 2)
        self.assertEqual(out, [])
        mid = wire(frames[-1])
        for i in range(6):   # all joints are half way at half time (smoothstep is symmetric)
            self.assertAlmostEqual(mid[i], (ab.HOME[i] + RAISED[i]) / 2, delta=1.0)
        out = run(arm, clock, dur / 2 + 0.2)
        self.assertEqual(out, [("app", {"event": "motion_done", "seq": 7, "servo": RAISED})])
        self.assertEqual(wire(frames[-1]), RAISED)
        self.assertEqual(len(frames), len({id(f) for f in frames}), "one frame per tick")

    def test_refuses_bad_paths_without_moving(self):
        arm, clock, frames, _ = rig()
        for path, why in (([[1, 2, 3]], "invalid_path"), ("x", "invalid_path"),
                          ([[180, 90, 0, 180, 90, 400]], "out_of_range"),
                          ([[180, 90, 0, 180, 141, 90]], "out_of_range"),    # Arm A only 40..140
                          ([[180, 90, 0, 180, 90, 270]], "tank")):           # base 180 with the arm low
            self.assertEqual(arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": path})[0]["reason"], why, path)
        run(arm, clock, 0.5)
        self.assertEqual(frames, [])

    def test_a_newer_arm_pose_replaces_the_one_in_flight(self):
        arm, clock, _, _ = rig()
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [RAISED]}, "app")
        run(arm, clock, 0.5)
        arm.handle({"cmd": "ARM_POSE", "seq": 2, "path": [ab.HOME]}, "app")
        out = run(arm, clock, 10)
        self.assertEqual([r["seq"] for _, r in out], [2])

    def test_home_is_planned_around_the_tank(self):
        arm, clock, frames, _ = rig()
        up = [75.0, 90.0, 0.0, 60.0, 60.0, 90.0]
        turned = up[:5] + [260.0]
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [up, turned]}, "app")
        run(arm, clock, 30)
        self.assertEqual(wire(frames[-1])[5], 260)
        arm.handle({"cmd": "HOME", "seq": 2}, "app")
        out = run(arm, clock, 40)
        self.assertEqual(out[-1][1]["event"], "motion_done")
        self.assertEqual(wire(frames[-1]), ab.HOME)
        for f in frames:
            self.assertFalse(ab.unsafe(ab.to_sim(wire(f))), f)

    def test_status_pick_and_lock(self):
        arm, _, _, _ = rig()
        st = arm.handle({"cmd": "STATUS", "seq": 1})[0]
        self.assertEqual((st["event"], st["at_home"], st["servo"]), ("ack", True, ab.HOME))
        self.assertEqual(arm.handle({"cmd": "PICK", "seq": 2})[0]["reason"], "not_implemented")
        self.assertEqual(arm.handle({"cmd": "LOCK_DRIVE", "seq": 3}), [{"event": "ack", "seq": 3}])


class BinsAndDrop(unittest.TestCase):
    def at_bin(self):
        arm, clock, frames, logs = rig()
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "b3"}, "app")[0]["event"], "ack")
        out = run(arm, clock, 40)
        self.assertEqual([r["event"] for _, r in out], ["motion_done"])
        move, _ = ab.load_sequences(HERE / "bin_sequences.json")["b3"]
        self.assertEqual(wire(frames[-1]), [round(v, 1) for v in move[-1][0]], "stops at Pose 4")
        return arm, clock, frames, logs

    def test_other_bins_have_no_sequence(self):
        arm, _, _, _ = rig()
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "organik"})[0]["reason"], "no_sequence")
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 2, "bin": "x"})[0]["reason"], "invalid_bin")

    def test_drop_needs_the_bin_and_its_tag(self):
        arm, clock, _, _ = rig()
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 1})[0]["reason"], "not_at_bin")
        arm, clock, frames, logs = self.at_bin()
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 2})[0]["reason"], "bin_not_confirmed")
        arm.on_tags([3])   # organik's tag at the B3 bin
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 3})[0]["reason"], "bin_not_confirmed")
        arm.on_tags([4])
        run(arm, clock, ab.BIN_TAG_FRESH_S + 0.1)
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 4})[0]["reason"], "bin_not_confirmed", "stale tag")
        arm.on_tags([4])
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 5}, "app"), [{"event": "ack", "seq": 5}])
        out = run(arm, clock, 40)
        self.assertEqual(out, [("app", {"event": "motion_done", "seq": 5, "servo": ab.HOME})], "Pose 7 is home")
        grips = [wire(f)[0] for f in frames]
        self.assertIn(180.0, grips, "Pose 5 opens the gripper")

    def test_any_other_move_leaves_the_bin(self):
        arm, clock, _, _ = self.at_bin()
        arm.on_tags([4])
        arm.handle({"cmd": "ARM_POSE", "seq": 2, "path": [RAISED]})
        arm.on_tags([4])
        self.assertEqual(arm.handle({"cmd": "DROP", "seq": 3})[0]["reason"], "not_at_bin")

    def test_busy_while_a_sequence_plays(self):
        arm, clock, _, _ = rig()
        arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "b3"})
        run(arm, clock, 0.5)
        self.assertEqual(arm.handle({"cmd": "ARM_POSE", "seq": 2, "path": [RAISED]})[0]["reason"], "busy")


class Safety(unittest.TestCase):
    def test_watchdog_holds_the_arm(self):
        arm, clock, frames, _ = rig()
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [RAISED]}, "app")
        run(arm, clock, 0.5)
        out = run(arm, clock, ab.WATCHDOG_S + 0.2, heartbeat=False)
        self.assertEqual(out, [("app", {"event": "error", "seq": 1, "reason": "watchdog"})])
        held = wire(frames[-1])
        run(arm, clock, 1, heartbeat=True)
        self.assertEqual(wire(frames[-1]), held, "holds, never releases")
        self.assertNotEqual(held, RAISED)

    def test_hold_and_stop_freeze(self):
        arm, clock, frames, _ = rig()
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [RAISED]}, "app")
        run(arm, clock, 0.5)
        self.assertEqual([r["event"] for r in arm.handle({"cmd": "HOLD", "seq": 2})], ["ack", "motion_done"])
        held = wire(frames[-1])
        run(arm, clock, 2)
        self.assertEqual(wire(frames[-1]), held)

    def test_esp32_reset_stops_streaming_until_home(self):
        arm, clock, frames, logs = rig()
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [RAISED]}, "app")
        run(arm, clock, 20)
        arm.on_line("BOOT reason=brownout\r")
        n = len(frames)
        run(arm, clock, 1)
        self.assertEqual(len(frames), n, "no frame after a reset")
        self.assertEqual(arm.handle({"cmd": "ARM_POSE", "seq": 2, "path": [RAISED]})[0]["reason"], "pose_unknown")
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 3, "bin": "b3"})[0]["reason"], "pose_unknown")
        st = arm.handle({"cmd": "STATUS", "seq": 4})[0]
        self.assertEqual((st["servo"], st["esp32_boot"]), (None, "reason=brownout"))
        arm.handle({"cmd": "HOME", "seq": 5}, "app")
        out = run(arm, clock, ab.UNKNOWN_HOME_S + 0.2)
        self.assertEqual(out[-1][1]["event"], "motion_done")
        self.assertEqual(wire(frames[-1]), ab.HOME)
        self.assertEqual(arm.handle({"cmd": "ARM_POSE", "seq": 6, "path": [RAISED]})[0]["event"], "ack")

    def test_stat_lines_are_kept(self):
        arm, _, _, _ = rig()
        arm.on_line("STAT rx=10 bad=0 i2c=0 fix=0 reinit=0 spike=0 out=180,90,0,180,90,90")
        self.assertTrue(arm.handle({"cmd": "STATUS", "seq": 1})[0]["esp32_stat"].startswith("rx=10"))


class Config(unittest.TestCase):
    def test_config_maps_the_apps_order_and_persists(self):
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d) / "arm.json")
            arm, clock, frames, _ = rig(config_path=path)
            reply = arm.handle({"cmd": "CONFIG", "seq": 1, "trims": [1, 2, 3, 4, 5],
                                "inverted": [False, True, False, False, False], "baseRate": 40})
            self.assertEqual(reply, [{"event": "ack", "seq": 1}])
            self.assertEqual(arm.trims, [0, 5, 4, 3, 2, 1], "app order Base, Arm A, Arm B, Pitch, Yaw")
            self.assertEqual(arm.inverted, [False, False, False, False, True, False])
            again, _, _, _ = rig(config_path=path)
            self.assertEqual((again.trims, again.inverted), (arm.trims, arm.inverted))
            self.assertEqual(arm.handle({"cmd": "CONFIG", "seq": 2, "trims": [99, 0, 0, 0, 0],
                                         "inverted": [False] * 5})[0]["reason"], "invalid_config")


if __name__ == "__main__":
    unittest.main()
