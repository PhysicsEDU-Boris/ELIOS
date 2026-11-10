# 0198 ELIOS 3 scan flows — phone test (10 Nov 2026)

Edge 60 Fusion, Android 16, USB, debug arm64 APK via `adb install -r` (data kept). The phone was
in dark mode + Bahasa Indonesia (owner's setting) and was left that way. History JSON md5
identical before/after.

- hub / hub-bottom / hub-fixed: three cards (long Indonesian title fixed to clear the art).
- phone-camera → identify → quiz: real ELIOS AI identified the item and wrote a hard MC question
  in portrait; the quiz was closed without answering (nothing saved).
- contrib-pick → rec → result: picked B3, recorded, the AI saw a bag (Daur ulang) → "Belum tepat",
  nothing saved (chosen on purpose so no test record lands in the owner's History).
- setup-connected / setup-video-quiz / quiz-off / reopened: fake MaixCAM2 via `adb reverse
  tcp:8765` (save-as-default off); connected shows Open control + Disconnect; quiz card on/off
  (left on); Open control reopens Control; Disconnect ends it.
Not checked: a matching contribution (+10) and a robot scan with the quiz off on the phone (both
would write to the owner's History; covered by `test/elios3_scan_flows_test.dart`).
