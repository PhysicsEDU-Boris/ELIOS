# 0221 — Joyful profile header and settings entry animation

Date: 16 November 2026. Branch `feat/profile-header-joyful` (from `feature/live-scan` 86f078e).
Figma `ELIOS 3`: 629:100965 (settings), 629:101085 (account menu), 629:101230 (guest); dark
629:101350, 629:101470, 629:101615.

## What changed

- `_ProfileHeader` (`lib/Screens/profile/profile_screen.dart`): the faint leaf backdrop is
  replaced by `_HeaderDecor`: a big green ellipse (primary fill) that also sits behind the
  status bar, a darker green bubble top right and a small one left (`primaryHover`), a ring
  bubble and mini leaf in the surface colour, confetti in the quiz yellow / blue / red tokens
  plus white, and a sparkle. Drawn with theme tokens on a 390 dp frame and spread to the real
  width; `ExcludeSemantics` + `IgnorePointer`.
- Avatar: leaf shape (58 / 16 / 58 / 16), 120 dp picture with a 5 dp surface ring outside and
  a soft shadow. Edit-leaf badge (ELIOS mark on primary) with a 3 dp surface ring. Name, email,
  chip and hint are unchanged; signed-in, account-menu and guest states use the same header.
- Entry: the avatar pops in (0.8 → 1, spring), the confetti fades in after it, then each
  section (title with its rows) rises in after the one before (`ElioPopIn`). Reduce motion: a
  150 ms fade, no movement. It plays when the page is built (once per app start in the tab
  shell), like the other `ElioPopIn` entrances.
- Dark mode, language, sound and quiz rows are the same widgets as before, only wrapped.

- Phone check (16 Nov): scrolled settings text ran under the status bar. A background strip
  (`_StatusBarScrim`) now covers the status bar once the list scrolls; at rest the green
  curve still shows there.

## Not 1:1

- Figma's dark frame draws the badge leaf in primary on primary (invisible); the app uses the
  on-primary ink there.
- Only the sparkle is a Figma asset (`assets/illustrations/home/icon_sparkle.svg`, tinted with
  the primary text colour). Curve, bubbles and confetti are plain shapes drawn from tokens so
  they follow the theme.
- On wide screens (landscape) the decoration spreads with the width; Figma has portrait only.

## Tests

`test/screens/profile_header_test.dart`: 16 fit checks (light/dark × EN/ID × portrait/landscape
× signed in/guest), entry order, reduce motion, account menu with its sound.
`PROFILE_RENDER=<dir>` writes PNGs; four are in `docs/test-results/0221-profile-header/`.
Break-check: 18 of the 19 fail on the old header (the menu test passes on both, as a guard).
