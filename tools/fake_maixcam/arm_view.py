"""The fake MaixCAM2's arm window (`fake_maixcam.py --show`): robotic_hand_sim's own 3D view
(hil/scene.py `Scene`, the one arm-hil-toolkit-2.py shows), posed from the fake's arm.

Runs as its own process with the sim's Python (PyQt5 + pyvistaqt), so Qt never shares the fake's
asyncio loop. Reads one JSON line per pose on stdin: {"servo": [six servo degrees, F0..F5]}.
Closing the window only closes the view; the fake keeps serving.

    <sim>/.venv/bin/python arm_view.py --sim-path ~/GITHUB/ELIO/robotic_hand_sim
"""
import argparse
import json
import os
import sys
import threading

ap = argparse.ArgumentParser()
ap.add_argument("--sim-path", required=True)
args = ap.parse_args()
SIM = os.path.abspath(os.path.expanduser(args.sim_path))
sys.path.insert(0, SIM)
os.chdir(SIM)   # the sim loads its STL parts relative to its folder

from PyQt5.QtCore import QObject, pyqtSignal  # noqa: E402
from PyQt5.QtWidgets import QApplication, QMainWindow  # noqa: E402

from hil import app as hil_app  # noqa: E402

hil_app.setup()   # joint limits and the user's trims; read only, nothing is saved
from hil import config, kinematics  # noqa: E402
from hil.motion import Motion  # noqa: E402
from hil.scene import Scene  # noqa: E402


class Poses(QObject):
    got = pyqtSignal(list)


def read_stdin(sig):
    for line in sys.stdin:
        try:
            servo = [float(v) for v in json.loads(line)["servo"]]
        except (ValueError, KeyError, TypeError):
            continue
        if len(servo) == len(config.AXES):
            sig.got.emit(servo)
    os._exit(0)   # the fake stopped: close the window too


def main():
    qt = QApplication(sys.argv)
    win = QMainWindow()
    win.setWindowTitle("Fake MaixCAM2 · arm (robotic_hand_sim)")
    scene = Scene(win)
    win.setCentralWidget(scene.widget)
    win.resize(900, 700)
    grip = config.AXES.index(config.GRIPPER)

    def show(servo):
        sim = Motion.to_sim(servo)
        scene.pose(sim, kinematics.fk(sim), config.grip_percent(servo[grip]))

    poses = Poses()
    poses.got.connect(show)
    show([a.home for a in config.AXES])
    win.show()
    threading.Thread(target=read_stdin, args=(poses,), daemon=True).start()
    sys.exit(qt.exec_())


if __name__ == "__main__":
    main()
