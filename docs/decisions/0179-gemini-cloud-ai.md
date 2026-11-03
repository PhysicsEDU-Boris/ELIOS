# 0179: ELIOS AI moves to the Gemini API through a Cloudflare Worker; on-device Gemma removed

- Status: Accepted (owner, 3 Nov 2026: the key lives in a backend, free-tier key for now; Cloudflare Worker instead of a Firebase Function because Blaze needs a 200k IDR prepayment).
- Date: 2026-11-03
- Builds on: [0176](0176-cloud-ai-benchmark.md) (chain and switch rules), 0017/0018/0145 (question source), 0040 (tester build).

## Decision

- **Where the key lives:** in the `elios-ai` Cloudflare Worker (`worker/`, free plan, no card), as
  the secret `GEMINI_API_KEY`. The app never holds it. The 0176 recommendation was a Firebase
  Function; that needs the Blaze plan, which asked the owner for a 200k IDR prepayment, so the same
  code runs on Cloudflare instead (free: 100,000 requests a day).
- **Only signed-in users** (guests included) can call it: the app sends the student's Firebase ID
  token, and the Worker checks its RS256 signature against Google's published keys, the `elio-apps`
  audience and issuer, the user and the expiry (`worker/auth.js`) before it spends the key.
- **The chain runs in the Worker** (`worker/chain.js`): `gemini-3.5-flash-lite` →
  `gemini-3.1-flash-lite` → `gemini-3-flash-preview` → `gemini-3.6-flash` →
  `gemini-robotics-er-2-preview`. Switch rules as in 0176: 429 daily cap rests the model until
  midnight Pacific; 429 per minute rests it for the `retryDelay`; 5xx or an 8 s timeout goes to the
  next model and rests that one 60 s; 404 drops it; an empty or invalid-JSON reply gets one retry on
  the same model. Each answer returns and logs the model that gave it.
- **The app** (`lib/services/ai_quiz_service.dart`, was `gemma_quiz_service.dart`) keeps its prompts,
  angles, parsing and one-request-at-a-time slot, and POSTs each request (prompt, optional 512 px JPEG,
  JSON or plain text) to the Worker (`AiQuizService.workerUrl`, or `--dart-define=ELIOS_AI_URL`). Identify, quiz questions, essay grading and chat all use it.
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
- **Owner steps:** a free Cloudflare account, `npx wrangler@4 login`, and setting the secret
  (`npx wrangler@4 secret put GEMINI_API_KEY` in `worker/`) are the owner's; the key is never printed
  or committed. Then `npx wrangler@4 deploy`. Until then every AI call fails and quizzes use the bank.
- Rest times live in each Worker isolate's memory, not shared between Cloudflare locations; a fresh
  isolate meets a capped model's 429 once more. Move them to Workers KV if that shows up in logs.
- No App Check: any signed-in user of `elio-apps`, guests included, could call the Worker.
- If Cloudflare runs the Worker in a location Gemini does not serve, Gemini answers 400 "location not
  supported"; the chain then fails to the bank. Checked on the first deploy.
- Android `minSdk` stays 30 (it was set for Gemma); lower versions are untested.
