# 0222 — Hazardous (B3) scan result as a full page

Date: 16 November 2026. Branch `feat/scan-hazard-b3`, **stacked on `feat/control-l4-figma`
(PR #126, 0217)** because the robot scan pages only exist there. Figma `ELIOS 3`: landscape
851:28659 (dark 855:28732), portrait 852:28687 (dark 855:28796).

## What changed

- A hazardous item no longer shows the red popup card on a blank page. `ScanQuizPages` routes
  `confirmingHazard` to the identified page (`_IdentifiedPage(hazard: true)`), so it has the
  same layout and entrance (polaroid drop, B3 bin buddy pop, result fade, ticket slide, S2 +
  H-light cue): overline "HANDLE WITH CARE" in the error text colour, item name, the red
  "Hazardous bin (B3)" chip with the B3 buddy, a caution note with a warning icon, and the quiz
  ticket "Keep learning about this item?" with **Scan again** and **Continue quiz**.
- Callbacks are the same: Scan again = the page's rescan (robot: restart the live scan),
  Continue quiz = `confirmHazard()`, and the first question opens directly (no second "Start
  quiz" step).
- Top right: the quiz voice switch (as in the popup header); on the robot also minimise and
  the STOP pill. Landscape puts them in the screen corner as in Figma; the item name keeps
  clear of them.
- Strings: `qzHazardBody` is split into `scanHazardNote` and `scanHazardKeepLearning`, plus
  `scanHazardOverline` (EN + ID). The old popup (`_HazardView`, still used where the popup is
  shown) joins the two.

## Not 1:1

- The "Not this?" correction chip is not shown on the hazard page (Figma has none; the old
  hazard card had none either).
- On the phone there is no minimise button (the phone pages cannot be minimised); close is the
  round X on the left, as on the identified page.
- Dark frames were not fetched one by one: they use the same tokens; dark is covered by the
  widget tests and renders.

## Tests

`test/screens/scan_quiz_pages_test.dart`: page instead of the popup card (EN/ID × light/dark),
Scan again + voice switch, robot landscape (STOP, minimise, rescan), portrait order, reduce
motion, and `hazard` in the no-overflow matrix (phone + robot, 4 sizes, light/dark, EN/ID).
Break-check: the 8 hazard tests fail with the old routing. Renders:
`docs/test-results/0222-hazard-b3/`.
