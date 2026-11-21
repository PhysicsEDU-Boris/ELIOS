# 0238 — App onboarding tour and first-visit screen tours

Date: 21 November 2026. Branch `feat/app-onboarding-tour`, from `feature/live-scan` 806dcdf.
Design: Figma ELIOS 3 page, section "18 · App onboarding tour" (node 933:31650), light and dark.

## Why

New users get no help finding their way around the app. Only the robot Control screen had a
guide (0174). The owner asked for a tour of every tab and the screens inside them, plus a button in
settings to replay it.

## Decision

One engine, `lib/widgets/tour/app_tour.dart`, built from the Control guide's pieces (scrim with a
hole, dashed green ring, ELIO coach card, finish card). The Control guide now uses the same card
and painter, so all tours look the same.

- **Welcome** (first launch on this device, after sign-in or Guest): three pages, then
  "Start the tour" or "Maybe later". Seen once (`tour_welcome_seen`).
- **Main tour**: Home 6 → Learn 5 → Scan 3 → History 3 → Profile 1 → finish card. The shell
  switches tab before each part (`mainTourParts` in `main_tour.dart`). Skip ends it.
- **Screen tours**: `TourTip` wraps a screen and runs its short tour the first time it opens
  (`tour_tip_<id>`): module, lesson, simulation, physics quiz, guide issue, guide quiz (+ result),
  mini lab, camera, scan result, question, answer review + ELIOS AI, contribute, select vehicle,
  ELIOS setup, robot Wi-Fi QR, scan detail, explanation, PDF export, scan timeline.
- **Profile ▸ App tour**: Start (whole tour), a chip per part (Robot control clears the Control
  guide's flag so it opens next time), and "Show tips on new screens" (default on; turning it
  back on shows each screen tour once more).

Rules:
- A step whose widget is not on screen (empty History, a sheet that is closed) is dropped, so
  every card points at something real.
- Screen tours never show on robot pages (the scan pages also run inside Control): the overlay
  would cover STOP. The Control guide keeps STOP live as before.
- Targets are `GlobalKey`s on the real widgets; the tour scrolls each one into view first.
- Screen tours stay off until `AppTour.load()` runs in `HomeShell`, so screens pumped alone in
  tests never start one.

## Not done

The ELIOS AI full-page chat has no tour of its own (the answer review tour points at the coach).
No per-user flags: seen once per device.

## Tests

`test/widgets/app_tour_test.dart`: a screen tour shows once and walks its steps; a missing target
is dropped; Skip ends it; tips off shows nothing; Welcome Next/Next/Start pops true. Break-checked:
without the drop rule and without the seen flag the first two fail. `profile_screen_test` now
scrolls to each switch (the new section pushes them down).
