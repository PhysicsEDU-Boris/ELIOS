# 0090 Design-system foundation (dark + light, scoped)

Status: accepted for the foundation PR; screen adoption is a later task.

## Decision
- `lib/theme/elio_tokens.dart` holds every colour, type-scale entry, spacing step, radius and glow from `docs/design.md` (`ElioTokens`, `ElioGlow`).
- `ElioPalette` (`ElioTokens.dark`, `ElioTokens.light`) carries one mode's colours under the same names; `elio_theme_builder.dart` builds a `ThemeData` from a palette. `ElioLightTheme` uses the derived light set from the addendum. `ElioTheme.wrap(child)` follows the platform brightness (ThemeMode.system); a manual switch is later.
- `lib/theme/elio_dark_theme.dart` builds an explicit `ThemeData` (Material 3, `ColorScheme.dark` from the tokens, not `fromSeed`) and exports `ElioDarkTheme.wrap(child)`.
- Scoped: `MaterialApp.theme` in `main.dart` is unchanged, so current screens look as before. A screen opts in by wrapping itself.
- Glow is a `BoxShadow` (`ElioGlow`, `ElioGlowBox`), shown only on hover, focus and active. No Material elevation, no drop shadows (overlay shadow excepted).
- Fonts: JetBrains Mono and Inter variable TTFs bundled in `assets/fonts` (OFL texts beside them). The robot is offline, so no runtime fetching; the theme does not use `google_fonts`.
- WCAG deviations from the owner file are in `docs/design.md` ("Deviations from the owner file"): Text Tertiary `#8392A8`, form border `#64748B`, dark text on quiz yellow.
- Old colour constants (`elio_learning_colors.dart`, `elio_colors.dart`) are untouched. `ElioTokens.answerRed/Blue/Yellow/Green` carry the same hues plus `onAnswer*` text colours.

## Not done
The manual light/dark switch in Settings, `google_fonts` removal from existing screens (`GoogleFonts.config.allowRuntimeFetching` is not set in this PR because the screens that use the package are out of scope), any screen adoption.
