# 0184: UI languages with gen-l10n, a sidebar picker and Gemini-filled ARB files

- Status: Proposed (owner asked for it, 5 Nov). Not yet checked on the robot or a phone.
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

## Not done

- Only the `Text('...')` labels, the sidebar and the picker are localized. Other literals (button labels in other widgets, tooltips, PDF report text in `quiz_pdf_service.dart`, question bank, Gemini prompts and answers) are still single-language.
- Default text changes: strings that were Indonesian now show in English on an English device (and vice versa). Tests were updated to the English text.
