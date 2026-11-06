# 0188: Should History live in the cloud?

- Status: Proposed (research only, 7 Nov 2026). No app code, no sign-up, no cloud setting changed.
- Builds on: [0184](0184-history-h3-ai-explanations.md), [0185](0185-ui-localization-gen-l10n.md) (schema v5), [0187](0187-h3-history-redesign.md), [0179](0179-gemini-cloud-ai.md) (ai-backend on Vercel sin1, Firebase ID token).

## Short answer

1. **Storage is not a reason to move History to the cloud.** A student who scans 20 times a day for a whole school year fills about 300 MB. The phone already spends more than that (about 300 MB) on WebView cache.
2. **Shrink first:** save History photos at JPEG quality 85 with a size cap (they are saved at quality 100 now), and limit or clear the WebView cache. The 140 MB of debug assets disappears in a release build.
3. **The cloud is useful for other reasons:** a backup if the phone is lost or reset, the same History on a new phone, and later a teacher view. If the owner wants that, use **Firestore** (already in the app, free Spark plan, Firebase Auth rules, built-in offline queue) for the record JSON only, with **local-first background sync**. Photos stay on the phone. Photos go to **Cloudflare R2** only if the owner later wants photo backup (10 GB free, free egress, signed URLs from ai-backend).

## 1. Numbers (measured on the owner's Edge 60 Fusion, 7 Nov 2026, 45 real scans)

| Item | Size |
|---|---|
| `scan_records.json` | 180 KB (~4.3 KB per record, largest 13 KB) |
| Crop photos `app_flutter/scans/` | 48 files, 3.3 MB (~68 KB each) |
| **History per scan** | **~75 KB** (photo ~68 + JSON ~4.3, ignoring PDFs) |
| WebView HTTP cache | ~300 MB |
| Debug `flutter_assets` copy | ~140 MB (debug build only) |
| Total app data | 478 MB |

Growth, assuming 200 school days per year and today's 75 KB per scan:

| Scans per day | Per student per year | 30 students | 100 students |
|---|---|---|---|
| 5 | 1,000 scans = **75 MB** (JSON 4.3 MB) | 2.2 GB (JSON 130 MB) | 7.5 GB (JSON 430 MB) |
| 20 | 4,000 scans = **300 MB** (JSON 17 MB) | 9 GB (JSON 520 MB) | 30 GB (JSON 1.7 GB) |

On one phone, a heavy year (300 MB) is about 0.2 % of 128 GB. The per-student column is what each phone holds. The class columns are what a cloud would hold, and they decide which free tier fits.

## 2. What History is, and what else uses space

- **Records JSON** (`lib/models/scan_record.dart`, saved by `lib/services/scan_record_store.dart` as one file in the app documents dir, `scan_records.json`, or `SCAN_RECORDS_FILE` in test builds). Each record holds the id, time, item name, category, difficulty, trophies, language, the crop photo path, schema v5, and for each question: the question, options, your answer, the right answer, correct or not, essay score, the bank explanation, `wrongWhy`, the saved ELIOS AI explanation, and a translation cache per language.
- **Crop photos** in `scans/` (`scans_<file>/` in test builds), written by `waste_quiz_provider.dart`. `detection_crop.dart` encodes them at **JPEG quality 100** with no size cap. Quality 85 and a long edge of about 720 px should make them several times smaller with no visible loss on a phone screen. This is an estimate: measure it on the robot's real crops before choosing.
- **Question PDFs**: on Android they go to Download/ELIOS (shared storage, outside app data). `reports/` in the app documents dir is used only on other platforms. Users can delete them, and they can always be made again from the record.
- **Not History:** the WebView cache (~300 MB, from the WebView pages and videos the app opens) and the debug asset copy (~140 MB). The WebView cache can be cleared on a schedule or when it passes a size (for example `WebView.clearCache` when the Learn screen closes, or once a week). A release APK does not copy `flutter_assets`.

## 3. Free-tier comparison (official pages, read 7 Nov 2026)

| | Firebase Firestore | Firebase Cloud Storage | Supabase | Cloudflare R2 (+D1) | Vercel Blob (+Neon Postgres) | Google Drive appDataFolder |
|---|---|---|---|---|---|---|
| Free storage | 1 GiB | **Needs Blaze**: no Spark quota. On Blaze: 5 GB-month free | DB 500 MB, files 1 GB | R2 10 GB-month; D1 5 GB | Blob 1 GB; Neon 1 GB per project | The user's own Drive (15 GB shared with Gmail and Photos) |
| Free traffic | 10 GiB/month egress | Blaze: 100 GB/month download | 5 GB egress (+5 GB cached) | **Egress free** | Blob 10 GB; Neon 5 GB | User's quota |
| Free ops | 50K reads, 20K writes, 20K deletes per day | Blaze: 5K uploads, 50K downloads per month | 50K MAU | R2 1M writes, 10M reads per month; D1 5M rows read, 100K written per day | Blob **2,000 uploads**, 10K reads per month | Not listed |
| Nearest region to Jakarta | **asia-southeast2 Jakarta** (or asia-southeast1 Singapore). Fixed at creation | Same GCP regions | Singapore `ap-southeast-1` (no Jakarta) | `apac` hint only (best effort, no Singapore option) | Store region chosen from 19 (sin1 Singapore); Neon not confirmed | Google picks |
| Offline | Built in on Android/iOS: 100 MB cache, writes queued, last write wins | None (app code) | None (app code) | None (app code) | None (app code) | None (app code) |
| Auth fit | Native Firebase Auth security rules | Native rules | Accepts Firebase ID tokens via Third-Party Auth, but needs a `role: authenticated` custom claim (Cloud Function, which needs Blaze, or an admin script) | ai-backend checks the token, then signs R2 URLs | ai-backend checks the token (already does) | Separate Google OAuth consent (`drive.appdata`, non-sensitive) |
| Over the limit | Spark: requests fail until the next day (no bill) | Blaze: pay as you go | Free projects **pause after 1 week inactive** (school holidays). Pro $25/month | $0.015/GB-month, $4.50 per M writes | Hobby: **Blob blocked for 30 days**. Pro plan | The user's Drive fills up |
| Students' photos | Private per uid by rules | Private by rules | Private by RLS | Private bucket, short-lived signed URLs | Private store only (public URLs are open to anyone with the link) | In each student's own account (their data, our app can't reach it) |
| Already in the app | `cloud_firestore` (users, learning progress, Learn content) | `firebase_storage` in pubspec, unused | No | No (Worker deleted 3 Nov; Gemini refused Cloudflare, storage is separate) | ai-backend project | `google_sign_in` |

Notes:
- **Latency** was not measured. Firestore in Jakarta or Singapore is one short hop from Indonesia. All the other options are Singapore or "somewhere in APAC". Because the design below is local-first, the user never waits on the cloud: the History screen reads the local file, and sync runs in the background. So latency does not decide the choice.
- The Firestore location of project `elio-apps` is already fixed and was not checked here. Check it (read-only) in Console > Firestore > Settings.
- Firebase Storage on Spark: Google's Sept 2024 change ended Spark access to Cloud Storage. Since 3 Feb 2026 a project not on Blaze cannot read or write any Storage bucket, so it is out while Blaze is skipped.
- Vercel Postgres no longer exists as a Vercel product. Postgres comes through the Marketplace (Neon).

## 4. Recommendation

**Phase 0 (no cloud, do first):** History photos at quality 85 with a long-edge cap (identify and Gemini crops unchanged), a WebView cache limit or clear, and a release build for students. This answers the storage worry.

**Phase 1 (if the owner wants backup or a new phone): Firestore for record JSON, local-first.**
- Path `users/{uid}/scans/{recordId}`: the record's `toJson()` plus `updatedAt` (server time) and `deleted` (bool). The local `cropPhotoPath` is stored but means nothing on another phone. A record is at most 13 KB (the document limit is 1 MiB).
- **Stays local:** the photos, `scan_records.json` (still what the screens read), guest History, test-build files (`SCAN_RECORDS_FILE` set means sync is off), PDFs.
- **Sync:** after each local save, mark the record dirty and push it with `set(merge)`. Firestore's offline queue retries. On sign-in on a new phone, pull all records once and merge.
- **Conflicts:** match records by `id`. Merge each record field by field: keep answered questions, keep a non-empty AI explanation over an empty one, and take the union of the translations. For other fields the newer `updatedAt` wins. Deletes are tombstones (`deleted: true`). **A pull only adds or updates local records. It never deletes a local record or photo.** Only the user's own delete in the app removes local data.
- **Cost check:** 45 records = 45 writes once. 20 scans/day × ~3 writes (answer, explanation, translation) = 60 writes per student per day, so the 20K/day free writes cover about 300 active students. 1 GiB holds a year of JSON for about 60 students at 20 scans/day or 230 at 5 scans/day.
- **Rules (owner deploys):** `match /users/{uid}/scans/{id} { allow read, write: if request.auth.uid == uid; }`, plus a size check.
- Set the Firestore cache to about 20 MB, so the 100 MB default does not add a second copy of History on the phone.

**Phase 2 (only if photo backup is wanted):** Cloudflare R2 private bucket (`apac` hint). ai-backend gets `/api/photo-url`: it checks the Firebase ID token and returns a short-lived presigned PUT/GET for `u/{uid}/{recordId}.jpg`. At about 25 KB per shrunk photo, 10 GB holds about 400K photos, and egress is free. The alternative: if the owner later moves to Blaze, use Firebase Storage (5 GB free, same rules, no new vendor).

**Not chosen:** Supabase (pauses after a week idle, Firebase tokens need a custom claim), Vercel Blob (2,000 uploads a month, then blocked for 30 days), Drive appDataFolder (a second Google consent, each student's quota, no teacher view).

**Privacy:** students are minors. Photos may show hands, faces or classrooms, so photo upload must be opt-in. Ask for school or parent consent before any upload. Indonesia's PDP law (UU 27/2022) treats children's data as specific personal data. Keep the data private per uid and never use public URLs.

## Migration (Phase 1), rough steps

1. Before the first sync, **copy** `scan_records.json` to `scan_records.pre-sync.json`. It is a copy, never a move, and it is never deleted by the app.
2. Upload every local record once, then set `historySyncedUid` in settings. Records already in the cloud are merged by the rules above.
3. A different user signing in on the same phone keeps their records apart (records sync only under the uid that made them; add `ownerUid` to new records).
4. Tests: a merge unit test (local-only, remote-only, both with a translation union, tombstone), a test that a pull never deletes local data, and a fake_cloud_firestore round-trip. Break-check each against a naive "overwrite local" merge.
5. Phone check: md5 of `scan_records.json` and `scans/` before and after the first sync, on a test build (`SCAN_RECORDS_FILE`) first.

## Owner decisions needed

- Phase 0 only, or Phase 0 + 1? Is photo backup (Phase 2) wanted?
- Deploy the Firestore rules and check the `elio-apps` Firestore location (cloud setting, owner's OK).
- R2 (Cloudflare account) or Blaze, if photos go to the cloud. Nothing has been signed up for.

## Sources (read 7 Nov 2026)

- Firebase pricing: https://firebase.google.com/pricing
- Firebase Storage Spark change: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Firestore locations: https://firebase.google.com/docs/firestore/locations; offline: https://firebase.google.com/docs/firestore/manage-data/enable-offline
- Supabase pricing: https://supabase.com/pricing; regions: https://supabase.com/docs/guides/platform/regions; Firebase auth: https://supabase.com/docs/guides/auth/third-party/firebase-auth
- R2 pricing: https://developers.cloudflare.com/r2/pricing/; location: https://developers.cloudflare.com/r2/reference/data-location/; D1: https://developers.cloudflare.com/d1/platform/pricing/
- Vercel Blob: https://vercel.com/docs/vercel-blob/usage-and-pricing, https://vercel.com/docs/vercel-blob; Neon: https://neon.com/pricing
- Drive app data: https://developers.google.com/workspace/drive/api/guides/appdata (quota use is not stated there; forum reports say it counts against the user's Drive)
