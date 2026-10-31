# 0100 Splash and login from the approved Figma (U9)

Status: accepted for the U9 PR.

## Decision
- Splash "Growth v2" (Figma 208:799, 214:799, spec 208:1551): one `AnimationController` of 3400 ms drives all 12 keyframes (0, 500, 1100, 1700, 1950, 2110, 2270, 2430, 2590, 2750, 3100, 3300 ms). Leaf, stem, buds and seed are `CustomPainter` paths read from the Figma vectors (`lib/widgets/splash/elio_leaf.dart`); no asset files. The 250 ms dissolve is the route fade after a 100 ms wait (ends 3650 ms). Reduced motion (`MediaQuery.disableAnimations`): F11 static, 600 ms hold, cut. The controller uses `AnimationBehavior.preserve`; the default would shrink the 600 ms hold to 30 ms.
- Wordmark is **ELIOS** and the tagline is "Environment Learning Intelligent Object Sorter" (Figma). The old splash said "ELIO" and "Smart Waste Sorting Robot".
- `main.dart` now starts on `SplashScreen`. Before, `SplashScreen` was not used at all: the app booted into an auth gate (signed in: Home, else Login). The splash makes the same choice after its animation.
- Login (196:688 to 196:1543): five states (Sign in, Sign up, Forgot password, Error, Loading), light and dark, phone full-height form and desktop (width 900 or more) brand panel plus 400 dp form column. Only `ElioTheme.wrap` and `lib/theme` tokens; theme button styles; `ElioGlowBox` focus ring. Components live in `lib/widgets/auth/auth_widgets.dart`.
- Forgot password is now a mode of the screen (Figma). Sending still uses the old checks and the old snackbar texts; the success banner is added.
- Behaviour unchanged: email-or-username sign in, sign up (Full Name, Email, Password), Google, guest, error mapping, every error and snackbar text, constructor signatures.

## Not done / follow-ups
- Snackbars show in the Home scaffold after the route change and keep the app theme (`ponytail:` in `login_screen.dart`).
- Contrast: light primary fill on bg is 1.67:1 (button boundary only, label is 10.25:1) and `border/medium` is decorative, as the Figma contrast page records. Tokens were not changed.
- Native launch screen and app icon belong to lane I1.
