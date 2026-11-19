"""Log the camera's tracked box (sent and raw) on every detection frame. Usage: camera_boxes.py out.jsonl seconds"""
import asyncio, json, sys, time
import websockets

OUT, SECS = sys.argv[1], float(sys.argv[2])


async def main():
    t0 = time.time()
    with open(OUT, "w") as f:
        async with websockets.connect("ws://10.73.69.1:8765", max_size=None, open_timeout=5) as ws:
            await ws.send(json.dumps({"cmd": "start_stream"}))
            while time.time() - t0 < SECS:
                m = json.loads(await asyncio.wait_for(ws.recv(), 10))
                if m.get("detection_frame_id") != m.get("frame_id") or "frame_id" not in m:
                    if "event" in m:
                        f.write(json.dumps({"t": round(time.time() - t0, 2), "event": m}) + "\n")
                    continue
                dets = m.get("detections") or []
                f.write(json.dumps({"t": round(time.time() - t0, 2), "frame": m["frame_id"],
                                    "track": [d for d in dets if "track_id" in d],
                                    "hands": [[d["x"], d["y"], d["w"], d["h"]] for d in dets if d.get("label") == "Human_Hand"],
                                    "tags": m.get("arm_tags")}) + "\n")
                f.flush()


asyncio.run(main())
