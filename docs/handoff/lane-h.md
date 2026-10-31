# Lane H handoff (H1 home screen) — BLOCKED, docs only

Status 31 Oct 2026: Phase 0 (inventory) and the design review are done. Phase 2 (Flutter) and Phase 3 (visual check) were NOT started, because no Flutter/Dart toolchain was reachable. No `lib/` or `test/` file is changed.

## Why it stopped
- The owner's Mac shell is a Linux VM without Flutter, with no GitHub credentials (`git fetch` failed; its `origin/feature/live-scan` was stale at 346b9aa, the real base is f6179aa).
- The cloud container cannot download the Dart SDK (`storage.googleapis.com` is refused by the egress proxy).
- Without `flutter analyze`/`flutter test` and PNG renders I will not rewrite a 3,415-line screen. Nothing was implemented from imagination.

## What the current home is (`lib/Screens/home_screen.dart`, shown by `home_shell.dart` tab 0)
It is the learning dashboard, not a scan history. Order top to bottom:
1. Top bar: menu button (opens the shell drawer), avatar (photo or person icon), "Hello, {name}" (Guest if no name) with "Ready to learn with ELIO?", bell with unread badge (9+) that opens the notifications sheet (Mark all read, Clear all, per-item action such as Open Learning or Open Config).
2. Progress warning banner with Retry (shown on load error or sync warning).
3. Hero card: 3D robot viewer ("DRAG TO ROTATE"; has a rotating fallback stage) and 3 stats: Learning, Quiz Avg, Current.
4. Thin loading bar while progress loads.
5. Continue Learning card (CONTINUE LEARNING or START LEARNING) with a Continue or Continue Module button. It writes `learningResumeIntentProvider` then calls `onOpenLearning`.
6. Your Progress (action "View learning") with 3 cards: Learning, Quiz Avg, Current Module. Each opens a detail sheet (Completed Learning, Quiz History, Current Module, Unfinished Learning) with Open Learning / Open Quiz / Review Answers.
7. Insight card ("Smart sorting starts with recognizing the material.") — static content.
8. Achievements: Environmental Explorer, Robotics Beginner, Sustainability Advocate.
9. Recent Activity list (empty text "Your lessons, videos, quizzes, and reflections will appear here once you begin.").
10. Quick Actions: Learn (onOpenLearning), Config (tab 2), Control (tab 3), Camera (tab 3; shares Control's tab, kept as is).
11. Guest banner when the user is anonymous.
Data: `learningProgressProvider`, `progressSyncWarningProvider`, `unreadNotificationCountProvider`, `currentUserProvider`, video and guide streams from `_elearningContentService`. Pull to refresh invalidates the progress provider. No scan data is shown, so the "no scans / recent scans" states map to first launch (no progress) and with activity.
No element is a stub. Colours and fonts are hard-coded (`_ink`, `_border`, `elioGreen`, GoogleFonts Sora/Manrope), so Phase 2 must move them to ElioTokens.

## Figma (file J2jSbARJSyJCStNFeWkWDj)
A page "H1 Home screen" (243:2358) already existed when this run started (made by an earlier or parallel run; I did not change it). Frames:
- 243:2359 Phone / Light / With activity (390x2222)
- 243:2556 Phone / Dark / With activity
- 243:2753 Phone / Light / First launch (guest)
- 245:2358 Desktop 1280 / Light
- 245:2446 spec frame (shared with N1 Sidebar page 244:2358)
Not drawn (the spec says so): loading state, text scale 1.3, 360 dp width; also no dark first-launch frame and no contrast note frame.

## Contrast (dark tokens from design.md; computed, light not computed)
Text primary on bg 16.30, on surface 13.35. Text secondary on surface 5.71, on bg 6.96, on raised 4.04 (FAILS 4.5, never put secondary text on raised). Navy on primary button 10.25. Error text on surface 5.29. Non-text: primary on surface 8.40 (ok), border medium on bg 1.72 and border strong on bg 2.36 (below 3:1; borders are decoration, state must not rely on them).

## Next chat starts with
1. Run on a machine with Flutter (the owner's Mac or a CI job); rebase onto `feature/live-scan` f6179aa.
2. Decide the Figma gaps above (add loading, 1.3x, 360 frames), then do Phase 2/3 of the H1 prompt.
3. Ponytail markers on the stale base 346b9aa: waste_quiz_provider.dart:717,995; login_screen.dart:80; live_scan_state_machine.dart:23; gemma_quiz_service.dart:662,788,928,1065; robot/r1_constants.dart:68; fake_maixcam.py:378. PR #65 says there were none on f6179aa; recheck there.
