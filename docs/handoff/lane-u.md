# Lane U handoff (UI screens)

## In progress
- U9 splash and login: branch `feat/u9-splash-login` from `feature/live-scan` d201cfb, draft PR. Decision 0100.
- Code done and tested; waiting for review. Not done: device feel check, native launch screen, a real sign-in.

## What is here
- `lib/Screens/splash_screen.dart` plus `lib/widgets/splash/` (`elio_leaf.dart` painter, `splash_growth.dart` timeline).
- `lib/Screens/login_screen.dart` plus `lib/widgets/auth/auth_widgets.dart` (field, banner, buttons, link, divider, brand panel).
- `main.dart` home is `SplashScreen` (it was unused; the app booted into an auth gate).
- Tests: `test/screens/{splash_screen,login_screen,entry_flow_layout}_test.dart`, `test/widget_test.dart` (the 2 stale splash tests, replaced).
- Renders: `docs/test-results/u9-entry-flow/` (32 PNG at Figma sizes) and its README (differences from Figma, contrast).

## Re-render the PNGs
`U9_RENDER=1 flutter test test/screens/u9_render_test.dart` (skipped otherwise).

## Notes
- Tests need local empty `.env.dev`, `.env.prod`, `.env.android.*`, `.env.ios.*` files (pubspec assets, git-ignored). Never commit them.
- HomeShell cannot build in tests (needs `Firebase.initializeApp`), so routing tests read the replacement route instead.
- Figma wordmark is ELIOS (the app said ELIO). Owner to confirm the name.

## Open
- Restyle the Home snackbars with the Home screen (U-lane).
- Light-mode login on a real device and the animation feel have not been seen.
