# 0206 — Learn L3 redesign

Date: 11 November 2026. Stacked on `feat/elios3-motion-more` (0203, PR #114), the only branch that
has the L2 v3 Learn hub, Daily Guides, `ElioMotion` and `ElioSound`.

Figma: file `J2jSbARJSyJCStNFeWkWDj`, page ELIOS 3, section 04 · Learn (`629:82486`); motion,
sound and haptics from section 13 row Cards · Learn (`640:24201`), cards 17–20 and 20a–20h.

## What changed

- **Hub.** Under Today's Guide: the archive stack (last 3 guides from the feed, today excluded) as
  fanned polaroids (−8°, 2°, 12°). Swipe the top photo past 40 % of the width (or fling > 600 dp/s)
  to send it to the back; tap to pull it out (×1.22, −2°) and show Continue (opens the guide).
  Back or a tap outside puts it back. Bubbles use the exported Quiz paper, Mini lab thermometer,
  Clover and gold medal art; badges are primary.
- **Explore** carousel now snaps per card; the card snapped to the left is the open module and the
  only module indicator (no chip or header in Discover). Neighbours rest at 0.94 / 90 %.
- **Discover more**: Videos, Guides, Simulations and Quizzes rails for that module, built from
  `L3 / Content pop card`. On a module change old cards sink and fade, new ones pop in (60 ms
  apart, rails 40 ms apart, max 6 waits), thumbnail rises, New sticker bounces last. No fun fact,
  no end-of-list footer.
- **Module, lesson, simulation and Kuis fisika pages** rebuilt in the L3 style (curved header,
  ticket with notches, tilted tags, leaf cards, stat bubbles, playlist rows, leaf lab card, QQ
  answer options). The simulation scaffold is shared, so every simulation gets the new layout;
  Densitas shows its live canvas in the header polaroid.
- **ELIO robot buddy** (7 moods) exported from `674:26769` as SVG; it replaces the old quiz mascot
  everywhere `LearnArt.mascot` was used. The ELIOS AI mark is untouched.
- Cards 17 (ticket stop pop + path draw, finished tear/XP pop/polaroid sway) and 20 (clover spin,
  count flip, leaves, wiggle) fire only when the value rises, never on first show.

## Phone fixes (11 Nov, after the owner's check)

- Explore and the Discover rails share `SnapRail`: a tail pad lets the far-right card snap to the
  left (module 3 / B3 and the last rail cards were unreachable), S1 + H-select fire only when the
  snapped card changes. Explore is a true skyline: the focused card at the Large size,
  neighbours shrink to the Small size (152 / 204), 90 % opacity. Explore title is Headline 28.
- Archive: photos fan in (rule 7, 40 ms). Swipe left like re-stacking cards: the top photo
  tilts to −17°, flies out left (base, exit), then slides in under the stack as the bottom card
  (expressive, spring/soft) while the next photo comes up; S1 + H-select when it lands. A pull to
  the right only gives 24 dp. Flick threshold is 40 % of the photo width; the whole photo area
  is the touch target (the tilted photo is drawn away from its layout box). While the feed has
  fewer than 3 older guides, today's guide joins at the back, and empty frames fill any slot
  still missing (they hold no content and stay at the back).
- Debug builds log `[ElioSound] <sfx> played` so sounds can be checked over adb.

- Opening the Learn tab no longer glitches: the hub reads the app-wide content providers
  (`learnModulesProvider` and friends, already used by the sidebar), which keep the last data,
  instead of starting four new Firestore streams per visit. That removes the one-frame old
  guide layout, the header jumping from "20 % · no module started" to the real numbers, and the
  archive fading in from blank. The archive fan-in plays once per app session. A cold start
  still loads once.

## Learn entrance (owner request, 11 Nov)

One shared 1.4 s timeline (`LearnIntroHost` + `LearnIntroSlice` in `learn_l3.dart`), on every
Learn open (owner choice), once the hub has its modules and lessons (until then the empty green
header shell shows, never the old guide layout). Reduce Motion shows it at rest. Returning from
a Learn sub-page does not replay it (the hub stays mounted).

| ms | Element | Motion | Sound |
|---|---|---|---|
| 0–580 | header bubbles, "Learn" squiggle | grow (pop), squiggle draws | |
| 0–760 | module ring | ring pops 0.8→1, arcs sweep one after another, % counts up, legend dots pop | S4 at 760 |
| 200–1000 | clover sticker | drops 36 px, turns −26°→0, bounce | S9-short at 1000 |
| 250–1350 | Today's Guide | ticket rises 32 px, polaroid swings −23°→−7°, done stops fill in turn, +XP bounces | S2 at 560 |
| 650–1290 | archive | photos dealt from the top slot to the fan, info slides in | |
| 800–1400 | quick bubbles | pop in left→right (60 ms), badges bounce | |
| 900–1400 | Explore / Discover | squiggle draws, pills slide in, skyline cards rise; Discover cards pop in from 1100 | |

Sounds are quiet (gain 0.5–0.7) and 200 ms apart (the 120 ms gap never drops one). No haptics:
the tab tap already gives one.

## Data rules

Only real app data. Rails come from the module's own videos, guide lessons and quiz sets.
Simulations have no module mapping, so the rail shows the module's related simulation first,
then the others. Guide polaroid captions are the guide's topic; covers are the feed photos.

## Not 1:1 with Figma

- Container transform on open (20d/20e) uses the existing fade-through route (`ElioPageRoute`):
  no `animations` package in the app.
- No Search (module) or Share (lesson) button: the app has neither feature.
- Lesson Play opens the existing YouTube / PDF page; the polaroid straightens and the play
  button shrinks before it opens, there is no inline player.
- Art parallax (19) and "only rails on screen animate" (20c) are not done; rails below the fold
  animate too, unseen.
- The guide quiz deck keeps 56 px answer rows (64 px only on Kuis fisika) so its fixed card fits.
- Chip tones use the existing `toneFg` at 10 % over the surface, like the rest of Learn, not
  separate `chip/*-bg` tokens (the app has none).

## Tests

`test/screens/learn_l3_test.dart` (archive swipe/pull, Discover sync with sounds, module, lesson,
density bins, Kuis flow, RiseWatcher, reduce motion, renders light/dark × EN/ID; set
`LEARN_RENDER=<dir>` to write PNGs). `learn_v2_test.dart` updated for the new layout.
