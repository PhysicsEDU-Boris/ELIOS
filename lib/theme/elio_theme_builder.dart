import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'elio_tokens.dart';

/// Builds one explicit ThemeData from a palette. [ElioDarkTheme] and
/// [ElioLightTheme] each hold one instance.
class ElioThemeBuilder {
  ElioThemeBuilder(this.p);
  final ElioPalette p;



  /// Opts a subtree into the theme and sets light status/nav-bar icons.
  Widget wrap(Widget child) => Theme(
        data: data,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child,
        ),
      );

  late final overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Icons contrast with the mode; iOS names the bar brightness, not the icons.
    statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static RoundedRectangleBorder _shape(double r, [BorderSide side = BorderSide.none]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side);

  static Color _dim(Color c) => c.withValues(alpha: ElioTokens.disabledOpacity);

  /// Button colours by state: [base], hover/pressed, disabled at 0.35.
  WidgetStateProperty<Color?> _states(Color base, Color hover, Color pressed) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _dim(base);
        if (s.contains(WidgetState.pressed)) return pressed;
        if (s.contains(WidgetState.hovered)) return hover;
        return base;
      });

  WidgetStateProperty<Color?> _fg(Color c, [Color? hover]) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _dim(c);
        if (s.contains(WidgetState.hovered) && hover != null) return hover;
        return c;
      });

  ButtonStyle _button({
    required WidgetStateProperty<Color?> bg,
    required WidgetStateProperty<Color?> fg,
    required Color border,
    Color? borderHover,
  }) =>
      ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: bg,
        foregroundColor: fg,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith((s) {
          if (border == Colors.transparent) return BorderSide.none;
          final c = s.contains(WidgetState.hovered) ? borderHover ?? border : border;
          return BorderSide(color: s.contains(WidgetState.disabled) ? _dim(c) : c);
        }),
        shape: WidgetStatePropertyAll(_shape(ElioTokens.radiusSmall)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
        textStyle: WidgetStatePropertyAll(ElioTokens.button),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      );

  /// Primary: also the [ElevatedButton] and [FilledButton] default.
  late final primaryButton = _button(
    bg: _states(p.primary, p.primaryHover, p.primaryActive),
    fg: _fg(p.onPrimary),
    border: p.primary,
  );
  late final secondaryButton = _button(
    bg: _states(p.surface, p.surfaceRaised, p.borderStrong),
    fg: _fg(p.textPrimary),
    border: p.borderMedium,
    borderHover: p.borderStrong,
  );
  late final ghostButton = _button(
    bg: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.pressed)) return p.surfaceRaised;
      if (s.contains(WidgetState.hovered)) return p.surface;
      return Colors.transparent;
    }),
    fg: _fg(p.textSecondary, p.textPrimary),
    border: Colors.transparent,
  );
  late final destructiveButton = _button(
    bg: _states(p.error, p.destructiveHover, p.destructiveActive),
    fg: _fg(p.onError),
    border: p.error,
  );

  /// Size variants: `style: ElioDarkTheme.primaryButton.merge(ElioDarkTheme.small)`.
  late final small = ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
        textStyle: WidgetStatePropertyAll(ElioTokens.button.copyWith(fontSize: 12)),
      );
  late final large = ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
        textStyle: WidgetStatePropertyAll(ElioTokens.button.copyWith(fontSize: 16)),
      );

  static OutlineInputBorder _inputBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioTokens.radiusSmall),
        borderSide: BorderSide(color: c),
      );

  late final ColorScheme colorScheme = ColorScheme(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.secondaryText,
    onSecondary: p.isDark ? p.background : p.surface,
    tertiary: p.tertiaryText,
    onTertiary: p.isDark ? p.background : p.surface,
    error: p.error,
    onError: p.onError,
    surface: p.background,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceRaised,
    surfaceContainerHighest: p.surfaceRaised,
    outline: p.formBorder,
    outlineVariant: p.borderMedium,
    inverseSurface: p.tooltipBg,
    onInverseSurface: p.tooltipText,
  );

  late final TextTheme textTheme = TextTheme(
    displayLarge: ElioTokens.display,
    displayMedium: ElioTokens.headline,
    displaySmall: ElioTokens.headline,
    headlineLarge: ElioTokens.headline,
    headlineMedium: ElioTokens.subhead,
    headlineSmall: ElioTokens.subhead,
    titleLarge: ElioTokens.subhead,
    titleMedium: ElioTokens.bodyLarge,
    titleSmall: ElioTokens.bodySmall.copyWith(fontWeight: FontWeight.w600),
    // M3 reads TextField input text from bodyLarge; the input spec is Inter 14.
    // The Body Large token (18) is on titleMedium.
    bodyLarge: ElioTokens.bodySmall,
    bodyMedium: ElioTokens.body,
    bodySmall: ElioTokens.bodySmall,
    labelLarge: ElioTokens.button,
    labelMedium: ElioTokens.label,
    labelSmall: ElioTokens.overline,
  ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

  late final ThemeData data = ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    fontFamily: ElioTokens.fontSans,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    dividerTheme: DividerThemeData(color: p.borderSubtle, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: overlayStyle,
      titleTextStyle: ElioTokens.subhead.copyWith(color: p.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    textButtonTheme: TextButtonThemeData(style: ghostButton),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: _shape(ElioTokens.radiusSmall, BorderSide(color: p.borderMedium)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.field,
      constraints: const BoxConstraints(minHeight: ElioTokens.inputHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      hintStyle: ElioTokens.bodySmall.copyWith(color: p.textTertiary),
      labelStyle: ElioTokens.label.copyWith(color: p.textSecondary),
      floatingLabelStyle: ElioTokens.label.copyWith(color: p.textSecondary),
      helperStyle: ElioTokens.caption.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400),
      errorStyle: ElioTokens.caption.copyWith(color: p.errorText, fontWeight: FontWeight.w400),
      border: _inputBorder(p.formBorder),
      enabledBorder: _inputBorder(p.formBorder),
      focusedBorder: _inputBorder(p.primaryText),
      errorBorder: _inputBorder(p.error),
      focusedErrorBorder: _inputBorder(p.error),
      disabledBorder: _inputBorder(p.borderMedium),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.primary,
      disabledColor: _dim(p.surface),
      checkmarkColor: p.onPrimary,
      side: BorderSide(color: p.borderMedium),
      shape: _shape(ElioTokens.radiusSmall),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      labelStyle: ElioTokens.chip.copyWith(color: p.textSecondary),
      secondaryLabelStyle: ElioTokens.chip.copyWith(color: p.onPrimary),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
      iconColor: p.primaryText,
      textColor: p.textPrimary,
      tileColor: Colors.transparent,
      selectedColor: p.textPrimary,
      selectedTileColor: p.surfaceRaised,
      titleTextStyle: ElioTokens.bodySmall.copyWith(color: p.textPrimary),
      subtitleTextStyle: ElioTokens.caption.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: _shape(ElioTokens.radiusCheckbox),
      checkColor: WidgetStatePropertyAll(p.onPrimary),
      fillColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final c = on ? p.primary : p.field;
        return s.contains(WidgetState.disabled) ? _dim(c) : c;
      }),
      side: WidgetStateBorderSide.resolveWith((s) {
        final c = s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? p.primaryText
            : p.formBorder;
        return BorderSide(color: s.contains(WidgetState.disabled) ? _dim(c) : c, width: 1.5);
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      visualDensity: VisualDensity.compact,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        final c = s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? p.primaryText
            : p.formBorder;
        return s.contains(WidgetState.disabled) ? _dim(c) : c;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      visualDensity: VisualDensity.compact,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(p.isDark ? p.textPrimary : p.surface),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 200),
      showDuration: Duration.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(maxWidth: ElioTokens.tooltipMaxWidth),
      textStyle: ElioTokens.caption.copyWith(color: p.tooltipText),
      decoration: BoxDecoration(
        color: p.tooltipBg,
        borderRadius: BorderRadius.circular(ElioTokens.radiusSmall),
        boxShadow: p.isDark ? ElioGlow.tooltip : null,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _shape(ElioTokens.radiusLarge, BorderSide(color: p.borderMedium)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ElioTokens.radiusLarge)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceRaised,
      contentTextStyle: ElioTokens.bodySmall.copyWith(color: p.textPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: _shape(ElioTokens.radiusSmall),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: p.primary,
      labelColor: p.primaryText,
      unselectedLabelColor: p.textSecondary,
      dividerColor: p.borderSubtle,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelStyle: ElioTokens.button,
      unselectedLabelStyle: ElioTokens.button,
    ),
  );
}
