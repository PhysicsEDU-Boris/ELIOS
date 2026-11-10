// ELIOS 3 scan flows (decision 0198): robot quiz card (own on/off and source),
// Scan to contribute rules and records, portrait photo crop.
import 'dart:async';
import 'dart:io';

import 'package:elio/Screens/scan/contribute_screen.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/frame_source/viewfinder_crop.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

const _box = TrackedDetection(label: 'Plastic', x: 40, y: 20, w: 40, h: 20);

CapturedFrame _frame() {
  final png = Uint8List.fromList(
    img.encodePng(img.Image(width: 40, height: 20)),
  );
  return CapturedFrame(
    bytes: png,
    cleanBytes: png,
    frameId: 1,
    detectionFrameId: 1,
    width: 80,
    height: 40,
    timestamp: DateTime(2026),
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('robot quiz preferences', () {
    test('robots keep the old shared source until set; both round-trip', () {
      final old = AppPreferences.fromMap({'questionSource': 'bank'});
      expect(old.robotQuestionSource, QuestionSource.bank);
      expect(old.robotQuizEnabled, isTrue);
      final p = AppPreferences.fromMap({
        'questionSource': 'bank',
        'robotQuestionSource': 'ai',
        'robotQuizEnabled': false,
      });
      expect(p.questionSource, QuestionSource.bank);
      expect(p.robotQuestionSource, QuestionSource.ai);
      expect(p.robotQuizEnabled, isFalse);
      final back = AppPreferences.fromMap(p.toMap());
      expect(back.robotQuestionSource, QuestionSource.ai);
      expect(back.robotQuizEnabled, isFalse);
    });
  });

  group('robot sessions', () {
    final service = AiQuizService.instance;
    late ProviderContainer c;
    late WasteQuizNotifier quiz;
    late Completer<String?> identify;
    late List<String> prompts;
    late Directory root;
    late ScanRecordStore store;
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() async {
      await service.cancel();
      identify = Completer<String?>();
      prompts = [];
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) {
        prompts.add(prompt);
        return imageBytes != null ? identify.future : Future.value(null);
      };
      WasteQuizNotifier.sourceOverride = null;
      root = await Directory.systemTemp.createTemp('elios3-robot-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      store = ScanRecordStore(customFile: File('${root.path}/records.json'));
      ScanRecordStore.setInstanceForTesting(store);
      c = ProviderContainer();
      quiz = c.read(wasteQuizProvider.notifier)..toggleVoice();
      await pumpEventQueue();
    });
    tearDown(() async {
      quiz.dismiss();
      if (!identify.isCompleted) identify.complete(null);
      await service.cancel();
      await pumpEventQueue();
      service.mockSendExecute = null;
      ScanRecordStore.setInstanceForTesting(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      c.dispose();
      await root.delete(recursive: true);
    });

    test('use the ELIOS setup source; phone scans use Profile', () async {
      c
          .read(appPreferencesProvider.notifier)
          .update(
            (p) => p.copyWith(
              questionSource: QuestionSource.bank,
              robotQuestionSource: QuestionSource.ai,
            ),
          );
      quiz.onRobotLocked(_frame(), _box);
      expect(c.read(wasteQuizProvider).questionSource, QuestionSource.ai);
      quiz.dismiss();
      await pumpEventQueue();
      quiz.onPhotoCaptured(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8))),
      );
      expect(c.read(wasteQuizProvider).questionSource, QuestionSource.bank);
    });

    test('quiz off: the scan is saved to History without questions', () async {
      c
          .read(appPreferencesProvider.notifier)
          .update((p) => p.copyWith(robotQuizEnabled: false));
      quiz.onRobotLocked(_frame(), _box);
      await _until(() => prompts.isNotEmpty);
      identify.complete(
        '{"item":"botol plastik","material":"plastik","category":"anorganik"}',
      );
      await _until(
        () => c.read(wasteQuizProvider).phase == WasteQuizPhase.finished,
      );
      expect(prompts.where((p) => p.contains('Buat SATU soal')), isEmpty);
      final r = store.records.single;
      expect(r.questions, isEmpty);
      expect(r.trophies, 0);
      expect(r.category, ScanCategory.recyclable);
      expect(r.cropPhotoPath, isNotNull);
      expect(c.read(wasteQuizProvider).notice, contains('quiz is off'));
    });
  });

  group('Scan to contribute', () {
    test('bins match, residu counts as Anorganik', () {
      expect(
        contributionMatches(ScanCategory.organic, ScanCategory.organic),
        isTrue,
      );
      expect(
        contributionMatches(ScanCategory.residu, ScanCategory.recyclable),
        isTrue,
      );
      expect(
        contributionMatches(ScanCategory.b3, ScanCategory.recyclable),
        isFalse,
      );
      expect(
        contributionMatches(ScanCategory.recyclable, ScanCategory.organic),
        isFalse,
      );
    });

    test('the most common bin wins; nothing named gives null', () {
      const none = PhotoIdentification(item: null);
      expect(pickContribution([none, none]), isNull);
      final found = pickContribution(const [
        PhotoIdentification(item: 'kulit pisang', category: 'organik'),
        PhotoIdentification(item: 'botol plastik', category: 'anorganik'),
        PhotoIdentification(item: 'botol', category: 'anorganik'),
        none,
      ]);
      expect(found?.category, ScanCategory.recyclable);
      expect(found?.item, 'botol plastik');
    });

    test('a contribution record keeps its kind and reward through JSON', () {
      final r = ScanRecord(
        id: 'contrib-1',
        time: DateTime(2026, 11, 10),
        itemName: 'botol plastik',
        category: ScanCategory.recyclable,
        questions: const [],
        trophies: contributionTrophies,
        kind: ScanRecord.contributionKind,
      );
      final back = ScanRecord.fromJson(r.toJson());
      expect(back.isContribution, isTrue);
      expect(back.trophies, 10);
      final scan = ScanRecord.fromJson({
        'id': 's',
        'itemName': 'x',
        'questions': <dynamic>[],
      });
      expect(scan.isContribution, isFalse);
      expect(scan.toJson().containsKey('kind'), isFalse, reason: 'old shape');
    });
  });

  // Guard: decodeJpg applies the EXIF rotation, so the portrait crop is upright.
  test('a portrait (EXIF-rotated) photo is cropped upright', () async {
    final sideways = img.Image(width: 40, height: 20);
    sideways.exif.imageIfd.orientation = 6; // stored sideways, shown portrait
    final jpeg = Uint8List.fromList(img.encodeJpg(sideways));
    final out = img.decodeJpg(
      await cropToViewfinder(
        jpeg,
        panel: const Size(100, 200),
        box: const Size(50, 50),
      ),
    )!;
    // Upright 20x40 under a 100x200 panel: scale 5, box 50*1.2/5 = 12 px.
    expect((out.width, out.height), (12, 12));
  });
}
