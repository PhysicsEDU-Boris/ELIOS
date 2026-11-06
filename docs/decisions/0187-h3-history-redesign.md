# 0187: H3 History redesign (trophy hero, category tiles, gamified explanation)

- Status: Proposed (owner asked, 6 Nov 2026). Widget/harness-tested; not yet checked on the phone.
- Builds on: [0184](0184-history-h3-ai-explanations.md) (H3 screens), [0185](0185-ui-localization-gen-l10n.md) (live languages).
- Design: `docs/design/h3-figma/README.md` (Figma `J2jSbARJSyJCStNFeWkWDj`, page `433:2358`, frames 01-10), merged from `design/h3-figma-refs`.

## Decision

- **List:** green trophy hero (total, level, progress, level art: sprout below level 3, tree from level 3) replaces the trophy summary card; a 2x2 grid of category tiles with bin buddies replaces the filter chips (tap = filter, selected = success tint + 2 dp edge + check); rows are grouped by day (HARI INI / KEMARIN / date); photos sit on the category tint; trophies are a warning pill.
- **Detail:** result stats (piala | benar | dipindai) replace the score card and scan-time line; difficulty tabs replace the chips (display only, one set is saved); the "Soal" header has no action, the top-bar icon is the only whole-record PDF export.
- **Explanation:** one widget for right and wrong: result hero (green "Mantap!" / red "Belum tepat!", question dots, +n piala, happy/sad bottle buddy), question card, answer tiles (one "Jawabanmu · Benar" tile when right), "Yuk pelajari alasannya" learn cards with bulb / category bin art, key idea card, mission card (AI steps as a path; finish row uses the saved `summary`, hidden when empty). Listen buttons: question, learn cards, mission. Essays keep a score chip and neutral answer tiles.
- **Language:** every new label is an ARB key in `app_en.arb` / `app_id.arb`, so the screens follow the sidebar language switch live (string audit 0). Indonesian keeps the app's word "piala" (Figma says "trofi"). Removed unused keys `h3ScannedMeta`, `h3TrophyRule`, `h3CorrectOf`; `h3All` is now "All scans" / "Semua scan".
- No data, store, AI, PDF or TTS logic changed.

## Checks

- Harness `test/history/h3_figma_harness_test.dart` renders frames 01-10 in en/id x light/dark; side-by-sides in `docs/test-results/0187-h3-redesign/compare/` (`L10N_RENDER=1`).
- New tests: category tile select styling, live id -> en switch of the redesigned list, correct-answer explanation (hero + no "why wrong" card). They fail on the old UI (widgets/keys did not exist).
