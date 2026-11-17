# 0220 — Trophy icons become the XP icon

Date: 16 November 2026. Branch `chore/xp-icons` (from `feature/live-scan` 86f078e). Follows
0213 (the word "trophies" became "XP"); the cup icon was still shown next to XP numbers.

## Decision

Every `Icons.emoji_events*` is replaced by the existing XP sprout sticker
(`assets/illustrations/history/icon_xp.svg`) through one widget, `XpIcon(size)` in
`lib/widgets/xp_icon.dart`. Sizes are unchanged. The sticker is full colour, so the old
single-colour tint is dropped. No trophy image asset existed. The icons were decorative before
(the text beside them carries "XP" for screen readers) and stay excluded from semantics.

Replaced (10): Home hero XP sticker, `TrophyAmount` (Home quests), Scan timeline row, History
`HistoryTrophyChip` and Scan-card XP badge, Control History pill, phone Control `TrophyCount`,
old quiz popup score chip, old explanation overlay "correct" verdict badge, Daily Guide lab
badge.

## Not changed

Internal names (`TrophyAmount`, `trophies`, `s9_trophy_sparkle.wav`) and saved data.

## Tests

`test/widgets/xp_icon_test.dart`: no `Icons.emoji_events` left in `lib/` (fails on the old
code), XP chip shows the 14 dp sticker in light and dark.
