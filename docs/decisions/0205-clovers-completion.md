# 0205 — Clovers count finished learning

Date: 12 November 2026. Stacked on `feat/xp-level-retune` (0204). Plan agreed in 0204.

## Problem

Clovers were the Daily Guide reading streak under another name (0197), so they meant
nothing a student could work toward. The Learn % used a hand-tuned weighting
(video 0.4 / guide 0.2 / quiz 0.4) that ignored Daily Guides and simulations.

## Decision

Clovers = finished items. Every item offers a fixed number, so "12 of 40 clovers" is meaningful:

| Item | Clovers |
|---|---|
| Video watched to the end (existing rule: within 2 s of the end) | 1 |
| Module guide read to the last page | 1 |
| Simulation opened (available ones only) | 1 |
| Module quiz best score ≥ 70 % / = 100 % | 1 / +1 |
| Daily Guide issue: story + physics read, quiz passed, lab approved | 1 each |

- Derived from stored completions (`CloverTally.from`, `cloverTallyProvider`); nothing new is saved,
  so it can't drift and existing students get their clovers at once.
- Only items in the current catalogue count, so earned ≤ possible.
- The Learn overall % (header ring, sidebar badge, Progress page) = clovers earned / possible.
  The old weighted getters on `LearningProgress` are removed.
- Header sticker shows clovers earned; the rewards line reads "12 of 40 clovers · 260 XP from Daily Guides".
- The Daily Guide streak still shows on the Daily Guides page; it no longer drives clovers.

## Not done (next)

- Video and lesson-quiz XP into the level total (0204 plan, step 1).
- Per-module % from clovers (module cards still use `moduleProgress`).
- One streak: the Daily Guide streak is still kept beside the scan streak.
- Clovers are computed on the phone from local progress; backend-written awards come with the XP log.
