import 'dart:convert';

import 'package:elio/Screens/profile/profile_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ELIOS 3 Profile tab (Figma 629:100963): settings that used to live in the
/// sidebar and the Config settings sheet.
Widget _app(User? user, {VoidCallback? onSignOut}) => ProviderScope(
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      locale: ref.watch(appLocaleProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        updateCurrentL10n(context); // as ElioApp does
        return child!;
      },
      home: Scaffold(
        body: ProfileScreen(user: user, onSignOut: onSignOut ?? () {}),
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester t, Widget app) async {
  t.view.physicalSize = const Size(800, 3600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  // The app icon switch is a platform call; there is none in tests.
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('elio/app_icon'),
    (_) async => null,
  );
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

final _signedIn = MockUser(
  isAnonymous: false,
  uid: 'u1',
  displayName: 'Boris Agung',
  email: 'zazzikun@gmail.com',
);

void main() {
  tearDown(() => debugSetL10n(const Locale('en')));

  test('email is masked and initials come from the name', () {
    expect(maskEmail('zazzikun@gmail.com'), 'z•••@gmail.com');
    expect(maskEmail('bad'), 'bad');
    expect(initialsOf(_signedIn), 'BA');
    expect(initialsOf(MockUser(isAnonymous: false, email: 'sam@x.id')), 'SX');
  });

  testWidgets('every Profile setting is saved and loads after a restart', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(t, _app(_signedIn));

    Future<void> toggle(String title) async {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(MergeSemantics),
      );
      // The App tour section (0238) pushes the lower rows below the fold.
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await t.pumpAndSettle();
    }

    await toggle('Dark mode');
    await toggle('Sound effects'); // on → off
    await t.tap(find.text('Question bank'));
    await t.tap(find.text('Hard'));
    await t.tap(find.text('90s'));
    await t.pumpAndSettle();
    await toggle('Allow skipping');
    // Essay questions sits directly below Difficulty (decision 0219).
    final essayY = t.getTopLeft(find.text('Essay questions')).dy;
    expect(essayY, greaterThan(t.getTopLeft(find.text('Hard')).dy));
    expect(essayY, lessThan(t.getTopLeft(find.text('Timer')).dy));
    await toggle('Essay questions'); // off → on
    await t.drag(find.byType(Slider), const Offset(-2000, 0));
    await t.pumpAndSettle();
    // Language last: the labels above are English.
    await t.tap(find.text('Bahasa Indonesia'));
    await t.pumpAndSettle();
    expect(find.text('Tampilan'), findsOneWidget, reason: 'live switch');

    final saved = await SharedPreferences.getInstance();
    final prefs = jsonDecode(saved.getString('app_preferences_v1')!);
    expect(prefs, containsPair('soundEffects', false));
    expect(prefs, containsPair('masterVolume', 0.0));
    expect(prefs, containsPair('questionSource', 'bank'));
    expect(prefs, containsPair('quizDifficulty', 'Hard'));
    expect(prefs, containsPair('quizTimer', '90s'));
    expect(prefs, containsPair('skipAllowed', true));
    expect(prefs, containsPair('essayQuestions', true));
    expect(saved.getString('elio_theme_mode_v1'), 'dark');
    expect(saved.getString('elio_locale_v1'), 'id');

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted
      ..read(appPreferencesProvider)
      ..read(elioThemeModeProvider)
      ..read(appLocaleProvider);
    await t.pump();
    final p = restarted.read(appPreferencesProvider);
    expect(p.soundEffects, isFalse);
    expect(p.masterVolume, 0);
    expect(p.questionSource, QuestionSource.bank);
    expect(p.quizTimer, '90s');
    expect(restarted.read(elioThemeModeProvider), ElioThemeMode.dark);
    expect(restarted.read(appLocaleProvider), const Locale('id'));
  });

  testWidgets('avatar opens the account menu; Sign out and Switch account', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var signedOut = 0;
    await _pump(t, _app(_signedIn, onSignOut: () => signedOut++));
    expect(find.text('Boris Agung'), findsOneWidget);
    expect(find.text('z•••@gmail.com'), findsOneWidget);
    expect(find.text('Google account · history synced'), findsOneWidget);

    await t.tap(find.byKey(const Key('profile-avatar')));
    await t.pumpAndSettle();
    expect(find.text('Switch account'), findsOneWidget);
    await t.tap(find.text('Sign Out'));
    await t.pumpAndSettle();
    expect(signedOut, 1);

    await t.tap(find.byKey(const Key('profile-avatar')));
    await t.pumpAndSettle();
    await t.tap(find.text('Switch account'));
    await t.pumpAndSettle();
    expect(signedOut, 2);
  });

  testWidgets('guest fallback: not signed in, menu offers Sign in only', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var signedOut = 0;
    await _pump(
      t,
      _app(MockUser(isAnonymous: true), onSignOut: () => signedOut++),
    );
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(
      find.text('Guest · history saved on this phone only'),
      findsOneWidget,
    );

    await t.tap(find.byKey(const Key('profile-avatar')));
    await t.pumpAndSettle();
    expect(find.text('Switch account'), findsNothing);
    await t.tap(find.text('Sign in'));
    await t.pumpAndSettle();
    expect(signedOut, 1);
  });
}
