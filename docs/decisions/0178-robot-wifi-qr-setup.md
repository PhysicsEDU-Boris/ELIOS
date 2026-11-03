# 0178: The robot joins a hotspot from a Wi-Fi QR, with rollback

- Status: Draft
- Date: 2026-11-03
- Amends: 0177 (`main.py` now changes Wi-Fi, but only from the setup screen)
- Code: `firmware/maixcam2/main.py` (`parse_wifi_qr`, `apply_wifi`, `draw_setup`), `lib/services/robot_wifi.dart`,
  `lib/Screens/config/robot_wifi_qr_sheet.dart`, `lib/Screens/config_screen.dart`
- Tests: `firmware/maixcam2/test_wifi_setup.py`, `test/services/robot_wifi_test.dart`

## Context

Each user brings their own phone hotspot. Moving the MaixCAM2 to a new hotspot needed SSH and
hand edits of `/boot/wifi.*`. Those marker files are what `/opt/scripts/wifi.sh` reads;
`/boot/configs` and `Wifi.start_ap()` do not switch the radio. After the move the camera's IP
comes from the phone's DHCP and changes with the hotspot.

## Decision

- Camera: a "Wi-Fi setup" button on the dashboard, shown only while no app is connected (the scan
  uses the stream camera). It scans for a standard `WIFI:T:WPA;S:..;P:..;;` QR for up to 90 s,
  then asks "Join <ssid>?". Nothing changes without that tap.
- Scan: `image.QRCodeDetector` (NPU, about 18 ms at 640x640 against 80 ms for `find_qrcodes`). Against
  phone-screen glare, every 1.5 s without a QR the picture gets darker (`luma` minus 0, 2 or 4), and
  the camera's own luma is restored when the scan ends. Manual exposure/gain is not used:
  a probe that set it restarted the camera, and the touch controller then failed its I2C probe on boot
  (fixed by re-binding `hyn_ts`).
- After Join: success goes straight to the dashboard with a 15 s green banner (SSID and IP). Failure goes
  back to scanning with the reason in a red box. There is no OK step.
- Accepted: WPA passwords of 8 to 63 printable ASCII characters, SSIDs of 1 to 32 bytes. Open and WEP
  are refused because `wifi.sh` builds the config with `wpa_passphrase`.
- Join: writes `wifi.ssid`, `wifi.pass`, `wifi.sta`, removes `wifi.ap`, leaves `wifi.ipv4_prefix`.
  Wi-Fi restarts: stop the service, kill hostapd and the wlan0 udhcpd, flush wlan0, unload the
  AIC8800 driver, start, restart udhcpc. `wifi.sh` stop leaves the first two running, and its start
  exits while the driver is loaded.
- Rollback: no STA IP within 45 s puts the previous four files back byte for byte and restarts
  the same way. A `/boot/wpa_supplicant.conf` override is refused and nothing is touched.
- The password is never printed by `main.py` and is cleared from memory after the attempt.
- App: Config gets "Robot Wi-Fi QR" (type the hotspot name and password, nothing is saved) and
  "Find ELIO", which tries port 8765 on every other address of the phone's private /24 networks
  and fills the IP. Android's own hotspot "Share" QR works as well.

## Consequences

- One network is remembered. Scanning a new QR replaces the old one, and the old one comes back
  only through the rollback.
- `wifi.sh` still writes the password to the system log on every start (`journalctl -u wifi.service`),
  and `/boot/wifi.pass` is plain text. Fixing that means changing the OS script, which is out of scope.
- Power loss in the middle of the file writes can leave a mixed state with no rollback at boot. The
  window is milliseconds.
- "Find ELIO" checks for an open port, not an ELIO handshake, and searches /24 networks only.

## Robot test (3 Nov, USB SSH + adb, Edge 60 Fusion hotspot)

- Camera already on hotspot `boris` (STA). QR with a wrong test password: "Not connected", back on
  `boris` at the same IP by itself, `/boot/wifi.*` byte-identical to before, no `.tmp` left.
- QR with the real password (typed by the owner): "Connected", `False True 10.51.200.84`, internet up.
- App: Find ELIO replaced `192.168.4.1` with `10.51.200.84`. Connect gave LIVE 14 fps.
- Second round (new flow): wrong password went back to scanning with the reason; real password
  went to the dashboard with the green banner. Both left the camera on `boris`, with no `.tmp` files.
- Home router: QR for `WIFIBOR` (phone on WIFIBOR, hotspot off): joined at 192.168.100.135 with internet.
  Find ELIO from the phone on WIFIBOR found it; Connect gave LIVE 13 fps.
- Not tested on the robot: switching from AP mode (the hostapd/udhcpd cleanup), and someone else's phone.
