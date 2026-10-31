import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/Screens/login_screen.dart';
import 'package:elio/Screens/splash_screen.dart';

import 'auth_test_support.dart';

/// Writes the PNGs in docs/test-results/u9-entry-flow/ (run with U9_RENDER=1):
///   U9_RENDER=1 flutter test test/screens/u9_render_test.dart
/// Skipped in normal runs so the committed images do not change.
final _render = Platform.environment['U9_RENDER'] == '1';
const _out = 'docs/test-results/u9-entry-flow';

Future<void> _png(WidgetTester t, String name) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _shot(Widget child) =>
    RepaintBoundary(key: const Key('shot'), child: child);

void main() {
  setUpAll(loadElioFonts);
  const sizes = {'phone': Size(390, 844), 'desktop': Size(1366, 768)};
  for (final MapEntry(key: device, value: size) in sizes.entries) {
    for (final b in Brightness.values) {
      testWidgets('render splash $device ${b.name}', (t) async {
        await pumpAt(
          t,
          _shot(SplashScreen(auth: MockFirebaseAuth())),
          size: size,
          brightness: b,
        );
        await t.pump();
        var at = 0;
        for (final (frame, ms) in [('F0', 0), ('F7', 2430), ('F11', 3300)]) {
          await t.pump(Duration(milliseconds: ms - at));
          at = ms;
          await _png(t, 'splash-$frame-${b.name}-$device');
        }
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 300));
        t.takeException();
      }, skip: !_render);

      testWidgets('render login $device ${b.name}', (t) async {
        for (final state in states) {
          final auth = state == 'error'
              ? FailAuth()
              : state == 'loading'
              ? SlowAuth()
              : MockFirebaseAuth();
          await pumpAt(
            t,
            _shot(LoginScreen(auth: auth)),
            size: size,
            brightness: b,
          );
          await openLoginState(t, state, auth);
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await t.pump(const Duration(milliseconds: 100));
          await _png(t, 'login-$state-${b.name}-$device');
        }
      }, skip: !_render);
    }
  }
}
