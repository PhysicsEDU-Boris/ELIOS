// On-device check of the offline Gemma 4 E2B quiz pipeline: photo
// identification, university-level questions, plain-text chat, essay review.
// Run with the phone in Airplane Mode:
//   flutter test integration_test/gemma_offline_test.dart -d <device-id>
// On a connected dev machine (e.g. macOS) add --dart-define=REQUIRE_OFFLINE=false.
import 'dart:convert';
import 'dart:io';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/phone_jpeg.dart';

Future<bool> _hasInternet() async {
  try {
    final r = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
    return r.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool _mentionsAny(String text, List<String> words) {
  final t = text.toLowerCase();
  return words.any(t.contains);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline Gemma: sees photos, writes university questions, chats in plain text',
      (tester) async {
    final online = await _hasInternet();
    debugPrint('[offline-test] internet reachable: $online');
    if (const bool.fromEnvironment('REQUIRE_OFFLINE', defaultValue: true)) {
      expect(online, isFalse, reason: 'Turn on Airplane Mode before running this test');
    }

    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    final service = GemmaQuizService.instance;
    final sw = Stopwatch()..start();

    // 1. Vision: a phone photo must be recognized as a phone, not plastic.
    expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
    debugPrint('[offline-test] vision model ready in ${sw.elapsed.inSeconds}s');
    final photo = await service.identifyItem(base64Decode(phoneJpegBase64));
    debugPrint('[offline-test] photo identified: item=${photo.item} material=${photo.material} '
        'category=${photo.category} failure=${photo.failure}');
    expect(photo.item, isNotNull, reason: photo.failure);
    expect(_mentionsAny(photo.item!, ['ponsel', 'hp', 'handphone', 'telepon', 'smartphone', 'phone', 'gawai']), isTrue,
        reason: 'expected a phone, got "${photo.item}"');
    expect(photo.item!.toLowerCase().contains('botol'), isFalse);

    // 2. Hard (university) multiple-choice question about cardboard.
    final kardus = ScannedWaste.fromLabel('kardus', material: 'kertas karton');
    final mc = await service.generateQuestion(
      waste: kardus,
      type: QuizQuestionType.multipleChoice,
      difficulty: QuizDifficulty.hard,
    );
    expect(mc, isNotNull, reason: 'multiple-choice generation failed');
    debugPrint('[offline-test] HARD MC: ${mc!.question} | ${mc.options} | correct=${mc.correctIndex} | ${mc.explanation}');
    expect(mc.options, hasLength(4));
    expect(_mentionsAny('${mc.question} ${mc.options.join(' ')} ${mc.explanation}',
        ['kardus', 'karton', 'kertas', 'serat', 'selulosa', 'pulp', 'lignin']), isTrue);

    // 3. Follow-up chat after answering must be plain text, never JSON.
    final reply = await service.discuss(
      quizContext: 'Konteks kuis tentang "kardus".\nSoal: ${mc.question}\n'
          'Jawaban benar: ${mc.options[mc.correctIndex]}\nJawaban mahasiswa: ${mc.options[mc.correctIndex]} (benar)',
      history: const [],
      message: 'Lalu kardus bekas sebaiknya dibuang ke mana?',
    );
    debugPrint('[offline-test] chat reply: $reply');
    expect(reply, isNotNull);
    expect(reply!.contains('{') || reply.contains('"hint"'), isFalse, reason: 'chat reply leaked JSON');

    // 4. Medium essay question + review.
    final essay = await service.generateQuestion(
      waste: kardus,
      type: QuizQuestionType.essay,
      difficulty: QuizDifficulty.medium,
      avoid: [mc.question],
    );
    expect(essay, isNotNull, reason: 'essay generation failed');
    debugPrint('[offline-test] MEDIUM essay: ${essay!.question}');
    final review = await service.reviewEssay(
      question: essay.question,
      expectedPoints: essay.explanation,
      answer: 'Kardus dipilah sebagai kertas kering lalu didaur ulang menjadi pulp, '
          'sehingga mengurangi penebangan pohon dan sampah di TPA.',
    );
    debugPrint('[offline-test] review: $review');
    expect(review, isNotNull);
    expect(review!.contains('{'), isFalse);

    debugPrint('[offline-test] total ${sw.elapsed.inSeconds}s');
    await service.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
