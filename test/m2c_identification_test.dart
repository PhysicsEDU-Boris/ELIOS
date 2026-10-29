import 'dart:async';
import 'dart:io';

import 'package:elio/models/scanned_waste.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:elio/services/scan_record_store.dart';
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
  cleanBytes:
      bytes ??
      Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 20))),
  frameId: 1,
  detectionFrameId: 1,
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
      if (!identify.isCompleted) identify.complete(null); // let a held call end so the slot frees
      await service.cancel();
      await pumpEventQueue();
      service.mockSendExecute = null;
      service.mockBeforeSubmit = null;
      c.dispose();
    });

    test('one lock sends the crop, then uses Gemma item and material', () async {
      var now = DateTime(2026);
      final controller = LiveScanController(
        clock: () => now,
        startQuiz: (box, frame) {
          quiz.onRobotLocked(frame ?? _frame(), box);
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

    test('identification keeps the original crop while History saves the padded photo', () async {
      final root = await Directory.systemTemp.createTemp('d1-split-photo-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      final store = ScanRecordStore(customFile: File('${root.path}/records.json'));
      ScanRecordStore.setInstanceForTesting(store);
      addTearDown(() async {
        quiz.dismiss();
        await service.cancel();
        await pumpEventQueue();
        ScanRecordStore.setInstanceForTesting(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      });
      final frame = _frame();
      quiz.onRobotLocked(frame, _box);
      await _until(() => images.isNotEmpty);
      final submitted = images.single!;
      final source = img.decodeImage(frame.cleanBytes!)!;
      expect(submitted, orderedEquals(img.encodeJpg(
        img.copyCrop(source, x: 10, y: 5, width: 20, height: 10))));
      identify.complete('{"item":"botol plastik","material":"plastik","category":"anorganik"}');
      await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.active);
      quiz.state = quiz.state.copyWith(
        difficulty: QuizDifficulty.easy, questionIndex: 0,
        question: const GeneratedQuestion(
          type: QuizQuestionType.multipleChoice, question: 'Pilah botol?',
          options: ['Daur ulang', 'Bakar'], correctIndex: 0,
        ),
      );
      quiz.selectOption(0);
      quiz.nextQuestion();
      await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished);
      final photo = File(store.records.single.cropPhotoPath!);
      expect(photo.path, startsWith('${root.path}/scans/'));
      final saved = photo.readAsBytesSync();
      expect(saved, orderedEquals(prepareDetectionCrop((frame, _box)).historyBytes!));
      final decoded = img.decodeJpg(saved)!;
      expect((decoded.width, decoded.height), (22, 12));
      expect(c.read(wasteQuizProvider).cropBytes, orderedEquals(submitted));
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
                ? '{"item":"kotak plastik","category":"residu"}'
                : '{"item":"baterai","category":"B3"}',
          );
          await _until(
            () =>
                c.read(wasteQuizProvider).phase ==
                WasteQuizPhase.confirmingHazard,
          );
          expect(c.read(wasteQuizProvider).scan?.category?.id, 'hazardous');
          if (detectorHazard) {
            expect(c.read(wasteQuizProvider).scan?.rawCategory, 'residu');
          }
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
          // Decision 0017: the question comes from the bank; Gemma only identified.
          expect(c.read(wasteQuizProvider).question?.bankId, isNotNull);
          expect(images.where((image) => image == null), isEmpty, reason: 'no question request to Gemma');
        },
      );
    }

    group('detector vs Gemma category mismatch', () {
      const cardboard = TrackedDetection(label: 'Cardboard', x: 40, y: 20, w: 40, h: 20, score: .81);
      late List<String> lines;
      setUp(() {
        lines = [];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
        addTearDown(() => debugPrint = original);
      });
      String logged(String event) =>
          lines.firstWhere((l) => l.contains('"event":"$event"'), orElse: () => '');

      Future<void> lockCardboard(String gemmaCategory) async {
        quiz.onRobotLocked(_frame(), cardboard);
        await _until(() => images.isNotEmpty);
        identify.complete('{"item":"kardus","material":"kertas","category":"$gemmaCategory"}');
      }

      test('Cardboard + organik: card, no quiz until the user picks; hard example and choice logged', () async {
        await lockCardboard('organik');
        await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.confirmingMismatch);
        await pumpEventQueue();
        expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.confirmingMismatch);
        expect(c.read(wasteQuizProvider).mismatchDetector, 'Cardboard');
        expect(images, hasLength(1), reason: 'no question generation before a choice');
        final hard = logged('category_mismatch');
        for (final field in ['"hardExample":true', '"appCommit":', '"frameId":1', '"detectorLabel":"Cardboard"',
            '"detectorScore":0.81', '"gemmaItem":"kardus"', '"gemmaCategory":"organik"',
            '"resolvedBin":"organic"', '"detectorBin":"inorganic"', '-identify.jpg"']) {
          expect(hard, contains(field));
        }
        quiz.resolveMismatch(useDetector: true);
        expect(logged('mismatch_choice'), allOf(contains('"choice":"detector"'), contains('"resolvedBin":"inorganic"')));
        expect(c.read(wasteQuizProvider).scan?.category?.id, 'inorganic');
        expect(c.read(wasteQuizProvider).scan?.detectorLabel, 'Cardboard', reason: 'the detector choice keeps its class');
        await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.active);
        expect(images, hasLength(1), reason: 'bank question: no question request to Gemma');
      });

      for (final compatible in ['anorganik', 'residu']) {
        test('Cardboard + $compatible: no card, straight to the quiz', () async {
          await lockCardboard(compatible);
          await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.active);
          expect(images, hasLength(1), reason: 'bank question: no question request to Gemma');
          expect(c.read(wasteQuizProvider).phase, isNot(WasteQuizPhase.confirmingMismatch));
          expect(c.read(wasteQuizProvider).scan?.category?.id, 'inorganic');
          expect(logged('category_mismatch'), isEmpty);
        });
      }

      test('24 Oct, decision 0025: Plastic box + Gemma "Label" (kertas): no card, plastic question, class_mismatch logged',
          () async {
        quiz.onRobotLocked(_frame(), _box);
        await _until(() => images.isNotEmpty);
        identify.complete('{"item":"Label","material":"kertas","category":"anorganik"}');
        await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.active);
        final state = c.read(wasteQuizProvider);
        expect(state.scan?.detectorLabel, 'Plastic');
        expect(state.scan?.rawLabel, 'Label');
        expect(state.question?.bankId, startsWith('plastic-'), reason: 'a plastic pool question');
        expect(logged('category_mismatch'), isEmpty);
        final line = logged('class_mismatch');
        for (final field in ['"detectorLabel":"Plastic"', '"gemmaItem":"Label"', '"gemmaMaterial":"kertas"',
            '"gemmaPool":"paper_family"', '"chosenPool":"plastic"']) {
          expect(line, contains(field));
        }
        expect(lines.where((l) => l.contains('question_source') && l.contains('detector=Plastic') && l.contains('pool=plastic')),
            isNotEmpty);
      });

      test('E_Waste + anorganik still shows the hazard card, not the mismatch card', () async {
        quiz.onRobotLocked(_frame(), const TrackedDetection(label: 'E_Waste', x: 40, y: 20, w: 40, h: 20));
        await _until(() => images.isNotEmpty);
        identify.complete('{"item":"laptop","category":"anorganik"}');
        await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.confirmingHazard);
        expect(logged('category_mismatch'), isEmpty);
      });

      test('Scan ulang on the mismatch card leaves no late quiz', () async {
        await lockCardboard('organik');
        await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.confirmingMismatch);
        quiz.dismiss();
        quiz.resolveMismatch(useDetector: false); // a late tap after closing does nothing
        await pumpEventQueue();
        expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
        expect(images, hasLength(1));
        expect(logged('mismatch_choice'), contains('"choice":"rescan"'));
      });
    });

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
          startQuiz: (_, _) => true,
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

    test('close while the model is still loading never submits', () async {
      final loading = Completer<void>();
      var prepared = false;
      service.mockBeforeSubmit = () {
        prepared = true;
        return loading.future;
      };
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => prepared);
      quiz.dismiss();
      loading.complete();
      await pumpEventQueue();
      expect(images, isEmpty);
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
    });

    test('close after submit discards the result, slot busy until the call ends', () async {
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => images.isNotEmpty);
      quiz.dismiss();
      await pumpEventQueue();
      expect((await service.identifyItem(Uint8List(1))).failure, 'busy');
      identify.complete('{"item":"baterai","category":"B3"}');
      await pumpEventQueue();
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
      final next = service.identifyItem(Uint8List(1));
      await pumpEventQueue();
      expect(images, hasLength(2), reason: 'slot free once the running call ended');
      identify = Completer<String?>()..complete('{"item":"botol"}');
      expect((await next).failure, isNot('busy'));
    });

    test('user close is logged as cancelled, not as a failure', () async {
      final lines = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = original);
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => images.isNotEmpty);
      quiz.dismiss();
      await _until(() => lines.any((l) => l.contains('"identify_result"')));
      final result = lines.firstWhere((l) => l.contains('"identify_result"'));
      expect(result, contains('"failure":"cancelled"'));
      expect(result, isNot(contains('belum siap')));
      expect(lines.where((l) => l.startsWith('[M2c] {')),
          everyElement(contains('"appCommit":')));
    });

    test('a real model failure still shows its failure text', () async {
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => images.isNotEmpty);
      identify.complete(null);
      await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished);
      expect(c.read(wasteQuizProvider).notice, GemmaQuizService.notReadyMessage);
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

    test(
      'legacy annotated robot frame stops with firmware notice and no Gemma request',
      () async {
        final frame = _frame();
        quiz.onRobotLocked(
          CapturedFrame(
            bytes: frame.bytes,
            width: frame.width,
            height: frame.height,
            timestamp: frame.timestamp,
          ),
          _box,
        );
        await _until(
          () => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished,
        );
        expect(c.read(wasteQuizProvider).notice, contains('firmware'));
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
