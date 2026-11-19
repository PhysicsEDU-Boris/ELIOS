"""Golden values from robotic_hand_sim's hil/kinematics.py for the app's Dart port (0234).

    python make_golden.py ../../../robotic_hand_sim ../../test/fixtures/arm_kinematics_golden.json

Rerun when the sim's arm geometry, limits or tank change, then run
flutter test test/robot/arm_kinematics_test.dart.
"""
import json
import subprocess
import sys

import numpy as np

SIM, OUT = sys.argv[1], sys.argv[2]
sys.path.insert(0, SIM)
from hil import config, kinematics as k  # noqa: E402
from hil.sim import ase  # noqa: E402

config.apply_sim_limits(ase.JOINT_LIMITS)
LIM = config.joint_limits()
rng = np.random.default_rng(234)


def pose():
    return np.array([rng.uniform(lo, hi) for lo, hi in LIM])


def r(a):
    return [round(float(v), 6) for v in a]


poses = [pose() for _ in range(60)] + [np.zeros(5)]
fk = [{"angles": r(a), "points": [r(p) for p in k.joint_points(a)], "unsafe": k.unsafe(a) is not None}
      for a in poses]
solve = []
for _ in range(60):
    cur, tgt = pose(), k.fk(pose()) if rng.random() < 0.7 else rng.uniform(-400, 400, 3)
    a, why = k.solve(tgt, cur, LIM)
    solve.append({"target": r(tgt), "current": r(cur), "angles": None if a is None else r(a), "reason": why})
plan = []
for _ in range(60):
    a, b = pose(), pose()
    way, why = k.plan(a, b)
    plan.append({"from": r(a), "to": r(b), "path": None if way is None else [r(w) for w in way], "reason": why})
sim_commit = subprocess.run(["git", "-C", SIM, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
json.dump({"sim_commit": sim_commit, "limits": [list(l) for l in LIM], "tank_z_mm": config.TANK_Z_MM,
           "fk": fk, "solve": solve, "plan": plan}, open(OUT, "w"), indent=1)
print("wrote", OUT, "from sim", sim_commit, "unsafe poses:", sum(f["unsafe"] for f in fk),
      "refused plans:", sum(p["path"] is None for p in plan), "2-leg plans:", sum(p["path"] is not None and len(p["path"]) == 2 for p in plan),
      "solved:", sum(s["angles"] is not None for s in solve))
