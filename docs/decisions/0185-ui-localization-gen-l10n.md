# 0185: UI languages with gen-l10n, a sidebar picker and Gemini-filled ARB files

- Status: Proposed (owner asked for it, 5 Nov). L2 phone-tested 5 Nov (Edge 60 Fusion); not checked on the robot.
- Builds on: [0176](0176-cloud-ai-benchmark.md) / [0179](0179-gemini-cloud-ai.md) (same Gemini free key and Flash-Lite model).

## Context

- The UI mixed English and Indonesian text typed straight into widgets; there was no way to pick a language.
- The owner wanted a free, easy setup without writing a JSON file per language by hand.

## Decision

- Flutter's built-in `gen-l10n` (`flutter_localizations`, `intl`, `l10n.yaml`). English `lib/l10n/app_en.arb` is the only file written by hand; `app_id.arb` keeps the app's existing Indonesian wording.
- `tools/l10n/translate_arb.py <lang>` fills `app_<lang>.arb` from English with Gemini 3.5 Flash-Lite (key only from `GEMINI_API_KEY`). It sends only missing keys, so hand fixes stay, and saves nothing if a reply drops a key or changes a `{placeholder}`.
- Translations are generated once and committed, not fetched at runtime: the app works offline, is fast, and every wording change is reviewed in git.
- Sidebar: a language dropdown under Dark mode lists every ARB language by its own name (`languageName`). The choice is saved (`elio_locale_v1`); with no choice the device language is used, falling back to English.
- `context.l10n` falls back to English where no localizations exist (bare `MaterialApp`s in tests).
- The sidebar footer scrolls on short screens so the extra row never squeezes the menu away.

## Initial scope (superseded by L2 below)

- Only the `Text('...')` labels, the sidebar and the picker are localized. Other literals (button labels in other widgets, tooltips, PDF report text in `quiz_pdf_service.dart`, question bank, Gemini prompts and answers) are still single-language.
- Default text changes: strings that were Indonesian now show in English on an English device (and vice versa). Tests were updated to the English text.

## L2: whole app and all content live, ELIO -> ELIOS (5 Nov 2026)

- **UI strings:** every user-visible string in `lib/` goes through ARB. `tools/l10n/audit_strings.py` fails on hard-coded text in Text, labels, tooltips, semantics, SnackBars, dialogs and sheets; exceptions with reasons live in `tools/l10n/audit_allow.txt` (brands, units, formulas, debug-only, prompt-internal topics). Audit: 0. Simulation and physics-module texts moved to ARB (English written from the reviewed Indonesian).
- **Dates and numbers:** intl in the app locale ("Today/Yesterday", "Hari ini/Kemarin", `Hm` = 23:29 / 23.29, `MMMd`), simulations use `fmtNum` (decimal comma in Indonesian).
- **Live switch:** one tap in the sidebar; `MaterialApp.locale` changes, every element rebuilds (`updateCurrentL10n`), open screens update, choice persists in `elio_locale_v1`. Dropdown kept (two-option toggle not done). Speech stops on a switch.
- **ELIOS AI:** the owner's system prompt (in `ai_quiz_service.dart`): every reply is one JSON with `id` and `en`. Identify, questions, explanations, essay grades and chat read the side for their language; a question keeps one shuffle and one correct index in both. A request finishes in the language it started with.
- **History (schema 5):** records keep `lang` (old records migrate as `id`) and `translations.{lang}`. New records save both languages at creation. An old record opened in the other language is translated once by one AI call and cached; replies that move the correct or chosen answer (matched by option index, not wording), change counts or drop texts are rejected and logged; offline shows the original with a note and Coba lagi. TTS and the question PDF use the text shown. Records saved without options (all 120 before H3) translate their answers as text.
- **Bank:** `assets/quiz/*_draft.en.json` (machine translation by Claude, needs owner review; 56 + 64 items, same ids, option order and answers). The bank serves the app language with the other as twin; English item names match the same objects. `tools/l10n/translate_assets.py` (Gemini, same rules as `translate_arb.py`) regenerates them and makes `module_chunks.en.json` (not generated: no key in the session; the app does not load module chunks).
- **Learn (Firestore):** documents may carry `i18n.{en,id}`; models show the app language, else the original field (quiz options only if the count matches). `tools/l10n/translate_firestore.py export en` reads Firestore and writes a review JSON; `upload` is a separate owner command. Nothing was written to Firestore.
- **Native:** iOS/macOS `InfoPlist.strings` (en, id), `CFBundleLocalizations` on macOS, permission texts say ELIOS. Android label is already ELIOS (same in both languages; no per-language variant needed).
- **ai-backend:** prompt cap 8000 -> 16000 characters (a whole record in one translation call). Not deployed: `cd ai-backend && npx vercel --prod`.

### Kept "ELIO" (machine-facing or source names)

- Dart identifiers and files (`ElioTokens`, `elio_sidebar.dart`, `elio_*.svg`), package `elio`, bundle/application id `com.boris.elio`, MethodChannels `elio/pdf`, `elio/app_icon`, `elio/device_health`.
- SharedPreferences keys `elio_*` (incl. `elio_locale_v1`, `elio_esp_config`), `--dart-define=ELIO_ENV`.
- Stored legacy value `Bank Soal ELIO` in old records (mapped to the localized ELIOS bank name when shown).
- `module_chunks.json` `source` path `docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf`: the PDF still says ELIO; the owner re-exports it.
- Robot Wi-Fi password `elio12345` (credential, unchanged). Code comments and a debug log line.

### Not done

- Offline (airplane mode) check on the phone: needs the owner to toggle it (system setting). Covered by unit tests.
- Two-option language toggle; Firestore `i18n` content and `module_chunks.en.json` (owner runs the scripts with `GEMINI_API_KEY`).
- Phone Control captions use the side gap around the 48 dp sliders. `OverflowBoxFit.deferToChild` keeps the caption's natural height; the earlier default fit stretched the column vertically and was reverted. Six real-font regressions (three phone sizes, light/dark) failed on the clipped caption before this fix and pass afterward.
