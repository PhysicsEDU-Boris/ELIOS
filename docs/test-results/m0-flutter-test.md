# M0.6: full `flutter test`

- **Date:** 2026-10-09, macOS 27.0 (arm64), Flutter 3.44.2
- **Command:** `flutter test` in the repo root. It runs `test/` only; the
  real-model tests in `integration_test/` are covered in M0.1–M0.5.
- **Branch / commit:** `test/m0-stage2-proof` at `669f62c`
- **Result:** **77 passed, 2 failed** (`00:11 +77 -2: Some tests failed.`)

## Failures

Both are the 2 known stale tests in `test/widget_test.dart` (plan 1.3). The
plan allows these and nothing else. There is no other failure.

| Test | Why it fails |
|---|---|
| `splash shows and navigates to login when signed out` | Looks for the text `ELIO` on the splash screen and `Login — coming soon`, neither of which exists any more (`Found 0 widgets with text "ELIO"`). |
| `splash navigates to home when already signed in` | Looks for `Home — coming soon`, which no longer exists. On the way, the real `HomeScreen` it navigates to throws `[core/no-app] No Firebase App '[DEFAULT]' has been created`, because the test only mocks `FirebaseAuth` and never sets up a Firebase app (`lib/Screens/home_shell.dart:63`). |

Both tests were written against the old placeholder screens. Fixing them
means rewriting them for the current splash and home screens (with a
Firebase test setup for the signed-in case). That is plan item 1.3, not M0.

## Raw log

`~/GITHUB/ELIO/elios-m0-logs/flutter-test.log` (outside the repo).
