# 0142 Bottom nav with Control centre and History tab

Status: accepted for the N3 draft PR; owner review pending. Owner decision 1 Nov 2026: the bottom nav stays.

## Decision
Figma: page N3 Bottom nav 269:2358, component set 270:5746, spec 270:8626. Cells have a 32 dp icon slot, 4 dp gap, 16 dp label line, 4 dp Surface ring and 1.5 px primary-text stroke on Control (light shadow, dark glow), drawer scrim 40%.
- `lib/widgets/elio_bottom_nav.dart` replaces `BottomNavigationBar` in `HomeShell`. Visual order: Home, Learn, Control (centre, 56 dp Primary circle, navy icon, raised 16 dp), Config, History.
- Tab indices do not change (`navigationIndexProvider`: 0 Home, 1 Learn, 2 Config, 3 Control). The widget takes provider indices and orders the cells itself. Control is an action (pushes the landscape route) and is never selected.
- Owner changed the Figma on 1 Nov 2026: the Profile cell is replaced by History (clock-arrow), the bar has 28 dp rounded top corners with a 1 px outline on the top and sides, and no top rule or dividers. History is tab index 4 and shows `ScanHistoryScreen` (its close button goes Home). Indices 0 to 3 are unchanged.
- The bar no longer has a button for the sidebar (Figma open point). The drawer stays reachable from the Home header menu button and the left-edge swipe; other tabs need a menu button (not built).
- Bar 64 dp + safe-area inset, grows with text scale. Active = filled icon, primary-text label (600) and a 24x3 stroke on the top rule. Focus = 2 px ring + 4 px halo from the palette. No animation of its own; ink splash off with `disableAnimations`.
- The circle is `ElioControlButton` in `Scaffold.floatingActionButton` (`ElioControlFabLocation`, no animation), so it overlaps the page and the bar stays 64 dp + inset: no strip above the bar, the page runs down to the top rule. The Control cell in the bar keeps the label, tap and semantics.
- Dark mode toggle gate (`DARK_MODE_OPTION`) is unchanged, in the sidebar.

## Not done
- Under 600 dp only is in the Figma spec; wide layouts (sidebar) are deferred, so the bar shows at every width for now.
- No rail or persistent sidebar on wide layouts (deferred). No test of `HomeShell` itself (needs Firebase init).
