# 0177: The MaixCAM2 dashboard shows the live SSID and IP

- Status: Accepted
- Date: 2026-11-03
- Code: `firmware/maixcam2/main.py` (`net_cards`, `draw_dashboard`), test `firmware/maixcam2/test_net_cards.py`

## Context

The camera now joins the owner's Android hotspot in STA mode instead of running its own AP
(ELIOS, 192.168.4.1). Its IP comes from the phone's DHCP and changes when the hotspot restarts,
so the hard-coded `AP_SSID` / `AP_IP` cards were wrong. The owner reads the IP off the camera
screen to type it into the app's Config screen.

## Decision

- The first dashboard row shows "WiFi SSID" as `<ssid> (AP|STA)` (mode from `is_ap_mode()`) and
  "IP" from `network.wifi.Wifi().get_ip()`.
- Both are re-read every 3 s (`NET_REFRESH_MS`), not every frame. With no IP, or if the read
  fails, both show `--` in the muted colour.
- Display-only: AP or STA is still chosen by the OS marker files `/boot/wifi.ap` / `/boot/wifi.sta`.
  `main.py` has no WiFi configuration code.

## Consequences

- The IP on screen is right after a hotspot restart within about 3 s.
- A very long SSID may run past its card; not handled.
- API checked read-only on the device over USB SSH (`get_ip`, `get_ssid`, `is_ap_mode`,
  `time.ticks_ms`); the new `main.py` itself was not deployed.

## Follow-up (3 Nov, PR #85)

- The "Flutter / WS" pill showed OFFLINE ("Idle") after the last app disconnected, while the server
  was still listening. It now shows WAITING ("Serving"), and CONNECTED while any client is still
  connected. Force-disconnect does the same. Test `firmware/maixcam2/test_ws_status.py` (break-checked).
