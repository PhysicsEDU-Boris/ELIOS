# 0199 — ELIOS 3 History: compact tab, timeline by device, device on records

Date: 10 November 2026

Fourth PR of the ELIOS 3 series, stacked on `feat/elios3-scan-flows` (0198). Figma
J2jSbARJSyJCStNFeWkWDj: History tab 629:99388, Scan timeline 629:99557.

- **History tab** (`ScanHistoryScreen(compact: true)` in the shell): its own title "History ·
  Scans, quizzes and contributions" with the sync state as a tappable chip (tap = sync now); a slim
  trophy strip (tree, total, level, progress, trophies to next level); the existing 2×2 category
  tiles (filter); **Recent scans** = the latest 3 as compact rows (polaroid, name, device chip,
  Contribution / Quiz c/t / Scan only, day, trophies) + **See timeline**; **By device** cards
  (Phone, ELIOS → their timeline; Drone locked "Coming soon"); **Questions to review** (records
  with a wrong answer; Review opens the first one's detail). The full card grid stays for the
  non-tab History route.
- **Scan timeline** (`ScanTimelineScreen`): tabs All / Phone / ELIOS / Drone (locked), a device
  hero (count, camera), day pills on a rail, rows with the clock time; the newest is highlighted.
  The chosen category tile carries over.
- **Device on records**: `ScanRecord.device` = 'phone' | 'elios', written from now on (robot
  sessions → elios, phone scans and contributions → phone). Older records have none and are never
  guessed: they appear under All (the timeline says so), not under a device. JSON adds `device`
  only when set; `localized()` now keeps `kind` and `device` (it dropped them, found by the test).

Not done: the Figma L3 Scan detail restyle (the H3 detail is kept; a contribution shows there as
0 questions); Figma's "Saved locally" chip on the strip (the header chip carries sync state).
