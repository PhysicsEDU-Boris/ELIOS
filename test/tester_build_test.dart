// Tester build (decision 0040): source switch, offline AI state, YUV photo.
import 'dart:io';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/frame_source/viewfinder_crop.dart';
import 'package:elio/services/frame_source/yuv_jpeg.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:elio/services/tester_log.dart';
import 'package:elio/widgets/tester_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = AiQuizService.instance;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('elio_tester_test');
    service.status.value = AiStatus.idle;
  });

  tearDown(() async {
    service.mockSendExecute = null;
    service.status.value = AiStatus.idle;
    WasteQuizNotifier.sourceOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('question source switch', () {
    test('the default is ELIOS AI, in every build (decision 0179)', () {
      expect(defaultQuestionSource, QuestionSource.ai);
    });

    testWidgets('the panel switch moves the source from ELIOS AI to Bank', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TesterPanel()))),
      ));
      expect(find.text('Question source'), findsOneWidget);
      expect(find.text('AI: Not used yet'), findsOneWidget);
      expect(c.read(appPreferencesProvider).questionSource, QuestionSource.ai);
      await tester.tap(find.text('Bank'));
      await tester.pump();
      expect(c.read(appPreferencesProvider).questionSource, QuestionSource.bank);
    });

    test('bank mode runs a full question without calling the AI', () async {
      var aiCalls = 0;
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        aiCalls++;
        return null;
      };
      WasteQuizNotifier.sourceOverride = QuestionSource.bank;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik', photo: Uint8List.fromList([1, 2, 3]));
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.cropBytes, [1, 2, 3], reason: 'the captured photo is kept for Scan History');
      expect(aiCalls, 0);
    });
  });

  group('AI offline', () {
    test('the panel names the model that answered, and says when none did', () {
      expect(aiStateLabel(AiStatus.ready, 'gemini-3.5-flash-lite'), 'Ready (gemini-3.5-flash-lite)');
      expect(aiStateLabel(AiStatus.offline, null), 'Not connected, bank mode');
    });

    test('identify and essay grading say so, without throwing', () async {
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) async => null;
      final id = await service.identifyItem(Uint8List.fromList([1]));
      expect(id.item, isNull);
      expect(id.failure, AiQuizService.notReadyMessage);
      expect(await service.reviewEssay(question: 'q', expectedPoints: 'p', answer: 'a'), isNull);
    });

    test('an AI-mode quiz with no AI answer uses a bank question and says so', () async {
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) async => null;
      WasteQuizNotifier.sourceOverride = QuestionSource.ai;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.isFallback, isFalse);
      expect(s.questionSource, QuestionSource.bank);
      expect(s.messages.last.text, contains('AI tidak tersambung'));
    });

    test('a real call without Firebase fails soft: null, status offline', () async {
      expect(await service.discuss(quizContext: 'k', history: const [], message: 'halo'), isNull);
      expect(service.status.value, AiStatus.offline);
    });
  });

  test('a retained phone photo is saved as the History photo (D1 + A1 overlap)', () async {
    final root = await Directory.systemTemp.createTemp('a1-history-photo-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    final store = ScanRecordStore(customFile: File('${root.path}/records.json'));
    ScanRecordStore.setInstanceForTesting(store);
    addTearDown(() async {
      ScanRecordStore.setInstanceForTesting(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    });
    final photo = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 6)));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final quiz = c.read(wasteQuizProvider.notifier);
    quiz.startForLabel('botol plastik', photo: photo);
    for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase != WasteQuizPhase.active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    quiz.state = quiz.state.copyWith(
      difficulty: QuizDifficulty.easy,
      questionIndex: 0,
      question: const GeneratedQuestion(
          type: QuizQuestionType.multipleChoice, question: 'Pilah botol?', options: ['Daur ulang', 'Bakar'], correctIndex: 0),
    );
    quiz.selectOption(0);
    quiz.nextQuestion();
    for (var i = 0; i < 400 && c.read(wasteQuizProvider).phase != WasteQuizPhase.finished; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(File(store.records.single.cropPhotoPath!).readAsBytesSync(), orderedEquals(photo));
    expect(c.read(wasteQuizProvider).historyPhotoPath, store.records.single.cropPhotoPath,
        reason: 'the result card PDF embeds the saved History photo');
  });

  group('tester log', () {
    test('writes lines to the file and is a no-op when disabled', () async {
      final log = TesterLog.instance;
      log.enabled = true;
      await log.init(dir: dir);
      log.log('ai', 'model=gemini-3.5-flash-lite ms=1800');
      expect(File('${dir.path}/elio_tester.log').readAsStringSync(), contains('[ai] model=gemini-3.5-flash-lite ms=1800'));
      log.clear();
      log.enabled = false;
      log.log('ai', 'ignored');
      expect(log.read(), isNot(contains('ignored')));
      log.enabled = testerBuild;
    });
  });

  test('the viewfinder crop keeps the centre box of a cover-fitted preview', () async {
    final src = img.Image(width: 1280, height: 720);
    img.fill(src, color: img.ColorRgb8(0, 0, 255));
    img.fillRect(src, x1: 540, y1: 310, x2: 740, y2: 410, color: img.ColorRgb8(255, 0, 0)); // centre mark
    final jpeg = Uint8List.fromList(img.encodeJpg(src, quality: 95));
    // panel 640x360 (scale 0.5): a 260x200 box is 520x400 image px, +20% margin = 624x480.
    final out = img.decodeJpg(await cropToViewfinder(jpeg, panel: const Size(640, 360), box: const Size(260, 200)))!;
    expect((out.width, out.height), (624, 480));
    expect(out.getPixel(312, 240).r, greaterThan(200), reason: 'the centre mark is in the middle of the crop');
    expect(out.getPixel(2, 2).b, greaterThan(200));
  });

  group('YUV photo', () {
    YuvFrame solid(int w, int h, int y, int u, int v) => YuvFrame(
          width: w,
          height: h,
          y: Uint8List(w * h)..fillRange(0, w * h, y),
          u: Uint8List(w * h ~/ 4)..fillRange(0, w * h ~/ 4, u),
          v: Uint8List(w * h ~/ 4)..fillRange(0, w * h ~/ 4, v),
          yRowStride: w,
          uvRowStride: w ~/ 2,
          uvPixelStride: 1,
        );

    test('a red frame decodes to red JPEG, rotated to portrait', () async {
      final out = await yuvToJpegInIsolate(solid(64, 32, 82, 90, 240), rotation: 90);
      expect((out.width, out.height), (32, 64));
      final image = img.decodeJpg(out.bytes)!;
      final px = image.getPixel(16, 32);
      expect(px.r, greaterThan(200));
      expect(px.g, lessThan(60));
      expect(px.b, lessThan(60));
    });

    test('handles row padding and interleaved chroma (uvPixelStride 2)', () {
      const w = 8, h = 4;
      final frame = YuvFrame(
        width: w,
        height: h,
        y: Uint8List(16 * h)..fillRange(0, 16 * h, 128),
        u: Uint8List(16 * 2)..fillRange(0, 32, 128),
        v: Uint8List(16 * 2)..fillRange(0, 32, 128),
        yRowStride: 16,
        uvRowStride: 16,
        uvPixelStride: 2,
      );
      final out = yuvToJpeg(frame);
      final px = img.decodeJpg(out.bytes)!.getPixel(3, 1);
      expect((px.r - 128).abs(), lessThan(6)); // mid grey stays grey
    });

    test('rotation follows sensor and device orientation', () {
      expect(yuvRotation(sensorOrientation: 90, deviceDegrees: 0, frontFacing: false), 90);
      expect(yuvRotation(sensorOrientation: 90, deviceDegrees: 90, frontFacing: false), 0);
      expect(yuvRotation(sensorOrientation: 90, deviceDegrees: 270, frontFacing: false), 180);
      expect(yuvRotation(sensorOrientation: 270, deviceDegrees: 90, frontFacing: true), 0);
    });
  });
}
