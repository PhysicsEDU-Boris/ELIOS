# 0160 Dark launch screen and launcher icon follow the in-app dark mode (Android)

Status: accepted for the N2 draft PR (owner request, 1 Nov 2026). Amends 0110 and 0130, which kept native launch screens and the icon light only.

## Decision
- Dark is still an in-app choice (0130). The app now mirrors it to Android through the `elio/appearance` channel (`AppearanceService`, `MainActivity.kt`), on every toggle and at every start.
- Launch screen: `UiModeManager.setApplicationNightMode` (API 31+) sets the per-app night mode, so the next cold start uses the new `values-night`, `values-night-v31` and `drawable-night` resources: navy `#0F172A` background and the same green seed as the light F0 (Figma 208:800 is the dark source). Before API 31 nothing changes (light).
- First Flutter frame: `startupModeOverrides()` reads the saved mode before `runApp`, so the Flutter splash starts dark with no white flash. Tests: `test/theme/elio_appearance_test.dart`.
- Launcher icon: two activity aliases, `LauncherLight` (default, enabled) and `LauncherDark` (disabled), with the dark foreground 199:921 on `#0F172A` (`ic_launcher_foreground_dark`). The swap runs in `MainActivity.onStop`, not at toggle time: swapping while the app is open closed the app on the test phone. The launcher may take a moment to refresh.

## Cost and limits
- The launcher entry is now an alias: a pinned home-screen shortcut created before this update may need to be added again. Tools that start `MainActivity` by name still work.
- Only Android. iOS and macOS icons follow the system appearance as before.
- The monochrome (themed icon) layer is the same in both aliases.
