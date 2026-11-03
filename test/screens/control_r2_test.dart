// R2 on the real ControlScreen (no robot: the link is down) and the camera HUD.
import 'dart:convert';

import 'package:elio/Screens/control_screen.dart';
import 'package:elio/models/control_session.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/websocket_service.dart' show Detection;
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/control/control_panels.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/control_layout.dart' show EmergencyStopButton;
import 'package:elio/widgets/elio_drawer_host.dart';
import 'package:elio/widgets/elio_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<ProviderContainer> _pumpScreen(WidgetTester t) async {
  t.view.physicalSize = const Size(1366, 768);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ControlScreen()),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> _leave(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const SizedBox()));
  await t.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GemmaQuizService.instance.mockSendExecute = (p, {imageBytes, fresh = false, isUser = false, onToken}) async => null;
  });
  tearDown(() => GemmaQuizService.instance.mockSendExecute = null);

  testWidgets('the avatar opens the existing drawer', (t) async {
    final c = await _pumpScreen(t);
    expect(t.state<ElioDrawerHostState>(find.byType(ElioDrawerHost)).isOpen, isFalse);
    await t.tap(find.bySemanticsLabel('Open profile menu'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.state<ElioDrawerHostState>(find.byType(ElioDrawerHost)).isOpen, isTrue);
    expect(find.byType(ElioSidebar), findsOneWidget);
    await _leave(t, c);
  });

  testWidgets('Voice uses the quiz TTS switch; Scan quiz is a session toggle', (t) async {
    final c = await _pumpScreen(t);
    expect(c.read(wasteQuizProvider).voiceOn, isTrue);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('toggle_voice')), matching: find.byType(Switch)));
    await t.pump();
    expect(c.read(wasteQuizProvider).voiceOn, isFalse);
    final scan = find.descendant(of: find.byKey(const ValueKey('toggle_scan_quiz')), matching: find.byType(Switch));
    expect(t.widget<Switch>(scan).value, isTrue);
    await t.tap(scan);
    await t.pump();
    expect(t.widget<Switch>(scan).value, isFalse);
    await _leave(t, c);
  });

  testWidgets('no robot: the disconnected design, controls dimmed, STOP live', (t) async {
    final c = await _pumpScreen(t);
    await t.pump(const Duration(seconds: 1));
    expect(
      find.text('Lost connection to ELIOS').evaluate().isNotEmpty ||
          find.text('Looking for MaixCAM2...').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.ancestor(of: find.byType(EmergencyStopButton), matching: find.byType(Opacity)), findsNothing);
    final joyOpacity = t.widget<Opacity>(
      find.ancestor(of: find.byType(DriveJoystick), matching: find.byType(Opacity)).first,
    );
    expect(joyOpacity.opacity, lessThan(1));
    await _leave(t, c);
  });

  group('camera HUD', () {
    Future<void> hud(WidgetTester t, List<Detection> d) async {
      t.view.physicalSize = const Size(640, 480);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ElioLightTheme.wrap(
              ControlCameraHud(
                frame: _png,
                imageSize: const Size(640, 480),
                detections: d,
                link: ControlLink.connected,
                fps: 10,
                retry: const RetryInfo(attempt: 0, maxAttempts: 30, nextRetryAt: null, autoReconnect: true),
                onReconnect: () {},
              ),
            ),
          ),
        ),
      );
      await t.pump();
    }

    HudFloorPainter painter(WidgetTester t) =>
        t.widgetList<CustomPaint>(find.byType(CustomPaint)).map((p) => p.painter).whereType<HudFloorPainter>().single;

    testWidgets('with dist_cm: floor bands, pick zone and "<label> · <n> cm"', (t) async {
      await hud(t, const [Detection(x: 320, y: 300, w: 120, h: 160, label: 'Plastic', score: 0.9, distCm: 24.4)]);
      expect(find.text('Plastic · 24 cm'), findsOneWidget);
      expect(painter(t).showFloor, isTrue);
    });

    testWidgets('without dist_cm: the label only, no bands, no invented distance', (t) async {
      await hud(t, const [Detection(x: 320, y: 300, w: 120, h: 160, label: 'Plastic', score: 0.9)]);
      expect(find.text('Plastic'), findsOneWidget);
      expect(find.textContaining('cm'), findsNothing);
      expect(painter(t).showFloor, isFalse);
    });

    testWidgets('hands are never tagged', (t) async {
      await hud(t, const [Detection(x: 320, y: 300, w: 120, h: 160, label: 'Human_Hand', score: 0.99, distCm: 22)]);
      expect(find.byKey(const ValueKey('hud_target_tag')), findsNothing);
    });

    test('band rows: nearer is lower in the image (decision 0022 geometry)', () {
      final rows = hudBandsCm.map(floorRowFraction).toList();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i], lessThan(rows[i - 1]));
      }
      expect(rows.every((r) => r > 0.5 && r < 1), isTrue);
    });
  });
}
