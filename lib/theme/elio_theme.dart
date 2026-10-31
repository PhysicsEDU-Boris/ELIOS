import 'package:flutter/material.dart';

import 'elio_dark_theme.dart';
import 'elio_light_theme.dart';

abstract final class ElioTheme {
  /// Light is the primary mode (owner, 31 Oct 2026), so the app starts light
  /// whatever the phone is set to. [ThemeMode.system] follows the platform
  /// brightness; the Settings switch that changes this comes later.
  static ThemeMode mode = ThemeMode.light;

  static Widget wrap(Widget child) => Builder(
        builder: (context) {
          final dark = mode == ThemeMode.dark ||
              (mode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          return dark ? ElioDarkTheme.wrap(child) : ElioLightTheme.wrap(child);
        },
      );
}
