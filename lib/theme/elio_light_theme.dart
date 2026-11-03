import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'elio_theme_builder.dart';
import 'elio_tokens.dart';

export 'elio_glow_box.dart';

/// Explicit derived light theme (docs/design.md). Scoped: nothing applies it
/// unless a screen wraps itself in [ElioLightTheme.wrap] (or [ElioTheme.wrap]);
/// `MaterialApp.theme` is not touched.
abstract final class ElioLightTheme {
  static final _b = ElioThemeBuilder(ElioTokens.light);

  static Widget wrap(Widget child) => _b.wrap(child);
  static SystemUiOverlayStyle get overlayStyle => _b.overlayStyle;
  static ThemeData get data => _b.data;
  static ColorScheme get colorScheme => _b.colorScheme;
  static TextTheme get textTheme => _b.textTheme;
  static ButtonStyle get primaryButton => _b.primaryButton;
  static ButtonStyle get secondaryButton => _b.secondaryButton;
  static ButtonStyle get ghostButton => _b.ghostButton;
  static ButtonStyle get destructiveButton => _b.destructiveButton;

  /// Size variants: `style: ElioLightTheme.primaryButton.merge(ElioLightTheme.small)`.
  static ButtonStyle get small => _b.small;
  static ButtonStyle get large => _b.large;
}
