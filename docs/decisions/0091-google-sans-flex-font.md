# 0091 Font change in the design file: Google Sans Flex

Status: draft, design file only. Code adoption is a later task.

## Decision
- `docs/design.md` now specifies Google Sans Flex for headings and UI text and Google Sans Code for code. It replaces JetBrains Mono (headings, code) and Inter (UI/body). Google Sans Flex is proportional, so Display, Headline and Overline are no longer monospaced.
- The Status Chip spec is rewritten (pill, sentence case, leading icon per status, Filled or Outlined, Small 24 px or Medium 32 px). Light-mode tints are lowered (6% success, 4% warning, 8% error, 6% info) because 12% fails 4.5:1 on light.
- The Figma file (U9 Entry flow, ELIOS UI, ELIOS PIPELINE and the archive page) already uses the new fonts.

## Not done
- No Flutter change. `assets/fonts/` and `pubspec.yaml` still bundle JetBrains Mono and Inter, `ElioTokens` still names them, and `home_screen.dart` still uses Sora and Manrope through `google_fonts`. Decision 0090 describes the current code and stays true until the adoption task.
- The Google Sans Flex and Google Sans Code licences have not been checked for bundling. Check them before adding the files.
- The wordmark animation in the splash was laid out for a proportional font in Figma; the Flutter version must measure each letter, not assume a fixed advance.
