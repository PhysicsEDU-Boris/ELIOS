import 'package:elio/l10n/app_localizations.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/widgets/elio_sidebar.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same locale wiring as ElioApp in lib/main.dart.
Widget _app() => ProviderScope(
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      locale: ref.watch(appLocaleProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ElioSidebar(
          user: MockUser(isAnonymous: true, photoURL: ''),
          currentIndex: 0,
          onSelect: (_) {},
          onSignOut: () {},
          onClose: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('sidebar language picker switches the UI and saves the choice', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.text('Dark mode'), findsOneWidget);

    await t.tap(find.byKey(const Key('sidebar-language')));
    await t.pumpAndSettle();
    await t.tap(find.text('Bahasa Indonesia').last);
    await t.pumpAndSettle();

    expect(find.text('Mode gelap'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('elio_locale_v1'),
      'id',
    );
  });

  testWidgets('a saved language is restored on start', (t) async {
    SharedPreferences.setMockInitialValues({'elio_locale_v1': 'id'});
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.text('Mode gelap'), findsOneWidget);
  });
}
