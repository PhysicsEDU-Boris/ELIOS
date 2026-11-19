# H3 validation — 5 Nov 2026

## Automated checks

- `flutter test --no-pub`: **1,235 passed, 20 skipped, 2 baseline failures**. The failing `test/theme/elio_tokens_test.dart` cases are “type scale matches the table” and “spacing scale and radii match the tables”. Both this test file and `lib/theme/elio_tokens.dart` are byte-identical to `origin/feature/live-scan`.
- `flutter analyze --no-pub`: no errors/warnings; two existing informational findings in unchanged `test/m2c_identification_test.dart:7` and `test/question_bank_integrity_test.dart:104` (exit 1 because infos count).
- Focused H3/compatibility run: **110 passed**; original H3-only matrix: **75 passed**. Native-QA refinements add nine passing regressions (six styles, note pagination and two Android-save paths); the PDF group now passes 19 cases.
- `git diff --check`: clean. `scripts/check-secrets.sh`: clean on the staged task diff.
- Per-question A4 PDF rendered with bundled Poppler and visually inspected, including the photo and notes. Native USB acceptance, live Gemini and downloaded PDF evidence: [phone report](0184-history-h3-phone.md). No Mac build.

Coverage: explanation JSON validation and caps; correct-option protection; reviewed wrongWhy precedence; one retry; exact saved answer input; shared request slot; concurrent opens; durable cache/reopen/PDF; unavailable result persistence and explicit retry; schema migration; failed writes; late TTS setup; all 16 PDF include combinations with source exclusion; light/dark list, detail, explanation, sheet, empty and three skeleton layouts; timeout/retry; crop containment and damaged/missing files; section switching, pause, background and route exit; one selected History nav tab.

## Break-checks

The initial offline regression test failed against the old implementation: it generated a local classification reason. Then all 75 core H3 cases (including the JSON validation matrix), the two draft-bank guards and the existing essay-provenance regression detected at least one deliberate runtime regression; all implementation files were restored afterward. No compile-error run is counted as a break-check.

| Deliberate regression | Failing cases |
| --- | ---: |
| routes-filters-nav | 14 |
| loading-motion-timeout | 9 |
| cache-migration-write | 7 |
| pdf-options-sources | 16 |
| tts-stop-race | 2 |
| bank-offline | 3 |
| validation | 13 |
| photo-containment | 12 |
| essay | 1 |
| invalid saved inputs / empty bank metadata | 3 |
| draft bank provenance | 1 |
| draft bank answer announcement | 1 |
| essay AI provenance | 1 |
| Indonesian nav copy | 2 |
| Native chip/title/action styling | 6 |
| PDF notes pagination | 1 |
| Android public save / storage failure | 2 |

Examples include removing validation, bank precedence, durable cache/migration/write failure reporting, PDF options/source exclusion, phone/wide navigation and filtering, single selected tab, timeouts/reduced motion, TTS stop/race guards, crop containment and essay presentation.

## Screenshots

Flutter test renderer, 390×844, isolated saved-question fixture (no owner History writes):

- [Explanation, light](../screenshots/h3/explanation-light.png)
- [Explanation, dark](../screenshots/h3/explanation-dark.png)
- [Sections and buddy art, light](../screenshots/h3/explanation-light-sections.png)
- [Sections and buddy art, dark](../screenshots/h3/explanation-dark-sections.png)

The five downloaded Figma SVGs are local/nonempty. Empty art is byte-identical between the light/dark frames (one asset retained). Buddy art is verified at 64×76 dp; empty art is 240×180; category fallback icons are 40×40 (88×88 in detail). The only fixed widget color is the export thumbnail's white A4 paper.

## Files changed

- UI: `lib/Screens/scan_history_screen.dart`, `question_explanation_screen.dart`, `home_shell.dart`; shared `lib/widgets/history_ui.dart`, nav copy and the existing R3 listen fallback; five local History SVG assets.
- Data/AI: `lib/models/scan_record.dart`, `quiz_explanation.dart`; `lib/services/ai_quiz_service.dart`, `quiz_explanation_service.dart`, `history_explanation_service.dart`, `question_bank.dart`, `scan_record_store.dart`, `quiz_tts_service.dart`, `quiz_pdf_service.dart`; `lib/providers/waste_quiz_provider.dart`.
- Regression tests/fixtures, four explanation screenshots, `CHANGELOG.md`, decision 0184 and `docs/HANDOFF.md` (45 lines).

## Phone / robot check

Build for a phone from this branch (no owner History seed):

```sh
flutter build apk --debug --dart-define=LIVE_SCAN=true --dart-define=TESTER_BUILD=true --dart-define=DARK_MODE_OPTION=true --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)
```

1. Use the tester build with `DARK_MODE_OPTION=true`; sign in so the existing Gemini backend can authenticate. Open Riwayat with light mode, then repeat in dark mode.
2. Finish a real scan/quiz with one correct and one wrong answer (also an essay if enabled). Verify saved crop, real trophy total, category filters, and pushed phone detail; wide windows should retain the two panes.
3. Open Lihat penjelasan. Check the saved answer is exact, the right answer is unchanged, the wrong-answer reason appears only when applicable, and no source/module/guide/simulation links appear. Reopen it; the backend log should show no second explanation request.
4. Listen to the whole question, switch to one section, tap pause, go back, and background the app during playback. There must be one voice and speech must stop. Check highlight and “Sedang dibacakan”.
5. Open a not-yet-explained question in airplane mode. Reviewed bank text may remain, otherwise show “Penjelasan lengkap belum tersedia” and Coba lagi. No made-up local text. Restore internet and retry; reopen offline to verify the completed explanation is saved.
6. Open Ekspor PDF, toggle each include option, share and save. Inspect `ELIOS_<item>_Q<n>.pdf`; only this question, the selected content and the saved explanation should appear. Whole-record Ekspor PDF should still export the record.
7. Check empty History starts a scan, skeletons stop animating with reduced motion, and a failed/stalled load offers Coba lagi. History must be the only selected nav tab.

USB acceptance was performed on Motorola Edge 60 Fusion / Android 16; see the [phone report](0184-history-h3-phone.md). No Mac build or LaunchServices/model-store changes.
