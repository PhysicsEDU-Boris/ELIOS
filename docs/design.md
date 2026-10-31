# DevLog

Technical, terminal-inspired.

## Overview

DevLog is a dark-mode design system built for developer blogs and technical writing platforms. It channels the aesthetic of a well-configured terminal — green on dark, clean geometric headings (Google Sans Flex), and soft glowing accents that feel like phosphor on glass. Code blocks are first-class citizens here, and every typographic choice serves readability under sustained technical reading. The density is standard, giving code snippets and prose equal breathing room.

## Colors

### Brand Palette

| Token     | Hex       | Role                                        |
|-----------|-----------|----------------------------------------------|
| Primary   | `#4ADE80` | Green — links, active states, primary actions |
| Secondary | `#FBBF24` | Amber — warnings, highlights, annotations    |
| Tertiary  | `#22D3EE` | Cyan — info accents, secondary links          |

### Surface Palette

| Token          | Hex       | Role                                    |
|----------------|-----------|------------------------------------------|
| Background     | `#0F172A` | Navy-black base                          |
| Surface        | `#1E293B` | Cards, code blocks, panels               |
| Surface Raised | `#334155` | Hover states, elevated elements          |

### Content Palette

| Token          | Hex       | Role                                   |
|----------------|-----------|----------------------------------------|
| Text Primary   | `#F1F5F9` | Body text, headings                    |
| Text Secondary | `#94A3B8` | Comments, metadata, secondary copy     |
| Text Tertiary  | `#64748B` | Placeholders, disabled labels          |

### Border Palette

| Token         | Hex       |
|---------------|-----------|
| Border Subtle | `#1E293B` |
| Border Medium | `#334155` |
| Border Strong | `#475569` |

### Semantic Colors

| Token   | Hex       |
|---------|-----------|
| Success | `#4ADE80` |
| Warning | `#FBBF24` |
| Error   | `#F87171` |
| Info    | `#22D3EE` |

## Typography

### Font Stack

| Role             | Font                                                     |
|------------------|----------------------------------------------------------|
| Display/Headings | Google Sans Flex, 'Google Sans', Inter, sans-serif |
| UI/Body          | Google Sans Flex, 'Google Sans', -apple-system, 'Segoe UI', Helvetica, sans-serif |
| Mono/Code        | Google Sans Code, Consolas, monospace |

### Type Scale

| Level        | Font           | Size   | Weight | Line Height | Letter Spacing | Usage                        |
|--------------|----------------|--------|--------|-------------|----------------|------------------------------|
| Display      | Google Sans Flex | 36px   | 700    | 1.2         | -0.02em        | Hero titles, landing headers |
| Headline     | Google Sans Flex | 28px   | 700    | 1.3         | -0.01em        | Post titles                  |
| Subhead      | Google Sans Flex | 20px   | 600    | 1.4         | 0              | Section headings             |
| Body Large   | Google Sans Flex | 18px   | 400    | 1.7         | 0              | Lead paragraphs, intros      |
| Body         | Google Sans Flex | 16px   | 400    | 1.7         | 0              | Default reading text         |
| Body Small   | Google Sans Flex | 14px   | 400    | 1.6         | 0              | Sidebar, supplementary text  |
| Caption      | Google Sans Flex | 12px   | 500    | 1.5         | 0.01em         | Timestamps, file paths       |
| Overline     | Google Sans Flex | 11px   | 600    | 1.4         | 0.1em          | Category tags, labels        |
| Code         | Google Sans Code | 14px | 400    | 1.65        | 0              | Inline code, code blocks     |

## Spacing

| Property                    | Value   |
|-----------------------------|---------|
| Base unit                   | 8px     |
| Scale                       | 4, 8, 16, 24, 32, 48, 64, 96 |
| Component padding — small   | 8px     |
| Component padding — medium  | 16px    |
| Component padding — large   | 32px    |
| Section spacing — mobile    | 48px    |
| Section spacing — tablet    | 64px    |
| Section spacing — desktop   | 96px    |

## Border Radius

Shape scale from Material 3 ([corner radius scale](https://m3.material.io/styles/shape/corner-radius-scale)), ten steps. Corners are continuous (Apple "squircle", see [Rounded Corners in the Apple Ecosystem](https://medium.com/minimal-notes/rounded-corners-in-the-apple-ecosystem-1b3f45e18fcc)): in Figma set corner smoothing to 60% on every rounded rectangle except pills; in Flutter use `RoundedSuperellipseBorder` (or `ContinuousRectangleBorder` where it is not available) instead of `RoundedRectangleBorder`.

| Token (Figma)         | Value  | Usage                                                        |
|-----------------------|--------|--------------------------------------------------------------|
| `radius/none`         | 0px    | Dividers, rules                                              |
| `radius/xs`           | 4px    | Checkbox, radio inner shapes, small marks                    |
| `radius/s`            | 8px    | Filter chips, tooltips                                       |
| `radius/m`            | 12px   | Text inputs, banners, snackbars, code blocks                 |
| `radius/l`            | 16px   | Cards, list containers                                       |
| `radius/l-increased`  | 20px   | Large cards, sheets on small screens                         |
| `radius/xl`           | 28px   | Dialogs, bottom sheets (top corners)                         |
| `radius/xl-increased` | 32px   | Hero containers                                              |
| `radius/xxl`          | 48px   | Splash and onboarding hero shapes                            |
| `radius/full`         | 9999px | Buttons, status chips, status dots, avatars                  |

Old DevLog values replaced: 4 to 8 (Small), 6 to 12 (Medium), 8 to 16 (Large), 12 to 20+ (XL). The old default of 4px is now `radius/xs`.

**Optical roundness (nested shapes):** inner radius = outer radius - padding (for example 28 - 12 = 16). Never reuse the outer radius on a child; if the result is 0 or less, use `radius/none`. A pill button inside a 28px dialog needs no adjustment because it is Full.

## Shadows

**Philosophy:** DevLog uses a dark-mode glow system instead of traditional drop shadows. Accents emit soft colored light against the dark background, evoking a monitor glow.

| Level   | CSS Value                                             | Usage                    |
|---------|-------------------------------------------------------|--------------------------|
| Subtle  | `0 0 8px rgba(74, 222, 128, 0.08)`                   | Hover hints on cards     |
| Medium  | `0 0 16px rgba(74, 222, 128, 0.12)`                  | Active cards, focus rings|
| Large   | `0 0 32px rgba(74, 222, 128, 0.16)`                  | Modals, hero elements    |
| Overlay | `0 0 0 1px rgba(241, 245, 249, 0.06), 0 24px 48px rgba(0, 0, 0, 0.5)` | Dropdown menus, overlays |

**Special — Cyan Glow:** `0 0 20px rgba(34, 211, 238, 0.15)` — used for info elements and secondary focus states.

**Special — Amber Glow:** `0 0 16px rgba(251, 191, 36, 0.12)` — used for warning highlights and annotation markers.

## Components

### Buttons

**Primary**
- Background: `#4ADE80`
- Text: `#0F172A`
- Border: `1px solid #4ADE80`
- Padding: 8px 20px
- Font: Google Sans Flex, 14px, weight 600
- Radius: Full (pill)
- Hover: Background `#22C55E`, shadow `0 0 16px rgba(74, 222, 128, 0.2)`
- Active: Background `#16A34A`

**Secondary**
- Background: `#1E293B`
- Text: `#F1F5F9`
- Border: `1px solid #334155`
- Padding: 8px 20px
- Font: Google Sans Flex, 14px, weight 600
- Radius: Full (pill)
- Hover: Background `#334155`, border `#475569`
- Active: Background `#475569`

**Ghost**
- Background: transparent
- Text: `#94A3B8`
- Border: none
- Padding: 8px 20px
- Font: Google Sans Flex, 14px, weight 600
- Radius: Full (pill)
- Hover: Background `#1E293B`, text `#F1F5F9`
- Active: Background `#334155`

**Destructive**
- Background: `#F87171`
- Text: `#0F172A`
- Border: `1px solid #F87171`
- Padding: 8px 20px
- Font: Google Sans Flex, 14px, weight 600
- Radius: Full (pill)
- Hover: Background `#EF4444`, shadow `0 0 16px rgba(248, 113, 113, 0.2)`
- Active: Background `#DC2626`

**Sizes:** Small 6px 14px / 12px, Medium 8px 20px / 14px, Large 12px 28px / 16px

**Disabled:** Opacity 0.35, cursor not-allowed, no glow.

### Cards

**Default**
- Background: `#1E293B`
- Border: `1px solid #334155`
- Radius: Large 16px
- Padding: 24px
- Shadow: none
- Hover: Border `#475569`, shadow `0 0 8px rgba(74, 222, 128, 0.08)`

**Elevated**
- Background: `#1E293B`
- Border: `1px solid #475569`
- Radius: Large 16px
- Padding: 24px
- Shadow: `0 0 16px rgba(74, 222, 128, 0.12)`

### Inputs

**Text Input**
- Height: 40px
- Background: `#0F172A`
- Border: `1px solid #334155`
- Radius: Medium 12px
- Padding: 8px 14px
- Font: Google Sans Flex, 14px, weight 400
- Text color: `#F1F5F9`
- Placeholder color: `#64748B`
- Focus: Border `#4ADE80`, shadow `0 0 12px rgba(74, 222, 128, 0.15)`
- Error: Border `#F87171`, shadow `0 0 12px rgba(248, 113, 113, 0.15)`
- Disabled: Background `#1E293B`, opacity 0.4

**Label:** Google Sans Flex, 12px, weight 600, color `#94A3B8`, margin-bottom 6px.

**Helper Text:** Google Sans Flex, 12px, weight 400, color `#64748B`, margin-top 4px. Error helper color `#F87171`.

### Chips

**Filter Chip**
- Background: `#1E293B`
- Border: `1px solid #334155`
- Radius: Small 8px
- Padding: 4px 12px
- Font: Google Sans Flex, 12px, weight 500
- Text: `#94A3B8`
- Selected: Background `#4ADE80`, text `#0F172A`, border `#4ADE80`

**Status Chip** (MUI-style: pill, sentence case, leading icon)
- Shape: Radius Full (pill). Label: Google Sans Flex, 12px, weight 500, sentence case (no uppercase).
- Sizes: Small 24px high (padding 0 10px 0 8px, icon 16px, gap 4px). Medium 32px high (padding 0 12px 0 10px, icon 18px, gap 6px).
- Leading icon, one shape per status so colour is never the only cue: Success check-circle, Warning triangle-alert, Error alert-circle, Info info-circle.
- Variant Filled: tinted background, no border. Variant Outlined: transparent background, 1px border in the text colour.
- Text and icon colour: Success `#4ADE80` (light `#15803D`), Warning `#FBBF24` (light `#B45309`), Error `#F87171` (light `#B91C1C`), Info `#22D3EE` (light `#0E7490`).
- Filled tint: dark 12% of the text colour. Light 6% success, 4% warning, 8% error, 6% info (12% fails 4.5:1 on light).
- Not interactive: no hover or focus state. If a chip becomes clickable, use Filter Chip behaviour.

### Lists

**Default List Item**
- Padding: 12px 16px
- Border bottom: `1px solid #1E293B`
- Font: Google Sans Flex, 14px, weight 400
- Text: `#F1F5F9`
- Secondary text: `#64748B`, 12px
- Hover: Background `#1E293B`
- Active: Background `#334155`
- Leading element: 18px icon, color `#4ADE80`

### Checkboxes

- Size: 16px
- Border: `1.5px solid #475569`
- Radius: Extra small 4px
- Background: `#0F172A`
- Checked: Background `#4ADE80`, border `#4ADE80`, checkmark `#0F172A`
- Indeterminate: Background `#4ADE80`, dash `#0F172A`
- Hover: Border `#4ADE80`, shadow `0 0 8px rgba(74, 222, 128, 0.1)`
- Focus: Shadow `0 0 0 2px #0F172A, 0 0 0 4px #4ADE80`
- Disabled: Opacity 0.35
- Label: Google Sans Flex, 14px, weight 400, color `#F1F5F9`, margin-left 8px

### Radio Buttons

- Size: 16px
- Border: `1.5px solid #475569`
- Radius: 9999px
- Background: `#0F172A`
- Selected: Border `#4ADE80`, inner dot `#4ADE80` (6px)
- Hover: Border `#4ADE80`, shadow `0 0 8px rgba(74, 222, 128, 0.1)`
- Focus: Shadow `0 0 0 2px #0F172A, 0 0 0 4px #4ADE80`
- Disabled: Opacity 0.35
- Label: Google Sans Flex, 14px, weight 400, color `#F1F5F9`, margin-left 8px

### Tooltips

- Background: `#F1F5F9`
- Text: `#0F172A`
- Font: Google Sans Flex, 12px, weight 500
- Padding: 6px 12px
- Radius: Small 8px
- Max width: 260px
- Arrow: 6px, same background
- Delay: 200ms enter, 0ms leave
- Shadow: `0 0 12px rgba(74, 222, 128, 0.1)`

## Do's and Don'ts

1. **Do** use Google Sans Flex for all headings and UI text and Google Sans Code for code — one family keeps the terminal aesthetic clean.
2. **Do** give code blocks generous padding (24px) and distinguish them clearly with `#1E293B` backgrounds.
3. **Do** use the green glow sparingly — reserve it for hover, focus, and active states only.
4. **Don't** use light backgrounds; the dark navy-black `#0F172A` is the foundation. Never invert it.
5. **Don't** mix Amber and Cyan accents in the same component — one accent per element.
6. **Do** ensure all text meets WCAG AA contrast against `#0F172A` (minimum 4.5:1 for body).
7. **Don't** use heavy box shadows — glow effects should be subtle and atmospheric, not prominent.
8. **Do** support syntax highlighting themes that respect the green/amber/cyan palette.
9. **Do** take every corner radius from the scale in Border Radius (no ad-hoc values), use continuous corners, and compute nested radii as outer radius minus padding. **Don't** put Large or bigger corners on information-dense components such as cards full of text.
10. **Do** provide a visible focus ring on all interactive elements using the green glow for keyboard navigation.

---

# ELIOS addendum (31 Oct 2026). The text above is the owner's DevLog file, unchanged.

Status: accepted by the owner on 31 Oct 2026. DevLog (designmd.ai/chef/devlog, MIT, v1) defines DARK only; the site's Light/Dark switch only changes its preview. The light mode below is DERIVED from the same hues (Tailwind slate/green/amber/cyan/red) and contrast-checked on 31 Oct 2026.

## Mode rule
- Both modes ship. Default: follow the system setting (ThemeMode.system). A manual switch in Settings is a later task.
- Supersedes Do/Don't #4 ("don't use light backgrounds, never invert") and the "dark-mode glow" philosophy for light mode.
- The PDF export is always light (printing). Photos are never tinted.

## Light tokens (derived)
| Token | Hex | Note |
|---|---|---|
| Background | `#F8FAFC` | |
| Surface | `#FFFFFF` | cards, panels, inputs |
| Surface Raised | `#F1F5F9` | hover, elevated |
| Text Primary | `#0F172A` | 17.1:1 on bg |
| Text Secondary | `#475569` | 7.2:1 on bg |
| Text Tertiary | `#64748B` | 4.55:1 on bg, 4.76:1 on surface; NOT on Raised (4.34:1), use Secondary there |
| Border Subtle | `#E2E8F0` | decorative dividers only |
| Border Medium | `#CBD5E1` | decorative only (1.4:1) |
| Border Strong | `#94A3B8` | decorative only (2.5:1) |
| Form border (inputs, checkbox, radio) | `#64748B` | 4.76:1; needed for the 3:1 non-text rule |
| Primary (fills, buttons) | `#4ADE80` | button text `#0F172A`, 10.25:1; same as dark |
| Primary (text, links, icons on light) | `#15803D` | 5.02:1 on surface; `#16A34A` is only 3.3:1, never as text |
| Secondary (amber text) | `#B45309` | 5.0:1 |
| Tertiary (cyan text) | `#0E7490` | 5.4:1 |
| Error | `#DC2626` fill, `#B91C1C` text | white on `#DC2626` 4.83:1 |
| Tooltip | bg `#0F172A`, text `#F1F5F9` | same as dark's inverse, 16.3:1 |

## Light mode effects
- No green glow on white (invisible). Focus = 2 dp ring `#15803D` plus a 4 dp `rgba(22,163,74,0.25)` halo. Hover = Surface Raised fill. Cards = 1 px border `#CBD5E1` (decorative) with a faint `0 1px 2px rgba(15,23,42,0.06)`; no heavy shadows. Overlay = `0 8px 24px rgba(15,23,42,0.12)`.

## Deviations in DARK mode (the owner file fails WCAG here)
- Text Tertiary `#64748B` is 3.75:1 on bg and 3.07:1 on surface. Use the nearest lighter slate that reaches 4.5:1 on bg, surface and raised; record the value.
- Input border `#334155` (1.72:1) and checkbox/radio border `#475569` (2.36:1) need 3:1: use about `#64748B`.
- Quiz answer fills (`#E21B3C`, `#1368CE`, `#26890C`, `#D89E00`) stay a fixed four-hue set in both modes: white text on red, blue and green (4.71, 5.39, 4.50:1); `#0F172A` text on yellow (7.49:1; white is 2.38:1).

## Not in the DevLog file (defined in the foundation PR, see "Defined here" and "Light mode notes" below; still open: manual mode switch, Settings screen styles)
- Disabled, selected-list, snackbar, dialog, bottom-sheet, tab bar, app bar and switch styles; extend from the tokens and record them here.

---

# Deviations from the owner file (task DS, dark theme)

Scope of this PR: dark (`ElioDarkTheme`) and light (`ElioLightTheme`), both explicit
`ThemeData`, tokens as `ElioTokens.dark` / `ElioTokens.light` (same field names).
`ElioTheme.wrap(child)` picks one from the platform brightness. The theme is scoped:
`MaterialApp.theme` in `main.dart` is unchanged. The light set is the addendum's, unchanged;
every light text pair reaches 4.5:1 and every form border 3:1, so it has no deviations.

Ratios are WCAG 2.x, measured by `test/theme/elio_tokens_test.dart`.

| Token | Owner value | Used | Measured | Why |
|---|---|---|---|---|
| Text Tertiary | `#64748B` | `#8392A8` | 5.65:1 on bg, 4.63:1 on surface (owner: 3.75, 3.07) | text needs 4.5:1. Not valid on Surface Raised (3.28:1): use Text Secondary there (4.04:1 is also under 4.5, so no body text on Raised at all) |
| Form border: input | `#334155` | `#64748B` | 3.75:1 on bg input fill (owner: 1.72) | non-text needs 3:1 |
| Form border: checkbox, radio | `#475569` | `#64748B` | 3.75:1 on bg (owner: 2.36) | non-text needs 3:1 |
| Quiz yellow text | white on `#D89E00` | `#0F172A` on `#D89E00` | 7.49:1 (white: 2.38) | text needs 4.5:1 |
| Placeholder, helper, list secondary text | `#64748B` | `#8392A8` (Text Tertiary) | as Text Tertiary | same role as Text Tertiary |

Everything else in the dark theme uses the owner values unchanged. Quiz fills keep the
four hues; white text on red, blue, green measures 4.71, 5.39, 4.50:1.

## Defined here (not in the owner file)

Extended from the tokens, dark only. Disabled = opacity 0.35 (buttons, checkbox, radio) and
0.4 (inputs). Selected list tile = Surface Raised fill. Snackbar = Surface Raised fill, Text
Primary, Success/Error never used as the fill. Dialog and bottom sheet = Surface, radius
Extra large (28) / top corners, overlay shadow from the Shadows table. App bar = Background,
no elevation. Tab bar = Primary indicator, Text Secondary unselected. Switch = Primary track
when on, Border Strong off. Material text roles: `bodyLarge` = Body Small (Google Sans Flex 14), because Material 3 reads TextField
input text from it and the input spec is Google Sans Flex 14; the Body Large token (18) sits on
`titleMedium`. Checkbox and radio render at Material's 18 dp, not 16 (not themeable).
Glow comes from `ElioGlowBox` (hover, focus-within), not from Material elevation.
Not yet verified against screens: nothing consumes the theme.

## Fonts

Changed from JetBrains Mono + Inter to Google Sans Flex (headings and UI text) and Google Sans Code
(code only). Google Sans Flex is proportional, so the Display, Headline and Overline roles are no
longer monospaced. Status: DRAFT, design only. The Flutter app still bundles JetBrains Mono and
Inter (`assets/fonts/`, `pubspec.yaml`) and `home_screen.dart` still uses Sora and Manrope through
`google_fonts`; none of that has changed. When implemented, bundle Google Sans Flex and Google Sans
Code as variable TTFs with their licence texts (check the licence first), set weights with
`FontVariation('wght')`, and keep no runtime font fetching (the robot runs offline).
Figma has no SemiBold for JetBrains Mono, which is why the old Subhead and Overline were Bold;
Google Sans Flex has SemiBold.

## Light mode notes

Light buttons: primary and destructive keep their fill; destructive text is white on `#DC2626`
(hover `#B91C1C`, active `#991B1B`). Checkbox and radio use `#15803D` (Primary text) for the
selected and hover border, because the `#4ADE80` fill is under 3:1 on white. Focus is the addendum
ring and halo (`ElioLightEffects.focus`, drawn by `ElioGlowBox`); hover is a fill change, no glow.
Tooltip has no shadow. Cards are border-only: the faint `0 1px 2px` card shadow is exposed as
`ElioLightEffects.card` but cannot be set through `CardThemeData` without Material elevation.
