"""Capture ChArUco views from the MaixCAM2 stream (clean_image, 640x480) and solve its intrinsics.
Usage: calib_capture.py outdir [seconds]   (frames accumulate in outdir/views across runs)"""
import asyncio, base64, glob, json, os, sys, time
import cv2, numpy as np, websockets

OUT = sys.argv[1]
SECS = float(sys.argv[2]) if len(sys.argv) > 2 else 90
VIEWS = os.path.join(OUT, "views")
os.makedirs(VIEWS, exist_ok=True)
BOARD = cv2.aruco.CharucoBoard((7, 10), 19.5, 14.6, cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50))  # on the laptop screen
DET = cv2.aruco.CharucoDetector(BOARD)
MIN_CORNERS = 12


def corners(gray):
    cc, ci, _, _ = DET.detectBoard(gray)
    return (cc, ci) if ci is not None and len(ci) >= MIN_CORNERS else (None, None)


async def capture():
    kept = [np.load(f) for f in sorted(glob.glob(f"{VIEWS}/*.npy"))]  # centroid+size of earlier views
    async with websockets.connect("ws://10.73.69.1:8765", max_size=None, open_timeout=5) as ws:
        await ws.send(json.dumps({"cmd": "start_stream"}))
        t0, last = time.time(), 0
        while time.time() - t0 < SECS:
            m = json.loads(await asyncio.wait_for(ws.recv(), 5))
            if "clean_image" not in m or time.time() - last < 0.8:
                continue
            jpg = base64.b64decode(m["clean_image"])
            gray = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_GRAYSCALE)
            cc, ci = corners(gray)
            if cc is None:
                continue
            p = cc.reshape(-1, 2)
            sig = np.array([*p.mean(0), np.ptp(p[:, 0]), np.ptp(p[:, 1])])
            if any(np.abs(sig - k).max() < 30 for k in kept):   # too like a view we have
                continue
            n = len(glob.glob(f"{VIEWS}/*.jpg"))
            open(f"{VIEWS}/v{n:03d}.jpg", "wb").write(jpg)
            np.save(f"{VIEWS}/v{n:03d}.npy", sig)
            kept.append(sig)
            last = time.time()
            print(f"view {n}: {len(ci)} corners at ({sig[0]:.0f},{sig[1]:.0f}) size {sig[2]:.0f}x{sig[3]:.0f}", flush=True)


def solve():
    obj, img, names = [], [], []
    for f in sorted(glob.glob(f"{VIEWS}/*.jpg")):
        gray = cv2.imread(f, cv2.IMREAD_GRAYSCALE)
        cc, ci = corners(gray)
        if cc is None:
            continue
        o, i = BOARD.matchImagePoints(cc, ci)
        obj.append(o); img.append(i); names.append(os.path.basename(f))
    size = (gray.shape[1], gray.shape[0])  # 640x360 since 0183
    rms, K, dist, rv, tv = cv2.calibrateCamera(obj, img, size, None, None)
    per = []
    for o, i, r, t in zip(obj, img, rv, tv):
        pr, _ = cv2.projectPoints(o, r, t, K, dist)
        per.append(float(np.sqrt(np.mean(np.sum((pr - i) ** 2, axis=2)))))
    fx, fy, cx, cy = K[0, 0], K[1, 1], K[0, 2], K[1, 2]
    fov = lambda f, n: float(np.degrees(2 * np.arctan(n / 2 / f)))
    allp = np.concatenate([i.reshape(-1, 2) for i in img])
    cover = np.histogram2d(allp[:, 1], allp[:, 0], bins=3, range=[[0, size[1]], [0, size[0]]])[0].astype(int)
    model = dict(camera="MaixCAM2 stream (clean_image, JPEG)", image_size=list(size), views=len(obj),
                 points=int(len(allp)), rms_px=float(rms), fx=float(fx), fy=float(fy), cx=float(cx), cy=float(cy),
                 dist_k1_k2_p1_p2_k3=[float(x) for x in dist.ravel()[:5]],
                 fov_h_deg=fov(fx, size[0]), fov_v_deg=fov(fy, size[1]),
                 fov_d_deg=float(np.degrees(2 * np.arctan(np.hypot(size[0] / 2 / fx, size[1] / 2 / fy)))),
                 coverage_3x3_points=cover.tolist(), per_view_rms_px=dict(zip(names, per)),
                 board="ChArUco 7x10, 24 mm squares, 18 mm DICT_4X4_50 markers")
    json.dump(model, open(os.path.join(OUT, "maixcam2_intrinsics.json"), "w"), indent=2)
    print(json.dumps({k: v for k, v in model.items() if k != "per_view_rms_px"}, indent=1))
    print("worst views:", sorted(zip(per, names))[-3:])


if SECS > 0:
    asyncio.run(capture())
solve()
