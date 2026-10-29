// E1 (decision 0041): smaller identify photo and prompt, "Bukan ini?" picker, background Gemma load.
import 'dart:io';
import 'dart:typed_data';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/device_health.dart';
import 'package:elio/services/frame_source/viewfinder_crop.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpeg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = GemmaQuizService.instance;
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('elio_e1_test');
    service.sideloadDirOverride = dir;
    service.thermal = ThermalGate(read: () async => 0);
    service.clearKilled();
    service.progress.value = const GemmaProgress(GemmaStatus.idle);
  });

  tearDown(() {
    service.sideloadDirOverride = null;
    service.mockSendExecute = null;
    service.thermal = ThermalGate();
    service.progress.value = const GemmaProgress(GemmaStatus.idle);
    dir.deleteSync(recursive: true);
  });

  group('identify photo and prompt', () {
    test('downscaleJpeg caps the long side, and leaves small or undecodable bytes alone', () async {
      final big = img.decodeJpg(await downscaleJpeg(_jpeg(1200, 800), maxSide: 512))!;
      expect((big.width, big.height), (512, 341));
      final tall = img.decodeJpg(await downscaleJpeg(_jpeg(600, 1000), maxSide: 512))!;
      expect((tall.width, tall.height), (307, 512));
      final small = _jpeg(300, 200);
      expect(await downscaleJpeg(small, maxSide: 512), orderedEquals(small));
      final junk = Uint8List.fromList([1, 2, 3]);
      expect(await downscaleJpeg(junk, maxSide: 512), orderedEquals(junk));
    });

    test('identify sends the downscaled photo and a prompt without the can example', () async {
      String? seenPrompt;
      Uint8List? seenImage;
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        seenPrompt = prompt;
        seenImage = imageBytes;
        return '{"item": "baterai", "material": "logam", "category": "B3"}';
      };
      final original = _jpeg(1000, 700);
      final result = await service.identifyItem(original);
      expect(result.item, 'baterai');
      expect(seenPrompt, isNot(contains('kaleng')));
      expect(seenPrompt, contains('baterai'));
      final sent = img.decodeJpg(seenImage!)!;
      expect(sent.width, GemmaQuizService.identifyMaxSide);
      expect(seenImage!.length, lessThan(original.length));
    });
  });

  group('"Bukan ini?" picker', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    Future<void> scanAs(ProviderContainer c, Uint8List photo, String json) async {
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async => json;
      c.read(wasteQuizProvider.notifier).onPhotoCaptured(photo);
      await _until(() => c.read(wasteQuizProvider).phase != WasteQuizPhase.identifying);
      await _until(() => c.read(wasteQuizProvider).phase != WasteQuizPhase.loadingQuestion);
    }

    test('a battery named a can is corrected to B3: confirmation card, same photo', () async {
      final c = container();
      final photo = _jpeg(40, 30);
      await scanAs(c, photo, '{"item": "kaleng minuman", "material": "aluminium", "category": "anorganik"}');
      expect(c.read(wasteQuizProvider).scan?.category?.id, 'inorganic');
      expect(c.read(wasteQuizProvider).canCorrectItem, isTrue);

      final battery = (await QuestionBank.load()).pickerItems.firstWhere((i) => i.name == 'baterai');
      c.read(wasteQuizProvider.notifier).correctItem(battery.name, category: battery.category);

      final s = c.read(wasteQuizProvider);
      expect(s.phase, WasteQuizPhase.confirmingHazard, reason: 'hazard rules still gate a corrected B3 item');
      expect(s.scan?.category?.id, 'hazardous');
      expect(s.cropBytes, orderedEquals(photo), reason: 'the photo stays the History photo');
    });

    test('a corrected non-hazard item restarts the quiz for the new item', () async {
      final c = container();
      await scanAs(c, _jpeg(40, 30), '{"item": "rol film", "material": "plastik", "category": "anorganik"}');
      final notifier = c.read(wasteQuizProvider.notifier);
      notifier.correctItem('kertas', category: 'anorganik');
      expect(c.read(wasteQuizProvider).scan?.displayName, 'Kertas');
      await _until(() => c.read(wasteQuizProvider).phase == WasteQuizPhase.active);
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.active);
      expect(c.read(wasteQuizProvider).questionIndex, 0);
    });

    test('not offered once the first question is answered, or before an object is named', () async {
      final c = container();
      expect(c.read(wasteQuizProvider).canCorrectItem, isFalse);
      await scanAs(c, _jpeg(40, 30), '{"item": "kertas", "material": "kertas", "category": "anorganik"}');
      final quiz = c.read(wasteQuizProvider.notifier);
      quiz.state = quiz.state.copyWith(
        phase: WasteQuizPhase.active,
        question: const GeneratedQuestion(
            type: QuizQuestionType.multipleChoice, question: 'Q?', options: ['a', 'b'], correctIndex: 0),
      );
      expect(c.read(wasteQuizProvider).canCorrectItem, isTrue);
      quiz.selectOption(0);
      expect(c.read(wasteQuizProvider).canCorrectItem, isFalse);
      quiz.correctItem('baterai');
      expect(c.read(wasteQuizProvider).scan?.displayName, 'Kertas', reason: 'a late correction is ignored');
    });

    test('every picker item resolves to its own bank object, B3 ones to hazardous', () async {
      final bank = await QuestionBank.load();
      expect(bank.pickerItems, hasLength(13));
      final seen = <String>{};
      for (final item in bank.pickerItems) {
        final scan = ScannedWaste.fromLabel(item.name, categoryHint: item.category);
        expect(scan.category, isNotNull, reason: item.name);
        final object = bank.matchObject(scan);
        expect(object, isNotNull, reason: item.name);
        seen.add(object!);
      }
      expect(seen, hasLength(13), reason: 'no two picker names collapse to one bank object');
      expect(ScannedWaste.fromLabel('baterai', categoryHint: 'B3').category?.id, 'hazardous');
    });
  });

  group('background load', () {
    // A sparse file of the full size: the plugin then fails (no platform in a unit test),
    // but only after the service has started the install, which is what is observed.
    void pushModel() {
      final f = File('${dir.path}/${GemmaQuizService.modelFileName}')..createSync();
      final raf = f.openSync(mode: FileMode.write)..truncateSync(2588147712);
      raf.closeSync();
    }

    Future<Set<GemmaStatus>> watch(void Function() act) async {
      final seen = <GemmaStatus>{};
      void on() => seen.add(service.progress.value.status);
      service.progress.addListener(on);
      act();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      service.progress.removeListener(on);
      return seen;
    }

    test('tester build: no load at launch, none from a non-scan screen', () async {
      pushModel();
      final seen = await watch(() => service.warmUp(vision: true, tester: true));
      expect(seen, isEmpty);
    });

    test('tester build: the scan screen starts the load when the model file is there', () async {
      pushModel();
      final seen = await watch(() => service.warmUp(vision: true, scanScreen: true, tester: true));
      expect(seen, contains(GemmaStatus.installing));
    });

    test('tester build: no model file leaves the state alone ("Model belum ada" comes from the scan)', () async {
      final seen = await watch(() => service.warmUp(vision: true, scanScreen: true, tester: true));
      expect(seen, isEmpty);
    });

    test('tester build: a killed run or a hot phone is not loaded over', () async {
      pushModel();
      service.thermal = ThermalGate(read: () async => 4);
      await service.thermal.check();
      final seen = await watch(() => service.warmUp(vision: true, scanScreen: true, tester: true));
      expect(seen, isNot(contains(GemmaStatus.installing)));
    });
  });
}
