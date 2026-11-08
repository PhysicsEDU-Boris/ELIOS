# G4-A phone test — 9 Nov 2026

Phone: motorola edge 60 fusion (ZP22233V8C), Android 16, 1220x2712, density 450, font scale 1.0, night mode auto
(dark at test time), app language English. Account: owner's Google account (uid `4eD58q…`). Backend: production
`ai-backend-seven-orpin.vercel.app`. Live catalogue: manifest v1 (issue #01, no photo, so topic art). Debug APK
`0eb7730` (`--dart-define=LIVE_SCAN=true`), installed with `adb install -r`; History backed up and md5-checked before
and after (99 files unchanged). No logcat exceptions or RenderFlex overflow.

| Check | Result |
|---|---|
| Learn hub Today card, archive row | OK (01) |
| Issue: hero, chips, EN/ID switch, quest map | OK after fix: "60 / 0 XP" and "English-page PDF · 4" were swapped ARB placeholders (02) |
| Sources sheet | Copy link only, no open (03) |
| PDF opens at page 2; page 2/3 earn Stop 1/2 | OK, server total 30, Jakarta day 9 Nov (UTC 8 Nov) counted, streak 1 (04-05) |
| Quiz: swipe never answers, front card only, flip back | OK (06-08); system back gesture from the left edge closes the quiz (OS) |
| Quiz first pass +10 XP via backend; retry from `_quiz_pool` 3/3 earns 0 | OK (server attempts 2, best 3, total 40) |
| Quiz result layout | Fixed: card was 33 dp left of centre and Q1-Q3 chips stacked; header "+10 XP" after a pass hidden |
| Accessibility | Fixed: TalkBack could reach all three stacked cards |
| Lab brief from published rubric | OK; safety items now end as sentences (10) |
| Lab record 30 s auto-stop, 8 frames, nothing sent before Send | Fixed: overlapping stops gave "0 photos ready" on a slow phone (11-12) |
| Real Gemini verdict | `retry`, correct reason (desk only), reasons en/id stored, no frames stored (13-14) |
| Ask teacher to review | `review_requested` recorded |
| Survives app restart | Server totals and stops kept |
| Lab `approved` +20 XP | Not tested: needs a real tray/cork/timer clip by the owner |
| Offline queue + restart | Not tested: needs airplane mode toggled by the owner |
| Guest import | Not tested: needs sign-out and Google sign-in by the owner |

The brief's "10 s clip" is shorter than the app's 15–30 s rule (G4 spec); the app keeps 15–30 s.
