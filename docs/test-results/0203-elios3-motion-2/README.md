# 0203 ELIOS 3 motion part 2: phone check

- Date: 10 Nov 2026
- Phone: Motorola Edge 60 Fusion (1220×2712, Android), USB, system animation scales untouched
- Build: debug APK, `APP_COMMIT=94b7dec`, `LIVE_SCAN`, `TESTER_BUILD`, `DARK_MODE_OPTION`; installed with `adb install -r` (data kept)
- App state: Bahasa Indonesia, light theme (left as found)
- Method: `adb shell screenrecord` + `input tap`; frames checked with ffmpeg (contact sheets and per-region luminance over time)
- History safety: md5 of every `*scan_records*` file identical before and after

| Item | Result | GIF |
|---|---|---|
| Profile → Mode gelap: circular reveal | Animates: dark circle grows from the switch over ~400 ms; toggled twice, back to light | `profile-dark-reveal.gif` |
| Scan hub idle hints | Animate for ~8 s after the tab opens, then stop: phone art tilts, robot spotlight breathes (2 s), REC dot blinks (1 s, luminance 230 → 83 → 186 …) | `scan-hub-idle-hints.gif` |
| Scan hub → Pindai dengan robot | Animates: robot Hero flies from the card into the Pilih kendaraan circle while the page fades up | `robot-hero-select-vehicle.gif` |
| History bin tiles | Animate: buddy jumps on tap, "Semua scan" plays the 3-buddy wave, check badge pops in | `history-bin-buddies.gif` |
| History recent scan → Detail scan | Animates: thumbnail Hero grows into the detail photo, and back on return | `history-thumb-hero.gif` |
| Home "Aktivitas scan" grid stagger | Animates when the Tahun view is shown (diagonal fade, today pulse). On a cold start it already finishes before you scroll to it: on this phone the grid is below the fold | `home-grid-stagger.gif` |
| Learn quiz answers (Simulasi → Uji Pemahaman (Kuis), in-memory only) | Animate: wrong answer shakes, correct answer's check pops; a right answer pops its check | `learn-quiz-wrong-shake.gif`, `learn-quiz-right-check.gif` |
| Level-up / medal celebration | Not observable on the phone (needs a real level change); covered by tests | — |

Notes

- Module quizzes (Belajar → Kuis) are all completed and locked on this account, so the physics quiz (no saved progress) was used; it was left unfinished.
- GIFs are cropped to leave out the profile photo and email.
