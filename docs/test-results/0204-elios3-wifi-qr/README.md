# 0204 Robot Wi-Fi QR sheet: phone check

10 Nov 2026, Motorola Edge 60 Fusion over USB, debug APK APP_COMMIT `1567368`
(`adb install -r`, data kept). Opened from Pindai → Pindai dengan robot → Pakai ELIOS →
QR Wi-Fi Robot. Phone was in Bahasa Indonesia + light; left that way. Dummy Wi-Fi only.

1. `1-light-empty.png`: sheet over ELIOS setup (handle, badge, subtitle, round close, labels above fields).
2. `2-light-qr-ElioTest.png`: `ElioTest` / `dummy-pass-1` (checked via the eye toggle) → QR + tip.
3. `3-dark-qr-ElioTest.png`: same values in dark mode; the QR card stays white.
4. `4-dark-edit-clears-qr.png`: editing the name to `ElioTest2` hides the old QR.
5. `5-dark-qr-ElioTest2.png`: Show QR again → a different QR (semantics "Kode QR Wi-Fi untuk ElioTest2").

Close (X) dismissed the sheet. Nothing is saved (reopening shows empty fields).
History `scan_records*.json` md5 identical before/after. Status bar cropped out.
Not tested: the robot actually scanning this QR (payload code unchanged).
