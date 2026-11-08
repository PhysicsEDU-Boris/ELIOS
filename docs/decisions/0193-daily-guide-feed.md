# 0193 — Daily bilingual guide feed

Accepted, 8 November 2026. Owner authorized the daily learning feed and publishing setup.

Read the public elios-guides GitHub Pages manifest directly. No new backend service, Firebase write
access or app secrets are needed. The separate Daily Guide entry remains accessible while existing
Firestore modules are loading, empty or unavailable. Existing courses and videos are unchanged.

Validate dates, duplicate issue IDs, bilingual text, asset revisions and relative issue asset paths
before caching a manifest. Fetch on opening, manual refresh and app resume; use the last validated
catalogue offline. Display newest first, with an archive and explicit empty/offline/error states.
Reuse GuideLesson and the existing cached PDF viewer. Match the selected EN/ID language; retain
stable daily-date IDs while revisioned URLs fetch corrected assets.

Store daily reading position in SharedPreferences under UID and issue ID. This keeps date-based
reading position across languages and avoids counting news guides as completed waste-course lessons.
Daily progress is local to this device and account; it does not award manifest XP or sync to Firestore.
Opened PDFs use the existing bounded cache and may be evicted; this is not a permanent download manager.

The separate elios-guides PR makes research daily and publishes validated EN/ID exports to Pages through
a public-only published branch. The owner confirms the existing 05:00 WIB Claude/Figma task runs daily.
Research runs at 03:00 WIB; a health workflow checks for today's publication at 08:00 WIB. GitHub Actions
failure notifications cover missing issues. Schedules and quotas do not guarantee delivery at a fixed time.

Verification: focused parser/cache/UI tests; old LearnHub fails the new empty-module entry test;
backend asset-revision test fails against old manifest code. Restored tests pass. Physical-device PDF
viewing and offline reopening remain a release check. No Mac bundle/model/signing change for this task.
