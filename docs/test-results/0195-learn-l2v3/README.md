# 0195 Learn L2 v3 — phone test, 9 Nov 2026

Motorola Edge 60 Fusion, APP_COMMIT `1e4810f`, account with real progress (71 %, 3 modules,
Daily Guide #02 at 2 of 3 stops, streak 1, 70 guide XP).

| Check | Result |
| --- | --- |
| Hub renders: header ring 79/55/36 → 71 %, ticket, bubbles, Explore | pass (`01-hub-light-en.png`) |
| Explore tabs Modules / Videos / Simulations / PDF guides, counts 3/11/9/4 | pass |
| Cards open Module, Lesson (video, guide), Simulation; See all per tab | pass |
| Bubbles: Quiz, Mini lab, Archive (ELIOS Guides), Progress | pass |
| Ticket Continue and ticket body open Issue #02; header opens My progress | pass |
| Sidebar on Learn: Learn shortcuts only, footer kept; Home tab still shows app navigation | pass |
| Every shortcut row (Today's Guide, Jump back in, 4 tabs, Knowledge challenge, Mini lab, My progress, Guide archive) | pass (`02-shortcuts-videos-quiz.png`) |
| Continue dropdown collapses and stays collapsed on reopen | pass |
| Tap scrim / close button closes the drawer | pass |
| Dark mode from the sidebar | pass (`03-dark.png`) |
| Bahasa Indonesia live switch | pass (`04-bahasa-indonesia.png`) |
| Numbers match: My progress 71 %, 79/55/36; guide streak 1, 70 XP | pass |
| History data unchanged (md5) | pass |

Fixed during the test (second build): ticket notches drawn past the card edge, all-caps "TODAY'S
GUIDE" in the sidebar, dropdown state lost on reopen, long simulation tag and boxy simulation art.
Not covered: tablet layout (not implemented), robot/MaixCAM2 paths (unchanged).
