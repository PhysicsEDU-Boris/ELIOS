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
PROFILE_GOLDEN = json.loads((HERE.parents[1] / "test/fixtures/arm_profile_golden.json").read_text())


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
        for i in range(6):   # all joints are half way at half time (equal accel and decel ramps are symmetric)
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
        self.assertEqual(wire(frames[-1]), [round(v, 1) for v in move[-1][0]], "stops at the state point (Pose 2)")
        return arm, clock, frames, logs

    def test_a_bin_without_a_sequence(self):
        seqs = ab.load_sequences(HERE / "bin_sequences.json")
        del seqs["organik"]
        arm, _, _, _ = rig(sequences=seqs)
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "organik"})[0]["reason"], "no_sequence")
        self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 2, "bin": "x"})[0]["reason"], "invalid_bin")

    def test_every_bin_moves_and_drops(self):
        seqs = ab.load_sequences(HERE / "bin_sequences.json")
        self.assertEqual(set(seqs), set(ab.BIN_TAG_IDS))
        for name in sorted(seqs):
            arm, clock, frames, _ = rig()
            self.assertEqual(arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": name})[0]["event"], "ack", name)
            self.assertEqual([r["event"] for _, r in run(arm, clock, 60)], ["motion_done"], name)
            self.assertEqual(wire(frames[-1]), [round(v, 1) for v in seqs[name][0][-1][0]], name)
            arm.on_tags([ab.BIN_TAG_IDS[name]])
            self.assertEqual(arm.handle({"cmd": "DROP", "seq": 2})[0]["event"], "ack", name)
            self.assertEqual([r["event"] for _, r in run(arm, clock, 60)], ["motion_done"], name)
            self.assertIn(180.0, [wire(f)[0] for f in frames], name + " opens the gripper")

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
        self.assertEqual([(o, r["event"], r["servo"]) for o, r in out], [("app", "motion_done", ab.HOME)], "the last step is home")
        grips = [wire(f)[0] for f in frames]
        self.assertIn(180.0, grips, "the release step opens the gripper")

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

    def test_config_profile_is_applied_saved_and_reported(self):
        """0240: CONFIG.profile drives manual moves; bad values are clamped, not rejected."""
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d) / "arm.json")
            arm, clock, _, _ = rig(config_path=path)
            self.assertEqual(arm.profile, ab.DEFAULT_PROFILE, "no profile yet (or a file from before 0240)")
            prof = {"Arm Base": {"vmax": 500, "accel": 0.72, "decel": 0.18}, "Arm A": {"vmax": "x"}}
            reply = arm.handle({"cmd": "CONFIG", "seq": 1, "trims": [0] * 5, "inverted": [False] * 5, "profile": prof})
            self.assertEqual(reply, [{"event": "ack", "seq": 1}])
            self.assertEqual(arm.profile["Arm Base"], {"vmax": 32.0, "accel": 0.72, "decel": 0.18})
            self.assertEqual(arm.profile["Arm A"], ab.DEFAULT_PROFILE["Arm A"])
            self.assertEqual(arm.handle({"cmd": "STATUS", "seq": 2})[0]["profile"], arm.profile)
            arm.handle({"cmd": "ARM_POSE", "seq": 3, "path": [RAISED]})
            self.assertEqual(arm.leg[5], ab._axes(arm.profile))
            again, _, _, _ = rig(config_path=path)
            self.assertEqual(again.profile, arm.profile, "saved with the trims")
            arm.handle({"cmd": "CONFIG", "seq": 4, "trims": [0] * 5, "inverted": [False] * 5})
            self.assertEqual(arm.profile, ab.DEFAULT_PROFILE, "an app from before 0240 sends none: defaults")


class SpeedProfile(unittest.TestCase):
    """0240 section 1, against robotic_hand_sim's ProfiledMotion (test/fixtures/arm_profile_golden.json)."""

    def test_clamping_matches_the_sim(self):
        self.assertEqual(PROFILE_GOLDEN["axes"], [a[0] for a in ab.AXES])
        for name, p in PROFILE_GOLDEN["profiles"].items():
            self.assertEqual(ab.complete_profile(p["input"]), p["clean"], name)
        self.assertEqual([g["vmax"] for g in ab.DEFAULT_PROFILE.values()], [72.0, 36.0, 36.0, 24.0, 24.0, 32.0])

    def test_leg_time_and_positions_match_the_sim(self):
        for leg in PROFILE_GOLDEN["legs"]:
            prof = PROFILE_GOLDEN["profiles"][leg["profile"]]["input"]
            dur = ab.leg_seconds(leg["start"], leg["goal"], prof)
            self.assertAlmostEqual(dur, leg["seconds"], places=5, msg=leg["profile"])
            axes = ab._axes(prof)
            for s in leg["samples"]:
                u = s["u"]
                got = leg["goal"] if u >= 1.0 else [a + (b - a) * ab.ramp(u, ta, td)
                                                     for a, b, (_, ta, td) in zip(leg["start"], leg["goal"], axes)]
                for g, want in zip(got, s["cmd"]):
                    self.assertAlmostEqual(g, want, places=4, msg="{} u={}".format(leg["profile"], u))

    def test_ramp_is_smooth_and_never_faster_than_vmax(self):
        for leg in PROFILE_GOLDEN["legs"]:
            prof = PROFILE_GOLDEN["profiles"][leg["profile"]]["input"]
            dur = ab.leg_seconds(leg["start"], leg["goal"], prof)
            for (a, b, (vmax, ta, td)) in zip(leg["start"], leg["goal"], ab._axes(prof)):
                self.assertEqual(ab.ramp(0.0, ta, td), 0.0)
                self.assertAlmostEqual(ab.ramp(1.0, ta, td), 1.0, places=9)
                for edge in (ta, 1.0 - td):   # both formulas meet at the ramp ends
                    self.assertAlmostEqual(ab.ramp(edge - 1e-9, ta, td), ab.ramp(edge + 1e-9, ta, td), places=6)
                n, prev = 400, 0.0
                for k in range(1, n + 1):
                    s = ab.ramp(k / n, ta, td)
                    self.assertGreaterEqual(s, prev - 1e-12)
                    if dur > 0:
                        self.assertLessEqual(abs(b - a) * (s - prev) * n / dur, vmax + 1e-6)
                    prev = s

    def test_sequence_steps_keep_their_saved_profile(self):
        seqs = ab.load_sequences(HERE / "bin_sequences.json")
        for name, (move, drop) in seqs.items():
            for _, _, prof, _ in move + drop:
                self.assertEqual(prof["Arm Base"], {"vmax": 32.0, "accel": 0.72, "decel": 0.18}, name)
                self.assertEqual(prof["Arm A"], {"vmax": 24.0, "accel": 0.33, "decel": 0.33}, name)

    def test_a_step_without_motion_plays_at_the_defaults(self):
        data = {"bins": {"b3": {"sequence": "s", "state_point": "a", "release": "b"}},
                "sequences": [{"name": "s", "steps": [
                    {"name": "a", "servo": dict(zip([x[0] for x in ab.AXES], RAISED))},
                    {"name": "b", "servo": dict(zip([x[0] for x in ab.AXES], ab.HOME)), "motion": {"Arm Base": "x"}}]}]}
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "s.json"
            path.write_text(json.dumps(data))
            (move, drop) = ab.load_sequences(path)["b3"]
        self.assertEqual(move[0][2], ab.DEFAULT_PROFILE)
        self.assertEqual(drop[0][2], ab.DEFAULT_PROFILE, "a bad motion falls back too")

    def test_sequence_plays_each_steps_profile_then_the_live_one_again(self):
        slow = ab.complete_profile({a[0]: {"vmax": 5, "accel": 0.5, "decel": 0.5} for a in ab.AXES})
        step = ab.complete_profile({"Arm B": {"vmax": 12, "accel": 0.2, "decel": 0.6}})
        lifted = [75.0, 90.0, 138.1, 131.22, 76.37, 12.99]   # Right-Tank-New Pose 1 and 2:
        turned = [75.0, 90.0, 180.0, 86.66, 75.91, -82.0]    # the planner adds a leg between them
        self.assertEqual(len(ab.plan(ab.to_sim(lifted), ab.to_sim(turned))), 2)
        seqs = {"b3": ([(lifted, 0.2, step, None), (turned, 0.2, step, None)], [(list(ab.HOME), 0.0, step, None)])}
        arm, clock, _, _ = rig(sequences=seqs)
        arm.profile = slow                                 # the live (CONFIG) profile
        arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "b3"})
        self.assertAlmostEqual(arm.leg[3], ab.leg_seconds(ab.HOME, lifted, step))
        self.assertEqual(arm.leg[5], ab._axes(step))
        self.assertTrue(all(len(l) == 4 and l[2] is step for l in arm.legs), "planner legs keep the step's profile")
        self.assertEqual([r["event"] for _, r in run(arm, clock, 60)], ["motion_done"])
        arm.handle({"cmd": "ARM_POSE", "seq": 2, "path": [turned[:5] + [190.0]]})
        self.assertEqual(arm.leg[5], ab._axes(slow), "manual moves use the live profile again")

    def test_bad_values_fall_back_to_the_defaults(self):
        bad = {"Arm Base": {"vmax": float("nan"), "accel": 0.5, "decel": 0.5}, "Arm A": {"vmax": "fast"},
               "Arm B": "x", "Gripper": {"vmax": 10, "accel": None, "decel": 0.2}}
        self.assertEqual(ab.complete_profile(bad), ab.DEFAULT_PROFILE)
        self.assertEqual(ab.complete_profile(None), ab.DEFAULT_PROFILE)
        self.assertEqual(ab.complete_profile([1, 2]), ab.DEFAULT_PROFILE)

    def test_bridge_streams_the_profiled_leg(self):
        leg = next(l for l in PROFILE_GOLDEN["legs"] if l["profile"] == "default" and l["goal"] == RAISED)
        arm, clock, frames, _ = rig()
        arm.handle({"cmd": "ARM_POSE", "seq": 1, "path": [RAISED]})
        t0 = clock.t
        for s in leg["samples"][1:-1]:
            run(arm, clock, t0 + s["u"] * leg["seconds"] - clock.t)
            u = (clock.t - t0) / leg["seconds"]
            want = [a + (b - a) * ab.ramp(u, ta, td) for a, b, (_, ta, td) in zip(ab.HOME, RAISED, ab._axes(None))]
            self.assertEqual(wire(frames[-1]), [round(v, 1) for v in want], "u={:.2f}".format(u))


class TagCentring(unittest.TestCase):
    """0240 section 5: Arm Base steers a tagged step's live tag back onto its saved line."""
    TAG = (4, 0.1)

    def play(self, slip, sign=1.0, seen=True, seconds=30):
        """One tagged step to RAISED. The hand camera turns with the base: turning it plus moves the tag
        right in the image (sign=-1: a camera that turns the other way, i.e. a wrong AZ_SIGN)."""
        seqs = {"b3": ([(list(RAISED), 0.2, ab.DEFAULT_PROFILE, self.TAG)], [(list(ab.HOME), 0.0, ab.DEFAULT_PROFILE, None)])}
        arm, clock, _, _ = rig(sequences=seqs)
        arm.handle({"cmd": "MOVE_TO_BIN", "seq": 1, "bin": "b3"}, "app")
        target = ab.saved_offset_deg(self.TAG[1])
        f = 320 / math.tan(math.radians(ab.CAM_HFOV_DEG) / 2)
        out = []
        for _ in range(int(seconds / ab.TICK_S)):
            clock.t += ab.TICK_S
            arm.handle({"cmd": "HEARTBEAT"})
            h = target + sign * (arm.cmd[ab.BASE] - (RAISED[ab.BASE] + slip))
            arm.on_tags([{"id": 4, "cx": 320 + f * math.tan(math.radians(h))}] if seen else [], 640)
            out += arm.tick()
            if out:
                break
        self.assertEqual([r["event"] for _, r in out], ["motion_done"])
        return arm, out[0][1]

    def test_a_slipped_base_is_centred_and_kept(self):
        arm, done = self.play(slip=6.0)
        self.assertEqual(done["align"][-1]["note"], "centred")
        self.assertAlmostEqual(done["base_corr"], 6.0, delta=ab.ALIGN_TOL_DEG)
        self.assertAlmostEqual(done["servo"][ab.BASE], RAISED[ab.BASE] + arm.base_corr, places=6)
        self.assertEqual(arm.handle({"cmd": "STATUS", "seq": 2})[0]["base_corr"], round(arm.base_corr, 2))
        arm.handle({"cmd": "HOME", "seq": 3})
        self.assertEqual(arm.base_corr, 0.0, "HOME clears the slip correction")

    def test_a_turn_the_wrong_way_is_undone(self):
        arm, done = self.play(slip=6.0, sign=-1.0)
        self.assertEqual(done["align"][-1]["note"], "diverged")
        self.assertEqual(arm.base_corr, 0.0)
        self.assertEqual(done["servo"][ab.BASE], RAISED[ab.BASE])

    def test_no_tag_carries_on_after_the_wait(self):
        arm, done = self.play(slip=6.0, seen=False)
        self.assertEqual(done["align"], [{"tag": 4, "note": "no_tag", "err_deg": None, "base_corr": 0.0}])

    def test_the_correction_never_passes_its_limit(self):
        arm, done = self.play(slip=60.0)
        self.assertLessEqual(abs(arm.base_corr), ab.ALIGN_MAX_CORR_DEG)
        self.assertIn(done["align"][-1]["note"], ("corr_limit", "max_moves"))

    def test_later_steps_get_the_correction_and_tags_are_wanted(self):
        arm, _ = self.play(slip=4.0)
        self.assertTrue(arm.wants_tags, "at the bin: the DROP guard needs tags")
        corr = arm.base_corr
        arm.on_tags([4])
        arm.handle({"cmd": "DROP", "seq": 2})
        self.assertAlmostEqual(arm.leg[1][ab.BASE], ab.HOME[ab.BASE] + corr)

    def test_the_bins_saved_tags_load(self):
        seqs = ab.load_sequences(HERE / "bin_sequences.json")
        self.assertEqual(seqs["b3"][0][-1][3], (4, -0.0859), "Left-Tank-New Pose 2")
        self.assertIsNone(seqs["b3"][0][0][3], "Pose 1 has no tag")


if __name__ == "__main__":
    unittest.main()
