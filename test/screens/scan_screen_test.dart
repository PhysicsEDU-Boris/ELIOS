// Q3 phone camera scan (decision 0175): ready, model loading and skeleton at three
// phone sizes in light and dark, and the identify crop exactly as before (0041, 0070).
import 'package:elio/Screens/device_scan_screen.dart';
import 'package:elio/services/frame_source/viewfinder_crop.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/phone_harness.dart'
    show loadFonts, phoneSizes, savePng, shotKey;

const _pngDir = String.fromEnvironment('R3_PNG');

Future<List<String>> _pump(
  WidgetTester t,
  Size size, {
  required bool dark,
  required AiStatus ai,
  bool ready = true,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final taps = <String>[];
  final wrap = dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap;
  await t.pumpWidget(
    ProviderScope(
      child: RepaintBoundary(
        key: shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: wrap(
            Builder(
              builder: (context) => Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: ScanScreenLayout(
                  ready: ready,
                  error: null,
                  cameraName: 'Back camera',
                  preview: const ColoredBox(color: Color(0xFF9CA3AF)),
                  capturing: false,
                  cropGeometry: DeviceScanScreenTestHook.cropGeometry(size),
                  onBack: () => taps.add('back'),
                  onHistory: () => taps.add('history'),
                  avatar: const SizedBox.square(dimension: 38),
                  onScan: () => taps.add('scan'),
                  onSwitchCamera: () => taps.add('switch'),
                  testLabels: const ['Botol plastik'],
                  onTestLabel: (l) => taps.add('test $l'),
                  ai: ValueNotifier(ai),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return taps;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadFonts();
  });

  test('the identify crop rectangle is unchanged', () {
    final g = DeviceScanScreenTestHook.cropGeometry(const Size(915, 412));
    expect(g.panel, const Size(675, 412)); // the old 240 dp sidebar
    expect(g.box, const Size(260, 200));
    // Hard-coded from the pre-Q3 code for a 1280x720 photo.
    expect(viewfinderCropRect(1280, 720, panel: g.panel, box: g.box), (
      x: 367,
      y: 150,
      w: 545,
      h: 419,
    ));
    expect(viewfinderCropRect(640, 480, panel: g.panel, box: g.box), (
      x: 172,
      y: 126,
      w: 296,
      h: 228,
    ));
  });

  for (final size in phoneSizes) {
    for (final dark in [false, true]) {
      final tag =
          '${size.width.toInt()}x${size.height.toInt()} ${dark ? 'dark' : 'light'}';
      Future<void> shot(WidgetTester t, String name) async {
        if (_pngDir.isNotEmpty) {
          await savePng(
            t,
            _pngDir,
            'scan_${name}_${size.width.toInt()}x${size.height.toInt()}_${dark ? 'dark' : 'light'}',
          );
        }
      }

      testWidgets('camera ready $tag', (t) async {
        final taps = await _pump(
          t,
          size,
          dark: dark,
          ai: AiStatus.ready,
        );
        expect(t.takeException(), isNull);
        expect(find.text('ELIOS AI ready'), findsOneWidget);
        expect(find.text('Scan & make quiz'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('scan_button')));
        await t.tap(find.byKey(const ValueKey('scan_switch_camera')));
        expect(taps, ['scan', 'switch']);
        // The corners sit where the crop is: centred in the old panel.
        final corners = t.getRect(find.byKey(const ValueKey('scan_corners')));
        final g = DeviceScanScreenTestHook.cropGeometry(size);
        expect(corners.center, Offset(g.panel.width / 2, g.panel.height / 2));
        expect(corners.size, g.box);
        await shot(t, 'ready');
      });

      testWidgets('camera, AI offline: Scan still works, chip says bank $tag', (t) async {
        final taps = await _pump(t, size, dark: dark, ai: AiStatus.offline);
        expect(t.takeException(), isNull);
        expect(find.text('ELIOS AI offline · question bank'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('scan_button')));
        expect(taps, ['scan']);
        await shot(t, 'offline');
      });

      testWidgets('camera skeleton $tag', (t) async {
        await _pump(
          t,
          size,
          dark: dark,
          ai: AiStatus.idle,
          ready: false,
        );
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('scan_skeleton')), findsOneWidget);
        await shot(t, 'skeleton');
      });
    }
  }
}
