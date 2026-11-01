# Lane N handoff (N3 bottom nav)

Branch `feat/n3-bottom-nav` from `feature/live-scan` (#69 merged). Decision 0142.
- New `lib/widgets/elio_bottom_nav.dart`; `home_shell.dart` uses it (wrapped in `ElioTheme.wrap`), Profile -> `openDrawer`, `_confirmLeaveQuiz` shared by tab taps and Profile.
- Tests: `test/widgets/elio_bottom_nav_test.dart` (light and dark order, taps, Control never selected, avatar fallbacks, 320 dp at text 1.3). Break-checked: wrong Config index and swapped order both fail.
- Not tested: `HomeShell` provider mapping and quiz guard (HomeScreen needs Firebase); not built or run on Mac or phone.
- Pages with their own bottom padding or SafeArea (check by eye, not edited): home_screen, config_screen, elearning_tab, scan_history_screen, quiz_page. The bar's layout box now includes the 16 dp raise, so body is 16 dp shorter than with the old bar.
- Unrelated: worktree `elios-n3-shell` holds uncommitted rail/sidebar work (wide layouts); untouched.
