# 0204 — One XP total for the level, thresholds retuned

Date: 12 November 2026. Stacked on `feat/elios3-motion-more` (0203).

## Problem

Five overlapping numbers: scan trophies (drive the level), Daily Guide XP (shown, but no
effect), clovers (= the guide reading streak), the scan streak, and a weighted Learn %.
Guide XP should count toward the level, but adding it on the old thresholds would lift
every guide reader up a level overnight.

## Decision (this change)

- Level total = scan trophies + daily quest rewards (0144) + Daily Guide XP (0194).
- Thresholds ×1.5: Lv2 150, Lv3 375, Lv4 750, Lv5 1500 (were 100/250/500/1000).
  A student who does both earns ~130 scan + ~60 guide XP a day at most, ≈1.5× the old
  scan-only rate, so a balanced student keeps their level.
- Guide XP stays backend-owned (`ai-backend/guides.js`). `HomeShell` pushes
  `guideProgressProvider.totalXp` into `ScanRecordStore.guideXp`; every level/trophy
  reader goes through `ScanRecordStore.totalTrophies` or `HomeStats.from(guideXp:)`.

Effect on existing students: scan-only students may drop one level (they now need 1.5×);
heavy guide readers may rise. Accepted by the owner (12 Nov).

## Agreed direction (later PRs)

1. **XP = effort**: rename trophies → XP in the UI; add XP for videos (15 at ≥90% watched)
   and lesson quizzes (10 per correct on first try, retakes only the improvement).
2. **Clovers = achievement**: 1 per guide finished, video ≥90%, quiz ≥70%; +1 for a perfect
   quiz. Finite per item, so "23 / 60 clovers" per topic; topic % = clovers / possible,
   replacing the 0.4/0.2/0.4 weighting.
3. **One streak**: scanning. The Daily Guide streak stops driving clovers.
4. Awards as an idempotent event log (one key per user+item+type), totals derived,
   backend-written — the pattern `guides.js` and `questBonus` already use.
