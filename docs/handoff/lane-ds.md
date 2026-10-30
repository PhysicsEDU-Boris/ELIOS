# Lane DS handoff (design-system foundation)

## In progress
- Branch `feat/ds-foundation` from `feature/live-scan` 330c346, draft PR. Decision 0090.
- Dark theme only. Light tokens and theme are documented in `docs/design.md` but not built; the task text asked for dark.
- Nothing consumes the theme yet. `MaterialApp.theme` is untouched.

## What is here
- `lib/theme/elio_tokens.dart`: `ElioTokens` (colours, type scale, spacing, radius), `ElioGlow` (BoxShadow glows).
- `lib/theme/elio_dark_theme.dart`: `ElioDarkTheme.data`, `.wrap(child)`, button styles (primary, secondary, ghost, destructive, small, large), `ElioGlowBox`.
- `assets/fonts`: Inter and JetBrains Mono variable TTFs + OFL texts; declared in `pubspec.yaml`.
- `docs/design.md`: owner file verbatim + addendum + "Deviations from the owner file".

## Use
`ElioDarkTheme.wrap(const MyScreen())`; wrap fields or cards in `ElioGlowBox` for the hover/focus glow.

## Open
- Owner OK on the addendum (still marked DRAFT) and on the dark-only scope.
- `google_fonts` is still used by ~10 screens and fetches at runtime (offline on the robot). Needs its own task: bundle-based replacement or `allowRuntimeFetching = false`.
- Checkbox/radio render at 18 dp, not 16.
- Tests: 39 new in `test/theme`. Full suite: 617 pass, 2 known splash failures.
