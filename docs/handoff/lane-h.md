# Lane H handoff (H1 home screen)

Branch `feat/h1-home-screen-v2` from `feature/live-scan` f6179aa. Draft PR. Decision 0140. (An earlier docs-only attempt, branch `feat/h1-home-screen`, was blocked for lack of Flutter; this branch supersedes it.)

## Figma (file J2jSbARJSyJCStNFeWkWDj, page "H1 Home screen" 243:2358)
- 243:2359 Phone / Light / With activity (390x2222)
- 243:2556 Phone / Dark / With activity
- 243:2753 Phone / Light / First launch (guest)
- 245:2358 Desktop 1280 / Light (wireframe with the N1 sidebar)
- 245:2446 spec frame; 252:2358 contrast note (added by this task, the only new node)

## Design to widget (`lib/Screens/home_screen.dart`)
- Top bar -> `_TopBar` (menu, avatar, greeting, bell + badge; 48 dp buttons).
- Hero: ELIO viewer + 3 stats -> `_HeroCard`, `_ElioRobot3DViewer` (fallback `_RotatingRobotStage`), `_HeroStat`.
- Warning banner -> `_ProgressWarning` (Retry).
- Continue card -> `_ContinueLearningCard` (overline, title, overall progress bar, `AuthPrimaryButton`).
- Your Progress -> `_SectionHeader`, `_ProgressGrid`, `_ProgressCard` (open the detail sheets).
- Did you know -> `_InsightCard`. Achievements -> `_AchievementList`. Recent Activity -> `_RecentActivityList` (empty text kept).
- Quick Actions -> `_QuickActions` (Learn, Config tab 2, Control tab 3, Camera tab 3). Guest note -> `_GuestBanner`.
- Shared: `_Card`, `_IconTile`, `_Bar`; `AuthPrimaryButton` and `authPalette` from `lib/widgets/auth`.
- Bottom nav is the shell's (`home_shell.dart`), unchanged.

## Differences from the design
See decision 0140: no "Welcome to ELIO" text, locked achievements show their description, no desktop sidebar (N1), no Figma frames for loading, text scale 1.3, 360 dp, dark first launch.

## Tests
`test/screens/home_screen_test.dart`: light and dark x empty, activity, loading; 360, 1.3x, tablet, desktop widths; 48 dp targets; every navigation target; semantics labels. `pumpAt` in `auth_test_support.dart` got an `overrides` argument.
Tests need empty local `.env.dev` and `.env.prod` (git-ignored).

## Open
- Sheets and the notification dialog keep the legacy look.
- Phone feel and the real 3D viewer are not checked here.

## Visual check (phase 3)
- A. PNGs from tests: `H1_RENDER=1 flutter test test/screens/home_screen_test.dart` writes 9 files to `docs/test-results/h1-home/` (phone light/dark activity and empty, loading, light/dark at text scale 1.3, desktop 1280 light/dark). Compared with Figma 243:2359, 243:2556, 245:2358. One round of fixes: Learning and Quiz Avg cards now have equal height (the Learning subtitle wrapped); locked achievement icon is grey, not green.
- Still different from Figma: headings and UI text use JetBrains Mono / Inter (the tokens) until DS2 bundles Google Sans Flex; Material icons instead of the Figma outline set; desktop has no sidebar; the real 3D robot is replaced by the static stage in renders.
- B. Native Mac check: skipped. Precondition 2 failed: no documented isolated test store (HOME or container override) exists in `docs/handoff`, `docs/NEXT_TASK.md` or `CLAUDE.md`, so the app was not built or launched and owner data was not touched. No phone work either (task rule).
