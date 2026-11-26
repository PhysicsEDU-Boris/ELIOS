"""Golden values from robotic_hand_sim's per-joint speed profile (arm-hil-toolkit-2.py
ProfiledMotion, complete_profile) for the MaixCAM2 bridge and, later, the app (0240 section 1).

    python make_profile_golden.py ../../../robotic_hand_sim ../../test/fixtures/arm_profile_golden.json

Run it with the sim's Python (it needs PyQt5, pyvista and paramiko to import the app). Rerun when
the sim's profile maths, axis speeds or SPEED_MARGIN change, then run
python -m unittest test_arm_bridge in firmware/maixcam2.
"""
import importlib.util
import json
import os
import subprocess
import sys

import numpy as np

SIM, OUT = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
sys.path.insert(0, SIM)
os.chdir(SIM)
from hil import app, config  # noqa: E402

app.setup()
spec = importlib.util.spec_from_file_location("tk2", os.path.join(SIM, "arm-hil-toolkit-2.py"))
tk2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tk2)

clock = [1000.0]
tk2.time.monotonic = lambda: clock[0]   # ProfiledMotion reads the time; drive it by hand
home = [a.home for a in config.AXES]
PROFILES = {
    "default": {},
    "tank_base": {"Arm Base": {"vmax": 32.0, "accel": 0.72, "decel": 0.18}},   # the owner's tank sequences
    "mixed": {"Gripper": {"vmax": 50, "accel": 0.1, "decel": 0.6}, "Wrist Yaw": {"vmax": 10, "accel": 0.5, "decel": 0.5},
              "Arm B": {"vmax": 20, "accel": 0.9, "decel": 0.9}, "Arm A": {"vmax": 99, "accel": 0.01, "decel": 0.2},
              "Arm Base": {"vmax": 0.5, "accel": 0.33, "decel": 0.33}},   # every clamp: vmax, ramps, overlap
}
LEGS = [
    (home, [75.0, 90.0, 30.0, 120.0, 100.0, 90.0]),
    ([75.0, 90.0, 138.1, 131.22, 76.37, 167.01], [75.0, 90.0, 179.75, 75.93, 76.4, 243.0]),
    (home, [180.0, 90.0, 0.0, 180.0, 90.0, 92.0]),   # short: MIN_LEG_S
    (home, [179.0, 90.0, 0.0, 180.0, 90.0, 90.0]),
]
U = [0.0, 0.05, 0.2, 0.33, 0.5, 0.7, 0.9, 0.97, 1.0]

out = {"sim_commit": subprocess.check_output(["git", "-C", SIM, "rev-parse", "--short", "HEAD"], text=True).strip(),
       "source": "robotic_hand_sim arm-hil-toolkit-2.py ProfiledMotion / complete_profile (decision 0240 section 1)",
       "axes": [a.name for a in config.AXES], "profiles": {}, "legs": []}
for name, prof in PROFILES.items():
    out["profiles"][name] = {"input": prof, "clean": tk2.complete_profile(prof)}
    for a, b in LEGS:
        m = tk2.Motion.__new__(tk2.ProfiledMotion)
        tk2.Motion.__init__(m)
        m.cmd = np.array(a, float)
        m.set_profile(prof)
        m.go(b)
        dur, samples = m._dur, []
        for u in U:
            clock[0] = m._t0 + u * dur
            m._dur, m.goal = dur, np.array(b, float)   # tick() ends the leg once u >= 1
            m.tick()
            samples.append({"u": u, "cmd": [round(float(v), 6) for v in m.cmd]})
        out["legs"].append({"profile": name, "start": a, "goal": b, "seconds": round(dur, 6), "samples": samples})

with open(OUT, "w") as f:
    json.dump(out, f, indent=1)
print("wrote", len(out["legs"]), "legs to", OUT)
