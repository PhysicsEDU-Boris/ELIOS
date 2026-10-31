import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/Screens/splash_screen.dart';
import 'package:elio/Screens/login_screen.dart';

import 'auth_test_support.dart';

double _opacityOf(WidgetTester t, Finder f) => t
    .widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first)
    .opacity;

// The ticker starts on the first frame after pumpWidget; one zero-length pump
// puts t = 0 at the start of every test below.
Future<RouteSpy> _pump(
  WidgetTester t, {
  bool signedIn = false,
  bool reduced = false,
}) async {
  final spy = await pumpAt(
    t,
    SplashScreen(auth: MockFirebaseAuth(signedIn: signedIn)),
    disableAnimations: reduced,
  );
  await t.pump();
  return spy;
}

const _ms = Duration(milliseconds: 1);

void main() {
  setUpAll(loadElioFonts);
  testWidgets('0 ms: nothing of the wordmark or tagline is visible', (t) async {
    await _pump(t);
    for (final l in ['E', 'L', 'I', 'O', 'S']) {
      expect(_opacityOf(t, find.text(l)), 0);
    }
    expect(
      _opacityOf(
        t,
        find.text('Environment Learning Intelligent Object Sorter'),
      ),
      0,
    );
    expect(find.text('ELIO'), findsNothing);
  });

  testWidgets('500 and 1700 ms: plant phase only, letters still hidden', (
    t,
  ) async {
    await _pump(t);
    await t.pump(_ms * 500);
    expect(_opacityOf(t, find.text('E')), 0);
    await t.pump(_ms * 1200); // 1700
    expect(_opacityOf(t, find.text('E')), 0);
    await t.pump(_ms * 249); // 1949, still the F4 pause
    expect(_opacityOf(t, find.text('E')), 0);
  });

  testWidgets('letters rise one by one, 160 ms each, from 1950 ms', (t) async {
    await _pump(t);
    await t.pump(_ms * 2110); // F5: E done, L not started
    expect(_opacityOf(t, find.text('E')), 1);
    expect(_opacityOf(t, find.text('L')), 0);
    await t.pump(_ms * 80); // 2190: L halfway
    expect(_opacityOf(t, find.text('L')), inExclusiveRange(0, 1));
    await t.pump(_ms * 560); // 2750: S done, tagline starts
    expect(_opacityOf(t, find.text('S')), 1);
    expect(
      _opacityOf(
        t,
        find.text('Environment Learning Intelligent Object Sorter'),
      ),
      0,
    );
  });

  testWidgets('3100 ms: wordmark and tagline fully in, still on the splash', (
    t,
  ) async {
    final spy = await _pump(t);
    await t.pump(_ms * 3100);
    for (final l in ['E', 'L', 'I', 'O', 'S']) {
      expect(_opacityOf(t, find.text(l)), 1);
    }
    expect(
      _opacityOf(
        t,
        find.text('Environment Learning Intelligent Object Sorter'),
      ),
      1,
    );
    expect(spy.pages, isEmpty);
  });

  testWidgets('signed out: dissolve starts at 3400 and Login shows at 3650', (
    t,
  ) async {
    final spy = await _pump(t);
    await t.pump(_ms * 3399);
    expect(spy.pages, isEmpty);
    await t.pump(_ms * 2); // just past 3400: navigation
    expect(spy.wentLogin, isTrue);
    await t.pump(_ms * 250); // dissolve done
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('signed in: routes to HomeShell', (t) async {
    final spy = await _pump(t, signedIn: true);
    await t.pump(_ms * 3402);
    expect(spy.wentHome, isTrue);
    expect(spy.wentLogin, isFalse);
    // HomeShell needs Firebase.initializeApp, which tests never call.
    t.takeException();
  });

  testWidgets('reduced motion: static F11, cut to Login after 600 ms', (
    t,
  ) async {
    final spy = await _pump(t, reduced: true);
    expect(_opacityOf(t, find.text('S')), 1);
    expect(
      _opacityOf(
        t,
        find.text('Environment Learning Intelligent Object Sorter'),
      ),
      1,
    );
    await t.pump(_ms * 599);
    expect(spy.pages, isEmpty);
    await t.pump(_ms * 2);
    expect(spy.wentLogin, isTrue);
    await t.pump(); // no dissolve
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('reduced motion, signed in: routes to HomeShell', (t) async {
    final spy = await _pump(t, signedIn: true, reduced: true);
    await t.pump(_ms * 602);
    expect(spy.wentHome, isTrue);
    t.takeException();
  });

  testWidgets('light and dark both build without overflow at 1366x768', (
    t,
  ) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      await pumpAt(
        t,
        SplashScreen(auth: MockFirebaseAuth()),
        size: const Size(1366, 768),
        brightness: b,
      );
      await t.pump(_ms * 3300);
      expect(t.takeException(), isNull);
      expect(find.text('E'), findsOneWidget);
    }
    // Leave the splash timers finished.
    await t.pump(_ms * 400);
    await t.pump(_ms * 300);
    t.takeException();
  });
}
