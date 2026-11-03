# 0179: ELIOS AI moves to the Gemini API through a Firebase Function; on-device Gemma removed

- Status: Accepted (owner, 3 Nov 2026: the key lives in a Firebase Function). Free or paid key still open.
- Date: 2026-11-03
- Builds on: [0176](0176-cloud-ai-benchmark.md) (chain and switch rules), 0017/0018/0145 (question source), 0040 (tester build).

## Decision

- **Where the key lives:** in the `eliosAi` callable Firebase Function (`functions/`, region
  `asia-southeast2`, Firebase project `elio-apps`), as the secret `GEMINI_API_KEY`. The app never
  holds it. Only signed-in users (guests included) can call the function.
- **The chain runs in the function** (`functions/chain.js`): `gemini-3.5-flash-lite` →
  `gemini-3.1-flash-lite` → `gemini-3-flash-preview` → `gemini-3.6-flash` →
  `gemini-robotics-er-2-preview`. Switch rules as in 0176: 429 daily cap rests the model until
  midnight Pacific; 429 per minute rests it for the `retryDelay`; 5xx or an 8 s timeout goes to the
  next model and rests that one 60 s; 404 drops it; an empty or invalid-JSON reply gets one retry on
  the same model. Each answer returns and logs the model that gave it. One function instance
  (`maxInstances: 1`) so the rest times are shared.
- **The app** (`lib/services/ai_quiz_service.dart`, was `gemma_quiz_service.dart`) keeps its prompts,
  angles, parsing and one-request-at-a-time slot, and sends each request (prompt, optional 512 px JPEG,
  JSON or plain text) to the function. Identify, quiz questions, essay grading and chat all use it.
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

## Not done / limits

- **Free or paid key** (0176 decision 2) is still the owner's call. On the free tier Google may use
  prompts and photos to improve its products, and most chain models cap at 20 calls a day.
- **Deploying** needs the owner: Firebase Blaze plan on `elio-apps`, `firebase login`, the secret, then
  `firebase deploy --only functions`. Until then every AI call fails and quizzes use the bank.
- Rest times live in one function instance's memory: a cold start forgets them (the first call
  then simply meets the same 429 again).
- No App Check: any signed-in user of the project could call the function. Upgrade if abuse shows up.
- Android `minSdk` stays 30 (it was set for Gemma); lower versions are untested.
