import 'package:elio/l10n/l10n.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's language plumbing in miniature: changing [locale] updates every guide screen live.
class G4TestApp extends StatelessWidget {
  const G4TestApp({
    super.key,
    required this.overrides,
    required this.home,
    required this.locale,
    this.dark = false,
    this.textScale = 1,
    this.reduceMotion = false,
  });

  final List<Override> overrides;
  final Widget home;
  final ValueNotifier<Locale> locale;
  final bool dark, reduceMotion;
  final double textScale;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: overrides,
    child: ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, l, _) => MaterialApp(
        locale: l,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: dark ? ElioDarkTheme.data : ElioLightTheme.data,
        builder: (context, child) {
          updateCurrentL10n(context);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          );
        },
        home: home,
      ),
    ),
  );
}
