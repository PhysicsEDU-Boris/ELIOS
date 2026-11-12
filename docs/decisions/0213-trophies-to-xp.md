# 0213 — "Trophies" become "XP" everywhere

Date: 12 November 2026. Stacked on `feat/lesson-xp` (PR #120, 0210–0212). Step 2 of the 0210 plan.

## Problem

After 0210–0212 the level total counts scan trophies, quest rewards, Daily Guide XP and lesson
XP, so "trophies" and "XP" are the same points under two names. Indonesian also mixed
"trofi" and "piala".

## Decision

- Every user-visible "trophies" / "trofi" / "piala" reads **XP** (37 strings in EN and ID: Home,
  History, quiz popup and explanation, result card, Control, contribute, PDF export, a11y labels).
- Two numbers remain for students: **XP** (all effort, sets the level) and **clovers** (finished
  items, sets the Learn %). The scan streak stays as the habit number.
- Text only. Internal names (`trophies` fields, `totalTrophies`, ARB keys, History JSON,
  `ai-backend/history.js`) are unchanged, so stored data and old History files load as before.
- The trophy artwork (sticker, pills) is kept for now; replacing it is a design task.
- Quiz grades (Sempurna, Hebat, Bagus, …) are unchanged: they grade one quiz, not progress.
