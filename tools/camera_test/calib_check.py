import asyncio, base64, json, sys, time, cv2, numpy as np, websockets
S, WAIT = sys.argv[1], float(sys.argv[2])
det = cv2.aruco.CharucoDetector(cv2.aruco.CharucoBoard((7, 10), 19.5, 14.6, cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)))
async def m():
    time.sleep(WAIT)
    async with websockets.connect("ws://10.73.69.1:8765", max_size=None, open_timeout=5) as ws:
        await ws.send(json.dumps({"cmd": "start_stream"})); n = 0
        while n < 6:
            r = json.loads(await asyncio.wait_for(ws.recv(), 5))
            if "clean_image" not in r: continue
            jpg = base64.b64decode(r["clean_image"]); g = cv2.imdecode(np.frombuffer(jpg, np.uint8), 0)
            _, ci, _, mi = det.detectBoard(g)
            print("markers", 0 if mi is None else len(mi), "corners", 0 if ci is None else len(ci))
            open(f"{S}/calib_check{n}.jpg", "wb").write(jpg); n += 1
asyncio.run(m())
