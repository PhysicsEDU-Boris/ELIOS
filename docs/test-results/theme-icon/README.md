# Theme switch + app icon: phone check (2 Nov 2026)

Edge 60 Fusion, Android 16, debug build (no DARK_MODE_OPTION / TESTER_BUILD), `adb install -r`, owner session
(no records touched; theme left on light).

| Check | Result | Files |
|---|---|---|
| Sidebar shows Dark mode without a flag | pass | `sidebar_light_toggle_back` |
| First build, instant switch | icon changed, but the app window closed each time → replaced | — |
| Switch to dark, app stays open | pass (`LauncherLight` still active until you leave) | `deferred_dark_app_stays` |
| Home → icon is dark (`LauncherDark`), reopen from it | pass | `drawer_dark_icon`, `deferred_reopen_dark` |
| Switch back to light, Home → `LauncherLight` | pass | `sidebar_dark_mode_on` |
| logcat FATAL | none | |

Not checked: whether a robot session survives leaving the app right after a theme change (expected: no,
the window closes), other launchers, iOS.
