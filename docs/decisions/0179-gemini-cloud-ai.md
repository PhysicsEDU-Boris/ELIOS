# 0179: ELIOS AI moves to the Gemini API through a Vercel function; on-device Gemma removed

- Status: Accepted (owner, 3 Nov 2026: the key lives in a backend, free-tier key for now; Vercel in Singapore after Firebase Blaze (200k IDR prepayment) and Cloudflare (Gemini refuses its locations) did not work).
- Date: 2026-11-03
- Builds on: [0176](0176-cloud-ai-benchmark.md) (chain and switch rules), 0017/0018/0145 (question source), 0040 (tester build).

## Decision

- **Where the key lives:** in the `ai-backend` Vercel function (`ai-backend/`, Vercel team ELIOS,
  Hobby plan, region `sin1` Singapore), as the secret env var `GEMINI_API_KEY`. The app never holds
  it. Tried first: a Firebase Function (needs the Blaze plan, which asked for a 200k IDR prepayment)
  and a Cloudflare Worker (Gemini answered "User location is not supported" from most Cloudflare
  locations, even through AI Gateway or with US placement). Gemini serves Singapore.
- **Only signed-in users** (guests included) can call it: the app sends the student's Firebase ID
  token, and the backend checks its RS256 signature against Google's published keys, the `elio-apps`
  audience and issuer, the user and the expiry (`ai-backend/auth.js`) before it spends the key.
- **The chain runs in the backend** (`ai-backend/chain.js`): `gemini-3.5-flash-lite` →
  `gemini-3.1-flash-lite` → `gemini-3-flash-preview` → `gemini-3.6-flash` →
  `gemini-robotics-er-2-preview`. Switch rules as in 0176: 429 daily cap rests the model until
  midnight Pacific; 429 per minute rests it for the `retryDelay`; 5xx or an 8 s timeout goes to the
  next model and rests that one 60 s; 404 drops it; an empty or invalid-JSON reply gets one retry on
  the same model. Each answer returns and logs the model that gave it.
- **The app** (`lib/services/ai_quiz_service.dart`, was `gemma_quiz_service.dart`) keeps its prompts,
  angles, parsing and one-request-at-a-time slot, and POSTs each request (prompt, optional 512 px JPEG,
  JSON or plain text) to the backend (`AiQuizService.workerUrl`, or `--dart-define=ELIOS_AI_URL`). Identify, quiz questions, essay grading and chat all use it.
- **Offline fallback is the question bank.** With no AI answer (no internet, every model busy or
  capped, a banned topic twice), an ELIOS AI quiz takes its question from the bank for the rest of the
  session and says "AI tidak tersambung, jadi soal ini dari bank soal." A failed photo identify shows
  "AI belum bisa membaca foto. Periksa internet, lalu coba lagi."
- **Default question source is ELIOS AI**, in every build (0018 kept it debug-only because Gemma was
  slow; the gate is gone). The Config tiles and the tester switch still let you pick the bank. A
  saved "gemma" choice from before this change reads as ELIOS AI.
- **Removed:** `flutter_gemma` and `flutter_gemma_litertlm`, the model install/copy/sideload, warm-up,
  the thermal gate and killed-run check, the Android thermal/memory/exit-reason channel, the macOS
  LiteRT-LM build phase, the Config card's Activate/Loading/Paused states, the scan screen's "loading"
  and "model missing" states, and the four on-device integration tests.

- **Free tier for now** (owner, 3 Nov). The chain order fits the free caps: 3.5 Flash-Lite and
  3.1 Flash-Lite allow 500 calls a day, the other three 20 each (about 1,060 a day together); a
  capped model is skipped until the reset, so only when all are capped does the bank take over.

## Open items / limits

- **Move to a paid key before students use it.** On the free tier Google may use the prompts and
  the students' photos to improve its products. Paid also lifts the 20-per-day caps.
- **Owner steps:** Vercel account, `npx vercel login`, and adding the key (`vercel env add
  GEMINI_API_KEY production` in `ai-backend/`) are the owner's; the key is never printed or committed.
  Deploy: `npx vercel deploy --prod --scope elios5` in `ai-backend/`.
- Rest times live in one function instance's memory; a cold start forgets them.
- Phone test, 3 Nov (Edge 60 Fusion): identify and 3 AI questions, about 1.1-1.4 s per call at the
  backend, 1.6 s on the phone; one 3.5 Flash-Lite timeout fell through to 3.1 Flash-Lite as designed.
- The Cloudflare Worker `elios-ai` from the first attempt was deleted (3 Nov).
- No App Check: any signed-in user of `elio-apps`, guests included, could call the backend.
- Android `minSdk` stays 30 (it was set for Gemma); lower versions are untested.
