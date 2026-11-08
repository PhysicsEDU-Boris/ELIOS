# Account history deployment (0191)

- Supabase: ELIOS / `tymiikfebewqvuokoyru`, Free, Sydney.
- Backend: Vercel `elios5/ai-backend`, `/api/history` on the existing production domain.
- Cloudinary: `zkebg27g`; public learning assets and authenticated private scan photos.
- Schema: `supabase/migrations/202611080001_scan_history.sql` (already applied live).
- Production environment: `SUPABASE_URL`, `SUPABASE_SECRET_KEY`,
  `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`.
  Secret values live only in Vercel; never copy them into Flutter or Git.
- No billing plan was upgraded. Free quotas and Supabase inactivity pausing still apply.

The app keeps records and pending writes under `accounts/<encoded Firebase UID>/`.
Switching UID replaces the navigation/provider tree. The previous account's cache
stays on disk for its next sign-in. Unowned legacy files remain intact; import
requires the student's explicit confirmation. A guest's Firebase UID is temporary:
ordinary anonymous sign-out does not provide recovery credentials.

Sync runs on launch, resume, new results/updates, every minute, and from History's
sync button. A durable `(updated_at,id)` cursor downloads only changed records.
The backend supplies ownership from the verified Firebase token. Cloudinary
private download URLs are never exposed to other users or stored as public links.

Four original English guides, four covers and eleven thumbnails were recovered.
Four Indonesian PDF editions were translated from those guides and rendered for
layout review; the original scientific claims and references were retained.
Translation sources are in `docs/content/guide-translations/`. Exact old URLs map
to the new public assets in `lib/models/content_media.dart`; Firestore documents
and YouTube video IDs were not changed. An explicit per-language Firestore
`i18n.<lang>.pdfUrl` also works for future editions.

Phone acceptance: sign in as A, complete a scan/quiz, check its photo, explanation,
PDF and EN/ID switch; switch to B (A's record/counters disappear); return to A;
repeat offline and reconnect; test guest isolation. No robot firmware changes.
