# 0206 — Videos, module guides and lesson quizzes give XP

Date: 12 November 2026. Stacked on `feat/clovers-completion` (0205). Step 1 of the 0204 plan.

## Decision

Lesson XP is added to the level total (scan trophies + quests + Daily Guide XP + lesson XP):

| Activity | XP |
|---|---|
| Video watched to the end | 15 |
| Module guide read to the last page | 10 (same as a Daily Guide story page) |
| Lesson quiz | 10 per correct answer of the best try |

- Derived from `LearningProgress` (`lessonXp`), so nothing new is stored and past lessons count at once.
- XP follows the best score, so a retake adds only its improvement and can't be farmed.
- `learnXpProvider` = Daily Guide XP + lesson XP; `HomeShell` pushes it into
  `ScanRecordStore.learnXp` (renamed from `guideXp`), read by every level/trophy display.

## Effect

Lessons are a finite catalogue (≈10 videos, 4 guides, 3 quiz modules ≈ 500 XP at most), so a
student who already did them all gains up to ~500 XP once and may go up a level or two. That
is earned work, so thresholds stay at 0204's values.

## Not done

- Lesson XP is computed on the phone from local progress, not written by the backend.
- Per-module % from clovers; one streak.
