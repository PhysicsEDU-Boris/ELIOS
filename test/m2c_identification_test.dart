import 'dart:async';
import 'dart:typed_data';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/detection_crop.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _box = TrackedDetection(label: 'Plastic', x: 40, y: 20, w: 40, h: 20);

CapturedFrame _frame({Uint8List? bytes, int width = 80}) => CapturedFrame(
  bytes:
      bytes ??
      Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 20))),
  width: width,
  height: 40,
  timestamp: DateTime(2026),
);

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'Identification did not settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all ten firmware classes map explicitly, hand remains ignored', () {
    const expected = {
      'Cardboard': 'inorganic',
      'E_Waste': 'hazardous',
      'Glass': 'inorganic',
      'Human_Hand': null,
      'Metal': 'inorganic',
      'Organic': 'organic',
      'Paper': 'inorganic',
      'Paperboard': 'inorganic',
      'Plastic': 'inorganic',
      'Tetra_Pak': 'inorganic',
    };
    expect(ScannedWaste.detectorLabels.keys, unorderedEquals(expected.keys));
    for (final entry in expected.entries) {
      expect(
        ScannedWaste.fromLabel(entry.key).category?.id,
        entry.value,
        reason: entry.key,
      );
    }
    expect(LiveScanController.ignoredLabels, contains('Human_Hand'));
    expect(
      ScannedWaste.fromLabel('E_Waste', categoryHint: 'anorganik').category?.id,
      'hazardous',
    );
  });

  test(
    'crop scales center coordinates, clamps edges, rejects invalid input',
    () {
      final frame = _frame();
      final cropped = img.decodeImage(cropDetection((frame, _box))!)!;
      expect((cropped.width, cropped.height), (20, 10));
      const edge = TrackedDetection(label: 'Plastic', x: 0, y: 0, w: 40, h: 20);
      final clipped = img.decodeImage(cropDetection((frame, edge))!)!;
      expect((clipped.width, clipped.height), (10, 5));
      expect(cropDetection((_frame(width: 0), _box)), isNull);
      expect(cropDetection((_frame(bytes: Uint8List(0)), _box)), isNull);
      for (final box in const [
        TrackedDetection(label: 'Plastic', x: 1000, y: 20, w: 40, h: 20),
        TrackedDetection(label: 'Plastic', x: 40, y: 20, w: -1, h: 20),
        TrackedDetection(label: 'Plastic', x: double.nan, y: 20, w: 40, h: 20),
      ]) {
        expect(cropDetection((frame, box)), isNull);
      }
    },
  );

  group('locked robot crop → identification → quiz', () {
    final service = GemmaQuizService.instance;
    late ProviderContainer c;
    late WasteQuizNotifier quiz;
    late Completer<String?> identify;
    late List<Uint8List?> images;

    setUp(() async {
      await service.cancel();
      identify = Completer<String?>();
      images = [];
      service.mockSendExecute =
          (prompt, {imageBytes, fresh = false, isUser = false, onToken}) {
            images.add(imageBytes);
            return imageBytes != null ? identify.future : Future.value(null);
          };
      c = ProviderContainer();
      quiz = c.read(wasteQuizProvider.notifier)..toggleVoice();
    });
    tearDown(() async {
      quiz.dismiss();
      await service.cancel();
      service.mockSendExecute = null;
      c.dispose();
    });

    test('one lock sends the crop, then uses Gemma item and material', () async {
      var now = DateTime(2026);
      final controller = LiveScanController(
        clock: () => now,
        startQuiz: (box) {
          quiz.onRobotLocked(_frame(), box);
          return true;
        },
      );
      addTearDown(controller.dispose);
      const detection = Detection(
        label: 'Plastic',
        x: 40,
        y: 20,
        w: 40,
        h: 20,
        score: .9,
      );
      for (var i = 0; i < 20; i++) {
        controller.onDetections([detection]);
        now = now.add(const Duration(milliseconds: 100));
      }
      expect(controller.machine.askCount, 1);
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.identifying);
      await _until(() => images.isNotEmpty);
      final crop = img.decodeImage(images.single!)!;
      expect((crop.width, crop.height), (20, 10));
      identify.complete(
        '{"item":"kaleng aluminium","material":"aluminium","category":"anorganik"}',
      );
      await _until(
        () => c.read(wasteQuizProvider).phase == WasteQuizPhase.active,
      );
      expect(c.read(wasteQuizProvider).scan?.displayName, 'Kaleng aluminium');
      expect(c.read(wasteQuizProvider).scan?.material, 'aluminium');
      expect(images.where((image) => image != null), hasLength(1));
    });

    for (final detectorHazard in [true, false]) {
      test(
        'hazard from ${detectorHazard ? "detector" : "Gemma"} waits for confirmation',
        () async {
          final box = detectorHazard
              ? const TrackedDetection(
                  label: 'E_Waste',
                  x: 40,
                  y: 20,
                  w: 40,
                  h: 20,
                )
              : _box;
          quiz.onRobotLocked(_frame(), box);
          await _until(() => images.isNotEmpty);
          identify.complete(
            detectorHazard
                ? '{"item":"kotak plastik","category":"anorganik"}'
                : '{"item":"baterai","category":"B3"}',
          );
          await _until(
            () =>
                c.read(wasteQuizProvider).phase ==
                WasteQuizPhase.confirmingHazard,
          );
          expect(c.read(wasteQuizProvider).scan?.category?.id, 'hazardous');
          expect(
            images,
            hasLength(1),
            reason: 'No question before confirmation',
          );
          quiz.confirmHazard();
          quiz.confirmHazard();
          await _until(
            () => c.read(wasteQuizProvider).phase == WasteQuizPhase.active,
          );
          expect(images.where((image) => image == null), isNotEmpty);
        },
      );
    }

    test('label-only hazardous scans also wait for confirmation', () {
      quiz.startForLabel('E_Waste');
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.confirmingHazard);
      expect(images, isEmpty);
    });

    test(
      'hazard confirmation keeps ASKING, failure records no question timing',
      () {
        var now = DateTime(2026);
        final controller = LiveScanController(
          clock: () => now,
          startQuiz: (_) => true,
        );
        addTearDown(controller.dispose);
        const detection = Detection(
          label: 'E_Waste',
          x: 40,
          y: 20,
          w: 40,
          h: 20,
          score: .9,
        );
        controller.onDetections([detection]);
        now = now.add(const Duration(seconds: 1));
        controller.onDetections([detection]);
        controller.onQuizPhase(WasteQuizPhase.identifying);
        controller.onQuizPhase(WasteQuizPhase.confirmingHazard);
        expect(controller.machine.state, LiveScanState.asking);
        controller.onQuizPhase(WasteQuizPhase.finished);
        expect(controller.machine.lastAskFailed, isTrue);
        expect(controller.lastAskToQuestionMs, isNull);
      },
    );

    test('dismiss during identify discards the late result', () async {
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => images.isNotEmpty);
      quiz.dismiss();
      identify.complete('{"item":"baterai","category":"B3"}');
      await pumpEventQueue();
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
      expect(images, hasLength(1));
    });

    test(
      'invalid crop never calls Gemma or quizzes on detector label',
      () async {
        quiz.onRobotLocked(_frame(bytes: Uint8List(0)), _box);
        await _until(
          () => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished,
        );
        expect(c.read(wasteQuizProvider).notice, isNotNull);
        expect(images, isEmpty);
      },
    );

    test('unrecognized photo stops without a detector-label quiz', () async {
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => images.isNotEmpty);
      identify.complete('{"item":"tidak jelas"}');
      await _until(
        () => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished,
      );
      expect(c.read(wasteQuizProvider).notice, isNotNull);
      expect(images, hasLength(1));
    });

    test('malformed identification fields fail without throwing', () async {
      final result = service.identifyItem(Uint8List(0));
      identify.complete('{"item":42,"material":[],"category":true}');
      expect((await result).item, isNull);
    });
  });
}
