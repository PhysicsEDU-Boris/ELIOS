# H3 History: Figma reference (source of truth for the UI)

Figma file `J2jSbARJSyJCStNFeWkWDj`, page "H3 History screen" (`433:2358`), exported 5 Nov 2026 at 1x
(390 px wide = 390 dp). Phone screenshots taken at the same dp width must match these images.
Figma copy is English; the app shows the Indonesian strings from decision 0184.

| File | Figma node (light / dark) |
| --- | --- |
| 01 History list | 435:2395 / 436:2987 |
| 02 Scan detail | 435:2581 / 436:3170 |
| 03 Loading list | 435:2781 / 436:3370 |
| 04 Loading detail | 435:2936 / 436:3525 |
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
- **Trophy summary** 358 wide, pad 16, gap 16, r16, `surface` + 1 px `border/subtle`.
  Header row gap 12: badge 44 circle (`chip/warning-bg`, `chip/warning-border`, trophy 24 `warning/text`),
  text column gap 2 (count Subhead `text/primary`, level Caption `text/secondary`).
  Progress track 8 high, r full, `raised`, fill `primary/fill`.
  Footer row space-between: "x trophies to Level n" Caption `text/secondary` + chip "Tersimpan lokal".
- **Chip** (status) height 24, pad 2/8, gap 4, r full, tint bg + 1 px tint border, icon 14, text Caption.
  success = `chip/success-*` + `primary/text`; error = `chip/error-*` + `error/text`;
  warning = `chip/warning-*` + `warning/text`; info = `chip/info-*` + `info/text`; neutral = `raised` + `text/secondary`.
- **Filter chips**: the existing Learn filter chip (height 40, r full). Selected = `primary/fill` + `primary/on-fill`;
  default = `raised` + `text/primary`. Row gap 8.
- **Section header**: the existing Learn section header (title Subhead, action Button `primary/text`).
- **Scan row** 358 wide, pad 12, gap 12, r16, `surface` + `border/subtle`, centred vertically.
  Photo 64x64 r12 `raised` (the saved crop, cover-fit; bin icon 40 only when no photo).
  Info column gap 4: title Body `text/primary` (wraps), category chip, meta Caption `text/secondary` (wraps).
  Right: trophy 18 + "+n" Button, both `warning/text`, gap 4. List gap 12.
- **Scan detail**: photo 358x200 r16 `raised`; title Headline + category chip (row gap 12);
  scan time row gap 6 (clock 16 + Caption `text/secondary`); difficulty filter chips; score card;
  "Soal" section header with action "Ekspor PDF"; question cards gap 12.
- **Score card** 358 wide, pad 16, gap 4, r16, `chip/warning-bg` + `chip/warning-border`, centred.
  Trophy 28 + score Display `warning/text` (gap 8); "n dari m benar" Button `text/primary`; hint Caption `text/secondary`.
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
- **Skeleton block**: `border/medium` at 60 % with a white shimmer band (peak 16 % alpha), radii as the real element.
  Skeleton layouts mirror the real cards (see 03, 04, 09).
- **Empty**: illustration 240x180, title Subhead, body Body Small `text/secondary` 280 wide centred, primary pill button.
