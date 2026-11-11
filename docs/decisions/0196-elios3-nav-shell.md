# 0196 — ELIOS 3 navigation: Scan hub, Profile tab, no top bar or sidebar

Date: 9 November 2026

First PR of the ELIOS 3 series (Figma J2jSbARJSyJCStNFeWkWDj, page "ELIOS 3" 628:2360, README
629:128520). Stacked on `feat/learn-l2v3` (0195) → `feat/g4-daily-guides` (#105) because the
Learn header and Daily Guides pills come from there.

- Bottom nav (`ELIOS BottomNav` 270:5746): Home · Learn · Scan (raised orb) · History · Profile
  picture. Provider indices: Home 0, Learn 1, Scan 2, History 4, Profile 5. Index 3 is no longer a
  tab; setting it still opens robot Control (Home quests, notifications keep working). The orb is a
  plain scan icon (the 3D robot orb is gone); the Profile cell shows the Google photo, else the
  initials, else a guest icon; Active adds a 2 dp primary ring.
- No top bar and no sidebar in the shell. Each tab draws its own title, which scrolls with the
  page: Home greeting + trophy pill and bell; Learn title + streak/XP pills on the curved green;
  Scan and History use `ElioPageTitle` (Display + squiggle). The Learn-shortcuts sidebar (0195) is
  no longer reachable from the shell; the bubbles and Explore tabs cover the same pages. Control
  and phone scan keep their own sidebar (the landscape control screen is unchanged by design).
- Scan hub (629:90675): Scan & quiz (phone) opens the existing landscape phone scan; Robot scan →
  Select vehicle (629:90849: ELIOS ready, Drone in colour but locked "Coming soon", not tappable)
  → ELIOS setup = the old Config tab as a pushed page with a back button. A successful connect
  still opens Control. Robots always use MaixCAM2: the camera-source tiles and phone mode are
  removed from setup; a saved `cameraSource: device` is ignored (nothing else reads it).
- Profile tab (629:100963): Appearance (Dark mode, Language English | Bahasa Indonesia), Sound
  (Sound effects, Master volume), Quiz (Question source, Difficulty, Timer, Allow skipping). Values
  are stored in the same keys as before (`app_preferences_v1`, `elio_theme_mode_v1`,
  `elio_locale_v1`), so existing choices carry over. Avatar → compact menu: Switch account and Sign
  out (both sign out and return to login, where the Google picker opens); guests get "Sign in".
- The ELIOS setup settings sheet keeps only Connection and Video; Sound and Quiz moved to Profile.

Not in this PR (later ELIOS 3 PRs): Scan to contribute, portrait phone Scan & quiz, the ELIOS
setup quiz card with its own robot question source (until then Profile and setup edit the same
source), Change photo, Home resume-control shortcut, History compact tab/timeline, Learn clovers,
login restyle, skeletons, sound palette S1–S10 and the haptic map. The Select vehicle art is the
Figma SVG, not a GLB render.

Tests: new `profile_screen_test.dart` (every setting saved and reloaded after restart, live
language switch, account menu, guest fallback); bottom nav test rewritten for the ELIOS 3 order;
Config tests: a saved phone camera is ignored, the sheet no longer has sound/quiz.
