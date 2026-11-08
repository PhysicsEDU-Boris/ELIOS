# 0191 — Account-owned scan history

Date: 8 November 2026

Use the existing Firebase identity (including anonymous guests). Each UID gets
an independent local records file and photo directory; the old unowned device
history is retained and can only be imported after the user claims it explicitly.
Rebuild the navigation/provider tree when the UID changes so previous detail,
photo, quiz, export and speech state cannot remain visible under another account.
Quiz completion and late explanations retain the store that started the session.

Supabase stores complete record JSON under an owner/id primary key. The existing
Vercel backend verifies the Firebase JWT and supplies the owner from its claims,
never the request body. RLS is enabled and anon/authenticated roles have no table
or RPC privileges. Only server credentials access the table. No Firebase billing.

Cloudinary stores authenticated scan photos under a hashed owner prefix. The
backend checks the owner record before upload/download and proxies downloads;
no permanent public scan-photo URLs or API secrets enter the Flutter app.
Public learning PDFs/thumbnails remain separate. Guide i18n may select a PDF URL
for each language while retaining its original fallback URL.

Local records and the pending upload set are written together using atomic rename.
Sync retries at startup, resume, every minute, and on demand. An indexed
(updated_at, id) cursor downloads only changed records and is persisted atomically
with the records, so paging does not inflate free bandwidth use. Record IDs include
secure random bytes; retries upsert the same ID. Results remain immutable in SQL;
late explanations and translation maps merge. All existing history-derived rewards
and statistics continue to calculate from the complete account record set.

Anonymous sign-out has no recovery credentials: link a permanent identity before
sign-out to guarantee guest recovery. Existing guest-upgrade UI is not added here.

Deployment and physical-device acceptance must be recorded in HANDOFF; local tests
alone do not prove the live accounts, quotas or Cloudinary delivery configuration.

Recovered 4 guide PDFs, 4 covers and 11 thumbnails into Cloudinary zkebg27g.
The app maps exact old public URLs to the recovered URLs; existing Firestore
content is retained. YouTube video IDs are unchanged. Four Indonesian guide editions are published alongside the recovered English
originals; the language switcher selects the matching PDF. Translation source JSON
is in docs/content/guide-translations; original scientific claims are retained.
