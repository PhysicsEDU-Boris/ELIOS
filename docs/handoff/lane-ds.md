# Lane DS handoff (design-system foundation)

## In progress
- Branch `feat/ds-foundation` from `feature/live-scan` 330c346, draft PR. Decision 0090.
- Dark and light themes (light added on owner request). `ElioTheme.wrap` follows the system brightness.
- Nothing consumes the theme yet. `MaterialApp.theme` is untouched.

## What is here
- `lib/theme/elio_tokens.dart`: `ElioTokens` (+ `.dark`/`.light` `ElioPalette`), `ElioGlow`, `ElioLightEffects`.
- `elio_theme_builder.dart` (palette to ThemeData), `elio_dark_theme.dart`, `elio_light_theme.dart`, `elio_theme.dart` (`ElioTheme.wrap`), `elio_glow_box.dart`. Button styles: primary, secondary, ghost, destructive, small, large.
- `assets/fonts`: Inter and JetBrains Mono variable TTFs + OFL texts; declared in `pubspec.yaml`.
- `docs/design.md`: owner file verbatim + addendum + "Deviations from the owner file".

## Use
`ElioDarkTheme.wrap(const MyScreen())`; wrap fields or cards in `ElioGlowBox` for the hover/focus glow.

## Open
- Owner OK on the addendum (still marked DRAFT).
- Light card has no faint shadow (border only); see design.md.
- `google_fonts` is still used by ~10 screens and fetches at runtime (offline on the robot). Needs its own task: bundle-based replacement or `allowRuntimeFetching = false`.
- Checkbox/radio render at 18 dp, not 16.
- Tests: 39 new in `test/theme`. Full suite: 617 pass, 2 known splash failures.
