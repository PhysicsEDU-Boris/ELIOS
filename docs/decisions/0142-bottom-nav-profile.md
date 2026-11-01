# 0142 Bottom nav with Control centre and Profile button

Status: accepted for the N3 draft PR; owner review pending. Owner decision 1 Nov 2026: the bottom nav stays.

## Decision
Figma: page N3 Bottom nav 269:2358, component set 270:5746, spec 270:8626. Cells have a 32 dp icon slot, 4 dp gap, 16 dp label line, hairline dividers (border/subtle) between cells, 4 dp Surface ring and 1.5 px primary-text stroke on Control (light shadow, dark glow), 32 dp Profile avatar with a 1.5 px form border, drawer scrim 40%.
- `lib/widgets/elio_bottom_nav.dart` replaces `BottomNavigationBar` in `HomeShell`. Visual order: Home, Learn, Control (centre, 56 dp Primary circle, navy icon, raised 16 dp), Config, Profile (user photo).
- Tab indices do not change (`navigationIndexProvider`: 0 Home, 1 Learn, 2 Config, 3 Control). The widget takes provider indices and orders the cells itself. Control is an action (pushes the landscape route) and is never selected.
- Profile opens the N1 sidebar with `Scaffold.openDrawer` (left drawer, as built in N1; the shell has no `endDrawer`). Profile counts as selected while the drawer is open. The quiz-leave dialog guards Learn, Config, Home and Profile (`_confirmLeaveQuiz`).
- Bar 64 dp + safe-area inset, grows with text scale. Active = filled icon, primary-text label (600) and a 24x3 stroke on the top rule. Focus = 2 px ring + 4 px halo from the palette. No animation of its own; ink splash off with `disableAnimations`.
- The circle is `ElioControlButton` in `Scaffold.floatingActionButton` (`ElioControlFabLocation`, no animation), so it overlaps the page and the bar stays 64 dp + inset: no strip above the bar, the page runs down to the top rule. The Control cell in the bar keeps the label, tap and semantics.
- Avatar: photo (initials shown while loading and on error, so offline never blocks), else initials, else a person icon for guests.
- Dark mode toggle gate (`DARK_MODE_OPTION`) is unchanged, in the sidebar.

## Not done
- Under 600 dp only is in the Figma spec; wide layouts (sidebar) are deferred, so the bar shows at every width for now.
- No rail or persistent sidebar on wide layouts (deferred). No test of `HomeShell` itself (needs Firebase init).
