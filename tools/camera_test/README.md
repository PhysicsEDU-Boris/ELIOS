# Camera test tools (decision 0183)

Run with `~/.venvs/fake-maixcam/bin/python` (websockets, opencv-contrib). Camera over USB: `ws://10.73.69.1:8765`.

- `record_test.sh OUT SECS`: phone test. Phone screen video + a screenshot every 5 s (adb), app logcat, and `camera_boxes.py` (the camera's tracked box, raw box, hands and `arm_tags` per detection frame).
- `tag_station.py D_MM IDS LABEL [SECS] [OUT]`: tags at a ruler distance. Firmware detection rate, OpenCV full-frame rate, tag width in px, live and corrected `dist_mm`.
- `calib_capture.py OUT [SECS]` / `calib_check.py OUT WAIT`: ChArUco intrinsics (board on a screen or printed). Writes `maixcam2_intrinsics.json`. Set the board's square size in `BOARD`.
- `make_pdf.py PNG_DIR OUT` / `make_board.py OUT`: vector print sheets (arm tags from robotic_hand_sim `paper/apriltags/*.png`, ChArUco board).
