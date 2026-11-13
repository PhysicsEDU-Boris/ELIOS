// Select vehicle (decision 0216, Figma 629:90849): slots, the locked drone's
// "Coming soon" reaction, no overflow in light/dark, EN/ID.
// SCAN_RENDER=<dir> writes PNGs.
import 'package:elio/Screens/scan/select_vehicle_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/r2_control_harness.dart' show loadFonts, savePng, shotKey;

const _png = String.fromEnvironment('SCAN_RENDER');

class _Mode extends ElioThemeModeNotifier {
  _Mode(this.mode);
  final ElioThemeMode mode;
  @override
  ElioThemeMode build() => mode;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(
  WidgetTester t, {
  Size size = const Size(390, 844),
  bool dark = false,
  String lang = 'en',
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  debugSetL10n(Locale(lang));
  addTearDown(() => debugSetL10n(const Locale('en')));
  await t.pumpWidget(
    RepaintBoundary(
      key: shotKey,
      child: ProviderScope(
        overrides: [
          elioThemeModeProvider.overrideWith(
            () => _Mode(dark ? ElioThemeMode.dark : ElioThemeMode.light),
          ),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SelectVehicleScreen(),
        ),
      ),
    ),
  );
  await _settle(t);
}

void main() {
  final sounds = <ElioSfx>[];
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    ElioSound.instance
      ..sink = ((s, _) => sounds.add(s))
      ..isSilent = (() async => false);
    await loadFonts();
  });
  tearDownAll(() => ElioSound.instance.sink = null);

  testWidgets('the locked drone knocks and shows Coming soon, ELIOS ticks', (
    t,
  ) async {
    await _pump(t);
    final toast = find.byKey(const ValueKey('vehicle_locked_toast'));
    double opacity() => t
        .widget<AnimatedOpacity>(
          find.ancestor(of: toast, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(), 0);

    sounds.clear();
    await t.tap(find.bySemanticsLabel('Drone, Coming soon'));
    await t.pump(const Duration(milliseconds: 400));
    expect(opacity(), 1);
    expect(sounds, [ElioSfx.knock]);
    await t.pump(const Duration(seconds: 3));
    expect(opacity(), 0);

    sounds.clear();
    ElioSound.instance.clock = () => DateTime(2030); // past the 120 ms gap
    addTearDown(() => ElioSound.instance.clock = DateTime.now);
    await t.tap(find.bySemanticsLabel('ELIOS, Ready'));
    await _settle(t);
    expect(sounds, [ElioSfx.tick]);
    expect(t.takeException(), isNull);
  });

  for (final (size, shape) in const [
    (Size(390, 844), 'portrait'),
    (Size(360, 640), 'small'),
    (Size(915, 412), 'landscape'),
  ]) {
    for (final dark in [false, true]) {
      for (final lang in ['en', 'id']) {
        final tag = '$shape-${dark ? 'dark' : 'light'}-$lang';
        testWidgets('no overflow: select vehicle $tag', (t) async {
          await _pump(t, size: size, dark: dark, lang: lang);
          expect(t.takeException(), isNull);
          if (_png.isNotEmpty) await savePng(t, _png, 'vehicle-$tag');
        });
      }
    }
  }
}
