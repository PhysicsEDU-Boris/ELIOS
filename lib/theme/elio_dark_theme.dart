import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'elio_tokens.dart';

/// Explicit DevLog dark theme (docs/design.md). Scoped: nothing applies it
/// unless a screen wraps itself in [ElioDarkTheme.wrap]; `MaterialApp.theme`
/// is not touched.
abstract final class ElioDarkTheme {

  /// Opts a subtree into the theme and sets light status/nav-bar icons.
  static Widget wrap(Widget child) => Theme(
        data: data,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child,
        ),
      );

  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark, // iOS naming: dark bar = light icons
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static RoundedRectangleBorder _shape(double r, [BorderSide side = BorderSide.none]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side);

  static Color _dim(Color c) => c.withValues(alpha: ElioTokens.disabledOpacity);

  /// Button colours by state: [base], hover/pressed, disabled at 0.35.
  static WidgetStateProperty<Color?> _states(Color base, Color hover, Color pressed) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _dim(base);
        if (s.contains(WidgetState.pressed)) return pressed;
        if (s.contains(WidgetState.hovered)) return hover;
        return base;
      });

  static WidgetStateProperty<Color?> _fg(Color c, [Color? hover]) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _dim(c);
        if (s.contains(WidgetState.hovered) && hover != null) return hover;
        return c;
      });

  static ButtonStyle _button({
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
  static final primaryButton = _button(
    bg: _states(ElioTokens.primary, ElioTokens.primaryHover, ElioTokens.primaryActive),
    fg: _fg(ElioTokens.background),
    border: ElioTokens.primary,
  );
  static final secondaryButton = _button(
    bg: _states(ElioTokens.surface, ElioTokens.surfaceRaised, ElioTokens.borderStrong),
    fg: _fg(ElioTokens.textPrimary),
    border: ElioTokens.borderMedium,
    borderHover: ElioTokens.borderStrong,
  );
  static final ghostButton = _button(
    bg: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.pressed)) return ElioTokens.surfaceRaised;
      if (s.contains(WidgetState.hovered)) return ElioTokens.surface;
      return Colors.transparent;
    }),
    fg: _fg(ElioTokens.textSecondary, ElioTokens.textPrimary),
    border: Colors.transparent,
  );
  static final destructiveButton = _button(
    bg: _states(ElioTokens.error, ElioTokens.destructiveHover, ElioTokens.destructiveActive),
    fg: _fg(ElioTokens.background),
    border: ElioTokens.error,
  );

  /// Size variants: `style: ElioDarkTheme.primaryButton.merge(ElioDarkTheme.small)`.
  static final small = ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
        textStyle: WidgetStatePropertyAll(ElioTokens.button.copyWith(fontSize: 12)),
      );
  static final large = ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
        textStyle: WidgetStatePropertyAll(ElioTokens.button.copyWith(fontSize: 16)),
      );

  static OutlineInputBorder _inputBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(ElioTokens.radiusSmall),
        borderSide: BorderSide(color: c),
      );

  static final ColorScheme colorScheme = const ColorScheme.dark(
    primary: ElioTokens.primary,
    onPrimary: ElioTokens.background,
    secondary: ElioTokens.secondary,
    onSecondary: ElioTokens.background,
    tertiary: ElioTokens.tertiary,
    onTertiary: ElioTokens.background,
    error: ElioTokens.error,
    onError: ElioTokens.background,
    surface: ElioTokens.background,
    onSurface: ElioTokens.textPrimary,
    onSurfaceVariant: ElioTokens.textSecondary,
    surfaceContainerLowest: ElioTokens.background,
    surfaceContainerLow: ElioTokens.surface,
    surfaceContainer: ElioTokens.surface,
    surfaceContainerHigh: ElioTokens.surfaceRaised,
    surfaceContainerHighest: ElioTokens.surfaceRaised,
    outline: ElioTokens.formBorder,
    outlineVariant: ElioTokens.borderMedium,
    inverseSurface: ElioTokens.textPrimary,
    onInverseSurface: ElioTokens.background,
  );

  static final TextTheme textTheme = TextTheme(
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
  ).apply(bodyColor: ElioTokens.textPrimary, displayColor: ElioTokens.textPrimary);

  static final ThemeData data = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ElioTokens.background,
    canvasColor: ElioTokens.background,
    fontFamily: ElioTokens.fontSans,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    dividerTheme: const DividerThemeData(color: ElioTokens.borderSubtle, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: ElioTokens.background,
      foregroundColor: ElioTokens.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: overlayStyle,
      titleTextStyle: ElioTokens.subhead.copyWith(color: ElioTokens.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    textButtonTheme: TextButtonThemeData(style: ghostButton),
    cardTheme: CardThemeData(
      color: ElioTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: _shape(ElioTokens.radiusSmall, const BorderSide(color: ElioTokens.borderMedium)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: ElioTokens.background,
      constraints: const BoxConstraints(minHeight: ElioTokens.inputHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      hintStyle: ElioTokens.bodySmall.copyWith(color: ElioTokens.textTertiary),
      labelStyle: ElioTokens.label.copyWith(color: ElioTokens.textSecondary),
      floatingLabelStyle: ElioTokens.label.copyWith(color: ElioTokens.textSecondary),
      helperStyle: ElioTokens.caption.copyWith(color: ElioTokens.textTertiary, fontWeight: FontWeight.w400),
      errorStyle: ElioTokens.caption.copyWith(color: ElioTokens.error, fontWeight: FontWeight.w400),
      border: _inputBorder(ElioTokens.formBorder),
      enabledBorder: _inputBorder(ElioTokens.formBorder),
      focusedBorder: _inputBorder(ElioTokens.primary),
      errorBorder: _inputBorder(ElioTokens.error),
      focusedErrorBorder: _inputBorder(ElioTokens.error),
      disabledBorder: _inputBorder(ElioTokens.borderMedium),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ElioTokens.surface,
      selectedColor: ElioTokens.primary,
      disabledColor: _dim(ElioTokens.surface),
      checkmarkColor: ElioTokens.background,
      side: const BorderSide(color: ElioTokens.borderMedium),
      shape: _shape(ElioTokens.radiusSmall),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      labelStyle: ElioTokens.chip.copyWith(color: ElioTokens.textSecondary),
      secondaryLabelStyle: ElioTokens.chip.copyWith(color: ElioTokens.background),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
      iconColor: ElioTokens.primary,
      textColor: ElioTokens.textPrimary,
      tileColor: Colors.transparent,
      selectedColor: ElioTokens.textPrimary,
      selectedTileColor: ElioTokens.surfaceRaised,
      titleTextStyle: ElioTokens.bodySmall.copyWith(color: ElioTokens.textPrimary),
      subtitleTextStyle: ElioTokens.caption.copyWith(color: ElioTokens.textTertiary, fontWeight: FontWeight.w400),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: _shape(ElioTokens.radiusCheckbox),
      checkColor: const WidgetStatePropertyAll(ElioTokens.background),
      fillColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final c = on ? ElioTokens.primary : ElioTokens.background;
        return s.contains(WidgetState.disabled) ? _dim(c) : c;
      }),
      side: WidgetStateBorderSide.resolveWith((s) {
        final c = s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? ElioTokens.primary
            : ElioTokens.formBorder;
        return BorderSide(color: s.contains(WidgetState.disabled) ? _dim(c) : c, width: 1.5);
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      visualDensity: VisualDensity.compact,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        final c = s.contains(WidgetState.selected) || s.contains(WidgetState.hovered)
            ? ElioTokens.primary
            : ElioTokens.formBorder;
        return s.contains(WidgetState.disabled) ? _dim(c) : c;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      visualDensity: VisualDensity.compact,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(ElioTokens.textPrimary),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ElioTokens.primary : ElioTokens.borderStrong),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 200),
      showDuration: Duration.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(maxWidth: ElioTokens.tooltipMaxWidth),
      textStyle: ElioTokens.caption.copyWith(color: ElioTokens.background),
      decoration: BoxDecoration(
        color: ElioTokens.textPrimary,
        borderRadius: BorderRadius.circular(ElioTokens.radiusSmall),
        boxShadow: ElioGlow.tooltip,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ElioTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _shape(ElioTokens.radiusLarge, const BorderSide(color: ElioTokens.borderMedium)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ElioTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ElioTokens.radiusLarge)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ElioTokens.surfaceRaised,
      contentTextStyle: ElioTokens.bodySmall.copyWith(color: ElioTokens.textPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: _shape(ElioTokens.radiusSmall),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: ElioTokens.primary,
      labelColor: ElioTokens.primary,
      unselectedLabelColor: ElioTokens.textSecondary,
      dividerColor: ElioTokens.borderSubtle,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelStyle: ElioTokens.button,
      unselectedLabelStyle: ElioTokens.button,
    ),
  );
}

/// Draws a glow around [child] on hover and on focus anywhere inside it
/// (glow only on hover, focus and active; never at rest). Pass [error] to
/// swap to the error glow while focused. Wrap a TextField, card or button.
class ElioGlowBox extends StatefulWidget {
  const ElioGlowBox({
    super.key,
    required this.child,
    this.glow,
    this.onFocusGlow,
    this.radius = ElioTokens.radiusSmall,
  });

  final Widget child;

  /// Shown on hover (default [ElioGlow.subtle]).
  final List<BoxShadow>? glow;

  /// Shown on focus (default [ElioGlow.inputFocus]).
  final List<BoxShadow>? onFocusGlow;
  final double radius;

  @override
  State<ElioGlowBox> createState() => _ElioGlowBoxState();
}

class _ElioGlowBoxState extends State<ElioGlowBox> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final shadows = _focus
        ? widget.onFocusGlow ?? ElioGlow.inputFocus
        : _hover
            ? widget.glow ?? ElioGlow.subtle
            : const <BoxShadow>[];
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focus = f),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: shadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
