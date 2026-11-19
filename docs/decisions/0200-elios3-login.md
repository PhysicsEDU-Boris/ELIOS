# 0200 — ELIOS 3 login (L4 organic)

Date: 10 November 2026

Fifth PR of the ELIOS 3 series, stacked on `feat/elios3-history` (0199). Figma J2jSbARJSyJCStNFeWkWDj
light 644:24854 (sign in), 644:24990 (sign up), 644:25133 (forgot), 644:25255 (error), 644:25397
(loading), dark copies below them.

- Phones: a curved green header (`AuthOrganicHeader`) scrolls with the form: the real ELIOS leaf
  logo (`ElioMark`, Figma `Brand/ELIOS leaf`) in a white circle (dark background in dark mode),
  the ELIOS wordmark, the three bin buddies and the robot. The title gets the green squiggle; the
  "or" divider gets a small leaf. Fields, validation, Google / guest / email flows, banners and
  the five states are unchanged. The wide (≥ 900 dp) layout keeps its brand panel.
- Profile needed no change after 0196 (Appearance, Sound, Quiz, account menu, guest). **Change
  photo** is not built: it needs a new image-picker dependency and Firebase Storage rules for
  profile photos — owner decision.

Verified with the existing login/entry tests (all five states, light/dark, 390×844 and 1366×768,
text 1.0/1.3, keyboard open/closed, no overflow) and widget renders in
`docs/test-results/0200-elios3-login/`. Not run on the phone: it would sign the owner out.
