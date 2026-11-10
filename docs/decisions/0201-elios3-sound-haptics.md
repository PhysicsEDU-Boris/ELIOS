# 0201 — ELIOS 3 sound, haptics and loading states

Date: 10 November 2026

Sixth PR of the ELIOS 3 series, stacked on `feat/elios3-login-profile` (0200). Figma
J2jSbARJSyJCStNFeWkWDj section 13 (motion · sound · haptics) and 12 (skeletons).

- **One audio service** (`lib/services/elio_feedback.dart`, `ElioSound`): the palette S1–S10
  (leaf tick, seed pop, twig toggle on/off, bloom chime, soft knock, robot blip, shutter, rec
  start/stop, trophy sparkle + short, air) as 44.1 kHz mono WAVs at ≤ −18 dBFS, synthesised by
  `tools/sounds/make_sounds.py` (re-runnable, ~200 KB). Rules: off when Profile → Sound effects is
  off, scaled by Master volume, silent when the ringer switch is on silent/vibrate (new `isSilent` on
  the existing `elio/device_health` channel reads `Settings.Global` `mode_ringer`, cached 1 s;
  `AudioManager.ringerMode` was wrong: it reports silent whenever Do Not Disturb is on, which
  muted every sound on the owner's phone), at most one sound per 120 ms (a clock set
  back never mutes), S10 off by default, never looped, mixes with music/voice
  (`AudioContextConfigFocus.mixWithOthers`). Playback: `audioplayers` `AudioPool` (new dependency:
  there was no audio player in the app).
- **Settings sync**: `applySoundPrefs` runs on every AppPreferences change and at start, so Sound
  effects / Master volume reach the service and the quiz voice (`QuizTtsService.volume`) at once
  and after a restart. The Control screen's press feedback (0188) now plays S1 through the
  service instead of the system click, so robot control sounds follow the same settings. Quiz
  popups play S4/S5 on answers.
- **Haptic map** (`ElioHaptics`): select, light, medium, heavy, success (2 pulses), warning
  (15 · 60 · 15 ms), error, celebrate (success + 3 ticks). Only on user-caused events.
- **Wired**: bottom nav (S1 + select on a new tab), Scan orb (S2 + medium), Profile switches and
  ELIOS setup switches (S3 on/off + select), segmented pills (S1 + select), volume slider (select
  per 10 % detent, S2 preview on release), account menu (S2 + light), Scan hub cards (S2 + light),
  Use ELIOS / Open control / Home Continue (S6 + medium), robot connected (S6 + success),
  Disconnect (heavy), shutter (S7 + medium), contribute record start/stop (S8), contribute result
  (S9 short + success / S5 + error), quiz answers (S4 + success / S5 + error).
- **Skeletons**: the existing Home, Learn, History list/detail and quiz popup loading states stay
  (static under reduced motion); the new Scan timeline shows the History list skeleton while
  History loads.

Not done: per-element motion (springs, stroke slide, stagger) from the 38 element cards beyond the
press scale on the Scan orb; S9 full / H-celebrate on level up and medals (no event hook yet);
quiz timer last-3-s ticks; the sweep shimmer (existing skeletons pulse).
