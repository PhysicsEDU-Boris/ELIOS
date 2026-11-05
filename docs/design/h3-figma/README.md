# H3 History: Figma reference (source of truth for the UI)

Figma file `J2jSbARJSyJCStNFeWkWDj`, page "H3 History screen" (`433:2358`), exported 5 Nov 2026 at 1x (list and detail redesigned 14:00: trophy hero, category tiles,
result stats, difficulty tabs)
(390 px wide = 390 dp). Phone screenshots taken at the same dp width must match these images.
Figma copy is English; the app shows the Indonesian strings from decision 0184.

| File | Figma node (light / dark) |
| --- | --- |
| 01 History list | 435:2395 / 454:4480 |
| 02 Scan detail | 435:2581 / 454:4505 |
| 03 Loading list | 435:2781 / 454:4525 |
| 04 Loading detail | 435:2936 / 454:4576 |
| 05 Empty | 435:3060 / 436:3649 |
| 06 Explanation | 439:3603 / 439:4238 |
| 07 Explanation, reading aloud | 439:3764 / 439:4323 |
| 08 Export this question sheet | 439:3944 / 439:4408 |
| 09 Explanation loading | 439:4165 / 439:4536 |

## Type (font: Google Sans Flex; code: Google Sans Code)

| Style | Weight / size | Letter spacing |
| --- | --- | --- |
| Display | Bold 36 | -2 % |
| Headline | Bold 28 | -1 % |
| Subhead | SemiBold 20 | 0 |
| Body Large | Regular 18 | 0 |
| Body | Regular 16 | 0 |
| Body Small | Regular 14 | 0 |
| Button | SemiBold 14 | 0 |
| Caption | Medium 12 | 1 % |
| Overline | SemiBold 11, uppercase | 10 % |
| Code | Google Sans Code Regular 14 | 0 |

## Screen frame (all H3 screens)
- Status inset 28, then top bar: Profile top bar 56 (list, empty, loading list) or Detail top bar 56
  (back 48 dp, title Subhead, Export PDF icon button 48 dp) or Explanation top bar 64.
- Content padding 8 top / 16 sides / 24 bottom, vertical gap 16. Background `bg`.
- Bottom nav 84 with only History active (list, detail, empty, loading list/detail).
  The explanation screen has no bottom nav; it has the actions bar instead.

## Components (dp; r = corner radius; colours are ELIOS token names)
- **Trophy hero** (replaces the old trophy summary card) 358x164, pad 18/20/20/20, gap 4, r20, `primary/fill`,
  clips its content. A circle 190 `primary/fill-hover` sits behind the top-right corner (x 210, y -40).
  Top row gap 8: "TROFI KAMU" Overline `primary/on-fill` at 72 % layer opacity + "Tersimpan lokal" pill
  (pad 2/8/2/6, r full, `primary/fill-hover`, check 12 + Caption `primary/on-fill`).
  Count row: total Display + "trofi" Body, both `primary/on-fill`, gap 6, baseline aligned.
  Level line Body Small `primary/on-fill`; 8 spacer; progress 190x8 r full, track `primary/fill-hover`,
  fill `primary/on-fill`; "x trofi lagi ke Level n" Caption `primary/on-fill` at 72 %.
  Level art bottom-right (x 226, y 34, 120x124): Eco tree Lv3 art; use Eco sprout Lv1 art at low levels
  (Figma components "Home art/Eco tree Lv3" 332:4411 and "Home art/Eco sprout Lv1" 332:4427).
  Same colours in dark mode (the green block stays green).
- **Category tiles** (replace the filter chips): 2x2 grid, gap 12, tiles fill the width (2 per row), 96 high,
  pad 12/12/12/14, gap 2, r16, clipped. Label Body `text/primary`, count "n scan" Caption `text/secondary`.
  Bin buddy art 52x62 at the bottom-right, partly cut by the tile edge (x = width-59, y 44):
  B3 = "Bin buddy B3" 332:4480, Daur ulang = "Bin buddy Anorganik" 332:4466, Organik = "Bin buddy Organik" 332:4452;
  "Semua" shows the three bins overlapping (36-40 wide). Default = `surface` + 1 px `border/subtle`.
  Selected = `chip/success-bg` + 2 px `primary/fill`, count in `primary/text`, a 20 dp `primary/fill` circle
  with a check 14 `primary/on-fill` at the top-right, and the art tilted 8 degrees. Tapping a tile filters the list.
- **Day groups** in the list: "HARI INI", "KEMARIN", then a date ("3 NOV"). Overline `text/tertiary`,
  12 above the first row of the group, groups 20 apart.
- **Chip** (status) height 24, pad 2/8, gap 4, r full, tint bg + 1 px tint border, icon 14, text Caption.
  success = `chip/success-*` + `primary/text`; error = `chip/error-*` + `error/text`;
  warning = `chip/warning-*` + `warning/text`; info = `chip/info-*` + `info/text`; neutral = `raised` + `text/secondary`.
- **Section header**: the existing Learn section header (title Subhead, action Button `primary/text`).
- **Scan row** 358 wide, pad 12, gap 12, r16, `surface` + `border/subtle`, centred vertically.
  Photo 64x64 r12 tinted by category: `chip/success-bg` (daur ulang), `chip/error-bg` (B3), `chip/warning-bg`
  (organik); the saved crop cover-fits it; bin icon 40 only when there is no photo.
  Info column gap 4: title Body `text/primary` (wraps), category chip, meta Caption `text/secondary` (wraps).
  Right: trophy pill pad 4/10/4/8, gap 4, r full, `chip/warning-bg` + `chip/warning-border`,
  trophy 16 + "+n" Button `warning/text`. Rows gap 12.
- **Scan detail**: photo 358x200 r16 tinted by category (as the scan row); title Headline + category chip
  (row gap 12); result stats; difficulty tabs; "Soal" section header WITHOUT an action; question cards gap 12.
  No separate scan-time line and no big score card. The only PDF export on this screen is the file icon
  button in the top bar (whole record, existing QuizPdfService).
- **Result stats** (replaces the score card; like the reference's rating | students | duration row):
  358 wide, pad 12/8, r16, `surface` + `border/subtle`. Three equal columns split by 1x40 `border/subtle` lines.
  Column: value row gap 6 (icon 18 + value Subhead `text/primary`) and label Caption `text/secondary`, centred.
  Trofi: trophy `warning/text`, "+20". Benar: check `primary/text`, "2/3". Dipindai: clock `info/text`, "23:29".
  Values follow the selected difficulty set.
- **Difficulty tabs** (replace the difficulty chips; same look as the L1 "My progress" switch):
  track 48 high, pad 4, gap 4, r full, `raised`; three equal segments 40 high r full.
  Selected = `primary/fill`, label Button `primary/on-fill`, count badge 20 high r full `primary/fill-hover`
  with Caption `primary/on-fill`. Others: label Button `text/secondary`, badge `surface` + Caption `text/secondary`.
  Labels Mudah / Sedang / Sulit with the question count of each set.
- **Question card** pad 16, gap 12, r16, `surface` + `border/subtle`.
  Header row gap 12: Q badge pad 3/10 r8 (`primary/fill` + `primary/on-fill` when right, `error/fill` + `error/on-fill` when wrong),
  question Body `text/primary`. Chips row gap 8 (Benar/Salah chip, +trophy chip).
  Answers panel pad 12, gap 12, r12, `raised`: label Overline `text/tertiary`, answer Body Small
  (`primary/text` right, `error/text` wrong); "Jawaban benar" block only when wrong.
  Link row gap 8: book icon 18 + "Lihat penjelasan" Button `primary/text`.
- **Explanation top bar** 64 high, pad 4/16/4/4: back 48 dp, title column (Subhead + Caption `text/secondary`), trophy pill.
- **Trophy pill** pad 6/12/6/10, gap 6, r full, `chip/warning-bg` + `chip/warning-border`, trophy 18 + count Button `warning/text`.
- **Explanation screen content** (gap 16):
  meta row = Q badge, difficulty chip (neutral), result chip, +trophy chip, spacer, listen button;
  question Headline `text/primary`;
  answers gap 8: "Jawabanmu" pad 12 r12 `chip/error-bg` + `chip/error-border` (label Overline `error/text`, text Body `text/primary`),
  "Jawaban benar" same with success tint and a check 14 before the label;
  "Penjelasan" section header (no action);
  sections column gap 4; each section pad 12, gap 8, r12, no fill; title row gap 8 = title Subhead (fills) + listen button;
  body Body `text/primary`. Reading state: `chip/success-bg` + `chip/success-border`, a "SEDANG DIBACAKAN" row
  (volume 14 + Overline `primary/text`) above the title, listen button in Pause state.
  Key idea card: pad 16/16/16/12, gap 12, r16, `chip/info-bg` + `chip/info-border`, bin buddy art 64x76 left,
  text column gap 4 (Overline "IDE UTAMA" `info/text`, Body Small `text/primary`). No listen button on this card.
  Steps block pad 0/12, gap 12: title Subhead, rows gap 12 = number circle 28 `raised` (Button) + Body.
  No physics link, no module/guide/simulation link, no source citation.
- **Listen button** 48 dp tap target, visual 36 circle. Play = `chip/success-bg` + `chip/success-border`, play icon 16 `primary/text`.
  Pause = `primary/fill`, pause icon 16 `primary/on-fill`.
- **Explanation actions** pad 12/16/28/16, gap 12, `surface`, top border 1 `border/subtle`.
  Two 48 high r full buttons that share the width: outline (`border/medium`, file icon 20 + "Ekspor PDF")
  and primary ("Soal berikutnya" + chevron 20, `primary/fill` + `primary/on-fill`).
- **Export sheet** top radius 28, pad 12/16/28/16, gap 16, `surface`, scrim `#0F172A` at 55 %.
  Handle 32x4 `border/medium`; title Subhead + Caption; file preview row pad 12 r12 `raised` (white A4 thumb 52x72);
  "SERTAKAN" Overline `text/tertiary`; option rows 48 high (checkbox 24 r4 + Body); buttons row like the actions bar
  ("Bagikan" outline with share icon, "Simpan PDF" primary with file icon).
- **Skeleton block**: `border/medium` (full opacity) with a white shimmer band (peak 16 % alpha), radii as the real element.
  Skeleton layouts mirror the real cards (see 03, 04, 09): hero block r20 164 high, 2x2 tile blocks 96 high,
  stats block 80 high r16, tabs block 48 high r full.
- **Empty**: illustration 240x180, title Subhead, body Body Small `text/secondary` 280 wide centred, primary pill button.
