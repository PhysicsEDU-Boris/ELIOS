import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/elio_theme_mode_provider.dart';
import 'elio_dark_theme.dart';
import 'elio_light_theme.dart';

abstract final class ElioTheme {
  /// Uses the saved user choice, with light on the first frame.
  static Widget wrap(Widget child) => Consumer(
    builder: (context, ref, _) =>
        ref.watch(elioThemeModeProvider) == ElioThemeMode.dark
        ? ElioDarkTheme.wrap(child)
        : ElioLightTheme.wrap(child),
  );
}
