// Scan & quiz camera: zoom steps and a photo from the gallery (owner, 12 Nov
// 2026), and the coloured bin tiles of Scan to contribute.
import 'dart:typed_data';

import 'package:elio/Screens/scan/contribute_screen.dart';
import 'package:elio/Screens/scan/phone_scan_screen.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/frame_source/phone_frame_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/r2_control_harness.dart' show loadFonts;

class _Camera extends PhoneFrameSource {
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) =>
      const ColoredBox(color: Colors.black);
  @override
  Future<void> setZoom(double value) async {
    zoom = value.clamp(1.0, maxZoom);
    notifyListeners();
  }

  @override
  Future<void> pausePreview() async {}
  @override
  Future<void> resumePreview() async {}
}

class _Quiz extends WasteQuizNotifier {
  Uint8List? photo;
  @override
  WasteQuizUiState build() => const WasteQuizUiState();
  @override
  void onPhotoCaptured(Uint8List imageBytes) => photo = imageBytes;
  @override
  void dismiss() {}
}

Future<void> _pump(
  WidgetTester t,
  Widget screen, [
  _Quiz? quiz,
  Size size = const Size(390, 844),
]) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [if (quiz != null) wasteQuizProvider.overrideWith(() => quiz)],
      child: MaterialApp(home: screen),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    ElioSound.instance.sink = (_, _) {};
    await loadFonts();
  });
  tearDownAll(() => ElioSound.instance.sink = null);

  testWidgets('zoom steps follow what the camera can do', (t) async {
    final camera = _Camera()..maxZoom = 3;
    await _pump(t, PhoneScanScreen(source: camera), _Quiz());
    expect(find.byKey(const ValueKey('scan_zoom_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan_zoom_5')), findsNothing);
    await t.tap(find.byKey(const ValueKey('scan_zoom_2')));
    await t.pump(const Duration(milliseconds: 300));
    expect(camera.zoom, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('phone landscape: every camera control fits on screen', (
    t,
  ) async {
    await _pump(
      t,
      PhoneScanScreen(source: _Camera()..maxZoom = 3),
      _Quiz(),
      const Size(915, 412),
    );
    expect(t.takeException(), isNull, reason: 'no overflow');
    final screen = Offset.zero & const Size(915, 412);
    for (final key in ['scan_gallery', 'scan_zoom_3', 'scan_flash']) {
      expect(
        screen.contains(t.getRect(find.byKey(ValueKey(key))).bottomRight),
        isTrue,
        reason: key,
      );
    }
    expect(
      screen.contains(
        t.getRect(find.bySemanticsLabel('Take photo and identify')).bottomRight,
      ),
      isTrue,
    );
  });

  testWidgets('a camera without zoom shows no zoom steps', (t) async {
    await _pump(t, PhoneScanScreen(source: _Camera()), _Quiz());
    expect(find.byKey(const ValueKey('scan_zoom_1')), findsNothing);
  });

  testWidgets('a gallery photo starts the scan', (t) async {
    final quiz = _Quiz();
    final bytes = Uint8List.fromList([1, 2, 3]);
    await _pump(
      t,
      PhoneScanScreen(source: _Camera(), pickPhoto: () async => bytes),
      quiz,
    );
    await t.tap(find.byKey(const ValueKey('scan_gallery')));
    await t.pump(const Duration(milliseconds: 300));
    expect(quiz.photo, bytes);
  });

  testWidgets('a cancelled gallery pick starts nothing', (t) async {
    final quiz = _Quiz();
    await _pump(
      t,
      PhoneScanScreen(source: _Camera(), pickPhoto: () async => null),
      quiz,
    );
    await t.tap(find.byKey(const ValueKey('scan_gallery')));
    await t.pump(const Duration(milliseconds: 300));
    expect(quiz.photo, isNull);
  });

  testWidgets('contribute bins are three tiles; a tap selects one', (t) async {
    await _pump(t, ContributeScreen(source: _Camera()));
    expect(t.takeException(), isNull);
    final organic = find.bySemanticsLabel('Organic');
    expect(organic, findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await t.tap(find.text('Recyclable'));
    await t.pump(const Duration(milliseconds: 300));
    expect(
      t.getSemantics(find.text('Recyclable')),
      matchesSemantics(
        label: 'Recyclable',
        isButton: true,
        hasTapAction: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );
  });
}
