# 0214 — Module % from clovers, one streak

Date: 12 November 2026. Based on `feature/live-scan` after #121. Step 3 of the 0210 plan.

## Module cards use clovers

`moduleProgress` (module cards, module page, lesson page, Progress page, Learn legend) is now
the module's clovers earned / possible, the same rule as the Learn ring (0211):

- each video and module guide of the module: 1 when finished
- the module quiz: 1 at ≥ 70 %, +1 at 100 %

A half-watched video or half-read guide no longer counts towards the module % (it still shows
its own "40 %" sticker and stays in Continue learning). A module is "done" only when all its
clovers are collected, including a perfect quiz.

## One streak: scanning

The scan streak (Home "days in a row") is the app's only streak. On the Daily Guides page:

- the reading-streak headline ("3-day reading streak") is now "Your reading this week"; the
  week's 7 days, guide XP and their pop-in motion stay; the fire icons are now a book
- the archive line drops its streak ("12 issues · 3-day streak" → "12 issues")
- the hint reads "Read today's guide to earn XP and clovers"

The backend still computes the guide streak (`ai-backend/guides.js`); the app no longer shows it.

## Unchanged

Quiz grades (Sempurna, Hebat, Bagus, Belajar Lagi, Coba Lagi) still grade a single quiz.
Backend-written awards remain a later step.
