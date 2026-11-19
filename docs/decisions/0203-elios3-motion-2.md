# 0203 — ELIOS 3 motion, part 2

Date: 10 November 2026. Stacked on `feat/elios3-animations` (0202).

- Dark-mode circular reveal from the Profile switch (`ThemeSwitchReveal` at the app root: snapshot,
  switch, shrink the old screen through a growing circle, 400 ms; reduced motion = 220 ms fade).
- Learn quiz answers: wrong pick shakes, the right one pulses once, the check pops.
- Level-up and medal celebration overlay (bounce art, 24 falling leaves, S9 + celebrate haptic,
  2.4 s or tap, max one per 3 s), triggered on Home against the last level/medals seen per
  account (first run only records).
- Scan-activity grid: diagonal fade-in (8 ms per step) and a single pulse on today.
- Fade-through page route (24 px rise) for Learn, Scan and History pushes; Hero morphs for the
  History thumbnail → scan detail photo and the hub robot → Select vehicle.
- Idle hints (stop after 8 s): hub phone tilt, ELIOS spotlight, REC dot, Home resume robot, camera
  brackets.
- History bin tiles: the picked tile's buddy jumps (All: 3 buddies in a 40 ms wave), check pops.

Not phone-verified yet (usage limit); covered by `test/theme/elio_motion_more_test.dart`.
