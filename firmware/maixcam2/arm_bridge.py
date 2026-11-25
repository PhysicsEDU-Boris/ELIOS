"""MaixCAM2 -> ESP32 arm bridge (decision 0235). Plain Python, no Maix imports, so it runs
off the board in test_arm_bridge.py.

The app plans manual moves (0234) and sends ARM_POSE paths in servo degrees. This module checks
each path again (joint ranges and the tank, a last line of defence), plays it like
robotic_hand_sim arm-hil-toolkit-2.py ProfiledMotion (all joints start and arrive together; each
axis ramps up, cruises at its max speed and ramps down, 0240) and streams one frame per tick to the ESP32 running
slave_code/6-axis-esp32-twoway-tmc2208 in stream mode:

    "F0,F1,F2,F3,F4,F5,CC\\n"  Gripper, Wrist Yaw, Wrist Pitch, Arm B, Arm A, Base (wire degrees,
                              trim and invert applied), CC = CRC-8 poly 0x07 of the text before it.

It also plays the owner's bin sequences (bin_sequences.json, 0233) and guards DROP: only at the
bin's state point with that bin's AprilTag seen in the last BIN_TAG_FRESH_S.

AprilTag centring (0240 section 5, the sim's _align_done / _slipped): the MaixCAM2 is the hand
camera (rides on Arm A, turns with Arm Base). When a sequence step saved with a tag arrives, Arm
Base alone steers the live tag back onto its saved vertical line, then the step's hold starts. The
correction found is kept in base_corr (the open-loop base slipped) and added to every later step
until HOME or an ESP32 reset.

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
# 0240 lag guard: a bin sequence or HOME carrying on when the app is only late (video lag, Wi-Fi) is
# better than an arm frozen over the tank with the item. Silent > WATCHDOG_S: the sequence PAUSES where
# it is (same pose streamed); app back within SEQ_GRACE_S: it carries on from the same point; longer:
# the old watchdog (freeze, error). Below the app's own 8 s stale-link timeout. Manual moves keep 1 s.
SEQ_GRACE_S = 5.0
SEQ_KINDS = ("MOVE_TO_BIN", "DROP", "HOME")
ESP32_SILENT_S = 3.0          # the ESP32 sends STAT every second: nothing for this long = not on the cable
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
BASE = 5                      # Arm Base in AXES

# Tag centring, robotic_hand_sim arm-hil-toolkit-2.py fce805d (0240 section 5).
CAM_HFOV_DEG = 83.0           # ponytail: the sim's placeholder; measure the MaixCAM2's real FOV
AZ_SIGN = -1.0                # tag left of its line -> Arm Base plus
TAG_MAX_AGE_S = 1.0           # detection at most this old
TAG_SETTLE_S = 0.4            # ...and taken this long after the arm stopped
ALIGN_TOL_DEG = 1.0
ALIGN_GAIN = 0.8
ALIGN_MAX_STEP_DEG = 10.0
ALIGN_MAX_MOVES = 8
ALIGN_WAIT_S = 4.0            # no usable tag this long -> carry on uncentred
ALIGN_RETRIGGER_DEG = 2.0     # a centred step drifting this far while it holds is centred again
ALIGN_MAX_CORR_DEG = 30.0
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


# ── Per-joint speed profile (0240 section 1, robotic_hand_sim arm-hil-toolkit-2.py) ──
# {axis name: {"vmax": deg/s, "accel": 0..1, "decel": 0..1}}: speed ramps up over the first `accel`
# share of a leg, cruises at `vmax`, ramps down over the last `decel` share. The same dict is a
# sequence step's "motion". Only the defaults are used for now; CONFIG and steps come later (0240).
FRAC_MIN, FRAC_MAX, FRAC_DEFAULT = 0.05, 0.95, 0.33


def vmax_cap(i):
    """Fastest allowed peak speed of axis i: firmware limit x SPEED_MARGIN."""
    return math.floor(AXES[i][5] * SPEED_MARGIN * 10) / 10


def clean_axis(i, vmax, accel, decel):
    vmax, accel, decel = float(vmax), float(accel), float(decel)
    if not all(math.isfinite(v) for v in (vmax, accel, decel)):
        raise ValueError("not a number")
    vmax = min(max(vmax, 1.0), vmax_cap(i))
    accel = min(max(accel, FRAC_MIN), FRAC_MAX)
    decel = min(max(decel, FRAC_MIN), FRAC_MAX)
    if accel + decel > 1.0:                # the ramps cannot overlap
        k = 1.0 / (accel + decel)
        accel, decel = accel * k, decel * k
    return {"vmax": round(vmax, 1), "accel": round(accel, 3), "decel": round(decel, 3)}


def complete_profile(d=None):
    """Any stored / partial / bad profile -> a full, clamped one (missing or bad axes get defaults)."""
    out = {}
    for i, a in enumerate(AXES):
        g = d.get(a[0]) if isinstance(d, dict) else None
        try:
            out[a[0]] = clean_axis(i, g["vmax"], g["accel"], g["decel"])
        except (TypeError, KeyError, ValueError):
            out[a[0]] = clean_axis(i, vmax_cap(i), FRAC_DEFAULT, FRAC_DEFAULT)
    return out


DEFAULT_PROFILE = complete_profile()


def _axes(profile):
    p = complete_profile(profile)
    return [(p[a[0]]["vmax"], p[a[0]]["accel"], p[a[0]]["decel"]) for a in AXES]


def leg_seconds(a, b, profile=None):
    """Leg time: the slowest axis at its own peak speed (peak = mean / (1 - (accel + decel) / 2))."""
    t = max(abs(y - x) / (1.0 - (ta + td) / 2.0) / vmax
            for (x, y, (vmax, ta, td)) in zip(a, b, _axes(profile)))
    return max(t, MIN_LEG_S) if t > 1e-9 else 0.0


def ramp(u, ta, td):
    """Share of the leg done at time share u (0..1) for one axis: trapezoid speed, ramps ta and td."""
    vp = 1.0 / (1.0 - (ta + td) / 2.0)
    if u < ta:
        return vp * u * u / (2.0 * ta)
    if u > 1.0 - td:
        return 1.0 - vp * (1.0 - u) ** 2 / (2.0 * td)
    return vp * (ta / 2.0 + u - ta)


def h_angle(u, w):
    """Horizontal angle (deg) of image column u off the vertical centre line, + = right (pinhole)."""
    return math.degrees(math.atan2(u - w / 2.0, (w / 2.0) / math.tan(math.radians(CAM_HFOV_DEG) / 2.0)))


def saved_offset_deg(norm):
    """A step's saved tag offset_norm as an angle with today's CAM_HFOV_DEG (the sim's saved_offset_deg)."""
    return math.degrees(math.atan(norm * math.tan(math.radians(CAM_HFOV_DEG) / 2.0)))


def _step_tag(s):
    """(tag id, offset_norm) a step was saved with, or None."""
    try:
        t = s["tag"]["tags"][0]
        return int(t["id"]), float(t["offset_norm"])
    except (KeyError, IndexError, TypeError, ValueError):
        return None


def load_sequences(path):
    """{bin: (move legs, drop legs)}; a leg is (servo pose, hold s, speed profile, tag). The profile is
    the step's saved "motion", completed; a step without one plays at the defaults, as in the sim (0240).
    tag is (id, offset_norm) for steps saved with one, else None. Bins without a sequence are left out."""
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
        legs = [([float(s["servo"][a[0]]) for a in AXES], float(s.get("hold", 0.5)),
                 complete_profile(s.get("motion")), _step_tag(s)) for s in steps]
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
        self.legs = []                # [(goal, hold[, profile])] still to play after the current one
        self.leg = None               # (start, goal, t0, dur, hold, per-axis (vmax, accel, decel))
        self.profile = DEFAULT_PROFILE  # speed profile for the next legs (0240)
        self.motion = None            # (owner, data, kind)
        self.pending_bin = None       # the bin MOVE_TO_BIN is going to
        self.at_bin = None            # bin whose state point the arm is at (MOVE_TO_BIN done, no move since)
        self.tag_seen = None          # when that bin's tag was last seen
        self.tag_frame = None         # (time, {id: cx px}, frame width) of the last tag search
        self.base_corr = 0.0          # Arm Base slip correction (servo deg) found by tag centring
        self.align = None             # centring state of the tagged step the arm is at
        self.align_log = []           # what centring did in this motion, for motion_done
        self.paused_at = None         # lag guard: when a sequence paused for a quiet app
        self.paused_s = 0.0           # how long this motion has been paused in all
        self.last_app = clock()
        self.started = clock()
        self.boot, self.stat = None, None
        self.esp32_at = None          # when the ESP32 last sent a line (BOOT, STAT, anything)
        self.silent_logged = False
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
                            servo=self.cmd if self.known else None, esp32_boot=self.boot, esp32_stat=self.stat,
                            profile=self.profile, base_corr=round(self.base_corr, 2), esp32_age_s=self.esp32_age())]

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
        # 0240: clamped per axis; missing or bad axes get the defaults, never a rejected CONFIG.
        # The leg already playing keeps its profile; the next leg uses this one.
        self.profile = complete_profile(data.get("profile"))
        self._save_config()
        self.log("[Arm] CONFIG trims={} inverted={} profile={}".format(self.trims, self.inverted, self.profile))
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
        self.base_corr = 0.0   # home is the base's reference again (the sim's Zero slip)
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
        lo, hi = servo_range(BASE)
        for goal, hold, prof, tag in steps:   # each step through the planner, as the sim plays a sequence
            goal = list(goal)
            goal[BASE] = min(hi, max(lo, goal[BASE] + self.base_corr))   # every later step keeps the slip correction
            way = plan(at, to_sim(goal))
            if way is None:
                return [self._reply("error", data, reason="tank")]
            # the planner's extra legs (arm first / base first) move at the step's profile too
            legs += [(from_sim(w, goal[0]), 0.0, prof, None) for w in way[:-1]] + [(goal, hold, prof, tag)]
            at = to_sim(goal)
        self._start(owner, data, kind, legs)
        self.pending_bin = at_bin
        return [self._reply("ack", data)]

    # -- motion --

    def _start(self, owner, data, kind, legs):
        self.at_bin = self.tag_seen = None
        self.pending_bin = None
        self.motion = (owner, data, kind)
        self.align_log = []
        self.paused_at, self.paused_s = None, 0.0
        self.legs = list(legs)
        self.leg = None
        self.streaming = True
        self._next_leg(self.clock())

    def _next_leg(self, now):
        goal, hold, *rest = self.legs.pop(0)   # a sequence step's own profile, else the live one
        prof = rest[0] if rest else self.profile
        tag = rest[1] if len(rest) > 1 else None
        self.align = None if tag is None else {"tag": tag, "moves": 0, "deadline": None, "done": False}
        self._leg_to(goal, hold, prof, now)

    def _leg_to(self, goal, hold, prof, now):
        # (start, goal, t0, duration, hold, per-axis ramps, profile, hold starts at; None until it arrives)
        self.leg = (list(self.cmd), list(goal), now, leg_seconds(self.cmd, goal, prof), hold, _axes(prof), prof, None)

    def _freeze(self):
        self.legs, self.leg, self.motion, self.align = [], None, None, None
        self.paused_at = None
        self.at_bin = self.tag_seen = None

    # -- tag centring (0240 section 5) --

    def _tag_err(self, tag, arrived, now):
        """Live horizontal error (deg) of the step's tag, AZ_SIGN applied; None when not usable yet."""
        f = self.tag_frame
        if f is None or f[0] < arrived + TAG_SETTLE_S or now - f[0] > TAG_MAX_AGE_S or tag[0] not in f[1]:
            return None
        return AZ_SIGN * (h_angle(f[1][tag[0]], f[2]) - saved_offset_deg(tag[1]))

    def _shift(self, delta, now):
        """Turn the step being held (and every later leg) by delta on Arm Base; False if it can't go."""
        _, goal, _, _, hold, _, prof, _ = self.leg
        lo, hi = servo_range(BASE)
        moved = [list(goal)] + [list(l[0]) for l in self.legs]
        for p in moved:
            p[BASE] += delta
            if not lo <= p[BASE] <= hi:
                return False
        at = to_sim(self.cmd)
        for p in moved:   # base turns over the tank are re-checked like any move
            if path_unsafe(at, to_sim(p)):
                return False
            at = to_sim(p)
        self.base_corr += delta
        self.legs = [(p,) + tuple(l[1:]) for p, l in zip(moved[1:], self.legs)]
        self._leg_to(moved[0], hold, prof, now)
        return True

    def _align_end(self, a, note, err=None):
        a["done"] = True
        self.align_log.append({"tag": a["tag"][0], "note": note, "err_deg": None if err is None else round(err, 2),
                               "base_corr": round(self.base_corr, 2)})
        self.log("[Arm] tag {} {} (err {}), base slip correction {:+.1f}".format(
            a["tag"][0], note, "-" if err is None else "{:+.1f}".format(err), self.base_corr))
        return True

    def _aligned(self, arrived, now):
        """One centring tick for a tagged step that has arrived. True when its hold may run."""
        a = self.align
        if a["deadline"] is None:
            a["deadline"] = now + ALIGN_WAIT_S
        err = self._tag_err(a["tag"], arrived, now)
        if a["done"]:
            if a.get("centred") and err is not None and abs(err) > ALIGN_RETRIGGER_DEG:
                self.log("[Arm] tag {} drifted {:+.1f}, centring again".format(a["tag"][0], err))
                a.update(done=False, centred=False, moves=0, deadline=now + ALIGN_WAIT_S)
                return False
            return True
        if err is None:
            return self._align_end(a, "no_tag") if now > a["deadline"] else False
        if abs(err) <= ALIGN_TOL_DEG:
            a["centred"] = True
            return self._align_end(a, "centred", err)
        if a["moves"] and abs(err) > abs(a["last_err"]) + ALIGN_TOL_DEG:
            self._shift(-a["last_step"], now)   # the turn pushed the tag further off: undo it (AZ_SIGN / FOV wrong)
            return self._align_end(a, "diverged", err)
        if a["moves"] >= ALIGN_MAX_MOVES:
            return self._align_end(a, "max_moves", err)
        step = max(-ALIGN_MAX_STEP_DEG, min(ALIGN_MAX_STEP_DEG, ALIGN_GAIN * err))
        new = max(-ALIGN_MAX_CORR_DEG, min(ALIGN_MAX_CORR_DEG, self.base_corr + step))
        if abs(new - self.base_corr) < 0.05:
            return self._align_end(a, "corr_limit", err)
        old = self.base_corr
        if not self._shift(new - old, now):
            return self._align_end(a, "blocked", err)
        a.update(moves=a["moves"] + 1, last_err=err, last_step=new - old, deadline=now + ALIGN_WAIT_S)
        return False

    def _at(self, pose):
        return all(abs(a - b) < 0.05 for a, b in zip(self.cmd, pose))

    def tick(self):
        now = self.clock()
        out = []
        silent = now - self.last_app
        if self.leg is not None and silent > WATCHDOG_S:
            owner, data, kind = self.motion
            if kind in SEQ_KINDS and silent <= SEQ_GRACE_S:
                if self.paused_at is None:
                    self.paused_at = now
                    self.log("[Arm] app quiet {:.1f} s: {} paused where it is".format(silent, kind))
            else:
                self.log("[Arm] watchdog: no app message for {:.1f} s, arm holds".format(silent))
                self._freeze()
                out.append((owner, self._reply("error", data, reason="watchdog")))
        elif self.paused_at is not None:
            # the app is back: carry on from the same point (the leg's clock skips the pause)
            gap = now - self.paused_at
            start, goal, t0, dur, hold, axes, prof, hold_from = self.leg
            self.leg = (start, goal, t0 + gap, dur, hold, axes, prof, None if hold_from is None else hold_from + gap)
            if self.align is not None and self.align.get("deadline") is not None:
                self.align["deadline"] += gap
            self.paused_at, self.paused_s = None, self.paused_s + gap
            self.log("[Arm] app back after {:.1f} s: {} carries on".format(gap, self.motion[2]))
        if self.leg is not None and self.paused_at is None:
            start, goal, t0, dur, hold, axes, _, hold_from = self.leg
            u = 1.0 if dur <= 0 else (now - t0) / dur
            if u < 1.0:
                self.cmd = [a + (b - a) * ramp(u, ta, td) for a, b, (_, ta, td) in zip(start, goal, axes)]
            else:
                self.cmd = list(goal)
                arrived = t0 + dur
                if self.align is not None and not self._aligned(arrived, now):
                    hold_from = None   # centring (or re-centring): the hold waits
                elif hold_from is None:
                    hold_from = arrived if self.align is None else now
                if self.leg[1] == goal:   # still the same leg (a correction starts a new one)
                    self.leg = self.leg[:7] + (hold_from,)
                if hold_from is not None and now - hold_from >= hold:
                    if self.legs:
                        self._next_leg(now)
                    else:
                        owner, data, kind = self.motion
                        self.leg, self.motion = None, None
                        if kind == "MOVE_TO_BIN":
                            self.at_bin = self.pending_bin
                        extra = {"base_corr": round(self.base_corr, 2), "align": self.align_log} if self.align_log else {}
                        if self.paused_s:
                            extra["paused_s"] = round(self.paused_s, 2)
                        out.append((owner, self._reply("motion_done", data, servo=self.cmd, **extra)))
        if self.streaming:
            self.write(make_frame(to_wire(self.cmd, self.trims, self.inverted)))
            age = self.esp32_age()
            if (age is None or age > ESP32_SILENT_S) and not self.silent_logged and now - self.started > ESP32_SILENT_S:
                self.silent_logged = True
                self.log("[Arm] ESP32 silent on its UART ({}): arm frames go out, nothing comes back. "
                         "Check ESP32 TX0/RX0 to the MaixCAM2, GND, power, and that no PC holds its USB.".format(
                             "never heard" if age is None else "{:.0f} s".format(age)))
        return out

    def esp32_age(self):
        """Seconds since the ESP32's last line, or None if it never sent one."""
        return None if self.esp32_at is None else round(self.clock() - self.esp32_at, 1)

    # -- inputs --

    @property
    def wants_tags(self):
        """main.py searches for tags while a bin sequence plays: centring and the DROP guard need them."""
        return self.motion is not None and self.motion[2] in ("MOVE_TO_BIN", "DROP") or self.at_bin is not None

    def on_tags(self, tags, width=640, now=None):
        """One tag search: main.py arm_tags dicts (id, cx) on a [width]-px frame, or bare ids. An empty
        list counts too (the tag is out of view). Feeds the DROP guard and the centring."""
        now = self.clock() if now is None else now
        self.tag_frame = (now, {t["id"]: t["cx"] for t in tags if isinstance(t, dict)}, float(width))
        ids = [t["id"] if isinstance(t, dict) else t for t in tags]
        if self.at_bin is not None and BIN_TAG_IDS[self.at_bin] in ids:
            self.tag_seen = now

    def on_line(self, line):
        line = line.strip()
        if line:
            self.esp32_at, self.silent_logged = self.clock(), False
        if line.startswith("BOOT"):
            # The ESP32 restarted: its servos are released until the next frame and the arm may have
            # dropped. Stop streaming; only HOME moves it again.
            self.log("[Arm] ESP32 " + line + ": arm pose unknown, HOME first")
            self.boot = line[5:]
            self._freeze()
            self.streaming = False
            self.known = False
            self.base_corr = 0.0
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
            self.profile = complete_profile(c.get("profile"))   # files from before 0240 have none
        except (OSError, ValueError, KeyError, TypeError, AssertionError):
            self.trims, self.inverted = [0.0] * 6, [False] * 6

    def _save_config(self):
        if not self.config_path:
            return
        tmp = self.config_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"trims": self.trims, "inverted": self.inverted, "profile": self.profile}, f)
        os.replace(tmp, self.config_path)
