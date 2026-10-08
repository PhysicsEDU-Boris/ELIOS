import 'package:elio/Screens/device_scan_screen.dart';
import 'package:elio/models/config_model.dart';
import 'package:elio/widgets/desktop_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void _setScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in const [Size(640, 320), Size(760, 360), Size(915, 412), Size(960, 540)]) {
    testWidgets('device scan screen has no overflow without a camera @ ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      _setScreen(tester, size);
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: DeviceScanScreen())));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Scan & Buat Kuis'), findsOneWidget);
      expect(find.text('Uji tanpa kamera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  group('macOS viewport', () {
    Future<Size> childSize(WidgetTester tester, {required bool landscape}) async {
      _setScreen(tester, const Size(1280, 800));
      desktopLandscape.value = landscape;
      addTearDown(() => desktopLandscape.value = false);
      const key = Key('content');
      await tester.pumpWidget(const MaterialApp(
        home: DesktopViewport(forceDesktop: true, child: SizedBox.expand(key: key)),
      ));
      return tester.getSize(find.byKey(key));
    }

    testWidgets('portrait screens use a 412dp phone column, not the full window', (tester) async {
      expect(await childSize(tester, landscape: false), const Size(412, 800));
    });

    testWidgets('landscape screens are capped at 960x540', (tester) async {
      expect(await childSize(tester, landscape: true), const Size(960, 540));
    });
  });

  test('camera source survives save/load and defaults to MaixCAM2', () {
    expect(const EspConfig().cameraSource, CameraSource.maixCam2);
    final saved = const EspConfig().copyWith(cameraSource: CameraSource.device).toMap();
    expect(EspConfig.fromMap(saved).cameraSource, CameraSource.device);
    expect(EspConfig.fromMap({'cameraSource': 'nonsense'}).cameraSource, CameraSource.maixCam2);
  });
}
