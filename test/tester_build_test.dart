// Tester build (decision 0040): source switch, no-model state, thermal gate, kill detection, YUV photo.
import 'dart:io';
import 'dart:typed_data';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/device_health.dart';
import 'package:elio/services/frame_source/yuv_jpeg.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/tester_log.dart';
import 'package:elio/widgets/tester_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

String _mcReply(String q) =>
    '{"question": "$q", "correct": "B3", "wrong": ["Organik", "Kertas", "Kaca"], "explanation": "e"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = GemmaQuizService.instance;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('elio_tester_test');
    service.sideloadDirOverride = dir;
    service.thermal = ThermalGate(read: () async => 0);
    service.clearKilled();
    service.progress.value = const GemmaProgress(GemmaStatus.idle);
  });

  tearDown(() async {
    service.sideloadDirOverride = null;
    service.mockSendExecute = null;
    service.thermal = ThermalGate();
    service.progress.value = const GemmaProgress(GemmaStatus.idle);
    WasteQuizNotifier.sourceOverride = null;
    dir.deleteSync(recursive: true);
  });

  group('question source switch', () {
    test('the build default is the bank and a plain release resolves to the bank', () {
      expect(defaultQuestionSource, QuestionSource.bank);
      expect(effectiveQuestionSource(QuestionSource.gemma, debug: false), QuestionSource.bank);
      // Run this file with and without --dart-define=TESTER_BUILD=true.
      expect(effectiveQuestionSource(QuestionSource.gemma, debug: false || testerBuild),
          testerBuild ? QuestionSource.gemma : QuestionSource.bank);
    });

    testWidgets('the panel switch moves the source from Bank to Gemma', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TesterPanel()))),
      ));
      expect(find.text('Sumber soal'), findsOneWidget);
      expect(c.read(appPreferencesProvider).questionSource, QuestionSource.bank);
      await tester.tap(find.text('Gemma'));
      await tester.pump();
      expect(c.read(appPreferencesProvider).questionSource, QuestionSource.gemma);
    });
  });

  group('no model file', () {
    test('prepare says "Model belum ada" with the path to push to, and loads nothing', () async {
      expect(await service.modelMissing(), isTrue);
      expect(await service.prepare(), isFalse);
      final p = service.progress.value;
      expect(p.status, GemmaStatus.missing);
      expect(p.error, contains('Model belum ada'));
      expect(p.error, contains('${dir.path}/${GemmaQuizService.modelFileName}'));
      expect(gemmaStateLabel(p), startsWith('Model belum ada'));
    });

    test('a half-pushed file is reported as incomplete, not loaded', () async {
      File('${dir.path}/${GemmaQuizService.modelFileName}').writeAsBytesSync(Uint8List(1024));
      expect(await service.prepare(), isFalse);
      expect(service.progress.value.status, GemmaStatus.error);
      expect(service.progress.value.error, contains('belum lengkap'));
    });

    test('bank mode runs a full question without the model', () async {
      var gemmaCalls = 0;
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        gemmaCalls++;
        return null;
      };
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik', photo: Uint8List.fromList([1, 2, 3]));
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.cropBytes, [1, 2, 3], reason: 'the captured photo is kept for Scan History');
      expect(gemmaCalls, 0);
    });
  });

  group('thermal gate', () {
    test('pauses at SEVERE, stays paused at SEVERE-1 only until MODERATE, resumes below', () async {
      var status = 1;
      final events = <String>[];
      final gate = ThermalGate(read: () async => status, onChange: (s, p) => events.add('$s:$p'));
      expect(await gate.check(), isFalse);
      status = 3;
      expect(await gate.check(), isTrue);
      status = 2;
      expect(await gate.check(), isFalse, reason: 'MODERATE resumes');
      status = 4;
      expect(await gate.check(), isTrue);
      expect(gate.statusName, 'CRITICAL');
      expect(events, ['1:false', '3:true', '2:false', '4:true']);
    });

    test('an unreadable status (null) keeps the last decision', () async {
      int? status = 3;
      final gate = ThermalGate(read: () async => status);
      expect(await gate.check(), isTrue);
      status = null;
      expect(await gate.check(), isTrue);
    });

    test('hot phone: identify and essay grading get honest text, Gemma is never called', () async {
      var gemmaCalls = 0;
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        gemmaCalls++;
        return 'x';
      };
      service.thermal = ThermalGate(read: () async => 3);
      await service.refreshBlocked();
      final id = await service.identifyItem(Uint8List.fromList([1]));
      expect(id.item, isNull);
      expect(id.failure, contains('panas'));
      expect(await service.reviewEssay(question: 'q', expectedPoints: 'p', answer: 'a'), isNull);
      expect(service.progress.value.status, GemmaStatus.paused);
      expect(gemmaCalls, 0);
    });

    test('hot phone in Gemma mode: the quiz uses a bank question and says so', () async {
      var gemmaCalls = 0;
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        gemmaCalls++;
        return _mcReply('Soal Gemma?');
      };
      service.thermal = ThermalGate(read: () async => 4);
      await service.refreshBlocked();
      WasteQuizNotifier.sourceOverride = QuestionSource.gemma;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.questionSource, QuestionSource.bank);
      expect(s.messages.last.text, contains('Ponsel terlalu panas'));
      expect(gemmaCalls, 0);
    });

    test('it cools down: Gemma is allowed again', () async {
      var status = 3;
      service.thermal = ThermalGate(read: () async => status);
      await service.refreshBlocked();
      expect(service.progress.value.status, GemmaStatus.paused);
      status = 1;
      await service.refreshBlocked();
      expect(service.progress.value.status, GemmaStatus.idle);
      expect(service.blockedReason, isNull);
    });
  });

  group('system kill', () {
    test('classifies the previous run', () {
      expect(classifyPreviousRun(markerLeft: false, exitReason: 3), PreviousRun.clean);
      expect(classifyPreviousRun(markerLeft: true, exitReason: 3), PreviousRun.systemKilled);
      expect(classifyPreviousRun(markerLeft: true, exitReason: 2), PreviousRun.systemKilled);
      expect(classifyPreviousRun(markerLeft: true, exitReason: null), PreviousRun.systemKilled);
      expect(classifyPreviousRun(markerLeft: true, exitReason: 5), PreviousRun.nativeCrash);
      expect(classifyPreviousRun(markerLeft: true, exitReason: 10), PreviousRun.clean, reason: 'user swiped it away');
    });

    test('a leftover marker shows the message and blocks Gemma until the tester retries', () async {
      File('${dir.path}/gemma_active.marker').writeAsStringSync('x');
      await service.checkPreviousRun();
      expect(service.progress.value.status, GemmaStatus.killed);
      expect(service.blockedReason, 'Gemma dihentikan sistem, mode bank aktif.');
      expect(await service.ensureReady(), isFalse, reason: 'no silent retry');
      service.clearKilled();
      expect(service.blockedReason, isNull);
    });

    test('no marker: nothing shown', () async {
      await service.checkPreviousRun();
      expect(service.progress.value.status, GemmaStatus.idle);
    });
  });

  group('tester log', () {
    test('writes lines to the file and is a no-op when disabled', () async {
      final log = TesterLog.instance;
      log.enabled = true;
      await log.init(dir: dir);
      log.log('gemma', 'load ms=123');
      expect(File('${dir.path}/elio_tester.log').readAsStringSync(), contains('[gemma] load ms=123'));
      log.clear();
      log.enabled = false;
      log.log('gemma', 'ignored');
      expect(log.read(), isNot(contains('ignored')));
      log.enabled = testerBuild;
    });
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
