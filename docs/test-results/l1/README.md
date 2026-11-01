# L1 Learn v2: phone check (1 Nov 2026)

Device: motorola edge 60 fusion (ZP22233V8C), Android 16, USB. Build: arm64 release tester build
(`--dart-define=TESTER_BUILD=true`, debug-signed), installed with `adb install -r` (app data kept).
Screenshots: `adb exec-out screencap -p`, scaled to 540 px wide JPEG. Owner's real Firestore content and progress.

| Check | Result | Files |
|---|---|---|
| Hub, light / dark | pass, real Cloudinary thumbnails load | `light_hub_1-3`, `dark_hub_1-3` |
| Module Organik | pass (7 lessons, Watch/Read again, Continue, Start) | `light_module_1-3`, `dark_module_1-3` |
| Lesson page (video, guide) | pass | `light_lesson_video`, `light_lesson_guide`, `dark_lesson_video` |
| YouTube plays >= 10 s with sound | pass: playing at 12 s, app audio track `state:started`; resumed from saved position; progress 15% -> 29% saved | `video_playing_12s` |
| Fullscreen, back | pass | `video_fullscreen` |
| Rotation | partly: the app rotates with the phone (`landscape_module`); the player page now allows landscape. Turning the phone inside the player not done (needs a hand on the phone) | |
| Guide PDF opens and pages | pass: opens at saved page 3/3, pager back to 1/3 | `guide_pdf_open`, `guide_pdf_paged` |
| Simulation sliders change the result | pass: Massa 1250 -> 399 g, ρ 2.50 -> 0.80, warning shown | `light_sim_densitas_1-2`, `sim_slider_changed` |
| Quiz completes | Kuis fisika 7/7 answered, result 3/7 (`light_kuis_fisika_result`). Waste quizzes: all 3 attempts already used on this account, so no new waste-quiz score was saved on the phone; saving is covered by the widget test | `light_quiz_list`, `dark_quiz_list` |
| My progress | pass | `light_progress_1-2`, `dark_progress_1-2` |
| Error state (airplane mode) | not reproducible: Firestore serves its offline cache, so Learn shows cached content (`dark_airplane_cached_hub`). The error screen is widget-tested | |
| Loading skeleton after clearing image cache | not done: a release build cannot be `run-as`, and `pm trim-caches` would clear other apps' caches | |

## Differences from Figma (not "fixed")
- Headings use the theme's JetBrains Mono (`titleLarge`), Figma uses a sans (decision 0091 is the pending font switch).
- Simulation tag shows the page's own tag ("MODUL A · MATERI"); the formula box lives in the Rumus tab, not above the sliders.
- Simulation canvases keep their light illustration background in dark mode.
- Guide lesson cover shows the guide's own PDF thumbnail (Firestore `coverUrl`) with a document icon, not a play button.
- Kuis fisika score is not saved anywhere (it never was: `updateQuizScore` has no callers).
- `light_kuis_fisika_answered` was taken before the list alignment fix (feedback text centred); `dark_kuis_fisika_answered` is after it.
