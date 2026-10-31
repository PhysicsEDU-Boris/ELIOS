# Lane P handoff (phone checks)

## P1 U9 splash, login and icon on the Edge 60 Fusion (31 Oct 2026)
- Build: `feature/live-scan` 578e009 (U9 #59) + `feat/i1-app-icon` 8e4c701 (#58), local throwaway merge, no conflict. arm64 release, `TESTER_BUILD=true`, debug-signed, 169,309,721 bytes.
- sha256 `4ca2da5c084e00c65c0401eeb0cb676a79a6f6d59872bebef474d9f1fd1075dd`. Installed with `adb install -r` over the existing app (no uninstall, no data clear). Private configs removed after the build.
- Phone 1220x2712, 450 dpi, 90 Hz panel. Not tested: real sign-in, Google, guest, reset email. Screenshots: `docs/test-results/u9-phone-check/`.

| Check | Result | What I saw |
|---|---|---|
| P1 cold start | Pass, one flash | Order and timing match Figma: seed, stem, buds, leaf, E L I O S one by one, tagline, dissolve at about 3.47 s after the first Flutter frame, done at about 3.68 s (spec 3.4 / 3.65). In dark mode the native launch screen is light (`#F8FAFC`, seed dot) for about 0.3 s, then fades to the dark Flutter splash: a visible light to dark flash. Light mode should match. |
| P2 smoothness | Not measurable with gfxinfo | `gfxinfo` shows 0 frames: Flutter draws into a SurfaceView, so HWUI counts nothing. `SurfaceFlinger --latency` also returned no frames for the BLAST layer. Proxy from the screen recording: 206 frames in 3.43 s, gap p50 20.5 ms, p90 22.3, p95 22.4, p99 23.0, max 43.2 ms (one gap over 33 ms). The OS caps the app to 45 Hz (`frameRateOverride uid=10458 45 Hz`, not thermal, thermal status 0, battery 31 C, charging), so about 45 fps is the ceiling. No visible hitch in the frames. |
| P3 reduced motion | Pass, with a note | `animator_duration_scale 0` does NOT trigger it: the full animation ran. Flutter's Android embedding reads `transition_animation_scale`. With that at 0: static F11 for about 0.6 s, hard cut to the login. |
| P4 login | Fail on one bug, rest pass | Sign in, Sign up, Forgot password, validation error, light and dark all render as Figma (pills, radius 12, order, spacing, colours). Keyboard (portrait) leaves the fields and Sign In visible. Tap targets are 48 dp (Sign In 135 px = 48 dp). Landscape uses the wide layout; the form scrolls and Sign Up is reachable. See bugs. |
| P5 icon | Pass (themed icon not checked) | App info and launcher show the dark navy tile with the green leaf and cursor, centred, not cropped, a little small in the mask but readable. The themed (monochrome) icon was not checked: no toggle found. |
| P6 known differences | Not reported | JetBrains Mono headings, system dark/light. |

## Bugs and differences
1. **Stale validation errors after the sign in / sign up toggle** (`p4-bug-stale-errors-after-toggle.jpg`): tap Sign In empty, then Sign Up: the Full Name field shows "Email or username is required", Email shows none. Cause: `AuthField`s have no keys, so field state is reused by position when the field list changes. Not caught by the unit tests (they toggle without errors showing). Fix belongs in `login_screen.dart` (keys on the name, email and password fields).
2. Validation errors show under each field; Figma's Error frame is a banner for a server error. Both exist in the app; not a bug.
3. Landscape on this phone is 964 dp wide, so it gets the desktop split layout. With the keyboard open only about 150 dp of the form is visible; Sign In is reachable only by closing the keyboard or scrolling that strip. No status-bar inset in the wide layout: the form scrolls under the clock and icons.
4. Light-mode focus ring is a heavy dark green band around the field (`p4-light-...-keyboard.jpg`).
5. Session: the app opened to Home ("Hello, Guest") on the first 3 launches, then to the login on every later launch, with no sign-out by me. Cause unknown (a force-stop during startup or a guest token expiry). The owner should check the guest session.
6. Cold start rotation: a landscape lock set before a cold start was reset to portrait; rotating with the app open works.

## Phone settings restored
night mode `yes` (as found; I switched to `no` for the light shots), `animator_duration_scale` deleted (was unset), `transition_animation_scale` 1.0, `accelerometer_rotation` 0, `user_rotation` 0 (rotation locked, portrait). A "elio" / "elios" text went into the Moto AI search box and the email field once; nothing was sent or submitted.

## Ponytail markers
Start and end: 9, unchanged (no code change in this PR).
