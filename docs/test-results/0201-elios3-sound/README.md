# 0201 ELIOS 3 sound and haptics — phone check (10 Nov 2026)

Edge 60 Fusion, Android 16, USB, debug arm64 APK via `adb install -r`, data kept.
- The phone was on **vibrate** (`settings get global mode_ringer` = 1). Tapping the tabs created
  no audio player for the app (`dumpsys audio`) and logged no ElioSound errors: silent mode mutes
  UI sounds as specified; haptics still fire. The ringer setting was not changed.
- Not verified on the phone: hearing S1–S10 and the Master volume scaling (needs the ringer on
  normal). Covered by `test/elio_sound_test.dart` (settings → service sync, restart, silent,
  throttle, assets) and `test/widgets/control_feedback_test.dart` (Control presses play S1).
