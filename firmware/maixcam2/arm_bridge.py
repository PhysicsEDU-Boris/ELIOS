"""MaixCAM2 -> ESP32 arm bridge (decision 0235). Plain Python, no Maix imports, so it runs
off the board in test_arm_bridge.py.

The app plans manual moves (0234) and sends ARM_POSE paths in servo degrees. This module checks
each path again (joint ranges and the tank, a last line of defence), plays it like
robotic_hand_sim hil/motion.py (all joints start and arrive together, smoothstep, 80 % of each
axis' speed) and streams one frame per tick to the ESP32 running
slave_code/6-axis-esp32-twoway-tmc2208 in stream mode:

    "F0,F1,F2,F3,F4,F5,CC\\n"  Gripper, Wrist Yaw, Wrist Pitch, Arm B, Arm A, Base (wire degrees,
                              trim and invert applied), CC = CRC-8 poly 0x07 of the text before it.

It also plays the owner's bin sequences (bin_sequences.json, 0233) and guards DROP: only at the
bin's state point with that bin's AprilTag seen in the last BIN_TAG_FRESH_S.

Every field is always filled: an empty field releases (limps) that servo.
"""
import json
import math
import os
import time

TICK_S = 0.05                 # hil/config.py TICK_MS: one frame per tick (20 Hz)
SPEED_MARGIN = 0.8            # hil/config.py: moves timed at 80 % of each axis' limit
MIN_LEG_S = 0.15
WATCHDOG_S = 1.0              # 0026: no app message this long -> arm holds
BIN_TAG_FRESH_S = 2.0         # DROP guard
UNKNOWN_HOME_S = 6.0          # HOME after an ESP32 reset: the slowest full travel
TANK_Z_MM = 167.0
WIRE_MIN, WIRE_MAX = -15.0, 195.0

# name, sim joint (None = gripper), home, servo lo, servo hi, speed deg/s, wire lo, wire hi (hil/config.py)
AXES = (
    ("Gripper", None, 180.0, 60.0, 180.0, 90.0, WIRE_MIN, WIRE_MAX),
    ("Wrist Yaw", 4, 90.0, 0.0, 180.0, 45.0, WIRE_MIN, WIRE_MAX),
    ("Wrist Pitch", 3, 0.0, 0.0, 180.0, 45.0, WIRE_MIN, WIRE_MAX),
    ("Arm B", 2, 180.0, 0.0, 180.0, 30.0, WIRE_MIN, WIRE_MAX),
    ("Arm A", 1, 90.0, 0.0, 180.0, 30.0, WIRE_MIN, WIRE_MAX),
    ("Arm Base", 0, 90.0, -90.0, 270.0, 40.0, -90.0, 270.0),
)
HOME = [a[2] for a in AXES]
# Effective sim limits (hil/config.py joint_limits()), J1..J5.
SIM_LIMITS = ((-180.0, 180.0), (-50.0, 50.0), (-180.0, 0.0), (0.0, 180.0), (-90.0, 90.0))
# The app's CONFIG lists trims / inverted as Base, Arm A, Arm B, Wrist Pitch, Wrist Yaw (0232).
CONFIG_FIELDS = (5, 4, 3, 2, 1)
BIN_TAG_IDS = {"anorganik": 2, "organik": 3, "b3": 4}
_D = ((0.0, 5.0, 35.5), (0.0, -47.5, 194.5), (0.0, 0.0, -140.0), (0.0, -24.5, 0.0))


def servo_range(i):
    _, joint, home, lo, hi = AXES[i][:5]
    return (lo, hi) if joint is None else (home + SIM_LIMITS[joint][0], home + SIM_LIMITS[joint][1])


# ── Frames ────────────────────────────────────────────────────────────────────

def crc8(text):
    crc = 0
    for b in text.encode("ascii"):
        crc ^= b
        for _ in range(8):
            crc = ((crc << 1) ^ 0x07) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc


def _fmt(v):
    s = "{:.1f}".format(round(v, 1))
    return s[:-2] if s.endswith(".0") else s


def make_frame(wire):
    payload = ",".join(_fmt(v) for v in wire)
    return "{},{:02X}\n".format(payload, crc8(payload))


def to_wire(servo, trims, inverted):
    """hil/config.py Axis.wire: trim, then invert, then clamp."""
    out = []
    for i, v in enumerate(servo):
        w = v + trims[i]
        w = 180.0 - w if inverted[i] else w
        out.append(min(AXES[i][7], max(AXES[i][6], w)))
    return out


# ── Kinematics (hil/kinematics.py: FK, tank check, planner) ───────────────────

def to_sim(servo):
    j = [0.0] * 5
    for i, a in enumerate(AXES):
        if a[1] is not None:
            j[a[1]] = servo[i] - a[2]
    return j


def from_sim(j, gripper):
    return [gripper if a[1] is None else a[2] + j[a[1]] for a in AXES]


def _rot(base, tilt, v):
    ct, st = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    x, y, z = v[0], ct * v[1] - st * v[2], st * v[1] + ct * v[2]
    cb, sb = math.cos(math.radians(base)), math.sin(math.radians(base))
    return (cb * x - sb * y, sb * x + cb * y, z)


def joint_points(a):
    def add(p, q):
        return (p[0] + q[0], p[1] + q[1], p[2] + q[2])
    j2 = _rot(a[0], 0.0, _D[0])
    j3 = add(j2, _rot(a[0], a[1], _D[1]))
    j4 = add(j3, _rot(a[0], a[1] + a[2], _D[2]))
    j5 = add(j4, _rot(a[0], a[1] + a[2] + a[3], _D[3]))
    return [(0.0, 0.0, 0.0), j2, j3, j4, j5]


def unsafe(a):
    """Elbow, end effector or wrist behind the base (y > 0) and below the tank top."""
    return any(p[1] > 1e-3 and p[2] < TANK_Z_MM for p in joint_points(a)[2:])


def path_unsafe(a, b, step=2.0):
    n = max(1, int(math.ceil(max(abs(y - x) for x, y in zip(a, b)) / step)))
    return any(unsafe([x + (y - x) * k / n for x, y in zip(a, b)]) for k in range(n + 1))


def plan(a, b):
    """Joint-space waypoints a -> b clear of the tank (straight, arm first, base first), or None."""
    if unsafe(b):
        return None
    if not path_unsafe(a, b):
        return [b]
    for via in ([a[0]] + list(b[1:]), [b[0]] + list(a[1:])):
        if not unsafe(via) and not path_unsafe(a, via) and not path_unsafe(via, b):
            return [via, b]
    return None


def leg_seconds(a, b):
    t = max(1.5 * abs(y - x) / (AXES[i][5] * SPEED_MARGIN) for i, (x, y) in enumerate(zip(a, b)))
    return max(t, MIN_LEG_S) if t > 1e-9 else 0.0


def load_sequences(path):
    """{bin: (move legs, drop legs)}; a leg is (servo pose, hold s). Bins without a sequence are left out."""
    with open(path) as f:
        data = json.load(f)
    seqs = {q["name"]: q["steps"] for q in data["sequences"]}
    out = {}
    for name, b in data["bins"].items():
        if not (b.get("sequence") and b.get("state_point") and b.get("release")):
            continue
        steps = seqs[b["sequence"]]
        names = [s["name"] for s in steps]
        at, rel = names.index(b["state_point"]), names.index(b["release"])
        legs = [([float(s["servo"][a[0]]) for a in AXES], float(s.get("hold", 0.5))) for s in steps]
        out[name] = (legs[:at + 1], legs[rel:])
    return out


# ── Bridge ────────────────────────────────────────────────────────────────────

class ArmBridge:
    """handle() each app command, tick() every TICK_S, on_line() each ESP32 line, on_tags() each
    tag frame. Replies are 0023 dicts; tick() returns (owner, reply) for motion_done / errors."""

    def __init__(self, write, sequences=None, config_path=None, clock=time.monotonic, log=print):
        self.write, self.sequences, self.config_path = write, sequences or {}, config_path
        self.clock, self.log = clock, log
        self.cmd = list(HOME)
        self.known = True             # False after an ESP32 BOOT: only HOME until home again
        self.streaming = False        # nothing is sent before the first move (the servos stay as they boot)
        self.trims, self.inverted = [0.0] * 6, [False] * 6
        self.legs = []                # [(goal, hold)] still to play after the current one
        self.leg = None               # (start, goal, t0, dur, hold)
        self.motion = None            # (owner, data, kind)
        self.pending_bin = None       # the bin MOVE_TO_BIN is going to
        self.at_bin = None            # bin whose state point the arm is at (MOVE_TO_BIN done, no move since)
        self.tag_seen = None          # when that bin's tag was last seen
        self.last_app = clock()
        self.boot, self.stat = None, None
        self._load_config()

    # -- app commands --

    def handle(self, data, owner=None):
        self.last_app = self.clock()
        cmd = data.get("cmd")
        h = getattr(self, "_cmd_" + str(cmd).lower(), None)
        if cmd in ("HEARTBEAT", None) or h is None:
            return []
        return h(data, owner)

    def _reply(self, event, data, **extra):
        r = {"event": event, "seq": data.get("seq")}
        r.update(extra)
        return r

    def _cmd_status(self, data, owner):
        return [self._reply("ack", data, at_home=self.known and self._at(HOME),
                            servo=self.cmd if self.known else None, esp32_boot=self.boot, esp32_stat=self.stat)]

    def _cmd_lock_drive(self, data, owner):
        return [self._reply("ack", data)]   # ponytail: wheels are a later task; only the 0023 ack

    _cmd_unlock_drive = _cmd_lock_drive

    def _cmd_pick(self, data, owner):
        return [self._reply("error", data, reason="not_implemented")]   # owner: picking is manual (gripper)

    def _cmd_config(self, data, owner):
        try:
            trims = [float(v) for v in data["trims"]]
            inverted = [v is True for v in data["inverted"]]
            assert len(trims) == len(inverted) == 5 and all(abs(t) <= 15 for t in trims)
        except (KeyError, TypeError, ValueError, AssertionError):
            return [self._reply("error", data, reason="invalid_config")]
        self.trims, self.inverted = [0.0] * 6, [False] * 6
        for k, field in enumerate(CONFIG_FIELDS):
            self.trims[field], self.inverted[field] = trims[k], inverted[k]
        self._save_config()
        self.log("[Arm] CONFIG trims={} inverted={}".format(self.trims, self.inverted))
        return [self._reply("ack", data)]

    def _cmd_hold(self, data, owner):
        self._freeze()
        return [self._reply("ack", data), self._reply("motion_done", data, servo=self.cmd)]

    def _cmd_stop(self, data, owner):
        self._freeze()
        return [self._reply("ack", data)]

    def _cmd_arm_pose(self, data, owner):
        path = data.get("path")
        try:
            path = [[float(v) for v in p] for p in path]
            assert path and all(len(p) == 6 and all(math.isfinite(v) for v in p) for p in path)
        except (TypeError, ValueError, AssertionError):
            return [self._reply("error", data, reason="invalid_path")]
        if not self.known:
            return [self._reply("error", data, reason="pose_unknown")]
        if self.motion is not None and self.motion[2] != "ARM_POSE":
            return [self._reply("error", data, reason="busy")]
        for p in path:
            if any(not (servo_range(i)[0] - 1e-6 <= v <= servo_range(i)[1] + 1e-6) for i, v in enumerate(p)):
                return [self._reply("error", data, reason="out_of_range")]
        at = to_sim(self.cmd)
        for p in path:
            if path_unsafe(at, to_sim(p)):
                return [self._reply("error", data, reason="tank")]
            at = to_sim(p)
        self._start(owner, data, "ARM_POSE", [(p, 0.0) for p in path])
        return [self._reply("ack", data)]

    def _cmd_home(self, data, owner):
        if self.motion is not None and self.motion[2] != "ARM_POSE":
            return [self._reply("error", data, reason="busy")]
        if not self.known:
            # After an ESP32 reset the arm's pose is unknown: home directly; the ESP32 limits the speed.
            self.cmd = list(HOME)
            self.known = True
            # ponytail: motion_done after the slowest full travel (Arm B 180 deg at 30 deg/s), not a measured arrival.
            self._start(owner, data, "HOME", [(list(HOME), UNKNOWN_HOME_S)])
            return [self._reply("ack", data)]
        way = plan(to_sim(self.cmd), to_sim(HOME))
        if way is None:
            return [self._reply("error", data, reason="tank")]
        self._start(owner, data, "HOME", [(from_sim(w, HOME[0]), 0.0) for w in way])
        return [self._reply("ack", data)]

    def _cmd_move_to_bin(self, data, owner):
        name = data.get("bin")
        if name not in BIN_TAG_IDS:
            return [self._reply("error", data, reason="invalid_bin")]
        if name not in self.sequences:
            return [self._reply("error", data, reason="no_sequence")]
        return self._play_steps(data, owner, "MOVE_TO_BIN", self.sequences[name][0], at_bin=name)

    def _cmd_drop(self, data, owner):
        if self.at_bin is None:
            return [self._reply("error", data, reason="not_at_bin")]
        fresh = self.tag_seen is not None and self.clock() - self.tag_seen <= BIN_TAG_FRESH_S
        if not fresh:
            self.log("[Arm] DROP refused: {} tag {} not seen".format(self.at_bin, BIN_TAG_IDS[self.at_bin]))
            return [self._reply("error", data, reason="bin_not_confirmed")]
        return self._play_steps(data, owner, "DROP", self.sequences[self.at_bin][1])

    def _play_steps(self, data, owner, kind, steps, at_bin=None):
        if not self.known:
            return [self._reply("error", data, reason="pose_unknown")]
        if self.motion is not None and self.motion[2] != "ARM_POSE":
            return [self._reply("error", data, reason="busy")]
        legs, at = [], to_sim(self.cmd)
        for goal, hold in steps:   # each step through the planner, as the sim plays a sequence
            way = plan(at, to_sim(goal))
            if way is None:
                return [self._reply("error", data, reason="tank")]
            legs += [(from_sim(w, goal[0]), 0.0) for w in way[:-1]] + [(goal, hold)]
            at = to_sim(goal)
        self._start(owner, data, kind, legs)
        self.pending_bin = at_bin
        return [self._reply("ack", data)]

    # -- motion --

    def _start(self, owner, data, kind, legs):
        self.at_bin = self.tag_seen = None
        self.pending_bin = None
        self.motion = (owner, data, kind)
        self.legs = list(legs)
        self.leg = None
        self.streaming = True
        self._next_leg(self.clock())

    def _next_leg(self, now):
        goal, hold = self.legs.pop(0)
        self.leg = (list(self.cmd), list(goal), now, leg_seconds(self.cmd, goal), hold)

    def _freeze(self):
        self.legs, self.leg, self.motion = [], None, None
        self.at_bin = self.tag_seen = None

    def _at(self, pose):
        return all(abs(a - b) < 0.05 for a, b in zip(self.cmd, pose))

    def tick(self):
        now = self.clock()
        out = []
        if self.leg is not None and now - self.last_app > WATCHDOG_S:
            owner, data, _ = self.motion
            self.log("[Arm] watchdog: no app message for {:.1f} s, arm holds".format(now - self.last_app))
            self._freeze()
            out.append((owner, self._reply("error", data, reason="watchdog")))
        if self.leg is not None:
            start, goal, t0, dur, hold = self.leg
            s = 1.0 if dur <= 0 else (now - t0) / dur
            if s < 1.0:
                s = s * s * (3.0 - 2.0 * s)
                self.cmd = [a + (b - a) * s for a, b in zip(start, goal)]
            else:
                self.cmd = list(goal)
                if now - t0 >= dur + hold:
                    if self.legs:
                        self._next_leg(now)
                    else:
                        owner, data, kind = self.motion
                        self.leg, self.motion = None, None
                        if kind == "MOVE_TO_BIN":
                            self.at_bin = self.pending_bin
                        out.append((owner, self._reply("motion_done", data, servo=self.cmd)))
        if self.streaming:
            self.write(make_frame(to_wire(self.cmd, self.trims, self.inverted)))
        return out

    # -- inputs --

    def on_tags(self, ids, now=None):
        """This frame's AprilTag ids (tag search on). Feeds the DROP guard."""
        if self.at_bin is not None and BIN_TAG_IDS[self.at_bin] in ids:
            self.tag_seen = self.clock() if now is None else now

    def on_line(self, line):
        line = line.strip()
        if line.startswith("BOOT"):
            # The ESP32 restarted: its servos are released until the next frame and the arm may have
            # dropped. Stop streaming; only HOME moves it again.
            self.log("[Arm] ESP32 " + line + ": arm pose unknown, HOME first")
            self.boot = line[5:]
            self._freeze()
            self.streaming = False
            self.known = False
        elif line.startswith("STAT"):
            self.stat = line[5:]

    def client_gone(self):
        """The app disconnected: the arm holds where it is (0023)."""
        self._freeze()

    # -- CONFIG persistence --

    def _load_config(self):
        if not self.config_path:
            return
        try:
            with open(self.config_path) as f:
                c = json.load(f)
            self.trims = [float(v) for v in c["trims"]]
            self.inverted = [v is True for v in c["inverted"]]
            assert len(self.trims) == len(self.inverted) == 6
        except (OSError, ValueError, KeyError, TypeError, AssertionError):
            self.trims, self.inverted = [0.0] * 6, [False] * 6

    def _save_config(self):
        if not self.config_path:
            return
        tmp = self.config_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"trims": self.trims, "inverted": self.inverted}, f)
        os.replace(tmp, self.config_path)
