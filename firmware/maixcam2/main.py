# ELIOS MaixCAM2 dashboard / WebSocket server / tracker, hands, arm tags (MaixPy v4).
# Derived from the owner's Maixcam.txt reference; see README.md for its hash.
# Nothing is drawn on streamed frames (decision 0182): image is the clean frame.
# WiFi (AP or STA) is set up by the OS; only the "Wi-Fi setup" QR screen changes it.

from maix import image, display, camera, touchscreen, nn, app, network, time as mtime
import json, asyncio, websockets, base64, math, hashlib, os, subprocess, threading, textwrap

# vision_protocol 1 is kept, so older apps still pair clean_image (decision 0182).
FIRMWARE_VERSION = "m2c-arm-v1"
with open(__file__, "rb") as source:
    FIRMWARE_SHA256 = hashlib.sha256(source.read()).hexdigest()
print("[Firmware]", FIRMWARE_VERSION, FIRMWARE_SHA256)

# ── Hardware ──────────────────────────────────────────────────────────────────
disp  = display.Display()
W, H  = disp.width(), disp.height()
ts    = touchscreen.TouchScreen()

# ── Network status (display-only) ────────────────────────────────────────────
# The OS picks AP or STA (/boot/wifi.ap, /boot/wifi.sta); in STA the IP comes
# from the phone hotspot's DHCP and changes, so the cards read it live.
# Nothing here configures WiFi.
WS_PORT = 8765
NET_REFRESH_MS = 3000
_wifi = None
_net = {"at": None, "ssid": "--", "ip": "--"}

def net_cards(now_ms):
    """(ssid_text, ip_text) for the dashboard, re-read every NET_REFRESH_MS."""
    global _wifi
    if _net["at"] is not None and now_ms - _net["at"] < NET_REFRESH_MS:
        return _net["ssid"], _net["ip"]
    _net["at"] = now_ms
    try:
        if _wifi is None:
            _wifi = network.wifi.Wifi()
        ip = _wifi.get_ip()
        ssid = "{} ({})".format(_wifi.get_ssid(), "AP" if _wifi.is_ap_mode() else "STA") if ip else "--"
    except Exception as e:
        print("[Net] status read failed:", e)
        ip, ssid = "", "--"
    _net["ssid"], _net["ip"] = ssid, ip or "--"
    return _net["ssid"], _net["ip"]

# ── Wi-Fi setup by QR (decision 0178) ────────────────────────────────────────
# The user taps "Wi-Fi setup" and shows a standard WIFI: QR (ELIOS app, or
# Android's hotspot "Share" QR). After a tap on Join, /boot/wifi.* is rewritten
# the way /opt/scripts/wifi.sh reads it. No IP within JOIN_TIMEOUT_S puts the
# old files back, so a wrong password never strands the robot.
BOOT_DIR = "/boot"
# Credentials first, markers last: wifi.sta is what switches the mode.
WIFI_FILES = ("wifi.ssid", "wifi.pass", "wifi.ap", "wifi.sta")
JOIN_TIMEOUT_S = 45
SETUP_SCAN_MS = 90000
# Phone screens glare: with no QR for LUMA_STEP_MS the scan darkens the picture a
# step (luma only; manual exposure/gain crashed this camera once, 3 Nov).
LUMA_STEP_MS = 1500
LUMA_DROPS = (0, 2, 4)
BANNER_MS = 15000

def parse_wifi_qr(text):
    """(ssid, password) from a WIFI:T:WPA;S:...;P:...;; QR. ValueError says why not."""
    if not text.startswith("WIFI:"):
        raise ValueError("Not a Wi-Fi QR")
    fields, key, buf, s, i = {}, None, "", text[5:], 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            buf += s[i + 1]
            i += 2
            continue
        if ch == ":" and key is None:
            key, buf = buf.upper(), ""
        elif ch == ";":
            if key is not None:
                fields[key] = buf
            key, buf = None, ""
        else:
            buf += ch
        i += 1
    ssid, pw = fields.get("S", ""), fields.get("P", "")
    if fields.get("T", "WPA").upper() in ("NOPASS", "WEP") or not pw:
        raise ValueError("Needs a WPA password (open/WEP not supported)")
    if not 1 <= len(ssid.encode("utf-8")) <= 32 or any(ord(c) < 32 for c in ssid):
        raise ValueError("Wi-Fi name must be 1-32 bytes")
    if not 8 <= len(pw) <= 63 or any(not 32 <= ord(c) < 127 for c in pw):
        raise ValueError("Password must be 8-63 plain characters")
    return ssid, pw

def _read_wifi_files(boot):
    files = {}
    for n in WIFI_FILES:
        p = os.path.join(boot, n)
        if os.path.exists(p):
            with open(p, "rb") as f:
                files[n] = f.read()
    return files

def _write_wifi_files(boot, files):
    """Make /boot/wifi.{ssid,pass,ap,sta} exactly `files` (missing name = deleted)."""
    for n in WIFI_FILES:
        p = os.path.join(boot, n)
        if n in files:
            with open(p + ".tmp", "wb") as f:
                f.write(files[n])
            os.replace(p + ".tmp", p)
        elif os.path.exists(p):
            os.remove(p)
    os.sync()

def _run(args):
    try:
        subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
    except Exception as e:
        print("[WiFi]", args[0], "failed:", e)

def _restart_wifi(run):
    run(["systemctl", "stop", "wifi.service"])
    # wifi.sh stop leaves hostapd and the wlan0 DHCP server up, and its start
    # gives up while the driver is still loaded: clear all three first.
    run(["pkill", "hostapd"])
    run(["pkill", "-f", "udhcpd -S /etc/udhcpd.wlan0.conf"])
    run(["ip", "addr", "flush", "dev", "wlan0"])
    run(["rmmod", "aic8800_fdrv"])
    run(["rmmod", "aic8800_bsp"])
    run(["systemctl", "start", "--no-block", "wifi.service"])
    run(["systemctl", "restart", "udhcpc.service"])

def _wait_for_ip(want_ap, timeout_s):
    """The wlan0 IP once it is up in the wanted mode, or "" after timeout_s."""
    end = mtime.ticks_ms() + timeout_s * 1000
    while mtime.ticks_ms() < end:
        mtime.sleep_ms(1000)
        try:
            w = network.wifi.Wifi()
            ip = w.get_ip()
            if ip and w.is_ap_mode() == want_ap and (want_ap or w.is_connected()):
                return ip
        except Exception:
            pass
    return ""

def apply_wifi(ssid, password, boot=BOOT_DIR, run=None, wait=None):
    """Join ssid; if that gives no IP, restore the old files. (ok, ip or message)."""
    run, wait = run or _run, wait or _wait_for_ip
    if os.path.exists(os.path.join(boot, "wpa_supplicant.conf")):
        return False, "/boot/wpa_supplicant.conf overrides this; remove it first"
    old = _read_wifi_files(boot)
    try:
        _write_wifi_files(boot, {"wifi.ssid": ssid.encode("utf-8"),
                                 "wifi.pass": password.encode("ascii"), "wifi.sta": b""})
        _restart_wifi(run)
        ip = wait(False, JOIN_TIMEOUT_S)
        if ip:
            return True, ip
        why = "no connection"
    except Exception as e:
        why = str(e)
    print("[WiFi] join failed ({}), restoring the previous Wi-Fi".format(why))
    _write_wifi_files(boot, old)
    _restart_wifi(run)
    back = wait("wifi.ap" in old and "wifi.sta" not in old, JOIN_TIMEOUT_S)
    return False, "Couldn't join {}. Back on the old Wi-Fi{}".format(
        ssid[:20], " ({})".format(back) if back else "")

# ── Vision (decision 0182) ───────────────────────────────────────────────────
# No waste model: the app's LOCK asks Gemini for the item and its box, sends
# track_start, and MixFormerV2 follows that box. Hands keep the arm pause (0027);
# AprilTags on the arm go out as arm_tags (0022). Nothing is drawn on the frame.
# elios_waste_seg.mud stays on the camera, unused.
TRACKER_PATH = "/root/models/mixformer_v2.mud"
# HandLandmarks loads hand_detector.mud (its detect_model); landmarks run only per hand found.
HAND_PATH    = "/root/models/hand_landmarks.mud"

# Tracker, hands and tags run every DET_EVERY_N_FRAMES pushed frames and are
# held in between. MixFormerV2 costs ~63 ms a call: on every frame the stream
# fell to 8 fps (robot test, 4 Nov), every 2nd frame keeps it near 11.
DET_EVERY_N_FRAMES = 2
# Smaller live video, the AI's picture unchanged (owner, 4 Nov: "better fps without hurting the AI").
# The preview is JPEG quality 60 (-37 % bytes against 80 on a desk frame, hardly visible); the AI
# picture (clean_image) stays at 80, what to_format(FMT_JPEG) gave before, but goes out only on a
# detection frame at most every CLEAN_EVERY_MS (it was a second copy on every frame with a box).
# The app uses a clean picture up to 1 s old for LOCK and refine.
PREVIEW_QUALITY = 60
CLEAN_QUALITY   = 80
CLEAN_EVERY_MS  = 700
TRACK_TH       = 0.5   # MixFormerV2 score below this: the box is not sent that frame
# MixFormerV2 searches 4.5x the box around its last good position; after this many low-score
# calls it searches the whole frame once (MaixCDK maix_nn_mixformer_v2.hpp). The default 60 was
# never reached (a fast lift lost the item for good, phone test 4 Nov); 5 is ~1 s.
TRACK_REFIND_AFTER = 5
TRACK_MIN_SIDE = 8
# A box more than 2x larger or smaller in area than the last good one (~0.2 s earlier) is a
# tracker jump, not the item: dropped. Driving closer grows it ~1.3x a call; after a flip the
# whole-frame re-find took a hand at 2.8x (robot test 4 Nov). Against the LOCK box instead,
# driving from 50 to 20 cm after LOCK would have dropped the item.
TRACK_MAX_GROWTH = 2
HAND_CONF_TH   = 0.7
HAND_LABEL     = "Human_Hand"   # r1_orchestrator / motion_gate pause on this label

# Black-square edge of each arm tag, ruler-measured on the print (owner, 4 Nov): id 0 arm5
# bottom, id 1 arm3 rear (a 10 mm print, so 6.17 mm black). Bin tags (0233): id 2 anorganik,
# 3 organik, 4 B3, printed 30 mm like id 0 (docs/print/apriltags-bins-id2-id3-id4-A4.pdf).
TAG_SIZES_MM = {0: 18.52, 1: 6.17, 2: 18.52, 3: 18.52, 4: 18.52}
# fx in px at STREAM_RESOLUTION 640x360 from the ChArUco board solve (27 views, 0.29 px RMS,
# docs/test-results/0183/maixcam2_intrinsics_640x360.json): 81.1 x 51.4 deg like the sim.
# ponytail: pinhole only (no tilt, no distortion; the corner is off by ~6 px), so arm_tags keep
# dist_rough: true until PnP with the full model is worth it.
CAMERA_FX = 374.0

def _load(ctor, path):
    try:
        m = ctor(model=path)
        print("[AI] loaded", path)
        return m, ""
    except Exception as e:
        print("[AI] load FAILED:", path, "-", e)
        return None, str(e)

tracker, tracker_error = _load(lambda model: nn.MixFormerV2(model=model, lost_find_interval=TRACK_REFIND_AFTER), TRACKER_PATH)
hands, hands_error     = _load(nn.HandLandmarks, HAND_PATH)
model_loaded     = tracker is not None and hands is not None
model_load_error = tracker_error or hands_error

# The app's LOCK box. pending = (x, y, w, h) waiting for the next frame to init on.
# Tracking runs until track_stop or the next track_start: a lost item is searched for, not dropped.
track = {"pending": None, "on": False, "id": 0, "label": "", "area": 1, "lock_area": 1, "box": None, "still": [], "odd": False}

def parse_track_box(box, img_w, img_h):
    """[x, y, w, h] top-left in stream pixels -> ints clipped to the frame. ValueError says why not."""
    if not isinstance(box, (list, tuple)) or len(box) != 4:
        raise ValueError("box must be [x, y, w, h]")
    if not all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in box):
        raise ValueError("box values must be numbers")
    x, y, w, h = box
    x0, y0 = max(0, int(x)), max(0, int(y))
    x1, y1 = min(img_w, int(x + w)), min(img_h, int(y + h))
    if x1 - x0 < TRACK_MIN_SIDE or y1 - y0 < TRACK_MIN_SIDE:
        raise ValueError("box is too small or outside the frame")
    return x0, y0, x1 - x0, y1 - y0

def box_det(label, x, y, w, h, score):
    """Wire format: centre x/y (websocket_service.dart reads 'x'/'y' as the centre)."""
    return {"label": label, "score": round(float(score), 3),
            "x": int(x + w / 2), "y": int(y + h / 2), "w": int(w), "h": int(h)}

# Hold a still item's box (owner, 4 Nov: "the lock needs a fixed box, not a jiggling one", and
# "not bouncing when the item is flipped"). Tracker noise on a still pack: centre x +-0.5 px,
# y +-4.5 px, height +-7 px of 124 (robot test 4 Nov); a flipped item gives larger, odd boxes.
# The held box is sent unchanged unless the item really moved: two calls in a row beyond
# HOLD_SHIFT of the centre or HOLD_SIZE of a side (one odd box is ignored). Smaller size
# changes, such as a flip in place, go through the settle: after SETTLE_CALLS still calls
# (~1 s) the held box moves once to their median, if that is more than SETTLE of the box away.
HOLD_SHIFT   = 0.10   # centre moved this fraction of the box's larger side
HOLD_SIZE    = 0.30   # or a side changed by this fraction
SETTLE_CALLS = 5
SETTLE       = 0.06
GROW_MIN     = 1.3    # area change either way that counts as "grew" or "shrank" (see hold())

def moved(held, new):
    hx, hy, hw, hh = held
    nx, ny, nw, nh = new
    shift = math.hypot(nx + nw / 2 - hx - hw / 2, ny + nh / 2 - hy - hh / 2) / max(hw, hh)
    return shift >= HOLD_SHIFT or abs(nw / hw - 1) >= HOLD_SIZE or abs(nh / hh - 1) >= HOLD_SIZE

def median_box(boxes):
    return tuple(sorted(v)[len(v) // 2] for v in zip(*boxes))

def hold(t, new):
    """The box to send for tracker box new (x, y, w, h); t keeps "box" (held), "still", "odd", "grow".
    A box that grew or shrank by more than GROW_MIN in area is taken only once SETTLE_CALLS such
    boxes in a row agree (within the hold band of their median): hand + item boxes kept changing size
    (244, 271, 249, 274, 402 px tall, log 4 Nov), and a card slid over the bottle shrank the box step
    by step to a patch of floor (phone video 4 Nov). A real item, or one the robot drove to or from
    and stopped at, keeps one size."""
    if t["box"] is None:
        t.update(box=new, still=[], odd=False, grow=[], size=new[2] * new[3])
        return new
    if moved(t["box"], new):
        # Size changes count against the last confirmed size (LOCK, a settle, a confirmed change), not
        # the last box: in steps of under GROW_MIN a box walked up to hand size, or down to a patch.
        area, size = new[2] * new[3], t.get("size", t["box"][2] * t["box"][3])
        if area > GROW_MIN * size or area * GROW_MIN < size:
            t["grow"] = (t.get("grow", []) + [new])[-SETTLE_CALLS:]
            mid = median_box(t["grow"])
            if len(t["grow"]) == SETTLE_CALLS and not any(moved(mid, b) for b in t["grow"]):
                t.update(box=mid, still=[], odd=False, grow=[], size=mid[2] * mid[3])
            return t["box"]
        t["grow"] = []
        if t["odd"]:  # the second in a row: a real move
            t.update(box=new, still=[], odd=False)
        else:
            t["odd"] = True
        return t["box"]
    t.update(odd=False, grow=[])
    t["still"].append(new)
    if len(t["still"]) >= SETTLE_CALLS:
        mid = median_box(t["still"])
        t["still"] = []
        if max(abs(a - b) for a, b in zip(mid, t["box"])) > SETTLE * max(t["box"][2:]):
            t.update(box=mid, size=mid[2] * mid[3])
    return t["box"]

# While a detected hand touches the item, the tracker box grows over hand and item together
# (owner video 15:21: 2-3x the pack). A box that grew by more than HAND_GROWTH in area while a hand
# overlaps it is not taken: the held box stays until the hand lets go.
HAND_GROWTH = 1.3
# The hand detector finds a hand over the pack on only about every other detection frame (log,
# 4 Nov), and the box ballooned exactly on the misses: a hand counts for HAND_MEMORY_MS.
HAND_MEMORY_MS = 1000

def recent_hands(seen, now, hands):
    """seen [(ms, box)] with this frame's hand boxes added and those older than HAND_MEMORY_MS dropped."""
    return [(t, b) for t, b in seen if now - t < HAND_MEMORY_MS] + [(now, b) for b in hands]

def overlaps(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

def size_ok(area, ref):
    return 1 / TRACK_MAX_GROWTH <= area / ref <= TRACK_MAX_GROWTH

def track_frame(frame, hand_boxes=()):
    """The tracked box for this frame as a detection, or None (nothing locked, or lost).
    hand_boxes: this frame's hands, top-left (x, y, w, h)."""
    if track["pending"] is not None:
        x, y, w, h = track["pending"]
        track.update(pending=None, on=True, area=w * h, lock_area=w * h, box=(x, y, w, h), still=[], odd=False,
                     grow=[], size=w * h)
        tracker.init(frame, x, y, w, h)
        return dict(box_det(track["label"], x, y, w, h, 1.0), track_id=track["id"])
    if not track["on"]:
        return None
    o = tracker.track(frame, TRACK_TH)
    new, area = (o.x, o.y, o.w, o.h), o.w * o.h
    # Against the last good box (driving closer grows it ~1.3x a call) or the LOCK box: after a
    # hand-sized box the real item, less than half that size, was refused for 15 s (video 15:21).
    if o.score < TRACK_TH or not (size_ok(area, track["area"]) or size_ok(area, track["lock_area"])):
        return None
    held = track["box"]
    if held is not None and area > HAND_GROWTH * held[2] * held[3] and any(overlaps(new, h) for h in hand_boxes):
        return dict(box_det(track["label"], *held, o.score), track_id=track["id"], raw=[int(v) for v in new], hand=True)
    track["area"] = area
    # raw: the tracker's own box this call (top-left x, y, w, h), for logs; the app ignores it.
    return dict(box_det(track["label"], *hold(track, new), o.score), track_id=track["id"], raw=[int(v) for v in new])

def hand_dets(frame):
    """Hands as Human_Hand, boxed by their 21 landmarks: obj x/y/w/h is the model's
    large square crop (300-770 px on a 640x480 frame, robot test 4 Nov)."""
    out = []
    for o in hands.detect(frame, conf_th=HAND_CONF_TH):
        pts = o.points[8:8 + 63]  # after the 4 crop corners: x, y, z per landmark
        xs = [min(max(v, 0), frame.width()) for v in pts[0::3]]
        ys = [min(max(v, 0), frame.height()) for v in pts[1::3]]
        if xs and max(xs) > min(xs) and max(ys) > min(ys):
            out.append(box_det(HAND_LABEL, min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys), o.score))
    return out

def arm_tags(tags, scale=1):
    """0022 arm_tags from find_apriltags results (on a 1/scale image): arm ids 0, 1 and bin ids 2-4 (0233), rough distance."""
    out = []
    for t in tags:
        size = TAG_SIZES_MM.get(t.id())
        if size is None:
            continue
        c = t.corners()
        side = scale * sum(math.hypot(c[i][0] - c[i-1][0], c[i][1] - c[i-1][1]) for i in range(4)) / 4
        tag = {"id": t.id(), "cx": t.cx() * scale, "cy": t.cy() * scale}
        if side > 1:
            tag.update(dist_mm=round(CAMERA_FX * size / side, 1), dist_rough=True)
        out.append(tag)
    return out

# find_apriltags on a 640x480 frame kills the process (no Python error) on this
# MaixPy (robot test, 4 Nov); 320x240 works in about 40 ms. At 640x360 it searches 320x180:
# id 1 (6.17 mm) needs ~10 px there, so about 110 mm at most (0183).
TAG_SCALE = 2

# AprilTags only around a grip (owner, 4 Nov): the app sends {"cmd":"arm_tags","on":true} while R1
# positions, picks and sorts, and for a manual PICK UP; off otherwise (the search costs ~40 ms).
tags = {"on": False}

def find_arm_tags(frame):
    small = frame.resize(frame.width() // TAG_SCALE, frame.height() // TAG_SCALE)
    return arm_tags(small.find_apriltags(families=image.ApriltagFamilies.TAG36H11), TAG_SCALE)

# ── Arm bridge (decision 0235): app ARM_POSE / HOME / MOVE_TO_BIN / DROP -> ESP32 on UART2 ──
# ESP32: robotic_hand_sim slave_code/6-axis-esp32-twoway-tmc2208 in stream mode, 9600 baud,
# MaixCAM2 B0 TX / B1 RX (owner, 19 Nov). Wheels (UART1) are a later task.
import arm_bridge
ARM_UART = "/dev/ttyS2"
ARM_BAUD = 9600
ARM_CONFIG = "/root/elios_arm_config.json"
ARM_CMDS = {"STATUS", "LOCK_DRIVE", "UNLOCK_DRIVE", "HOME", "PICK", "MOVE_TO_BIN", "DROP", "HOLD", "STOP",
            "ARM_POSE", "CONFIG", "HEARTBEAT"}
arm_lock = threading.Lock()
arm_uart = None
try:
    from maix import uart
    arm_uart = uart.UART(ARM_UART, ARM_BAUD)
    print("[Arm] UART", ARM_UART, ARM_BAUD, "open")
except Exception as e:
    print("[Arm] UART unavailable, arm commands answer but nothing reaches the ESP32:", e)

def _arm_write(text):
    if arm_uart is not None:
        arm_uart.write_str(text)

try:
    _arm_sequences = arm_bridge.load_sequences(os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin_sequences.json"))
except Exception as e:
    print("[Arm] bin_sequences.json not loaded, MOVE_TO_BIN answers no_sequence:", e)
    _arm_sequences = {}
arm = arm_bridge.ArmBridge(_arm_write, sequences=_arm_sequences, config_path=ARM_CONFIG)

def _arm_send(owner, reply):
    if owner is not None and _ws_loop is not None:
        asyncio.run_coroutine_threadsafe(owner.send(json.dumps(reply)), _ws_loop)

def arm_loop():
    """20 Hz: advance the arm, one frame to the ESP32, read its BOOT / STAT lines."""
    buf = b""
    while not app.need_exit():
        t0 = mtime.ticks_ms()
        try:
            with arm_lock:
                out = arm.tick()
                if arm_uart is not None:
                    chunk = arm_uart.read(-1, 0)
                    if chunk:
                        buf += chunk
                        *lines, buf = buf.split(b"\n")
                        for line in lines:
                            arm.on_line(line.decode("ascii", "replace"))
            for owner, reply in out:
                _arm_send(owner, reply)
        except Exception as e:
            print("[Arm] loop error:", e)
        mtime.sleep_ms(max(1, int(arm_bridge.TICK_S * 1000) - (mtime.ticks_ms() - t0)))

threading.Thread(target=arm_loop, daemon=True).start()

model_name = "MixFormerV2 + hands" if model_loaded else "Not loaded"

# ── Colours ───────────────────────────────────────────────────────────────────
def rgb(r,g,b): return image.Color.from_rgb(r,g,b)
C_BG     = rgb(243,245,242)
C_CARD   = rgb(249,250,248)
C_GREEN  = rgb(  0,105, 76)
C_RED    = rgb(186, 26, 26)
C_WHITE  = rgb(255,255,255)
C_MUTED  = rgb( 90,100, 95)
C_DIV    = rgb(210,215,210)
C_BLUE   = rgb( 30,100,200)

def blend(fr,fg,fb,br,bg,bb,a):
    return rgb(int(fr*a+br*(1-a)),int(fg*a+bg*(1-a)),int(fb*a+bb*(1-a)))

# ── Primitives ────────────────────────────────────────────────────────────────
def rrect(c,x,y,w,h,r,col,fill=True,th=1):
    r=min(r,w//2,h//2)
    if fill:
        c.draw_rect(x+r,y,w-2*r,h,color=col,thickness=-1)
        c.draw_rect(x,y+r,w,h-2*r,color=col,thickness=-1)
        for px,py in[(x+r,y+r),(x+w-r-1,y+r),(x+r,y+h-r-1),(x+w-r-1,y+h-r-1)]:
            c.draw_circle(px,py,r,color=col,thickness=-1)
    else:
        c.draw_rect(x,y,w,h,color=col,thickness=th)

def pill(c,x,y,w,h,col,fill=True):
    rrect(c,x,y,w,h,h//2,col,fill)

def txt(c,x,y,s,col,sc=0.75):
    c.draw_string(x,y,str(s),color=col,scale=sc)

def hit(tx,ty,x,y,w,h):
    return x<=tx<=x+w and y<=ty<=y+h

# ── Layout ────────────────────────────────────────────────────────────────────
PAD   = 20
INNER = W - PAD*2
CW    = (INNER-12)//2
CH    = 60
CY1   = 44
CY2   = CY1 + CH + 6
CY3   = CY2 + CH + 6
AH    = 40
CY4   = CY3 + AH + 10

# Force-disconnect is the only interactive control left on the dashboard now
# that there's no "Connect to ELIOS" button (AP + WS server both start
# automatically at boot). Shown/hit-tested only when ws_status is not Idle.
FORCE_DC_Y = CY4 + AH + 20
FORCE_DC_H = 40

# Bottom row: "Wi-Fi setup" on the dashboard; Cancel/Join/OK on the setup screens.
BTN_H     = 44
BTN_Y     = H - PAD - BTN_H
SETUP_BTN = (PAD, BTN_Y, INNER, BTN_H)
LEFT_BTN  = (PAD, BTN_Y, CW, BTN_H)
RIGHT_BTN = (PAD+CW+12, BTN_Y, CW, BTN_H)

# ── App state ─────────────────────────────────────────────────────────────────
# Screen off while a phone is connected (owner, 4 Nov): saves battery and leaves the CPU to the
# stream. A tap wakes it for SCREEN_WAKE_MS; that tap only wakes it, it presses no button.
SCREEN_WAKE_MS = 15000
screen = {"on": True, "level": 50, "awake_until": 0, "swallow": False}
try:
    screen["level"] = disp.get_backlight() or 50
except Exception as e:
    print("[Screen] backlight read failed:", e)

tick             = 0
force_dc_pressed = False
last_pressed     = False

# WebSocket / stream state
ws_status     = "Idle"        # Idle | Serving | Client connected
ws_streaming  = False         # True when flutter sent start_stream
ws_clients    = set()         # connected websocket clients
stream_cam    = None          # camera used for streaming
_ws_loop      = None          # asyncio event loop for WS server
_ws_server    = None
cam_lock      = threading.Lock()  # stream_cam: WS pusher thread vs the QR scan

# Wi-Fi setup: stage None (dashboard) | scan | confirm | joining
setup = {"stage": None, "until": 0, "ssid": "", "pw": "", "msg": "", "t0": 0,
         "luma0": None, "lidx": 0, "lat": 0, "banner": "", "banner_col": None, "banner_until": 0}

# ── Stream resolution — FIXED, no runtime switching ──────────────────────────
# 640x360 (16:9) is the sensor's full wide view, 83 x 53 deg like the lens spec and
# robotic_hand_sim's camera; 640x480 is a 67 deg crop and 1280x720 a 53 deg crop
# (measured 4 Nov, decision 0183). The trackers take any size, so nothing is resized before them.
STREAM_RESOLUTION = (640, 360)

def _open_stream_camera(width, height):
    """
    Attempt to open the stream camera at (width, height) — normally always
    STREAM_RESOLUTION, since resolution is fixed. Falls back to the display's
    native (W, H) only if the fixed resolution genuinely fails to open (e.g.
    the sensor rejects 1080p on this unit) — this is a hardware-failure
    safety net, not a feature. The fallback's actual (w, h) is only used
    locally to tag outgoing frames; it doesn't need to be stored globally.
    Returns (camera_obj, actual_width, actual_height).
    """
    try:
        print("[WS] Opening stream camera at {}x{}".format(width, height))
        c = camera.Camera(width, height)
        c.skip_frames(3)
        print("[WS] Stream camera ready at {}x{}".format(width, height))
        return c, width, height
    except Exception as e:
        print("[WS] Failed to open camera at {}x{}: {} — falling back to native display size".format(width, height, e))
        c = camera.Camera(W, H)
        c.skip_frames(3)
        print("[WS] Fell back to native display size {}x{}".format(W, H))
        return c, W, H

# ── Force-disconnect (device-side recovery lever) ────────────────────────────
def force_disconnect_all_clients():
    """
    Close every currently-open WebSocket client from the main (touch) thread.
    The WS server runs on its own asyncio event loop in a background thread,
    so we schedule the actual close()s onto that loop via
    run_coroutine_threadsafe rather than touching the sockets directly.
    Each client's own ws_handler `finally` block (already existing) does the
    real state cleanup (ws_clients.discard, ws_status reset) once its close
    completes — this function only asks them to close, it doesn't duplicate
    that cleanup logic.
    """
    global ws_status, ws_streaming
    if _ws_loop is None or not ws_clients:
        ws_status = "Idle" if _ws_loop is None else "Serving"
        ws_streaming = False
        return

    async def _close_all():
        for c in list(ws_clients):
            try:
                await c.close()
            except Exception:
                pass

    try:
        asyncio.run_coroutine_threadsafe(_close_all(), _ws_loop)
        print("[WS] Force-disconnect requested for {} client(s)".format(len(ws_clients)))
    except Exception as e:
        print("[WS] Force-disconnect schedule failed:", e)

# ── WebSocket server ──────────────────────────────────────────────────────────
# websockets v14+ (Python 3.13) handler takes only (websocket), no path arg
async def ws_handler(websocket):
    # Declare ALL globals used in this function to avoid Python's
    # "local variable referenced before assignment" crash.
    global ws_status, ws_streaming, ws_clients, stream_cam

    ws_clients.add(websocket)
    ws_status = "Client connected"
    print("[WS] Client connected:", websocket.remote_address)

    # Tell Flutter websocket_service.dart: status=Connected
    try:
        await websocket.send(json.dumps({"status": "Connected"}))
    except Exception:
        pass

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                cmd  = data.get("cmd", "")

                if cmd in ARM_CMDS:
                    with arm_lock:
                        replies = arm.handle(data, websocket)
                    for reply in replies:
                        await websocket.send(json.dumps(reply))
                    if cmd != "HEARTBEAT":
                        print("[Arm]", cmd, data.get("seq"), [r["event"] + "/" + str(r.get("reason", "")) for r in replies])

                elif cmd == "ping":
                    await websocket.send(json.dumps({"event": "pong", "firmware_version": FIRMWARE_VERSION, "firmware_sha256": FIRMWARE_SHA256}))
                    print("[WS] pong sent")

                elif cmd == "start_stream":
                    ws_streaming = True
                    print("[WS] start_stream — streaming ON")

                elif cmd == "stop_stream":
                    ws_streaming = False
                    print("[WS] stop_stream — streaming OFF")

                elif cmd == "disconnect":
                    # Orderly client-initiated disconnect. Ack, then close
                    # from our side — the `finally` block below handles the
                    # actual ws_clients/ws_status cleanup once the loop ends.
                    print("[WS] Client requested orderly disconnect")
                    try:
                        await websocket.send(json.dumps({"event": "disconnect_ack"}))
                    except Exception:
                        pass
                    await websocket.close()
                    break

                elif cmd == "motor":
                    left  = data.get("left", 0)
                    right = data.get("right", 0)
                    print("[WS] motor left={} right={}".format(left, right))

                elif cmd == "servo":
                    part = data.get("part", "")
                    val  = data.get("val", 0)
                    print("[WS] servo part={} val={}".format(part, val))

                elif cmd == "track_start":
                    # The app's LOCK box (Gemini). The next frame inits MixFormerV2 on it.
                    try:
                        if tracker is None:
                            raise ValueError("tracker not loaded: " + tracker_error)
                        box = parse_track_box(data.get("box"), *STREAM_RESOLUTION)
                    except ValueError as e:
                        await websocket.send(json.dumps({"event": "track_error", "error": str(e)}))
                    else:
                        track.update(pending=box, on=False, id=track["id"] + 1,
                                     label=str(data.get("label") or "Item")[:40])
                        await websocket.send(json.dumps({"event": "track_started", "track_id": track["id"]}))
                        print("[Track] start", track["id"], track["label"], box)

                elif cmd == "arm_tags":
                    tags["on"] = data.get("on") is True
                    print("[Tags]", "on" if tags["on"] else "off")

                elif cmd == "track_stop":
                    track.update(pending=None, on=False)
                    await websocket.send(json.dumps({"event": "track_stopped", "track_id": track["id"]}))
                    print("[Track] stop", track["id"])

                elif cmd == "set_resolution":
                    # Resolution is fixed at STREAM_RESOLUTION. Ignored
                    # (not an error) so an older client build doesn't break.
                    print("[WS] set_resolution received but ignored — resolution is fixed at {}x{}".format(*STREAM_RESOLUTION))

            except Exception as pe:
                print("[WS] parse error:", pe)

    except Exception as ce:
        print("[WS] connection closed:", ce)
    finally:
        ws_clients.discard(websocket)
        # The server keeps listening after a client leaves: WAITING, not OFFLINE.
        ws_status = "Client connected" if ws_clients else "Serving"
        if not ws_clients:
            ws_streaming = False
            with arm_lock:
                arm.client_gone()
        print("[WS] clients remaining:", len(ws_clients))

async def ws_frame_pusher():
    """Stream clean frames: detections = the tracked box + hands, plus arm_tags.

    Nothing is drawn. image is the preview JPEG (PREVIEW_QUALITY). Every
    DET_EVERY_N_FRAMES-th frame is a detection frame (detection_frame_id ==
    frame_id, fresh box, hands and tags, clean_detections); at most every
    CLEAN_EVERY_MS one of them also carries clean_image, the same frame at
    CLEAN_QUALITY for the AI, so older apps still pair it.
    """
    global stream_cam
    cam_w, cam_h = STREAM_RESOLUTION
    det_frame_count = 0
    frame_id = 0
    last_tracked, last_hands, last_tags = None, [], []
    hands_seen = []
    stats = dict(t0=mtime.ticks_ms(), n=0, track=0, det=0, send=0)
    clean_at = None

    while True:
        if ws_streaming and ws_clients and setup["stage"] != "scan":
            try:
                with cam_lock:
                    if stream_cam is None:
                        stream_cam, cam_w, cam_h = _open_stream_camera(*STREAM_RESOLUTION)
                    frame = stream_cam.read()
                frame_id += 1
                detection_frame_id = None
                t0 = t1 = mtime.ticks_ms()

                det_frame_count += 1
                if det_frame_count >= DET_EVERY_N_FRAMES:
                    det_frame_count = 0
                    try:
                        last_hands = hand_dets(frame) if hands is not None else []
                        last_tags = find_arm_tags(frame) if tags["on"] else []
                        if last_tags:
                            with arm_lock:
                                arm.on_tags([t["id"] for t in last_tags])
                        detection_frame_id = frame_id
                    except Exception as de:
                        print("[AI] detect error:", de)
                    t1 = mtime.ticks_ms()
                    last_tracked = None
                    if tracker is not None:
                        try:
                            hands_seen = recent_hands(hands_seen, t1, [(d["x"] - d["w"] / 2, d["y"] - d["h"] / 2, d["w"], d["h"])
                                                                       for d in last_hands])
                            last_tracked = track_frame(frame, [b for _, b in hands_seen])
                        except Exception as te:
                            print("[Track] error, tracking stopped:", te)
                            track.update(on=False, pending=None)
                t2 = mtime.ticks_ms()

                if not (track["on"] or track["pending"]):
                    last_tracked = None  # track_stop shows at once, not at the next detection frame
                dets = ([last_tracked] if last_tracked else []) + last_hands
                b64 = base64.b64encode(frame.to_jpeg(quality=PREVIEW_QUALITY).to_bytes()).decode()
                message = {
                    "vision_protocol": 1,
                    "firmware_sha256": FIRMWARE_SHA256,
                    "frame_id": frame_id,
                    "detection_frame_id": detection_frame_id,
                    "image":      b64,
                    "img_w":      cam_w,
                    "img_h":      cam_h,
                    "detections": dets,
                    "arm_tags":   last_tags,
                }
                if detection_frame_id == frame_id:
                    message["clean_detections"] = dets
                    if clean_at is None or t2 - clean_at >= CLEAN_EVERY_MS:
                        clean_at = t2
                        message["clean_image"] = base64.b64encode(
                            frame.to_jpeg(quality=CLEAN_QUALITY).to_bytes()).decode()
                payload = json.dumps(message)

                dead = set()
                for client in ws_clients.copy():
                    try:
                        await client.send(payload)
                    except Exception:
                        dead.add(client)
                for d in dead:
                    ws_clients.discard(d)

                # One timing line every 5 s (decision 0180's "step zero").
                t3 = mtime.ticks_ms()
                stats["n"] += 1
                stats["det"] += t1 - t0     # hands + tags
                stats["track"] += t2 - t1   # tracker
                stats["send"] += t3 - t2
                if t3 - stats["t0"] >= 5000:
                    n = stats["n"]
                    print("[FPS] {:.1f} fps | ms/frame track {:.0f}, hands+tags {:.0f}, jpeg+send {:.0f}".format(
                        n * 1000 / (t3 - stats["t0"]), stats["track"] / n, stats["det"] / n, stats["send"] / n))
                    stats.update(t0=t3, n=0, track=0, det=0, send=0)

            except Exception as fe:
                print("[WS] frame push error:", fe)
                stream_cam = None
                await asyncio.sleep(0.2)
        else:
            # No streaming — release camera; a lock made on old frames is stale.
            if stream_cam is not None:
                print("[WS] Releasing stream camera")
                stream_cam = None
                track.update(on=False, pending=None)
                tags["on"] = False
            det_frame_count = 0
            last_tracked, last_hands, last_tags = None, [], []
            await asyncio.sleep(0.05)

        await asyncio.sleep(0)   # yield to handler coroutines

async def run_ws_server(port):
    global ws_status, _ws_server

    ws_status = "Serving"
    server = await websockets.serve(
        ws_handler, "0.0.0.0", port,
        reuse_address=True
    )
    _ws_server = server
    print("[WS] Server listening on port {}".format(port))
    await asyncio.gather(server.wait_closed(), ws_frame_pusher())

def start_ws_server_in_thread(port):
    """Start asyncio WS server in a daemon thread — UI stays responsive."""
    import threading
    global _ws_loop, _ws_server

    if _ws_loop is not None and _ws_loop.is_running():
        print("[WS] Loop already running, skipping restart")
        return

    def _run():
        global _ws_loop
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        _ws_loop = loop
        try:
            loop.run_until_complete(run_ws_server(port))
        except Exception as e:
            print("[WS] server error:", e)

    t = threading.Thread(target=_run, daemon=True)
    t.start()
    print("[WS] Server thread started on port {}".format(port))

# ══════════════════════════════════════════════════════════════════════════════
# DRAW: DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════
def draw_dashboard(c, t):
    c.draw_rect(0,0,W,H, color=C_BG, thickness=-1)

    # Header
    c.draw_rect(0,0,W,38, color=C_CARD, thickness=-1)
    c.draw_line(0,38,W,38, color=C_DIV, thickness=1)
    dot = C_GREEN if (t%60)<30 else blend(0,105,76,249,250,248,0.35)
    c.draw_circle(PAD-2,19,5, color=dot, thickness=-1)
    txt(c,PAD+10,8,"ELIOS",C_GREEN,sc=1.35)
    bx=W-PAD-26
    c.draw_rect(bx,10,22,14,color=C_GREEN,thickness=1)
    c.draw_rect(bx+22,14,3,6,color=C_GREEN,thickness=-1)
    c.draw_rect(bx+1,11,18,12,color=C_GREEN,thickness=-1)

    def card(cx,cy,title,value,vcol):
        rrect(c,cx,cy,CW,CH,10,C_CARD)
        rrect(c,cx,cy,CW,CH,10,C_DIV,fill=False,th=1)
        txt(c,cx+12,cy+8, title,C_MUTED,sc=0.60)
        txt(c,cx+12,cy+28,value,vcol,   sc=0.78)

    if mtime.ticks_ms() < setup["banner_until"]:
        c.draw_rect(0,0,W,38, color=setup["banner_col"] or C_GREEN, thickness=-1)
        txt(c, PAD, 11, setup["banner"][:W//9], C_WHITE, sc=0.72)

    # Row 1 — live SSID (mode) / IP (display-only — WiFi is set up by the OS)
    ssid, ip = net_cards(mtime.ticks_ms())
    ncol = C_GREEN if ip != "--" else C_MUTED
    card(PAD,       CY1,"WiFi SSID", ssid, ncol)
    card(PAD+CW+12, CY1,"IP",        ip,   ncol)

    # Row 2 — AP Port / Connected clients
    card(PAD,       CY2,"AP Port", str(WS_PORT), C_GREEN)
    n = len(ws_clients)
    card(PAD+CW+12, CY2,"Clients", str(n), C_GREEN if n else C_MUTED)

    # Row 3 — AI model status
    mcol = C_GREEN if model_loaded else C_RED
    card(PAD,       CY3,"AI Model", model_name, mcol)
    card(PAD+CW+12, CY3,"Tracking",
         "#{} {}".format(track["id"], track["label"][:12]) if track["on"] else "--",
         C_GREEN if track["on"] else C_MUTED)

    # Row 4 — Flutter connection + streaming status
    flutter_connected = ws_status == "Client connected"
    flutter_serving   = ws_status == "Serving"

    if flutter_connected:
        ind_col  = C_GREEN
        ind_text = "CONNECTED"
    elif flutter_serving:
        ind_col  = C_BLUE
        ind_text = "WAITING"
    else:
        ind_col  = C_RED
        ind_text = "OFFLINE"

    rrect(c,PAD,CY4,INNER,AH,10,C_CARD)
    rrect(c,PAD,CY4,INNER,AH,10,C_DIV,fill=False,th=1)
    txt(c,PAD+12,CY4+8, "Flutter / WS", C_MUTED, sc=0.60)
    txt(c,PAD+12,CY4+24, ws_status,     ind_col,  sc=0.78)

    pill_w = len(ind_text)*8 + 16
    pill_x = PAD + INNER - pill_w - 8
    pill_y = CY4 + 10
    pill(c, pill_x, pill_y, pill_w, 20, ind_col, fill=True)
    txt(c, pill_x+8, pill_y+4, ind_text, C_WHITE, sc=0.60)

    if ws_streaming and flutter_connected:
        live_dot = C_WHITE if (t%30)<15 else ind_col
        c.draw_circle(pill_x-14, CY4+AH//2, 5, color=live_dot, thickness=-1)
        txt(c, pill_x-34, CY4+24, "LIVE", C_GREEN, sc=0.55)

    # Force-disconnect recovery lever — only shown when there's actually an
    # active/stuck connection to reset.
    if ws_status != "Idle":
        fc = C_RED if force_dc_pressed else blend(186,26,26,243,245,242,0.12)
        rrect(c, PAD, FORCE_DC_Y, INNER, FORCE_DC_H, FORCE_DC_H//2, fc)
        rrect(c, PAD, FORCE_DC_Y, INNER, FORCE_DC_H, FORCE_DC_H//2, C_RED, fill=False, th=1)
        flbl = "Force Disconnect Clients"
        flbl_col = C_WHITE if force_dc_pressed else C_RED
        txt(c, PAD+(INNER-len(flbl)*7)//2, FORCE_DC_Y+(FORCE_DC_H-16)//2, flbl, flbl_col, sc=0.64)
    elif not model_loaded:
        txt(c, PAD, FORCE_DC_Y, "Model load error: {}".format(model_load_error[:48]), C_RED, sc=0.58)

    # Only while no app is connected: the QR scan needs the stream camera.
    if not ws_clients:
        button(c, SETUP_BTN, "Wi-Fi setup", C_GREEN, filled=False)

def button(c, rect, label, col, filled=True):
    x, y, w, h = rect
    rrect(c, x, y, w, h, h//2, col if filled else C_CARD)
    rrect(c, x, y, w, h, h//2, col, fill=False, th=1)
    txt(c, x+(w-len(label)*8)//2, y+(h-16)//2, label, C_WHITE if filled else col, sc=0.7)

# ══════════════════════════════════════════════════════════════════════════════
# DRAW: WI-FI SETUP (scan QR → confirm → joining → done)
# ══════════════════════════════════════════════════════════════════════════════
def start_scan(msg=""):
    setup.update(stage="scan", until=mtime.ticks_ms() + SETUP_SCAN_MS, msg=msg,
                 luma0=None, lidx=0, lat=mtime.ticks_ms())

def leave_scan(stage=None):
    """Leave the scan stage with the camera's own luma back for the stream."""
    if setup["luma0"] is not None and stream_cam is not None:
        try:
            stream_cam.luma(setup["luma0"])
        except Exception as e:
            print("[WiFi] luma restore failed:", e)
    setup.update(stage=stage, luma0=None)

_qr_det = None

def find_qr(frame):
    """Payloads in frame: the NPU detector (about 18 ms at 640x640), else find_qrcodes (80 ms)."""
    global _qr_det
    if _qr_det is None:
        try:
            _qr_det = image.QRCodeDetector()
        except Exception as e:
            print("[WiFi] QRCodeDetector unavailable:", e)
            _qr_det = False
    qrs = _qr_det.detect(frame) if _qr_det else frame.find_qrcodes()
    return [q.payload() for q in qrs]

def lines(c, x, y, text, col, width, sc=0.62, step=22, max_lines=3):
    for i, ln in enumerate(textwrap.wrap(text, width)[:max_lines]):
        txt(c, x, y + i*step, ln, col, sc=sc)

def guide(c, x, y, w, h, col):
    """Corner brackets around the centre square of the preview."""
    s = min(w, h) * 2 // 3
    x0, y0, k = x + (w-s)//2, y + (h-s)//2, s//6
    for cx, cy, dx, dy in ((x0, y0, 1, 1), (x0+s, y0, -1, 1), (x0, y0+s, 1, -1), (x0+s, y0+s, -1, -1)):
        c.draw_line(cx, cy, cx + dx*k, cy, color=col, thickness=4)
        c.draw_line(cx, cy, cx, cy + dy*k, color=col, thickness=4)

def header(c, title, sub):
    c.draw_rect(0,0,W,H, color=C_BG, thickness=-1)
    c.draw_rect(0,0,W,38, color=C_CARD, thickness=-1)
    c.draw_line(0,38,W,38, color=C_DIV, thickness=1)
    txt(c, PAD, 9, title, C_GREEN, sc=0.95)
    txt(c, W - PAD - len(sub)*7, 13, sub, C_MUTED, sc=0.6)

# ══════════════════════════════════════════════════════════════════════════════
# DRAW: WI-FI SETUP (scan QR → confirm → joining → dashboard, or back to scan)
# ══════════════════════════════════════════════════════════════════════════════
def draw_setup(c, t):
    global stream_cam
    st, now, chars = setup["stage"], mtime.ticks_ms(), INNER // 8
    if st == "scan":
        with cam_lock:
            if stream_cam is None:
                stream_cam, _, _ = _open_stream_camera(*STREAM_RESOLUTION)
            if setup["luma0"] is None:
                setup["luma0"] = stream_cam.luma()
            elif now - setup["lat"] > LUMA_STEP_MS:
                setup["lidx"] = (setup["lidx"] + 1) % len(LUMA_DROPS)
                setup["lat"] = now
                stream_cam.luma(max(1, setup["luma0"] - LUMA_DROPS[setup["lidx"]]))
            frame = stream_cam.read()
        for payload in find_qr(frame):
            try:
                setup["ssid"], setup["pw"] = parse_wifi_qr(payload)
                setup["msg"] = ""
                leave_scan("confirm")
                break
            except ValueError as e:
                setup["msg"], setup["lat"] = str(e), now
        header(c, "Wi-Fi setup", "{} s".format(max(0, (setup["until"] - now)//1000)))
        top = 46
        room_h = BTN_Y - top - (74 if setup["msg"] else 50)
        sc = min(INNER / frame.width(), room_h / frame.height())
        fw, fh = int(frame.width()*sc), int(frame.height()*sc)
        fx = (W - fw)//2
        c.draw_image(fx, top, frame.resize(fw, fh))
        guide(c, fx, top, fw, fh, C_GREEN)
        y = top + fh + 8
        if setup["msg"]:
            rrect(c, PAD, y, INNER, 44, 8, blend(186,26,26,243,245,242,0.12))
            lines(c, PAD+10, y+4, setup["msg"], C_RED, chars-2, sc=0.58, step=18, max_lines=2)
            y += 50
        lines(c, PAD, y, "Hold the QR in the square, 15-25 cm away. Too bright? "
              "Lower the phone brightness or tilt it a little.", C_MUTED, chars, sc=0.58, step=18, max_lines=2)
        button(c, SETUP_BTN, "Cancel", C_MUTED, filled=False)
    elif st == "confirm":
        header(c, "Wi-Fi setup", "Step 2 of 3")
        txt(c, PAD, 60, "Join this Wi-Fi?", C_MUTED, sc=0.8)
        rrect(c, PAD, 90, INNER, 64, 12, C_CARD)
        rrect(c, PAD, 90, INNER, 64, 12, C_GREEN, fill=False, th=2)
        txt(c, PAD+16, 108, setup["ssid"][:chars-4], C_GREEN, sc=1.15)
        lines(c, PAD, 170, "ELIOS leaves its current Wi-Fi. If it can't connect within "
              "{} s, the old Wi-Fi comes back by itself.".format(JOIN_TIMEOUT_S), C_MUTED, chars)
        button(c, LEFT_BTN, "Cancel", C_MUTED, filled=False)
        button(c, RIGHT_BTN, "Join", C_GREEN)
    else:  # joining
        el = (now - setup["t0"]) / 1000
        header(c, "Wi-Fi setup", "Step 3 of 3")
        txt(c, PAD, 60, "Connecting" + "." * (t//15 % 4), C_BLUE, sc=0.9)
        txt(c, PAD, 92, setup["ssid"][:chars-4], C_GREEN, sc=1.15)
        frac = min(1.0, el / JOIN_TIMEOUT_S)
        rrect(c, PAD, 140, INNER, 14, 7, C_DIV)
        if frac > 0.03:
            rrect(c, PAD, 140, max(14, int(INNER*frac)), 14, 7, C_BLUE if el < JOIN_TIMEOUT_S else C_RED)
        msg = ("Usually 10-20 s. The app link drops while Wi-Fi restarts." if el < JOIN_TIMEOUT_S
               else "No connection. Putting the old Wi-Fi back...")
        lines(c, PAD, 170, msg, C_MUTED, chars)

def _join_worker(ssid, pw):
    print("[WiFi] joining", ssid)
    ok, msg = apply_wifi(ssid, pw)
    print("[WiFi] result:", ok, msg)
    setup["pw"] = ""
    _net["at"] = None
    if ok:
        setup.update(banner="Wi-Fi: {}  ·  IP {}".format(ssid, msg), banner_col=C_GREEN,
                     banner_until=mtime.ticks_ms() + BANNER_MS, stage=None)
    else:
        start_scan(msg + ". Check the password, then scan again.")

def setup_touch(tx, ty):
    st = setup["stage"]
    if st == "confirm" and hit(tx, ty, *RIGHT_BTN):
        setup.update(stage="joining", t0=mtime.ticks_ms())
        threading.Thread(target=_join_worker, args=(setup["ssid"], setup["pw"]), daemon=True).start()
    elif st == "confirm" and hit(tx, ty, *LEFT_BTN):
        setup.update(pw="")
        start_scan()
    elif st == "scan" and hit(tx, ty, *SETUP_BTN):
        leave_scan()

# ══════════════════════════════════════════════════════════════════════════════
# BOOT — AP is already running via OS-level hostapd/dnsmasq; just start the WS
# server on top of it.
# ══════════════════════════════════════════════════════════════════════════════
start_ws_server_in_thread(WS_PORT)

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP — dashboard, or the Wi-Fi setup screens while setup["stage"] is set
# ══════════════════════════════════════════════════════════════════════════════
while not app.need_exit():
    tick += 1
    t = tick

    tx,ty,pressed = ts.read()
    just_released = last_pressed and not pressed
    last_pressed  = pressed

    if setup["stage"]:
        if setup["stage"] == "scan" and mtime.ticks_ms() > setup["until"]:
            leave_scan()
            continue
        c = image.Image(W,H)
        try:
            draw_setup(c,t)
        except Exception as e:
            print("[WiFi] setup screen error:", e)
            leave_scan()
            setup.update(banner="Wi-Fi setup: camera error", banner_col=C_RED,
                         banner_until=mtime.ticks_ms() + BANNER_MS)
        disp.show(c)
        mtime.sleep_ms(20)
        if just_released:
            setup_touch(tx,ty)
        continue

    if ws_clients and mtime.ticks_ms() > screen["awake_until"]:
        if pressed:  # wake for a while; this touch presses nothing
            screen.update(awake_until=mtime.ticks_ms() + SCREEN_WAKE_MS, swallow=True)
        else:
            if screen["on"]:
                disp.set_backlight(0)
                screen["on"] = False
            mtime.sleep_ms(100)
            continue
    if not screen["on"]:
        disp.set_backlight(screen["level"])
        screen["on"] = True
    if screen["swallow"]:
        if just_released:
            screen["swallow"] = False
        just_released = False

    if just_released and not ws_clients and hit(tx,ty,*SETUP_BTN):
        start_scan()
        continue

    force_dc_pressed = (
        ws_status != "Idle" and pressed and
        hit(tx,ty,PAD,FORCE_DC_Y,INNER,FORCE_DC_H)
    )

    c = image.Image(W,H)
    draw_dashboard(c,t)
    disp.show(c)

    # Single constant throttle — dashboard is mostly static (a blinking dot
    # + status text), ~30fps is plenty, and sleeping here still frees the
    # GIL for the streaming thread far more often than an unthrottled loop.
    mtime.sleep_ms(20)

    if just_released and ws_status != "Idle" and hit(tx,ty,PAD,FORCE_DC_Y,INNER,FORCE_DC_H):
        force_dc_pressed = False
        force_disconnect_all_clients()