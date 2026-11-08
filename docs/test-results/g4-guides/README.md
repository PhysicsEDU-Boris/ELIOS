# G4-A validation — 9 November 2026

- Full `flutter test --no-pub`: 1419 passed, 20 skipped, no failures.
- `flutter analyze --no-pub`: no issues.
- `npm test` in `ai-backend`: 26 passed.
- `bash scripts/check-secrets.sh`: clean. String audit: 0.
- Test fixes: in-memory progress except the real-file restart test, remove unused widget temp directories, restore inherited fake-camera disposal, clear analyzer lints, repair the stale legacy-radius assertion without changing tokens.
- Existing `app/` renders: 48 EN/ID × light/dark frames plus 48 Figma comparisons; render tests pass in the full suite. Images were not regenerated in this continuation.
- Preview: https://ai-backend-24phg5dz3-elios5.vercel.app (Vercel authentication protection). `vercel curl` POST `/api/guides` with no Firebase token returned 401 `Sign in first`.
- Owner must apply `supabase/migrations/202611090001_guide_progress.sql`, then `cd ai-backend && npx vercel --prod`. No migration or production deployment performed.
- Device smoke check remains: Learn → Today/Guides → EN/ID issue → quiz → lab; read offline, restart and reconnect. No app build/install or model/firmware/signing changes.
