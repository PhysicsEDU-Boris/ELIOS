# 0146 Dark mode switch in every build; Android icon follows the theme

Status: Draft (owner request, 2 Nov 2026). Changes 0130 (gate) and 0110 (Android light icon in both modes).

## Decision
- The sidebar "Dark mode" row (0141) is shown in every build. The `DARK_MODE_OPTION` / `TESTER_BUILD`
  gate (`darkModeOption`) is removed. Why it seemed gone: the C1 phone builds were plain debug builds
  without either flag. Screens not yet on tokens (Control, History, scan screens) stay light.
- Android launcher icon follows the in-app theme. Two `activity-alias` launcher entries target
  `MainActivity`: `.LauncherLight` (default, `@mipmap/launcher_icon`) and `.LauncherDark`
  (`@mipmap/launcher_icon_dark`: the 0110 dark exports, foreground 199:921 on `#0F172A`).
  `ElioThemeModeNotifier` sends `setDark` on `elio/app_icon` on every change and after loading the
  saved mode. MainActivity switches the aliases in `onStop`.
- Why `onStop`: switching at once closed the app's window on the Edge 60 Fusion, because the alias it
  was opened through got disabled. Deferred, the app stays open. The trade-off: the first time you
  leave the app after a theme change, its window closes, so reopening starts at Home (the robot link
  and an open quiz are gone).
- iOS and macOS are unchanged (iOS keeps its system light/dark icon appearances). An iOS alternate icon
  needs Xcode project changes and shows a system alert on every switch; not done.

## Consequences
- After this update the launcher entry moves from `.MainActivity` to `.LauncherLight`; some launchers
  drop a home-screen shortcut once (the Edge 60 Fusion kept it).
- Tests: `test/theme/app_icon_theme_test.dart` (4).
