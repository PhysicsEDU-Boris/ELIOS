# 0215 — History tab in the Figma L4 style, with an entrance and nested-screen motion

Date: 12 November 2026. Branch `feat/history-l4-figma` (from `feat/elios3-setup-wifi`). Owner
request: make the History tab match the newest Figma (`10 · History (tab)`, 629:99388 light,
629:100097 dark), give it an entrance like Home's (0209) and add motion, sound and haptics to
the screens it opens.

## What changed against Figma

- Hero zone (751:31190) replaces the title + trophy strip: green ellipse under the status bar,
  darker circle, two sparkles, "History" with a squiggle, eco tree in a leaf box, "YOUR ECO
  LEVEL", level name (28 bold), a 6 px level bar, "n XP to Level n", tilted XP sticker and a
  tilted sync sticker (tap = sync now).
- Tiles: 98 high leaf shapes (mirrored on the second diagonal), tone tints (B3 red, Recyclable
  blue, Organic green); the selected one is surface with a 3 px green edge and a 26 px check on
  the top edge. The three-bin group sits as in Figma.
- Recent scans: no cards. 54 px leaf thumbnail, name, borderless bold chips (device on surface,
  Quiz info, Contribution warning with a dot), day, XP icon + amount. A red dot marks a
  contribution's thumbnail. "See timeline" is the tinted pill with the Figma timeline icon.
- By device: 150 high leaf cards; Phone bubble, ELIOS robot and drone art rise above the card;
  the drone has the dark lock badge.
- Questions to review: warning leaf card with the quiz paper art and a surface "Review" pill.
- New Figma icons in `assets/illustrations/history/`: XP (sprout spark, 760:31331), synced,
  timeline, phone, chip phone / robot, lock.
- The shell no longer puts History in a `SafeArea`; loading, empty and error states keep the
  plain title (without the sync chip, which wrapped the title letter by letter).

## Motion, sound, haptics

| Where | Motion | Sound | Haptic |
|---|---|---|---|
| Open History (every time; 1.5 s) | curve drops in, circle and sparkles pop, title rises and its squiggle draws, sync sticker drops in turning, tree grows from the pot then sways, level text rises, bar fills, XP sticker drops in and counts up, tiles pop in one by one, bins hop in, counts tick up | S2 tree, S4 bar full, S9-short sticker | light at the bar |
| Recent scans (after the hero) | heading rises, squiggle draws, See timeline slides in and its chevron nudges, rows rise, thumbnails pop in turning, XP counts up | - | - |
| By device (when scrolled to) | cards dealt from below, phone bubble pops and tilts, ELIOS rises and rocks, drone flies in and hovers, lock pops | S2 | light |
| Questions to review | card rises, paper pops in and wiggles, Review pops | S1 | select |
| Taps | tree springs: S2 + light. XP sticker wobbles: S9-short. Sync sticker wobbles: S1 + select. Tile (bins jump): S1 + select. Row, See timeline, Phone / ELIOS card, Review: S2 + light with a press squeeze. Drone shakes: S5 + warning | | |
| Scan timeline | entry S1 + select as the page lands; device hero pops and counts up, day pills and rows rise (again on a tab change); tabs S1 + select; row S2 + light | | |
| Scan detail | entry S1 + select; photo morphs from the row (Hero), title, stats, tabs and question cards rise; Export, photo, Explain: S2 + light | | |
| Explanation | entry S4 + light for a right answer, S1 + select otherwise; sections rise, again per question; Listen: select only (no sound over the voice); Export S2 + light; Next question S1 + select | | |
| Photo viewer | Close S1 + select, Share S2 + light | | |

Entry sounds wait for the route transition to finish (`elioOnRouteEntered`), so they do not land
on the tap sound. Reduce Motion shows everything at rest with no entrance sounds.

## Not 1:1

- Figma has no motion data for these frames (`get_motion_context` is empty); timings follow Home.
- Thumbnails show the real scan photo (Figma crops a mock scan card).
- "· saved locally" shows only while History is not synced (Figma shows it next to "Synced").
- Chevrons, the check and the not-synced / syncing cloud icons are Material look-alikes.
- The new XP icon is used on the History tab only; other screens keep the trophy icon.
- Scan timeline, Scan detail (Figma L3, 629:99653) and Explanation keep their current layout:
  only motion, sound and haptics were added there.
