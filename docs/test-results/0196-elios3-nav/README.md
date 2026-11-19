# 0196 ELIOS 3 nav shell — phone test (9 Nov 2026)

Motorola Edge 60 Fusion, Android 16, USB. Debug arm64 APK (LIVE_SCAN, TESTER_BUILD,
DARK_MODE_OPTION), `adb install -r` over the existing app, data kept (History JSON md5 recorded
before install).

- before-*: the installed `1e4810f` build (Control orb, Config tab, avatar top bar, sidebar).
- after-*: this branch. Checked: bottom nav order and active states; Scan hub → Select vehicle
  (drone locked, not tappable) → ELIOS setup (MaixCAM2 only, settings sheet = connection + video);
  Profile settings, account menu (Switch account, Sign Out); Home/Learn/History in-page titles;
  dark mode and Bahasa Indonesia on every tab; both survive a force-stop + relaunch.
- Not checked here: connecting to the real robot (camera offline), phone Scan & quiz end to end,
  sign out (would end the owner's session), guest account on the phone (covered by widget test).
