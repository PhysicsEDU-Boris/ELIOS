# ELIO MaixCAM2 dashboard / WebSocket server / segmentation (MaixPy v4).
# Derived from the owner's Maixcam.txt reference; see README.md for its hash.
# Clean pixels are encoded before drawing; annotated preview remains unchanged.
# Hardware behavior is inherited from that reference, not deployment-verified.
# WiFi (AP or STA) is set up by the OS; only the "Wi-Fi setup" QR screen changes it.

from maix import image, display, camera, touchscreen, nn, app, tensor, network, time as mtime
import json, asyncio, websockets, base64, math, hashlib, os, subprocess, threading, textwrap
import numpy as np

# Clean vision protocol: image stays annotated for old preview clients.
FIRMWARE_VERSION = "m2c-clean-v1"
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

# ── AI Model ──────────────────────────────────────────────────────────────────
# Your trained waste-segmentation model (converted from
# ~/maixcam2_convert/out/, deployed to /root/models/ on the device).
MODEL_PATH = "/root/models/elios_waste_seg.mud"

# Detection cadence — decoupled from the video frame rate. Decoding a real
# seg model is far slower than a 640x480→JPEG encode, so running it on
# every streamed frame would drag the whole stream down to the model's
# speed. Instead we run it every DET_EVERY_N_FRAMES pushed frames and hold
# the last result in between — the video keeps moving at full rate, the
# overlay just updates less often.
#
# STREAM_RESOLUTION (below, set once the model is loaded) is now the
# model's OWN native input size, not a separate 1920x1080 capture — so
# there is no resize between "what the camera captured" and "what the
# model saw", and no second resize between "the mask the model produced"
# and "the mask drawn on screen" either. An earlier revision streamed at
# 1920x1080 and upscaled the model's mask into that space with a second
# .resize() call; that extra, unverified upscale is what caused the mask to
# visibly bleed past the object's real edges. Trade-off: live video is now
# at the model's resolution (lower than 1080p), not the sensor's full
# frame — but the mask is pixel-exact with what the model actually decoded,
# which matters far more for the planned real-world-dimension calculation
# than video sharpness does.
DET_EVERY_N_FRAMES = 2
DET_IOU_TH  = 0.45

# Object locking — real-world YOLO confidence is noisy frame-to-frame (a
# real object can read 45% one detection cycle and 35% the next), so a
# single fixed threshold applied fresh every cycle makes objects flicker in
# and out. Fix: decode candidates at a LOW floor (RAW_CONF_TH) so a
# momentary dip is still visible to the tracker, but only let a candidate
# ENTER the locked set once it has cleared LOCK_CONF_TH (0.4) at least once.
# Once locked, it's tracked by IoU across cycles and stays displayed through
# LOCK_GRACE_CYCLES more misses (including score dips below LOCK_CONF_TH,
# which are IoU-matched and never count as a miss at all) before being
# dropped — see _update_lock(). Kept LOW (not the original 5) specifically
# so swinging the camera to a different object clears the old lock almost
# immediately instead of visibly lingering — a genuine score dip on the
# SAME object never hits this path, only a total dropout does.
RAW_CONF_TH = 0.25
LOCK_CONF_TH = 0.4
LOCK_IOU_TH = 0.3
LOCK_GRACE_CYCLES = 1

# Raw output tensor names + decode math — copied unchanged from
# elios_seg_manual.py, which proved this exact model needs the manual path.
BOX_NAME = "/model.23/Concat_output_0"          # raw box, pre-DFL, (1,64,8400)
CLS_NAME = "/model.23/Concat_1_output_0"        # raw class logits, pre-sigmoid, (1,10,8400)
MASKCOEF_NAME = "/model.23/Concat_2_output_0"   # raw mask coefficients, (1,32,8400)
PROTO_NAME = "/model.23/proto/cv3/conv/Conv_output_0"  # mask proto, (1,160,160,32)

REG_MAX = 16
STRIDES = [8, 16, 32]

LABELS = ['Cardboard', 'E_Waste', 'Glass', 'Human_Hand', 'Metal', 'Organic',
          'Paper', 'Paperboard', 'Plastic', 'Tetra_Pak']

detector          = None   # kept only for its metadata (input size/format) —
model             = None   # this is what actually runs inference
model_loaded      = False
model_load_error  = ""
det_input_w       = 0
det_input_h       = 0
anchor_x = anchor_y = anchor_stride = None
mean = scale = None
try:
    # `detector` is only used for its already-working metadata (input size) —
    # detector.detect() must NEVER be called for this model, see header.
    detector     = nn.YOLO11(model=MODEL_PATH, dual_buff=False)
    model        = nn.NN(MODEL_PATH, dual_buff=False)
    det_input_w  = detector.input_width()
    det_input_h  = detector.input_height()

    extra = model.extra_info()
    mean  = [float(v) for v in extra["mean"].split(",")]
    scale = [float(v) for v in extra["scale"].split(",")]

    # Anchor grid, built in the same P3->P4->P5 scale order the model concatenated.
    ax, ay, astride = [], [], []
    for s in STRIDES:
        gh, gw = det_input_h // s, det_input_w // s
        for gy in range(gh):
            for gx in range(gw):
                ax.append(gx); ay.append(gy); astride.append(s)
    anchor_x = np.array(ax, dtype=np.float32)
    anchor_y = np.array(ay, dtype=np.float32)
    anchor_stride = np.array(astride, dtype=np.float32)

    model_loaded = True
    print("[AI] Model loaded:", MODEL_PATH, "input", det_input_w, "x", det_input_h)
except Exception as _me:
    model_load_error = str(_me)
    print("[AI] Model load FAILED:", MODEL_PATH, "-", model_load_error)

model_name = MODEL_PATH.rsplit("/", 1)[-1] if model_loaded else "Not loaded"


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def softmax(x, axis):
    x = x - x.max(axis=axis, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)


def nms(boxes, scores, classes, iou_th):
    order = scores.argsort()[::-1]
    picked = []
    while order.size > 0:
        i = order[0]
        picked.append(i)
        if order.size == 1:
            break
        rest = order[1:]
        xx1 = np.maximum(boxes[i, 0], boxes[rest, 0])
        yy1 = np.maximum(boxes[i, 1], boxes[rest, 1])
        xx2 = np.minimum(boxes[i, 2], boxes[rest, 2])
        yy2 = np.minimum(boxes[i, 3], boxes[rest, 3])
        inter = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
        area_i = (boxes[i, 2] - boxes[i, 0]) * (boxes[i, 3] - boxes[i, 1])
        area_r = (boxes[rest, 2] - boxes[rest, 0]) * (boxes[rest, 3] - boxes[rest, 1])
        iou = inter / (area_i + area_r - inter + 1e-6)
        suppress = (classes[rest] == classes[i]) & (iou > iou_th)
        order = rest[~suppress]
    return picked


def decode_seg(outputs, conf_th=RAW_CONF_TH, iou_th=DET_IOU_TH):
    """Manual YOLO11-seg decode — copied unchanged from elios_seg_manual.py.
    Returns [{"x","y","w","h","class_id","score","seg_mask"}] in
    det_input_w x det_input_h space, x/y = TOP-LEFT (ws_frame_pusher scales
    to full stream size and converts to center coords, same as it did for
    detector.detect()'s obj.x/obj.y/obj.w/obj.h before)."""
    box = tensor.tensor_to_numpy_float32(outputs[BOX_NAME], copy=False)[0]           # (64, 8400)
    cls = tensor.tensor_to_numpy_float32(outputs[CLS_NAME], copy=False)[0]           # (10, 8400)
    maskcoef = tensor.tensor_to_numpy_float32(outputs[MASKCOEF_NAME], copy=False)[0]  # (32, 8400)
    proto = tensor.tensor_to_numpy_float32(outputs[PROTO_NAME], copy=False)[0]       # (160, 160, 32)

    bins = box.reshape(4, REG_MAX, -1)                      # (4, 16, 8400): left,top,right,bottom
    probs = softmax(bins, axis=1)
    weights = np.arange(REG_MAX, dtype=np.float32).reshape(1, REG_MAX, 1)
    dist = (probs * weights).sum(axis=1)                    # (4, 8400)

    x1 = (anchor_x + 0.5 - dist[0]) * anchor_stride
    y1 = (anchor_y + 0.5 - dist[1]) * anchor_stride
    x2 = (anchor_x + 0.5 + dist[2]) * anchor_stride
    y2 = (anchor_y + 0.5 + dist[3]) * anchor_stride

    conf = sigmoid(cls)                                      # (10, 8400)
    class_id = conf.argmax(axis=0)
    score = conf.max(axis=0)

    idxs = np.nonzero(score > conf_th)[0]
    if idxs.size == 0:
        return []

    boxes = np.stack([x1[idxs], y1[idxs], x2[idxs], y2[idxs]], axis=1)
    scores_k = score[idxs]
    classes_k = class_id[idxs]

    picked = nms(boxes, scores_k, classes_k, iou_th)

    proto_h, proto_w = proto.shape[0], proto.shape[1]
    results = []
    for i in picked:
        a = idxs[i]
        bx1, by1, bx2, by2 = boxes[i]
        bx1 = max(0.0, bx1); by1 = max(0.0, by1)
        bx2 = min(float(det_input_w), bx2); by2 = min(float(det_input_h), by2)
        box_w, box_h = int(bx2 - bx1), int(by2 - by1)
        if box_w <= 1 or box_h <= 1:
            continue

        mx1 = int(bx1 * proto_w / det_input_w)
        my1 = int(by1 * proto_h / det_input_h)
        mx2 = max(mx1 + 1, int(bx2 * proto_w / det_input_w))
        my2 = max(my1 + 1, int(by2 * proto_h / det_input_h))

        w_a = maskcoef[:, a]                                          # (32,)
        mask_crop = proto[my1:my2, mx1:mx2, :] @ w_a                  # (mh, mw), proto-space res
        mask_prob = sigmoid(mask_crop)

        # draw_seg_mask() needs the mask 1:1 pixel-for-pixel with the box,
        # so it must already be upscaled from proto-space (1/4 res) to the
        # box's actual pixel size, or it only ever covers a small corner of
        # the object. (This upscale is to the box's own det-input-space
        # size; ws_frame_pusher upscales it again to full-stream-space
        # right before actually drawing it onto the streamed frame.)
        mh, mw = mask_prob.shape
        row_idx = np.minimum((np.arange(box_h) * mh // box_h), mh - 1)
        col_idx = np.minimum((np.arange(box_w) * mw // box_w), mw - 1)
        mask_full = mask_prob[row_idx][:, col_idx]                    # (box_h, box_w)

        mask_bytes = (mask_full * 255).astype(np.uint8).tobytes()
        seg_img = image.from_bytes(box_w, box_h, image.Format.FMT_GRAYSCALE, mask_bytes)

        results.append({
            "x": int(bx1), "y": int(by1), "w": box_w, "h": box_h,
            "class_id": int(classes_k[i]), "score": float(scores_k[i]),
            "seg_mask": seg_img,
        })
    return results


def _iou_xywh(a, b):
    """IoU of two top-left x/y/w/h boxes, same det-input-space decode_seg
    returns — used to match a locked object to this cycle's raw candidates."""
    ax1, ay1, ax2, ay2 = a["x"], a["y"], a["x"] + a["w"], a["y"] + a["h"]
    bx1, by1, bx2, by2 = b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"]
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = a["w"] * a["h"]
    area_b = b["w"] * b["h"]
    return inter / float(area_a + area_b - inter + 1e-6)


_locked_objects = []  # persists across ws_frame_pusher's detection cycles


def _update_lock(raw_objs):
    """Threshold-based locking so a real object doesn't flicker on/off just
    because its score dipped below LOCK_CONF_TH for one detection cycle.

    - A raw candidate only starts a NEW lock once it clears LOCK_CONF_TH.
    - An already-locked object is refreshed from whichever raw candidate of
      the SAME class_id overlaps it most (by IoU) this cycle, regardless of
      that candidate's own score — so a locked object riding out a 45%->35%
      dip still gets its position updated, it just isn't re-evaluated
      against the lock threshold again.
    - If nothing matches a locked object this cycle (e.g. it dropped below
      even RAW_CONF_TH and produced no candidate at all), it's held as-is
      for up to LOCK_GRACE_CYCLES more cycles before being dropped, so a
      brief total dropout doesn't make it vanish either.
    """
    global _locked_objects
    matched_raw = set()
    updated = []

    for lo in _locked_objects:
        best_i, best_iou = -1, 0.0
        for i, r in enumerate(raw_objs):
            if i in matched_raw or r["class_id"] != lo["class_id"]:
                continue
            iou = _iou_xywh(lo, r)
            if iou > best_iou:
                best_iou, best_i = iou, i
        if best_i >= 0 and best_iou >= LOCK_IOU_TH:
            matched_raw.add(best_i)
            refreshed = dict(raw_objs[best_i])
            refreshed["misses"] = 0
            updated.append(refreshed)
        else:
            held = dict(lo)
            held["misses"] = held.get("misses", 0) + 1
            if held["misses"] <= LOCK_GRACE_CYCLES:
                updated.append(held)
            # else: expired — dropped from the locked set entirely.

    for i, r in enumerate(raw_objs):
        if i in matched_raw:
            continue
        if r["score"] >= LOCK_CONF_TH:
            new_lock = dict(r)
            new_lock["misses"] = 0
            updated.append(new_lock)

    _locked_objects = updated
    return updated


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
# The model's own native input size when it loaded successfully, so the
# camera captures directly at the resolution the model consumes — no
# resize between capture and inference, and no second resize between the
# model's mask output and what gets drawn on screen (see the
# DET_EVERY_N_FRAMES comment above for why that second resize was the
# actual cause of the mask bleeding past object edges). Falls back to
# 1920x1080 only if the model failed to load, since there's nothing to
# match resolution to in that case.
STREAM_RESOLUTION = (det_input_w, det_input_h) if model_loaded else (1920, 1080)

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
        ws_status = "Idle"
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

                if cmd == "ping":
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
        ws_status = "Serving" if ws_clients else "Idle"
        if not ws_clients:
            ws_streaming = False
        print("[WS] clients remaining:", len(ws_clients))

async def ws_frame_pusher():
    """Keep annotated preview; send clean pixels only on fresh inference frames.

    clean_image and clean_detections share frame_id == detection_frame_id.
    Cached/held detections remain preview-only. One extra JPEG per nonempty
    inference frame; no second encode or clean transmission between inferences.
    """
    global stream_cam, ws_streaming, ws_clients
    cam_w, cam_h = STREAM_RESOLUTION
    det_frame_count = 0
    frame_id = 0
    last_dets = []
    last_render_objs = []  # full-stream-space: x, y, w, h, label, score, seg_mask

    while True:
        if ws_streaming and ws_clients and setup["stage"] != "scan":
            try:
                with cam_lock:
                    if stream_cam is None:
                        stream_cam, cam_w, cam_h = _open_stream_camera(*STREAM_RESOLUTION)
                    frame = stream_cam.read()
                frame_id += 1
                detection_frame_id = None
                clean_dets = []
                clean_b64 = None

                if model_loaded and model is not None:
                    det_frame_count += 1
                    if det_frame_count >= DET_EVERY_N_FRAMES:
                        det_frame_count = 0
                        try:
                            # frame is ALREADY at det_input_w x det_input_h
                            # (STREAM_RESOLUTION == the model's own native
                            # input size, see that constant's comment) — no
                            # resize needed before forward_image(), exactly
                            # matching elios_seg_manual.py's own usage.
                            outputs = model.forward_image(frame, mean, scale, image.Fit.FIT_CONTAIN)
                            raw_objs = decode_seg(outputs, conf_th=RAW_CONF_TH, iou_th=DET_IOU_TH) if outputs is not None else []
                            objs = _update_lock(raw_objs)

                            dets = []
                            render_objs = []
                            for o in objs:
                                class_id = o["class_id"]
                                label = LABELS[class_id] if 0 <= class_id < len(LABELS) else str(class_id)
                                # No scaling needed — o["x"/"y"/"w"/"h"] are
                                # already in this same frame's pixel space.
                                # Convert top-left to center for the wire
                                # payload (Flutter's overlay expects center
                                # coordinates, not top-left).
                                cx = o["x"] + o["w"] / 2.0
                                cy = o["y"] + o["h"] / 2.0

                                dets.append({
                                    "class_id": class_id,
                                    "label":    label,
                                    "score":    round(float(o["score"]), 3),
                                    # NOTE: key names must be "x"/"y", not
                                    # "cx"/"cy" — websocket_service.dart's
                                    # Detection parser reads item['x']/['y']
                                    # (falling back to 0.0 if absent), so
                                    # "cx"/"cy" here silently renders every
                                    # box at (0,0) on the Android side.
                                    "x": int(cx), "y": int(cy),
                                    "w":  int(o["w"]), "h": int(o["h"]),
                                })
                                if o.get("misses", 0) == 0:
                                    clean_dets.append(dets[-1])
                                render_objs.append({
                                    "x": o["x"], "y": o["y"],
                                    "w": o["w"], "h": o["h"],
                                    "label": label, "score": o["score"],
                                    "seg_mask": o.get("seg_mask"),
                                })
                            last_dets = dets
                            last_render_objs = render_objs
                            detection_frame_id = frame_id
                        except Exception as de:
                            print("[AI] decode error:", de)

                # Encode original pixels before any mask, box or text mutates them.
                if detection_frame_id == frame_id and clean_dets:
                    clean_bytes = frame.to_format(image.Format.FMT_JPEG).to_bytes()
                    clean_b64 = base64.b64encode(clean_bytes).decode()

                # Bake the last known detections onto THIS frame, every
                # frame — see the docstring above for why this can't just
                # run inside the detection-cycle block. seg_mask is already
                # exactly ro["w"] x ro["h"] (decode_seg() upscales it to the
                # box's own size, and there is no further resize now that
                # the stream is already at the model's native resolution),
                # so it can be drawn directly — the same
                # draw_seg_mask(img, x, y, seg_mask, threshold=127) call
                # elios_seg_manual.py already proved correct, unmodified.
                for ro in last_render_objs:
                    try:
                        seg_mask = ro.get("seg_mask")
                        if seg_mask is not None:
                            detector.draw_seg_mask(frame, ro["x"], ro["y"], seg_mask, threshold=127)
                        frame.draw_rect(ro["x"], ro["y"], ro["w"], ro["h"], color=image.COLOR_GREEN)
                        frame.draw_string(
                            ro["x"], max(0, ro["y"] - 16),
                            "{}: {:.2f}".format(ro["label"], ro["score"]),
                            color=image.COLOR_GREEN,
                        )
                    except Exception as draw_e:
                        print("[AI] draw error:", draw_e)

                # MaixPy v4 JPEG encode path:
                #   img.to_format(FMT_JPEG) → jpeg image object
                #   jpeg_img.to_bytes()     → raw JPEG bytes
                jpeg_img   = frame.to_format(image.Format.FMT_JPEG)
                jpeg_bytes = jpeg_img.to_bytes()
                b64        = base64.b64encode(jpeg_bytes).decode()

                message = {
                    "vision_protocol": 1,
                    "firmware_sha256": FIRMWARE_SHA256,
                    "frame_id": frame_id,
                    "detection_frame_id": detection_frame_id,
                    "image":      b64,
                    "img_w":      cam_w,
                    "img_h":      cam_h,
                    "detections": last_dets
                }
                if detection_frame_id == frame_id:
                    message["clean_detections"] = clean_dets
                    if clean_b64 is not None:
                        message["clean_image"] = clean_b64
                payload = json.dumps(message)

                dead = set()
                for client in ws_clients.copy():
                    try:
                        await client.send(payload)
                    except Exception:
                        dead.add(client)
                for d in dead:
                    ws_clients.discard(d)

            except Exception as fe:
                print("[WS] frame push error:", fe)
                stream_cam = None
                await asyncio.sleep(0.2)
        else:
            # No streaming — release camera.
            if stream_cam is not None:
                print("[WS] Releasing stream camera")
                stream_cam = None
            det_frame_count = 0
            last_dets = []
            last_render_objs = []
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
    txt(c,PAD+10,8,"ELIO",C_GREEN,sc=1.35)
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
    card(PAD+CW+12, CY3,"Model Input",
         "{}x{}".format(det_input_w, det_input_h) if model_loaded else "--",
         mcol)

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
        lines(c, PAD, 170, "ELIO leaves its current Wi-Fi. If it can't connect within "
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