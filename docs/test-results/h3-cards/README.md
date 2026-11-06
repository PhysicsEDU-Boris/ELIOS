# H3-cards: test results (7 Nov 2026)

Design: `docs/design/h3-figma` from `design/h3-figma-refs` `ae25ef1` (frames 01-04, 11).

- `compare/`: Figma | app, frames 01-11 in en/id x light/dark at 390 dp (`L10N_RENDER=1 flutter test test/history/h3_figma_harness_test.dart`). The harness uses no saved photo for 01/02, so the polaroids show the bin buddy (Figma shows painted placeholder covers); the viewer (11) uses a generated 16:9 test photo.
- `phone/`: Motorola Edge 60 Fusion, real History (45 scans). en-light and id-dark: list, detail, viewer, viewer zoomed (double-tap 2.5x). The tall PET bottle photo is whole in the card, frame and viewer.

## Tests
- `test/history/h3_cards_test.dart`: long names 2 lines + ellipsis, equal card heights, spoken card label, no overflow at 320 dp x 1.3 text, score fill = correct/total (0 hides it), portrait and very wide photos contained in the viewer, photo tap opens the viewer, Android back and swipe down close it.
- `test/screens/scan_history_screen_test.dart`: portrait/landscape/wide/tiny photos are `BoxFit.contain` in card (104x58) and frame (224x126); fullscreen button opens the viewer, close returns; missing/legacy photo shows the bin buddy and no viewer.
- Break-check: the new tests fail on the previous UI (card, frame and viewer did not exist; photos were cover-fit).
- Full suite: 1320 passed, 1 known token-radius failure (also on base). Analyze: 2 existing test infos. String audit 0. Secret scan clean.

## Phone (USB)
- `adb install -r` only (APP_COMMIT `e9fb890+viewerfix+essayfix`: branch + the uncommitted localized essay-keyboard fix so the phone keeps it). Private backup first; afterwards both History files md5-identical. Left light/English on History.
- `adb logcat`: no Flutter exceptions or overflow.
- Found on the phone and fixed: dark status-bar icons on the black viewer (now light), and the title was hard to read over a zoomed photo (dark fade behind the bar).

## Differs from the Figma
- Share sends the photo as a one-page PDF: the app's only share path (`printing`) shares PDFs; no new share dependency added.
- Time pill and stats say "Yesterday"/a date for older scans (same `historyTime` as the rest of History); Figma shows a clock time.
- Indonesian keeps "piala" (Figma: "trofi"), as in decision 0187.
- An unreadable (but present) photo file still offers the viewer, which then shows a broken-image icon; only a missing file hides it, as specified.
