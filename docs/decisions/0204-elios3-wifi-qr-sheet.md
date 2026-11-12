# 0204 — ELIOS 3 Robot Wi-Fi QR sheet

Date: 10 November 2026. Stacked on `feat/elios3-motion-more` (0203, PR #114).
Figma: C1 Light `629:91020`, C1 Dark `629:91453` (file `J2jSbARJSyJCStNFeWkWDj`).

- Only the look of `RobotWifiQrSheet` changes (0178 behaviour kept): drag handle, 44 dp
  green-tint QR badge, 28 px headline + new subtitle "Join ELIOS to a hotspot or Wi-Fi",
  48 dp round close, caption labels above 48 dp fields (theme input style), Show QR pill,
  QR on a white 8 px card with a 16 dp quiet zone (white in dark mode too), tip under it.
- The QR payload is untouched: still `wifiQrPayload` (`WIFI:T:WPA;S:…;P:…;;`) that the
  firmware's `parse_wifi_qr` reads. Editing a field still hides the old QR until Show QR.
- Intro copy follows Figma ("…or use your home Wi-Fi…"): the payload is plain WPA, so a home
  router works the same as the hotspot; no new feature.
- Motion: `ElioPress` on close and Show QR, `ElioPopIn` when the QR appears.
- Tests: `test/screens/robot_wifi_qr_sheet_test.dart` (header/labels, fields → exact QR SVG,
  stale QR cleared, dark white card, close). Break-checked by breaking each of payload,
  clear-on-edit, close and card colour.
