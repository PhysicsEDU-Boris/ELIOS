import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/Screens/login_screen.dart';
import 'package:elio/Screens/splash_screen.dart';

import 'auth_test_support.dart';

void main() {
  setUpAll(loadElioFonts);
  for (final size in [const Size(390, 844), const Size(1366, 768)]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.3]) {
        for (final keyboard in [false, true]) {
          final name =
              '${size.width.toInt()}x${size.height.toInt()} ${brightness.name} '
              'scale $scale ${keyboard ? 'keyboard open' : 'keyboard closed'}';
          testWidgets('login: no overflow, all five states, $name', (t) async {
            for (final state in states) {
              final auth = state == 'error'
                  ? FailAuth()
                  : state == 'loading'
                  ? SlowAuth()
                  : MockFirebaseAuth();
              await pumpAt(
                t,
                LoginScreen(auth: auth),
                size: size,
                brightness: brightness,
                textScale: scale,
                viewInsets: keyboard
                    ? const EdgeInsets.only(bottom: 336)
                    : EdgeInsets.zero,
              );
              await openLoginState(t, state, auth);
              expect(t.takeException(), isNull, reason: state);
              // Every state keeps its primary action reachable by scrolling.
              expect(find.byType(FilledButton), findsOneWidget, reason: state);
              if (auth is SlowAuth) {
                auth.gate.complete();
                await t.pump();
                t.takeException(); // HomeShell needs Firebase.initializeApp
              }
            }
          });
        }
      }

      testWidgets(
        'splash: no overflow at ${size.width.toInt()}x${size.height.toInt()} ${brightness.name} scale 1.3',
        (t) async {
          await pumpAt(
            t,
            SplashScreen(auth: MockFirebaseAuth()),
            size: size,
            brightness: brightness,
            textScale: 1.3,
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 3300));
          expect(t.takeException(), isNull);
          await t.pump(const Duration(milliseconds: 300));
          t.takeException();
        },
      );
    }
  }
}
