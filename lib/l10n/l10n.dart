import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

final _en = lookupAppLocalizations(const Locale('en'));
AppLocalizations _current = _en;

/// The app's current language for code without a BuildContext (models, enums,
/// painters). Set by [ElioApp]; English in tests that pump bare widgets.
AppLocalizations get l10n => _current;

// Loads every locale's date names synchronously; Material only does this for
// the app's own locales, and bare test widgets have none.
final _dates = initializeDateFormatting();

/// Locale for DateFormat in code without a BuildContext.
String get dateLocale {
  _dates;
  return _current.localeName;
}

/// Called from ElioApp's builder. A language change marks every element dirty,
/// so widgets that only read [l10n] (no Localizations dependency) rebuild too.
void updateCurrentL10n(BuildContext context) {
  final next = AppLocalizations.of(context) ?? _en;
  if (next.localeName == _current.localeName) return;
  _current = next;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  });
}

extension L10nContext on BuildContext {
  /// English when no Localizations ancestor exists (bare MaterialApps in tests).
  AppLocalizations get l10n => AppLocalizations.of(this) ?? _en;
}
