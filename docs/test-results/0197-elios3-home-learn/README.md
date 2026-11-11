# 0197 ELIOS 3 Home + Learn — phone test (10 Nov 2026)

Edge 60 Fusion, Android 16, USB, debug arm64 APK installed with `adb install -r` (data kept).
Robot: the repo's fake MaixCAM2 (`tools/fake_maixcam`, scenario single_item_60s) on the Mac,
reached through `adb reverse tcp:8765 tcp:8765` and IP 127.0.0.1 with "Save as default" off (the
owner's saved robot IP was not changed).

- home-top / home-mid / learn: L4 Home and Learn clover sticker, light, English.
- control → stopped: connect from ELIOS setup opens Control; STOP stops the robot (fake camera
  logged motor 0,0).
- home-resume: after leaving Control the robot stays connected and Home shows the card.
- resumed / back-from-bg: Continue reopens Control; Home button + relaunch keeps it connected.
- home-after-disc: Disconnect on ELIOS setup → the card is gone.
- *-dark-id: dark mode, Bahasa Indonesia.
Not checked: the real MaixCAM2 (offline); sound/haptics (PR 6).
