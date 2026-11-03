# 0140 Home screen restyle (H1)

Status: accepted for the H1 draft PR; owner review of the look pending.

## Decision
- `lib/Screens/home_screen.dart` (the learning dashboard shown by tab 0 of `HomeShell`) follows the Figma page "H1 Home screen" (243:2358): `ElioTheme.wrap` around the screen, `authPalette` colours, `ElioTokens` type, M3 shape scale with continuous corners (`RoundedSuperellipseBorder`), `AuthPrimaryButton` for the green pill with navy text. No hard-coded colours and no new `google_fonts` call in the restyled part; the fonts come from the tokens and switch when DS2 lands Google Sans.
- Light is the default, dark follows the user option (decision 0130). `MaterialApp.theme` is unchanged.
- Behaviour is unchanged: same providers, streams, pull-to-refresh, notification sheet, progress sheets, resume intent, tab switches (Config 2, Control 3, Camera 3).
- Layout: one column below 840 dp; from 840 dp two columns (hero, Continue, Your Progress, Recent Activity left; Did you know, Achievements, Quick Actions right) in a 1040 dp centred container. All tap targets are 48 dp or more.
- The bottom sheets and the notification dialog keep the legacy look (re-themed with their own screens). Sheets are launched from inside the wrapped screen, so `_legacyTheme` re-applies the app theme to them; otherwise the dark theme would leak into light-only content.

## Differences from the Figma frames
- The old "Welcome to ELIO" text and its progress bar are gone (not in Figma). The overall progress bar now sits in the Continue card.
- The old "Continue Learning" section title is the card's overline.
- Locked achievements show their real description (Figma) instead of "Start learning to unlock achievements"; the lock icon and semantics label say locked.
- Desktop: Figma shows the N1 sidebar; the sidebar belongs to the shell lane and is not part of this screen, so only the content columns are built.
- Figma has no loading, text-scale 1.3, 360 dp or dark first-launch frame; they are covered by tests and PNG renders.
- Icons are Material Symbols; Figma icons are close outline versions.

## Test seams
`homeContentServiceForTest` (fake Firestore content) and `homeStaticRobotForTest` (the WebView 3D viewer cannot run in widget tests) are `@visibleForTesting` top-level members.

## Not done
Re-theme the sheets and the notification dialog; sidebar on desktop (N1); contrast of decorative card borders (1.4:1 light, see the contrast note frame 252:2358).
