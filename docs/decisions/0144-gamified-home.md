# 0144 Gamified Home (H1 v4)

Status: accepted for the H1v4 draft PR; owner review pending. Quest rewards: owner decided 2 Nov 2026 that they count. Replaces the layout of 0140 (its
achievement rules stay).

## Decision
Figma file J2jSbARJSyJCStNFeWkWDj, page "H1 v2 Home (reference style)" 321:2358: Home 333:4383,
Guest / no scans 334:4584, Loading 334:5265, dark 334:5353 / 334:5681 / 334:5993, Search 329:3722,
Calendar month 329:3836. Dark comes from `ElioTokens.dark` through the theme.

Sections, top to bottom: search, guest banner (guest sessions only), level hero, stats, daily quests,
scan activity (Year / Month), bin buddies, this week + quiz accuracy, medals, did you know. Removed
from Home: 3D robot viewer, continue learning, progress grid, recent activity, quick actions. The
header trophy pill and bell sit in the N4 top bar (`ElioTopBar.trailing`), Home tab only.

Data rules (`lib/models/home_stats.dart`, pure, unit-tested with a fixed clock):
- Source: `ScanRecordStore` only. Level, progress and "N to LvX" from `StudentLevel` (`trophy_rules.dart`).
- Days are local calendar days (`DateTime.toLocal()`), so counts split at local midnight.
- Day streak: consecutive days with a scan ending today, or yesterday when there is no scan today yet.
  Longest = longest run ever.
- Quiz accuracy: correct / answered over the last 10 scans that have answered questions; essays still
  waiting for a grade are not counted. "—" when none. Sparkline = per-scan % of those scans; change =
  last − first.
- Year grid: 17 weeks × 7, Sunday first, last column holds today; future days hidden; today outlined;
  5 levels (0, 1, 2, 3, 4+) as opacity of the primary fill. Tap a day → Month view with it selected.
- Bins are the robot's three bins: Organik = organic, **Anorganik = recyclable + residu** (the robot
  sorts residu there; the caption names the residu count), B3 = b3. "Top" = most scans, none on a tie.
- This week: Monday-first stacked bars of the current week, by bin.
- Total trophies = sum of `ScanRecord.trophies` + quest rewards (below).
- Daily quests from today's scans: scan 3 items (progress n/3), finish a scan quiz (a scan today with
  all its questions answered and graded), sort one B3 item. They reset at local midnight.
  **Rewards (+10, +10, +20) count toward trophies and levels** (owner, 2 Nov 2026). They are derived
  from each local day's scans (`questBonus`), nothing extra is stored, and only days from 2 Nov 2026
  count, so older records add nothing. `ScanRecordStore.totalTrophies` includes them, so Home, the
  header pill, History, the Control total and the quiz result popup all show the same number. Per-scan
  trophies in History rows are unchanged, so the History total is now more than the sum of its rows.
  An essay graded after midnight completes "Finish a scan quiz" for the day the scan was made.
- Medals: the three achievements of the old Home with the same unlock rules, gold art when unlocked,
  locked art otherwise. No new achievements. (Robotics Beginner and Sustainability Advocate look only
  at the tracked modules organic/inorganic/hazardous, so they cannot unlock today; unchanged.)
- Tree art: Lv1–2 sprout, Lv3–5 tree until more art exists.
- Did you know: a const list of 5 facts (the Figma one first), one per local day.

Search: local and offline over the cached video/guide/quiz-set streams, the 9 `physicsModules`, and
the user's scans by item name. 250 ms debounce; scope chips with counts, results count, clear button,
bold match; "See all" lifts the 2-per-group limit. Taps reuse existing routes: learning items via
`learningResumeIntentProvider`, simulations via `openPhysicsModule` (moved out of
`SimulationsContent`), scans and "Open in History" open the History tab (not filtered by day: History
has no date filter). "Scan an item" opens Control, like the old quick action.

Art: 13 SVGs exported from component frame 321:2359 into `assets/illustrations/home/` (grey canvas
rect removed), drawn with `flutter_svg`. Silver and bronze medals are exported but unused.

The bell opens the existing notifications panel, moved unchanged to
`lib/widgets/home_notifications_sheet.dart` (H2 #70 is still a draft); its badge is the existing
unread count.

## Differs from Figma
- Font: Figma uses Google Sans Flex, which the app does not bundle; titles and numbers use Inter.
- "Top" tag is clipped in Figma ("To"); drawn in full here.
- Medals header shows "N of 3" without "see all" (there is no medals screen).
- Signed-in avatar shows the N4 person icon or photo, not an initial.
- Dark hero progress track is a 25% tint of the on-primary ink (Figma's dark track and fill are both
  near-black).
- Medals stack one per row when a tile would be under 100 dp × text scale (360 dp, large text).
- Year-grid cells are about 14 dp, below 48 dp; Month view (52 dp cells) is the accessible way in.
