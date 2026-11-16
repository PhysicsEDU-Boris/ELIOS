# 0218 — Language switch: saved scans open at once, Today's Guide follows the app language

Date: 16 November 2026. Branch `fix/language-switch-sync` (from `feature/live-scan` 86f078e).
Owner report: after switching EN ↔ ID, a scan opened from History stays on the skeleton for a
long time, and Learn → Today's Guide keeps the old language.

## What was measured

- Scan detail (`ScanDetailScreen`): on a language the record has no cached translation for, it
  asked ELIOS AI for one (`HistoryTranslationService.ensure`, one call, cached per scan +
  language since 0185) and showed the **whole page as a skeleton** until the reply or the 15 s
  timeout. Nothing was re-generated; the wait was the translation call alone. The explanation
  page did the same for up to 45 s even when the explanation was already saved.
- Today's Guide: with no guide-language pick, the ticket already rebuilt in the first frame
  (the test passes on the old code). It stayed in the old language when the student had once
  used the EN/ID switch **inside a guide**: that pick is stored and wins over the app language,
  so the title, cover polaroid and topic never followed the app.

## Decision

- Saved content shows immediately. While the translation is fetched a small "Translating…"
  note sits on top; the text is replaced in place when it arrives, and the existing "Shown in
  …, connect to translate" note with Try again appears when it fails. The cache per scan +
  language is unchanged (one request, then never again). Each request logs its duration
  (`[HistoryTranslation] <id> -> <lang>: … ms`).
- The explanation page shows a skeleton only when no explanation is saved yet.
- Switching the app language clears the in-guide language pick, so guides follow the app
  again. The switch inside a guide still works and holds until the next app language change.
- `guideLangOf` reads the language from the widget's `Localizations` (not the global `l10n`),
  and the ticket uses `context.l10n`, so it depends on the locale directly.

## Tests

`test/l10n/language_switch_sync_test.dart`: ticket switches in one frame (light/dark); app
switch wins over an in-guide pick; scan detail (EN and ID) and the explanation page show
content while the fake network never answers. Break-check: the History tests and the pick test
fail on the old code. The one-frame ticket test passes on the old code too (kept as a guard).

## Not done

- The first open in a new language still needs one online translation; it is not pre-fetched
  when the language is switched.
