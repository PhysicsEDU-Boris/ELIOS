# Lane N handoff (N3 bottom nav)

Branch `feat/n3-bottom-nav` from `feature/live-scan` (#69 merged). Decision 0142.
- New `lib/widgets/elio_bottom_nav.dart`; `home_shell.dart` uses it (wrapped in `ElioTheme.wrap`), Profile -> `openDrawer`, `_confirmLeaveQuiz` shared by tab taps and Profile.
- Tests: `test/widgets/elio_bottom_nav_test.dart` (light and dark order, taps, Control never selected, avatar fallbacks, 320 dp at text 1.3). Break-checked: wrong Config index and swapped order both fail.
- Not tested: `HomeShell` provider mapping and quiz guard (HomeScreen needs Firebase); not built or run on Mac or phone.
- Pages with their own bottom padding or SafeArea (check by eye, not edited): home_screen, config_screen, elearning_tab, scan_history_screen, quiz_page. The Control circle floats over the page (FAB slot) and overlaps the last 20 dp above the bar, so any page with its own bottom padding under 20 dp can have content under the circle.
- Figma read: N3 Bottom nav 269:2358 (spec 270:8626, component 270:2378).
- Unrelated: worktree `elios-n3-shell` holds uncommitted rail/sidebar work (wide layouts); untouched.
- Device check (1 Nov 2026, Motorola edge 60 fusion, debug APK, dark): Profile opens the left drawer with the scrim over the bar and the Profile ring; Learn and Config switch tabs; Control opens the landscape route and Back returns. Not checked on device: light mode, quiz guard, text scale 1.3, offline photo. Learn and Config pages are still the legacy light look under the dark bar.
- Figma changed 1 Nov 2026: Profile cell -> History tab (index 4, `ScanHistoryScreen`), rounded top, no dividers. Checked on device: History tab opens and is active; rounded bar. Sidebar now only from the Home header menu or edge swipe. `control_layout.dart` still pushes ScanHistoryScreen as a route (unchanged).
- Control circle: green sphere with the live 3D robot (`assets/models/mobilElios5.glb`, opaque copy of the owner's file). Checked on device in light mode: drag spins it, a still press opens Control. Not checked: dark mode on device, battery or speed with the web view alive on every tab, pinch zoom.
- Dark mode white area: the shell Scaffold background (behind the rounded bar corners) now follows the saved theme mode (`home_shell.dart`). Found in a dark screenshot before the fix; the fixed build was NOT re-checked in dark mode (phone locked, then still on a light screen). Learn and Config are legacy light pages, so in dark mode their corner gaps are navy.
- Phone: `adb` night mode was set to auto at the end; the debug build `com.boris.elio` stays installed.
