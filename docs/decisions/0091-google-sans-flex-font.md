# 0091 Design file: Google Sans Flex font and rounded shape scale

Status: fonts adopted in code (5 Nov 2026, H3-fix); shape scale still design file only.

## Decision
- `docs/design.md` now specifies Google Sans Flex for headings and UI text and Google Sans Code for code. It replaces JetBrains Mono (headings, code) and Inter (UI/body). Google Sans Flex is proportional, so Display, Headline and Overline are no longer monospaced.
- The Status Chip spec is rewritten (pill, sentence case, leading icon per status, Filled or Outlined, Small 24 px or Medium 32 px). Light-mode tints are lowered (6% success, 4% warning, 8% error, 6% info) because 12% fails 4.5:1 on light.
- The Figma file (U9 Entry flow, ELIOS UI, ELIOS PIPELINE and the archive page) already uses the new fonts.

- Shape: the radius tokens follow the Material 3 corner radius scale (none 0, xs 4, s 8, m 12, l 16, l-increased 20, xl 28, xl-increased 32, xxl 48, full). Buttons, links and status chips are Full (pill); text inputs, banners and snackbars Medium 12; cards Large 16; dialogs and bottom sheets Extra large 28; checkbox Extra small 4; filter chips and tooltips Small 8. Corners are continuous (60% smoothing in Figma, `RoundedSuperellipseBorder` in Flutter); nested shapes use outer radius minus padding. The old 4px default is replaced.

## Not done
- No Flutter change (fonts and radii). `assets/fonts/` and `pubspec.yaml` still bundle JetBrains Mono and Inter, `ElioTokens` still names them, and `home_screen.dart` still uses Sora and Manrope through `google_fonts`. Decision 0090 describes the current code and stays true until the adoption task.
- The Google Sans Flex and Google Sans Code licences have not been checked for bundling. Check them before adding the files.
- The wordmark animation in the splash was laid out for a proportional font in Figma; the Flutter version must measure each letter, not assume a fixed advance.

## Code adoption (fonts, 5 Nov 2026)
- `assets/fonts/GoogleSansFlex-Variable.ttf` and `GoogleSansCode-Variable.ttf` (variable, from github.com/google/fonts `ofl/`) with their `OFL-*.txt`; Inter and JetBrains Mono removed. Licence checked: both SIL OFL 1.1, bundling allowed.
- `ElioTokens.fontSans` = Google Sans Flex, `fontMono` = Google Sans Code. Every type style except Code uses the sans family; weights via the `wght` axis, letter spacing as a fraction of the size (Caption 1 %, Overline 10 %, Display -2 %, Headline -1 %).
- Token test: type scale now passes; the radii test still fails because the M3 radius scale is not adopted yet. `home_screen.dart` Sora/Manrope via `google_fonts` is unchanged.
