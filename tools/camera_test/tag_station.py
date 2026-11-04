"""One tag station (readability + size): tag id 0 flat to the lens at a ruler distance D (mm, lens to tag face).
Usage: tag_station.py D_mm tag_id label [seconds] [outdir]
fx = side_px * D / S, from OpenCV sub-pixel corners on the full 640x480 clean_image."""
import asyncio, base64, json, sys, time
import cv2, numpy as np, websockets

D, LABEL = float(sys.argv[1]), sys.argv[3]
IDS = [int(x) for x in sys.argv[2].split(",")]
S = {0: 18.52, 1: 6.17}
FW_S = S  # firmware 26049b58 uses the true sizes
FX = 362.0
SECS = float(sys.argv[4]) if len(sys.argv) > 4 else 8
OUT = sys.argv[5] if len(sys.argv) > 5 else "."
NOMINAL_FX = 362.0  # firmware CAMERA_FX (0183)
p = cv2.aruco.DetectorParameters()
p.cornerRefinementMethod = cv2.aruco.CORNER_REFINE_SUBPIX
det = cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_APRILTAG_36h11), p)


async def main():
    sides, centres, fw = ({i: [] for i in IDS} for _ in range(3))
    fw_hits = {i: 0 for i in IDS}
    det_frames = clean_n = 0
    async with websockets.connect("ws://10.73.69.1:8765", max_size=None, open_timeout=5) as ws:
        await ws.send(json.dumps({"cmd": "start_stream"}))
        await ws.send(json.dumps({"cmd": "arm_tags", "on": True}))
        t0, saved = time.time(), False
        try:
            while time.time() - t0 < SECS:
                m = json.loads(await asyncio.wait_for(ws.recv(), 5))
                if m.get("detection_frame_id") == m.get("frame_id"):
                    det_frames += 1
                    for TID in IDS:
                        mine = [t for t in m.get("arm_tags") or [] if t.get("id") == TID]
                        fw_hits[TID] += bool(mine)
                        fw[TID] += [t["dist_mm"] for t in mine if "dist_mm" in t]
                if "clean_image" not in m:
                    continue
                clean_n += 1
                jpg = base64.b64decode(m["clean_image"])
                img = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_GRAYSCALE)
                if clean_n == 2:
                    open(f"{OUT}/ids{sys.argv[2].replace(',', '')}_{int(D)}mm_{LABEL}.jpg", "wb").write(jpg)
                c, ids, _ = det.detectMarkers(img)
                for cc, i in zip(c, [] if ids is None else ids.flatten()):
                    if i in IDS:
                        q = cc.reshape(4, 2)
                        sides[i].append(np.mean([np.linalg.norm(q[k] - q[k - 1]) for k in range(4)]))
                        centres[i].append(q.mean(0))
        finally:
            await ws.send(json.dumps({"cmd": "arm_tags", "on": False}))
    for TID in IDS:
        f, sd = fw[TID], sides[TID]
        fw_side = [NOMINAL_FX * FW_S[TID] / d for d in f]
        row = dict(id=TID, D=D, light=LABEL, fw_rate=fw_hits[TID] / max(det_frames, 1), fw_n=det_frames,
                   cv_rate=len(sd) / max(clean_n, 1), cv_n=clean_n,
                   fw_side=float(np.median(fw_side)) if f else None, cv_side=float(np.median(sd)) if sd else None,
                   fw_side_spread=float(np.ptp(fw_side)) if f else None,
                   dist_live=float(np.median(f)) if f else None,
                   dist_fixed=float(FX * S[TID] / np.median(fw_side)) if f else None)
        print(json.dumps(row))
        open(f"{OUT}/tag_rows_169.jsonl", "a").write(json.dumps(row) + "\n")


asyncio.run(main())
