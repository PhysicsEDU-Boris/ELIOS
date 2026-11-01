# 0143 Profile top bar and phone drawer (N4)

Status: accepted for the N4 draft PR (stacked on N3, #72); owner review pending.

## Decision
Figma: page N4 Profile top bar 278:2358, top bar 278:2388, avatar button 278:2387, spec 279:2399.
- The bottom nav has no Profile item (already so since 0142; indices Home 0, Learn 1, Config 2, Control 3, History 4 unchanged).
- `lib/widgets/elio_top_bar.dart`: 56 dp bar, 40 dp avatar in a 48 dp target (label "Open profile menu", focus ring 2 px + 4 px halo, pressed halo), title 20 semibold, optional subtitle. Only the avatar is tappable. `HomeShell` shows it above every tab (Home, Learn, Configure, History) with the status-bar inset taken once.
- `lib/widgets/elio_drawer_host.dart` replaces `Scaffold.drawer` (it settles at 50% / 365 dp/s and can edge-swipe open). 304 dp, at most 80% of the width (288 at 360), scrim 40%, open 250 ms ease-out, close 200 ms ease-in, none with reduced motion. Closes by scrim tap, drag, Back (`PopScope`), Escape, or choosing a destination. No edge-swipe open.
- Drag follows the finger 1:1; direction lock: after 8 dp it is a drawer drag only if |dx| > |dy|, else the recognizer steps aside so the menu scrolls. Closes past 40% of the width or faster than 700 dp/s, otherwise it springs back.
- Focus moves into the drawer (profile header first) on open, the page behind is excluded from focus and semantics, and focus returns to the avatar when it has closed.
- The drawer content is the N1 sidebar unchanged (logo header, profile row, Dark mode switch behind `darkModeOption`, Sign Out). Owner chose it over the N4 spec's profile-first header with no brand mark (1 Nov, after a phone test).
- The Home screen lost its hamburger and its own avatar; its greeting and notification button stay (`HomeScreen.onOpenDrawer` removed).

## Not done / open
- Under 600 dp only is in the spec. Wide layouts have no rail or persistent sidebar yet, so the bar and drawer (with the old brand header) are used at every width.
- Learn still has its own "ELIO" app bar under the new bar, so it shows two bars. Learn's notification button lives there; needs a Figma decision.
- Drawer sub-screens pushed on top (Control, quiz pages) keep their own app bars.
- `HomeShell` is not widget-tested (needs Firebase); tests compose the same widgets. Not run on a phone or the Mac window.
