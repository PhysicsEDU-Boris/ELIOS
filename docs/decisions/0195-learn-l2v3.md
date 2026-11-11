# 0195 — Learn hub L2 v3 "organic" and the Learn-shortcuts sidebar

Date: 9 November 2026

Implements the owner-approved Figma L2 v3 (J2jSbARJSyJCStNFeWkWDj, page 560:2358: hub 570:5147 /
571:6200, sidebar 571:5567 / 571:5690). Stacked on `feat/g4-daily-guides` (#105) because the
ticket is the Daily Guides Today issue.

- Hub: curved green header (oversized quadratic curve) with a ring split into the module thirds,
  each arc filled by `moduleProgress`; title/subtitle keep the old strings. Today's Guide is a
  ticket (notches, tear line, polaroid sticking out, stop dots, Continue) lifted over the curve by a
  small render object (`_Lift`) so taps follow the painted position. Bubbles: Quiz, Mini lab
  (today's lab; hidden without an issue), Archive, Progress. Explore: squiggle heading, tabs
  Modules / Videos / Simulations / PDF guides with counts, and a bottom-aligned carousel of leaf
  cards (corners 30/10/30/10); the first card is large and is the "Jump back in" item when one is in
  progress. See all goes to the existing list pages.
- Removed from the hub: the knowledge-challenge hero, progress card, module chips and the separate
  Continue / Watch / Simulations / Guides sections; their features are reachable from the bubbles,
  tabs and See all. Guide archive row folded into the Archive bubble.
- Top bar on Learn: green, with the Daily Guides streak and total XP as pills. There is no "level"
  in the app, so the Figma's "Level 3 / Eco Learner" is not shown.
- Sidebar on the Learn tab: `ElioSidebar.body` replaces the Navigate section with
  `LearnShortcutsMenu` (Continue dropdown with Today's Guide and Jump back in, Explore tabs,
  Knowledge challenge, Mini lab, My progress, Guide archive); footer (profile, Dark mode, Language,
  Sign Out) unchanged. Rows set `learnShortcutProvider`; the hub opens the page or selects the tab
  and scrolls to Explore. The active row is the selected tab; the dropdown remembers its state.
  Tapping the scrim already closed the drawer (`ElioDrawerHost`). Other tabs keep app navigation.

Differences from the Figma: Medals bubble/row replaced by Progress (no medals feature in Learn);
the tablet "sidebar always open" layout is not implemented (the shell has no wide layout yet);
module titles stay as Firestore sends them (not localized).
