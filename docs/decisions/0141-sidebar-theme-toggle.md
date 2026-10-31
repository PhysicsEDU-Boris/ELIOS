# 0141 Sidebar from Figma N1 with a dark mode toggle

Status: accepted for the N1 draft PR; owner review pending.

## Decision
- `lib/widgets/elio_sidebar.dart` replaces the legacy drawer contents in `HomeShell` (Figma "N1 Sidebar" 244:2358: phone drawer 244:2561 light, 244:2625 dark). Tokens only, 48 dp rows, selected item has a surface fill, border and a green left bar, Guest chip, Sign Out in the error colour. Navigation, Sign Out and the quiz-leave guard are unchanged (the same `_onDrawerTap`).
- The Figma has no theme toggle, so its place is mine: a "Dark mode" switch row between the user row and Sign Out, following the shadcn sidebar footer pattern. It calls `elioThemeModeProvider.setMode` (decision 0130, saved on the device).
- The row stays behind `darkModeOption` (`DARK_MODE_OPTION` or `TESTER_BUILD`), as the Config setting does, until every screen is on tokens (0130).
- The bottom navigation bar and the other tabs stay on the legacy look.

## Not done
Desktop expanded sidebar and the collapsed rail (244:2359 to 244:2521); item badges and hover states from 244:2689 (the drawer has no hover).
