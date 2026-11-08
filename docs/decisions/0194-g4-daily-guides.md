# 0194 — G4 Daily Guides in the app

Date: 9 November 2026

Implements the approved Figma "G4 · Daily Guides (app)" (J2jSbARJSyJCStNFeWkWDj, page 537:2358) on top of 0193.

- Manifest v1 and v2 are both read; one bad entry is skipped and logged. `pages`, `theme`, `photo`,
  `content_sha` and `xp_parts` (or an `xp` object) are used when present. Revision/content_sha are
  cache keys in every asset URL; progress is keyed by issue date, so republished issues keep it.
- Progress is server-written (`ai-backend/api/guides.js`, ops progress/event/quiz/lab/review/import),
  same auth pattern as 0191. The quiz is graded and the lab rubric read from the published JSON,
  never from the client. Streaks are in Asia/Jakarta days; days without an issue never break them.
- The phone keeps a durable per-uid queue of idempotent events (file + atomic rename), shows it at
  once, and replaces totals with each server reply. #102 page positions are migrated.
- Guest import: the server signs a guest claim (HMAC with the Supabase key); another account on the
  same phone may import it only after an explicit confirmation.
- Mini lab keeps no video: one 512 px JPEG 70 frame per second stays in memory, 8 are picked, shown,
  sent only on Send, then dropped.

Differences from the Figma/prompt: share buttons omitted (no share plugin); source links are copied,
not opened (no url_launcher dependency); parked quiz cards sit at -95 % so a sliver shows as in the
Figma; migration lives in `supabase/migrations/` (repo convention), not `ai-backend/migrations/`.
