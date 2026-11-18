# 0228 — Quiz PDF export redesign and light / dark PDF theme

Date: 17 November 2026. Branch `feat/pdf-export-redesign`, branched from
`feat/essay-explanation-review` (0227, PR #139). Phase 3 of 3; merge after #138 and #139.
Figma: file J2jSbARJSyJCStNFeWkWDj, page "ELIOS 3", section "17 · Quiz PDF export · A4"
(874:30391): cover 874:30404, Q1 875:30470, Q2 skipped essay 875:30619, Q3 875:30770,
single question 875:30919, notes 876:30705, footer 874:30394, answer tile 875:30469.

## Decision

The PDF layout moved to `lib/services/quiz_pdf_design.dart` (a part of
`quiz_pdf_service.dart`); the public API (`generatePdfBytes`, `generateAndSave`,
`shareOrSave`, `generateQuestionPdfBytes`, `saveQuestion`, `shareQuestion`) is unchanged
apart from an optional theme. A4, 595 × 842 pt, sizes taken 1:1 from Figma.

- **Full report**: cover (curved green header, ElioMark, export date, category chip, item
  title, meta line, score ring with a headline for 0 / some / all correct, XP chip, tilted
  polaroid of the scan photo, grade stamp, ticket summary with notches and a dashed tear
  line, "Question map" with the page of each question, tip built from the quiz's own key
  ideas), then one page per question (green band with progress dots and tilted result
  sticker, number leaf, side-by-side answer tiles, "why this is right" leaf card with the
  robot, "why your answer fell short" bubble with the sad robot when wrong, key idea ticket,
  essay rubric card, step path, and "My notes" lines filling the rest of the page).
- **Long content** flows onto extra pages with a slim continuation header; text is never
  clipped and no page starts with an empty band. Cards never split; an answer over 700
  characters is printed as plain paragraphs that flow.
- **No explanation**: the dashed "Explanation not saved yet" box with the sleepy robot and
  a hint to open the question in the app. Never a bare sentence.
- **Single question**: the question page (polaroid in the header when "Scan photo" is on,
  step path) and, with "Space for my notes", the notes page. Every prompt on the notes page
  is built from the question, its key idea and the item name.
- **Theme**: `QuestionPdfOptions.dark` (null = the remembered choice). Both export sheets
  have "PDF theme: Light / Dark" (`PdfThemeChoice`); the full-report buttons (History scan
  detail, quiz result card, old popup) now open a small sheet with it. Light is the
  default; the choice is saved in SharedPreferences (`pdf_theme_dark`). Dark uses the dark
  ELIOS tokens for page, cards, text and borders; the green header and stickers stay green.
- **Contrast**: tints are mixed as opaque colours. Body text and labels meet WCAG AA
  (4.5:1) on every background in both themes; checked in a test. To get there the label
  tints are 4-8 % in light and 10 % in dark, and quiet (skipped) boxes use `surface` in dark.

## Fonts and art

- Google Sans Flex Regular / Medium / SemiBold / Bold are embedded. The `pdf` package
  cannot pick a weight from a variable font, so four static instances
  (`assets/fonts/pdf/`, ~130 KB each, same OFL licence) were cut from the bundled variable
  font with fontTools `varLib.instancer` (wght 400/500/600/700, wdth 100, opsz 18). No new
  package; fontTools ran once in a scratch environment and is not a dependency.
- Art is the app's existing Figma exports (`assets/illustrations/…`): robot moods, bin
  characters, medal, light bulb, quest target, XP sprout, squiggle. The ElioMark is drawn
  from the same vector as `ElioLeaf` (Figma 208:1144). Nothing was redrawn.
- The scan photo is re-encoded: at most 640 px, JPEG 80. A 3-question report with a
  photo is about 340 KB (target under 1 MB); without a photo about 50 KB.

## Old export bugs (each has a test)

- (a) "Penjelasan" printed twice: the old export printed `summary` and
  `correctAnswerReason`, which are the same text for bank explanations. Now one text.
- (b) Page 2 started with an empty heading and divider lines: the old report was one
  MultiPage whose header repeated on every page. Now each question has its own page; a
  continuation gets the slim header only when content really flows over.
- (c) Essays printed "Penjelasan tidak tersimpan" although data existed: the old check
  `!exp.isComplete && !q.isEssay` and the essay fields were not printed. Now the essay
  feedback, rubric and model answer print; the box shows only when nothing is saved.

## Differences from Figma (intentional)

- Pills are rounded rectangles (radius 7-10) rather than full stadiums: the `pdf` package
  draws a radius larger than half the height with torn edges.
- The step path shows at most 5 steps (the AI and the bank give 3-5).
- The light bulb's outline is navy art and is faint on the dark page (fixed art colours,
  as in the app).
- Map rows say "P. n" / "HAL. n" (the page where that question starts).
- The "why this is right" card has no bold one-line headline (Figma "Lebih banyak
  permukaan = …"): saved explanations have no such field, and none is invented.

## Tests

`test/pdf_export_design_test.dart` (22): every export in EN / ID and light / dark; 0, some
and all correct; 1-question quiz; no photo; long answer; skipped essay; the three old bugs;
notes prompts from the question; all 16 include combinations; theme default, persistence,
option and dark tokens; AA contrast; both sheets show the theme. The older PDF tests read
the drawn text from `QuizPdfService.debugTexts` (the embedded font writes glyph ids).
Rendered pages: `docs/test-results/0228-pdf-export/` (via `tools/pdf/render_pdf_pages.swift`).
