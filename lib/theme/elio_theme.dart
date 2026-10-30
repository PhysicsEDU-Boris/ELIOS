import 'package:flutter/material.dart';

import 'elio_dark_theme.dart';
import 'elio_light_theme.dart';

abstract final class ElioTheme {
  /// Picks the dark or light theme from the platform brightness (ThemeMode.system).
  static Widget wrap(Widget child) => Builder(
        builder: (context) =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark
                ? ElioDarkTheme.wrap(child)
                : ElioLightTheme.wrap(child),
      );
}
