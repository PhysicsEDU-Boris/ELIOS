# 0202 ELIOS 3 motion — phone check (10 Nov 2026)

Edge 60 Fusion, Android 16, debug APK via `adb install -r`; screen recordings with
`adb shell screenrecord`, frames compared with ffmpeg.
- nav-stroke.gif: tab taps — stroke slides, icons swap.
- scan-hub-entrance.gif: hub cards rise in.
- home-entrance.gif / home-entrance-frames.png: cold start — empty dial, arc sweeps, tree and
  trophy sticker come in. Before the after-first-frame fix the same recording showed Home already
  settled (the debug build's first frame outlasted the animation).
