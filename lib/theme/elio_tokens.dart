import 'package:flutter/painting.dart';

/// Design tokens from docs/design.md (DevLog, dark). Names follow the file.
/// Deviations from the owner values (WCAG) are listed in docs/design.md under
/// "Deviations from the owner file"; each one is marked `DEVIATION` below.
abstract final class ElioTokens {
  // Brand palette
  static const primary = Color(0xFF4ADE80);
  static const secondary = Color(0xFFFBBF24);
  static const tertiary = Color(0xFF22D3EE);

  // Surface palette
  static const background = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceRaised = Color(0xFF334155);

  // Content palette
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  // DEVIATION: owner #64748B is 3.75:1 on background, 3.07:1 on surface.
  static const textTertiary = Color(0xFF8392A8);

  // Border palette
  static const borderSubtle = Color(0xFF1E293B);
  static const borderMedium = Color(0xFF334155);
  static const borderStrong = Color(0xFF475569);
  // DEVIATION: inputs (owner #334155, 1.72:1), checkbox/radio (owner #475569,
  // 2.36:1) need 3:1.
  static const formBorder = Color(0xFF64748B);

  // Semantic colours
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF22D3EE);

  // Button states
  static const primaryHover = Color(0xFF22C55E);
  static const primaryActive = Color(0xFF16A34A);
  static const destructiveHover = Color(0xFFEF4444);
  static const destructiveActive = Color(0xFFDC2626);

  // Quiz answer fills: fixed four-hue set. Old names (unchanged, in
  // elio_learning_colors.dart): elioAnswerRed/Blue/Yellow/Green = same hex.
  // DEVIATION: white on yellow is 2.38:1, so yellow takes dark text.
  static const answerRed = Color(0xFFE21B3C);
  static const answerBlue = Color(0xFF1368CE);
  static const answerYellow = Color(0xFFD89E00);
  static const answerGreen = Color(0xFF26890C);
  static const onAnswerRed = Color(0xFFFFFFFF);
  static const onAnswerBlue = Color(0xFFFFFFFF);
  static const onAnswerYellow = background;
  static const onAnswerGreen = Color(0xFFFFFFFF);

  // Fonts (bundled in assets/fonts, declared in pubspec.yaml)
  static const fontMono = 'JetBrains Mono';
  static const fontSans = 'Inter';
  static const _monoFallback = ['Fira Code', 'Cascadia Code', 'Consolas', 'monospace'];
  static const _sansFallback = ['-apple-system', 'Segoe UI', 'Helvetica', 'sans-serif'];

  static TextStyle _t(String family, double size, double weight, double height,
          double emSpacing) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: family == fontMono ? _monoFallback : _sansFallback,
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight)],
        height: height,
        letterSpacing: emSpacing * size,
      );

  // Type scale (colour is applied by the theme)
  static final display = _t(fontMono, 36, 700, 1.2, -0.02);
  static final headline = _t(fontMono, 28, 700, 1.3, -0.01);
  static final subhead = _t(fontMono, 20, 600, 1.4, 0);
  static final bodyLarge = _t(fontSans, 18, 400, 1.7, 0);
  static final body = _t(fontSans, 16, 400, 1.7, 0);
  static final bodySmall = _t(fontSans, 14, 400, 1.6, 0);
  static final caption = _t(fontSans, 12, 500, 1.5, 0.01);
  static final overline = _t(fontMono, 11, 600, 1.4, 0.1);
  static final code = _t(fontMono, 14, 400, 1.65, 0);
  // Component fonts
  static final button = _t(fontSans, 14, 600, 1.2, 0);
  static final label = _t(fontSans, 12, 600, 1.5, 0);
  static final chip = _t(fontMono, 12, 500, 1.4, 0);

  // Spacing
  static const spaceBase = 8.0;
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;
  static const space64 = 64.0;
  static const space96 = 96.0;
  static const spaceScale = [4.0, 8.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0];
  static const paddingSmall = 8.0;
  static const paddingMedium = 16.0;
  static const paddingLarge = 32.0;
  static const sectionMobile = 48.0;
  static const sectionTablet = 64.0;
  static const sectionDesktop = 96.0;

  // Radius (default 4; max XL 12 for containers)
  static const radiusNone = 0.0;
  static const radiusSmall = 4.0;
  static const radiusMedium = 6.0;
  static const radiusLarge = 8.0;
  static const radiusXl = 12.0;
  static const radiusFull = 9999.0;
  static const radiusCheckbox = 3.0;

  static const inputHeight = 40.0;
  static const disabledOpacity = 0.35;
  static const disabledInputOpacity = 0.4;
  static const tooltipMaxWidth = 260.0;

  static const dark = ElioPalette(
    isDark: true,
    background: background,
    surface: surface,
    surfaceRaised: surfaceRaised,
    field: background,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    borderSubtle: borderSubtle,
    borderMedium: borderMedium,
    borderStrong: borderStrong,
    formBorder: formBorder,
    primary: primary,
    primaryText: primary,
    onPrimary: background,
    primaryHover: primaryHover,
    primaryActive: primaryActive,
    secondaryText: secondary,
    tertiaryText: tertiary,
    error: error,
    errorText: error,
    onError: background,
    destructiveHover: destructiveHover,
    destructiveActive: destructiveActive,
    tooltipBg: textPrimary,
    tooltipText: background,
  );

  // Derived light set (docs/design.md addendum). Borders subtle/medium/strong
  // are decorative only; inputs, checkbox and radio use formBorder.
  static const light = ElioPalette(
    isDark: false,
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    field: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    borderSubtle: Color(0xFFE2E8F0),
    borderMedium: Color(0xFFCBD5E1),
    borderStrong: Color(0xFF94A3B8),
    formBorder: Color(0xFF64748B),
    primary: Color(0xFF4ADE80),
    primaryText: Color(0xFF15803D),
    onPrimary: Color(0xFF0F172A),
    primaryHover: Color(0xFF22C55E),
    primaryActive: Color(0xFF16A34A),
    secondaryText: Color(0xFFB45309),
    tertiaryText: Color(0xFF0E7490),
    error: Color(0xFFDC2626),
    errorText: Color(0xFFB91C1C),
    onError: Color(0xFFFFFFFF),
    destructiveHover: Color(0xFFB91C1C),
    destructiveActive: Color(0xFF991B1B),
    tooltipBg: Color(0xFF0F172A),
    tooltipText: Color(0xFFF1F5F9),
  );
}

/// Glow = BoxShadow, never Material elevation. Use only on hover, focus and
/// active (design.md rule 3). Blur values match the CSS blur radius.
abstract final class ElioGlow {
  static BoxShadow _g(Color c, double blur, double a) =>
      BoxShadow(color: c.withValues(alpha: a), blurRadius: blur);

  static final subtle = [_g(ElioTokens.primary, 8, 0.08)];
  static final medium = [_g(ElioTokens.primary, 16, 0.12)];
  static final large = [_g(ElioTokens.primary, 32, 0.16)];
  static final cyan = [_g(ElioTokens.tertiary, 20, 0.15)];
  static final amber = [_g(ElioTokens.secondary, 16, 0.12)];
  static final buttonHover = [_g(ElioTokens.primary, 16, 0.2)];
  static final destructiveHover = [_g(ElioTokens.error, 16, 0.2)];
  static final inputFocus = [_g(ElioTokens.primary, 12, 0.15)];
  static final inputError = [_g(ElioTokens.error, 12, 0.15)];
  static final control = [_g(ElioTokens.primary, 8, 0.1)];
  static final tooltip = [_g(ElioTokens.primary, 12, 0.1)];
  // Focus ring: 2 dp gap in background, then 2 dp of primary.
  static const focusRing = [
    BoxShadow(color: ElioTokens.background, spreadRadius: 2),
    BoxShadow(color: ElioTokens.primary, spreadRadius: 4),
  ];
  // The only non-glow shadow: dropdowns and overlays.
  static final overlay = [
    BoxShadow(color: ElioTokens.textPrimary.withValues(alpha: 0.06), spreadRadius: 1),
    BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.5),
        blurRadius: 48,
        offset: const Offset(0, 24)),
  ];
}

/// One mode's colours, same field names in both sets: [ElioTokens.dark] and
/// [ElioTokens.light]. Light values are the derived set in the docs/design.md
/// addendum. `primary` is the fill (buttons); `primaryText` is for text, links,
/// icons and focus on this mode's surfaces.
class ElioPalette {
  const ElioPalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.field,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.borderMedium,
    required this.borderStrong,
    required this.formBorder,
    required this.primary,
    required this.primaryText,
    required this.onPrimary,
    required this.primaryHover,
    required this.primaryActive,
    required this.secondaryText,
    required this.tertiaryText,
    required this.error,
    required this.errorText,
    required this.onError,
    required this.destructiveHover,
    required this.destructiveActive,
    required this.tooltipBg,
    required this.tooltipText,
  });

  final bool isDark;
  final Color background, surface, surfaceRaised;

  /// Input, checkbox and radio fill.
  final Color field;
  final Color textPrimary, textSecondary, textTertiary;
  final Color borderSubtle, borderMedium, borderStrong, formBorder;
  final Color primary, primaryText, onPrimary, primaryHover, primaryActive;
  final Color secondaryText, tertiaryText;
  final Color error, errorText, onError, destructiveHover, destructiveActive;
  final Color tooltipBg, tooltipText;
}

/// Light mode effects (addendum): no green glow on white. Focus = 2 dp ring
/// `#15803D` plus a 4 dp `rgba(22,163,74,0.25)` halo. Hover = raised fill.
abstract final class ElioLightEffects {
  static const focus = [
    BoxShadow(color: Color(0x4016A34A), spreadRadius: 6),
    BoxShadow(color: Color(0xFF15803D), spreadRadius: 2),
  ];
  static const card = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const overlay = [
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
