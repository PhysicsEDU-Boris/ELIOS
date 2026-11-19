# H3 History: Figma reference (source of truth for the UI)

Figma file `J2jSbARJSyJCStNFeWkWDj`, page "H3 History screen" (`433:2358`), exported 5 Nov 2026 at 1x (list and detail redesigned 14:00: trophy hero, category tiles,
result stats, difficulty tabs; explanation redesigned 14:40: result hero, answer tiles, learn cards,
mission path)
(390 px wide = 390 dp). Phone screenshots taken at the same dp width must match these images.
Figma copy is English; the app shows the Indonesian strings from decision 0184.

| File | Figma node (light / dark) |
| --- | --- |
| 01 History list | 435:2395 / 520:7486 |
| 02 Scan detail | 435:2581 / 520:6055 |
| 03 Loading list | 435:2781 / 520:6074 |
| 04 Loading detail | 435:2936 / 520:6116 |
| 05 Empty | 435:3060 / 436:3649 |
| 06 Explanation | 439:3603 / 459:5288 |
| 07 Explanation, reading aloud | 439:3764 / 459:5355 |
| 08 Export this question sheet | 459:5039 / 459:5422 |
| 09 Explanation loading | 439:4165 / 459:5529 |
| 10 Explanation, correct answer | 460:5171 / 460:5436 |
| 11 Photo viewer (one dark screen for both modes) | 520:5626 |

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
- **Scan card** (replaces the scan row; like the reference's course cards): 2-column grid, gap 12, cards fill
  half the width, rows 12 apart; a lone last card keeps half width. Card pad 8/8/12/8, gap 8, r20,
  `surface` + `border/subtle`. All cards in a list are the same height (title slot is always 2 lines).
  - Cover 116 high, r16, clipped, tinted by category (`chip/success-bg` daur ulang, `chip/error-bg` B3,
    `chip/warning-bg` organik); a 110 circle of the category border colour at 35 % top-right; three sparkles
    (14, 10, 8) in the category text colour.
  - The scan photo as a **polaroid**: `surface` frame pad 4 r8 with a soft shadow (0/4/10, #0F172A 14 %),
    rotated -4 degrees, image about 104x58 shown **contain (BoxFit.contain), never cropped**, letterboxed on
    `raised`. Category sticker bottom-left (pad 3/8, r full, `surface`, shadow, 8 dot + Caption in the category
    text colour); trophy pill top-right (`warning/text` fill, trophy 14 + "+n" Caption in `surface`).
  - Text pad 0/4: meta Caption `text/secondary` ("23:29 · 3 soal"), title Body `text/primary`, max 2 lines,
    ellipsis, fixed 2-line height.
  - Score row: 6 high track r full `raised`, fill `primary/fill` = correct/total of the record (hidden at 0),
    "2/3" Caption `text/primary`.
  - "Lihat hasil" button 36 high r full `primary/fill`, Button `primary/on-fill` + chevron 16. The whole card
    is also tappable (one target: the card).
- **Scan photo frame** (Scan detail; replaces the big cropped photo) 358x184, r20, clipped, category tint,
  two blobs of the category border colour at 30 %, four sparkles. The photo is a polaroid (pad 4,
  r8, shadow, rotated -3 degrees) about 224x126, **contain, never cropped**. Time pill top-left
  (clock 14 + Caption). Fullscreen button bottom-right: 44 visual / 48 dp target, `surface` circle, shadow,
  expand icon 20 `text/primary`. Tapping the photo or the button opens the photo viewer.
- **Photo viewer** (frame 11): full-screen route, near-black background #05080F in both modes (fixed colour,
  allowed), status inset, top bar 64: close 48 dp (X 22), title Subhead + Caption "Dipindai hari ini 23:29 ·
  Daur ulang", share 48 dp. The photo fills the width with BoxFit.contain, centred; InteractiveViewer pinch
  zoom 1x to 4x, double-tap toggles 1x/2.5x, swipe down to close. Hint pill at the bottom ("Cubit untuk zoom ·
  ketuk dua kali untuk reset") fades after 2 s. Hero animation from the detail photo. Accessible labels on
  close/share.
- **Scan detail**: scan photo frame (above); title Headline + category chip
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
- **Explanation screen content** (gamified; content gap 16; no meta chip row, no tinted answer boxes):
  1. **Result hero** 358x176, r20, clipped, pad 18/20/20/20, gap 8. Wrong = `error/fill` with text/icons
     `error/on-fill` and a 200 circle `error/fill-hover` behind the top-right; Right = `primary/fill`,
     `primary/on-fill`, `primary/fill-hover`. Rows: "SOAL 2 DARI 3" Overline (80 % layer opacity) + progress
     dots (8x8, current 20x8, r full, others 45 % layer opacity, one per question); headline Headline
     ("Belum tepat!" / "Mantap!"); subtitle Body Small 200 wide ("Coba lagi, yuk cari tahu alasannya." /
     "Jawabanmu benar."); trophy pill (pad 4/10/4/8, r full, `*-fill-hover`, trophy 16 + "+n trofi" Button).
     Mascot "Control art/Bottle buddy" Mood=Sad (wrong) / Mood=Happy (right), 90x122 at x 246 y 46, partly
     cut by the bottom edge; three sparkle stars (18, 12, 10) in the on-fill colour around it.
     Same colours in dark mode (dark `error/fill` is the lighter red, text stays `error/on-fill`).
  2. **Question card** 358 wide, r20, pad 12/12/16/16, gap 8, `surface` + `border/subtle`. Top row gap 8:
     28 r8 tile `chip/info-bg` with quiz icon 18 `info/text`, "PERTANYAAN" Overline `text/tertiary` (fills),
     listen button. Question Subhead `text/primary`.
  3. **Answer tiles** (gap 8), r16, pad 12/16/12/12, gap 12, 2 px border:
     "Jawabanmu" wrong = `chip/error-bg` + `error/fill` border, 32 badge `error/fill` with X 18 `error/on-fill`,
     tag Overline `error/text`; "Jawaban benar" = `chip/success-bg` + `primary/fill` border, badge `primary/fill`
     with check `primary/on-fill`, tag `primary/text`; when the student was right show one tile
     "JAWABANMU · BENAR" in the success style. Answer Body `text/primary`.
  4. Header row gap 8: sparkle 18 `warning/text` + "Yuk pelajari alasannya" Subhead.
  5. **Learn cards** (gap 12), r20, pad 16/12/16/16, gap 12, `surface` + `border/subtle`. Header row gap 12:
     art tile 52 r16 (tint + painted art 36-40), title Subhead (fills, wraps), listen button. Body Body.
     "Kenapa ini benar": Bulb buddy art on `chip/warning-bg`. "Kenapa jawabanmu kurang tepat" (only when wrong):
     Bin buddy art of the item's category on `chip/error-bg` (B3 here).
     Reading state: `chip/success-bg`, 2 px `primary/fill` border, a "SEDANG DIBACAKAN" pill above the header
     (pad 4/10/4/8, r full, `primary/fill`, volume 14 + Overline `primary/on-fill`), listen button = Pause.
  6. **Key idea** card r20, pad 16, gap 12, `chip/info-bg` + `chip/info-border`: 52 r16 `surface` tile with
     Quest target art 40; text gap 4 = sparkle 12 + "IDE UTAMA" Overline `info/text`, Body `text/primary`.
     No listen button.
  7. **Mission** card r20, pad 16, gap 16, `surface` + `border/subtle`. Header gap 12: 52 r16 `chip/warning-bg`
     tile with flag 26 `warning/text`, title "Misimu" Subhead + Caption "n langkah agar benar", listen button.
     Steps path: each row gap 12 = rail (28 `primary/fill` circle with the number Button `primary/on-fill`,
     a 2 px `primary/fill` line below that stretches to the next step) + text Body (pad top 3, bottom 16).
     Finish row: Medal gold art 28x33 + "Misi selesai: ..." Body Small `text/secondary`.
     The mission rows are the AI "steps"; hide the card when there are none.
- **Correct vs wrong answer** (frames 06 and 10): the screen is the same widget, driven by the saved result.
  Correct = Result hero "Right" (green, happy bottle buddy, "+n trofi"), progress dot on the current question,
  ONE answer tile "JAWABANMU · BENAR", no "Kenapa jawabanmu kurang tepat" card, then key idea and mission as usual.
  Wrong = Result hero "Wrong" (red, sad bottle buddy, "+0 trofi"), two answer tiles (yours with X, the right one
  with a check), and the "kurang tepat" card with the category bin buddy.
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
  Skeleton layouts mirror the real cards (see 03, 04, 09): explanation = hero block 176 r20, question card,
  two 64 r16 answer blocks, a learn card skeleton; list = hero block r20 164 high, 2-column skeleton cards
  (116 cover, 2 lines, bar, 36 button); detail photo block 184 r20; 2x2 tile blocks 96 high,
  stats block 80 high r16, tabs block 48 high r full.
- **Empty**: illustration 240x180, title Subhead, body Body Small `text/secondary` 280 wide centred, primary pill button.
