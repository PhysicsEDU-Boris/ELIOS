# H3-fix: History UI matched to Figma (PR #94)

Source of truth: [`docs/design/h3-figma`](../../design/h3-figma/README.md) (Figma `J2jSbARJSyJCStNFeWkWDj`, page 433:2358),
plus Figma frame metadata read through the Figma MCP for exact offsets.

## Harness

`test/history/h3_figma_harness_test.dart` renders the 9 states in light and dark at 390 dp wide (height = the Figma
frame, so long screens show in full; 844 for the 844 frames), 1x, status inset 28, with an isolated fixture whose text is
the Figma sample in Indonesian and no photo. List, loading list and empty are wrapped in the real shell parts
(`ElioTopBar`, `ElioBottomNav` with History active). It writes:

- `app/<mode>-0N-<state>.png`: app renders (after the fix)
- `compare/<mode>-0N-<state>.png`: Figma | app (after the fix)
- `before/<mode>-0N-<state>.png`: Figma | app before the fix

Re-run: `flutter test test/history/h3_figma_harness_test.dart`.

## Diff list (Figma value: before -> after)

**All screens**
- Font Google Sans Flex / Code: Inter + JetBrains Mono (headings mono) -> bundled Google Sans Flex/Code (commit `b9f076b`).
- Chip tints `chip/*-bg`, `chip/*-border` (light 6/8/4/6 % + 35 %, dark 12 % + 25 %): ad-hoc 6 %/12 % + 35 % for all -> per-tone values from the Figma variables.
- Detail/explanation top bar (56 / 64, back 48, Subhead title, Caption subtitle): Material AppBar, default title style -> `HistoryTopBar`.
- Content padding 8/16/24, gap 16: 16 all round -> 8/16/24.

**01 History list**
- Trophy summary: bare 40 dp trophy icon -> 44 badge circle (`chip/warning-*`), text gap 2; footer Wrap -> space-between row.
- Filter chips (40 high, Button style, `raised`/`primary`): ChoiceChip ~36, Body Small w600, `text/secondary` -> `HistoryFilterChip`.
- Section header "Scan terbaru" + count Button `primary/text`: count Caption -> Button.
- Scan row trophies (trophy 18 + "+n" Button `warning/text`, no pill): tinted pill -> icon + text. Category chip B3 "B3 · Hazardous": "B3" -> "B3 · Berbahaya". Photo cover-fit (README): contain -> cover.
- Chip height 24, pad 2/8: ~22, pad 3/8 -> 24, 2/8.

**02 Scan detail**
- Title row: Wrap -> title fills, chip right. Scan time: no clock -> clock 16 + gap 6.
- Difficulty: small pills -> 40 dp filter chips; label "Mudah · 1Q" (Figma "Easy · 1Q", fits one row; "1 soal" wrapped).
- Score card: trophy 24 + Headline score, plain "n dari m" -> trophy 28 + Display `warning/text`, Button `text/primary`; tint 6 % -> 4 %.
- "Soal" header: TextButton grey -> Button `primary/text`; header -> list gap 0 -> 16.
- Question card: pad 12 -> 16; chip gap 6 -> 8; "Benar" chip gained check icon; answers: two white tinted cards (Body) -> one `raised` panel (Overline `text/tertiary` + Body Small `primary/text`/`error/text`, gap 12); link TextButton with padding -> book 18 + Button row.

**03/04/09 Loading**
- Skeleton blocks: `border/medium` + 35 % text sweep, stretched full width -> `border/medium` + 16 % white sweep, left-aligned widths that mirror 03/04/09 (summary badge/lines/track, chips 56/44/96/80, rows 64 square + 3 lines + right pill; detail photo/title/chip/score/question card; explanation meta row 100 with circle, 2 headline lines, 2 answer blocks, section lines).

**05 Empty**: gaps 24/12/16 -> 16/8/16, body width 280, button Button style.

**06/07 Explanation**
- Meta row 100 high (Figma frame), chip gap 6 -> 8, difficulty chip neutral; question gap 24 -> 12.
- Answers: white tint, Overline in sans override -> Figma tints, check 14 before "JAWABAN BENAR".
- Sections: gap 8 between cards -> column gap 4; title/body gap 0 -> 8; reading: Caption "Sedang dibacakan" under title -> "SEDANG DIBACAKAN" row (volume 14 + Overline) above title.
- Listen button: tinted pause -> Pause filled `primary/fill` + `primary/on-fill`, icons 16.
- Key idea: tertiary 6 % tint with listen button -> `chip/info-*`, pad 16/16/16/12, no listen button.
- Steps: card with listen button and grey pills -> plain block pad 0/12, number circle 28 `raised`, no listen button.
- Trophy pill pad 6/12/6/10, icon 18, Button: small chip -> `HistoryTrophyPill`.
- Actions bar: pad 16 -> 12/16/28/16; "Soal berikutnya" gains chevron 20; button sides 16 so Indonesian fits on one line.

**08 Export sheet**: Material drag handle -> 32x4 `border/medium`; scrim default -> `#0F172A` 55 %; top radius 28;
preview card `surface`+border -> `raised` r12 with white A4 thumb 52x72; options 56 dp Body Small -> 48 dp, checkbox 24, Body; "SERTAKAN" `text/secondary` -> `text/tertiary`.

**Remaining differences (allowed or out of scope)**: Indonesian copy (some titles wrap where English fits); real level
title; "A4 · PDF" instead of "A4 · 1 page · about 220 KB" (size unknown before generating); the shared `ElioBottomNav`
(label "Riwayat", filled Learn icon, 64 dp + inset vs Figma 84) is not an H3 file; detail is a pushed route without the
bottom nav (routes unchanged); dark unchecked checkbox border is the theme `formBorder`.

## Phone (USB)

| | |
| --- | --- |
| Device | Motorola Edge 60 Fusion (`ZP22233V8C`), Android 16 |
| `wm size` / `wm density` | 1220x2712 / 450 -> 434 dp wide (not 390; fixed paddings, flexible widths) |
| Build | `flutter build apk --debug --dart-define=LIVE_SCAN=true --dart-define=APP_COMMIT=642e5c4`, `adb install -r` (data kept); then reinstalled with the owner's usual flags (`TESTER_BUILD`, `DARK_MODE_OPTION`) |
| Data | owner records read-only: `scan_records.json` 113,543 bytes, mtime 13:01 before and after |

Screens in `phone/`: `light|dark-01-list-*`, `-02-detail-*`, `-06-explanation-*`, `-07-reading*`, `-08-export-sheet`.
Loading and empty are harness-only (cached data loads instantly; empty would need touching owner data).

Functional checks: TTS plays (Android speech audio track `started`), switches section, stops on back (track gone) and on
app background (reading state cleared on resume); Simpan PDF wrote `Download/ELIOS/ELIOS_Modul-buck-converter_Q1.pdf`
(5,841 bytes, left in Downloads) and showed the snackbar; Bagikan opened the Android share sheet (dismissed, nothing
sent); trophy pill shows the real 442. `adb logcat -d | grep -i -E "flutter|elios"`: no exceptions, 0 "RenderFlex overflowed".
Not done on the phone: airplane mode (a system setting; offline/retry stays covered by the existing tests and PR #94's phone run).
