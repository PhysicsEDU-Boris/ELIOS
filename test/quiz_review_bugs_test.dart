// Quiz review bugs (decision 0226): mute, coach language, back confirm, and
// the explanation that kept changing.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/r2_control_harness.dart' show loadFonts;

class _Seeded extends WasteQuizNotifier {
  _Seeded(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

final _scan = ScannedWaste.fromLabel('botol-kaca');

/// A reviewed bank question.
const _bankQ = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Ke tempat sampah mana botol kaca harus dibuang?',
  options: ['Organik', 'Daur Ulang', 'B3', 'Residu'],
  correctIndex: 1,
  bankId: 'reviewed-glass',
  explanation: 'Kaca adalah material anorganik yang dapat didaur ulang.',
);

/// An AI question with no explanation of its own.
const _bareQ = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Where does a glass bottle go?',
  options: ['Organic', 'Recycling', 'B3', 'Residue'],
  correctIndex: 1,
);

const _essayQ = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Jelaskan mengapa botol kaca dipilah.',
  explanation: 'Kaca dapat dilebur dan dipakai lagi tanpa batas.',
);

String _reply(String why) => jsonEncode({
  'correct_option': 'Daur Ulang',
  'why_correct': why,
  'why_wrong': '',
  'key_idea': 'Kaca didaur ulang.',
  'steps': <String>[],
});

ProviderContainer _container(WasteQuizUiState seed) {
  final c = ProviderContainer(
    overrides: [wasteQuizProvider.overrideWith(() => _Seeded(seed))],
  );
  addTearDown(c.dispose);
  return c;
}

WasteQuizUiState _active(GeneratedQuestion q, {bool voiceOn = false}) =>
    WasteQuizUiState(
      phase: WasteQuizPhase.active,
      scan: _scan,
      question: q,
      voiceOn: voiceOn,
    );

Future<void> _pumpPages(WidgetTester t, ProviderContainer c) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(390, 844);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ElioLightTheme.wrap(
          const Scaffold(body: SizedBox.expand(child: ScanQuizPages())),
        ),
      ),
    ),
  );
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var stops = 0;
  final spoken = <String>[];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugSetL10n(const Locale('en'));
    await AiQuizService.instance.cancel();
    stops = 0;
    spoken.clear();
    ElioSound.instance.sink = (_, _) {};
    QuizTtsService.instance
      ..muted = false
      ..mockSpeak = (text) async {
        spoken.add(text);
      }
      ..mockStop = () async {
        stops++;
      };
    AiQuizService.instance.mockSendExecute =
        (_, {imageBytes, isUser = false}) async => null;
  });
  tearDown(() {
    ElioSound.instance
      ..sink = null
      ..quizMuted = false;
    QuizTtsService.instance
      ..muted = false
      ..mockSpeak = null
      ..mockStop = null;
    AiQuizService.instance.mockSendExecute = null;
    WasteQuizNotifier.explanationTimeout = const Duration(seconds: 25);
  });

  group('1.1 mute', () {
    testWidgets('the speaker button toggles mute and stops the voice', (
      t,
    ) async {
      final c = _container(
        _active(_bankQ, voiceOn: true).copyWith(
          phase: WasteQuizPhase.explaining,
          selectedOption: 1,
          currentExplanation: const QuizExplanation(
            summary: 'Kaca didaur ulang.',
            correctAnswerReason: '',
          ),
        ),
      );
      await _pumpPages(t, c);
      expect(find.byTooltip('Mute voice and sounds'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      final before = stops;

      await t.tap(find.byKey(const ValueKey('scan_review_mute')));
      await _settle(t);
      expect(c.read(wasteQuizProvider).voiceOn, isFalse);
      expect(c.read(appPreferencesProvider).quizMuted, isTrue);
      expect(QuizTtsService.instance.muted, isTrue);
      expect(ElioSound.instance.quizMuted, isTrue);
      expect(stops, greaterThan(before), reason: 'the voice stops at once');
      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
      expect(find.byTooltip('Turn voice and sounds on'), findsOneWidget);

      // Unmuting reads the explanation on screen.
      spoken.clear();
      await t.tap(find.byKey(const ValueKey('scan_review_mute')));
      await _settle(t);
      expect(c.read(appPreferencesProvider).quizMuted, isFalse);
      expect(spoken, ['Kaca didaur ulang.']);
    });

    test('mute is still on after restoring from storage', () async {
      SharedPreferences.setMockInitialValues({
        'app_preferences_v1': jsonEncode(
          const AppPreferences(quizMuted: true).toMap(),
        ),
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(appPreferencesProvider);
      c.read(wasteQuizProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(appPreferencesProvider).quizMuted, isTrue);
      expect(c.read(wasteQuizProvider).voiceOn, isFalse);
      expect(QuizTtsService.instance.muted, isTrue);
    });

    test('no speech and no quiz sound start while muted', () async {
      final played = <ElioSfx>[];
      ElioSound.instance.sink = (s, _) => played.add(s);
      QuizTtsService.instance.muted = true;
      ElioSound.instance.quizMuted = true;
      await QuizTtsService.instance.speak('Halo');
      quizFeedback(ElioSfx.chime, () {});
      await Future<void>.delayed(Duration.zero);
      expect(spoken, isEmpty);
      expect(played, isEmpty);
    });
  });

  group('1.2 coach language', () {
    test('the language of the message wins, the app language on a tie', () {
      String lang(String m, String app) => AiQuizService.messageLang(m, app);
      expect(lang('Why is glass recycled and not burned?', 'id'), 'en');
      expect(lang('Mengapa kaca harus didaur ulang?', 'en'), 'id');
      for (final unclear in ['ok', '?', '👍', '123']) {
        expect(lang(unclear, 'id'), 'id');
        expect(lang(unclear, 'en'), 'en');
      }
      // Mixed: more matching words wins; a tie is the app language.
      expect(lang('Why is kaca in the recycling bin, jelaskan', 'id'), 'en');
      expect(lang('why mengapa', 'id'), 'id');
      expect(lang('why mengapa', 'en'), 'en');
    });

    test('the request asks for the message language explicitly', () async {
      final prompts = <String>[];
      AiQuizService.instance.mockSendExecute =
          (String prompt, {Uint8List? imageBytes, bool isUser = false}) async {
            prompts.add(prompt);
            return '{"id": {"reply": "Jawaban."}, "en": {"reply": "Answer."}}';
          };
      debugSetL10n(const Locale('id'));
      final reply = await AiQuizService.instance.discuss(
        quizContext: 'Konteks',
        history: const [],
        message: 'Why is glass recycled and not burned?',
      );
      expect(prompts.single, contains('reply language: en'));
      expect(reply, 'Answer.');

      debugSetL10n(const Locale('en'));
      await AiQuizService.instance.discuss(
        quizContext: 'Konteks',
        history: const [],
        message: 'Mengapa kaca harus didaur ulang?',
      );
      expect(prompts.last, contains('reply language: id'));

      debugSetL10n(const Locale('id'));
      await AiQuizService.instance.discuss(
        quizContext: 'Konteks',
        history: const [],
        message: 'ok',
      );
      expect(prompts.last, contains('reply language: id'));
    });
  });

  group('1.3 back during a quiz', () {
    testWidgets('back + "Keep going" keeps the question and the answer', (
      t,
    ) async {
      final c = _container(
        _active(_essayQ).copyWith(questionIndex: 1, essayAnswer: 'Draf'),
      );
      await _pumpPages(t, c);
      final before = c.read(wasteQuizProvider);

      await t.binding.handlePopRoute();
      await _settle(t);
      expect(find.text('Leave the quiz?'), findsOneWidget);
      expect(find.text('Your progress will be lost.'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('quiz_leave_keep')));
      await _settle(t);
      expect(find.text('Leave the quiz?'), findsNothing);
      expect(c.read(wasteQuizProvider), same(before));

      // Dismissing the sheet also keeps the quiz.
      await t.binding.handlePopRoute();
      await _settle(t);
      await t.binding.handlePopRoute();
      await _settle(t);
      expect(find.text('Leave the quiz?'), findsNothing);
      expect(c.read(wasteQuizProvider), same(before));
    });

    testWidgets('back + "Leave" ends the quiz', (t) async {
      final c = _container(_active(_essayQ).copyWith(questionIndex: 1));
      await _pumpPages(t, c);
      await t.binding.handlePopRoute();
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('quiz_leave_leave')));
      await _settle(t);
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
    });

    testWidgets('a system back in the answer review shows the sheet too', (
      t,
    ) async {
      final c = _container(
        _active(
          _bankQ,
        ).copyWith(phase: WasteQuizPhase.explaining, selectedOption: 1),
      );
      await _pumpPages(t, c);
      await t.binding.handlePopRoute();
      await _settle(t);
      expect(find.byKey(const ValueKey('quiz_leave_sheet')), findsOneWidget);
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.explaining);

      // The page's own close button asks as well.
      await t.tap(find.byKey(const ValueKey('quiz_leave_keep')));
      await _settle(t);
      await t.tap(find.byTooltip('Close'));
      await _settle(t);
      expect(find.byKey(const ValueKey('quiz_leave_sheet')), findsOneWidget);
    });
  });

  group('1.4 explanation', () {
    test(
      'the same key is requested once; a late old reply is ignored',
      () async {
        final replies = <Completer<String?>>[];
        AiQuizService.instance.mockSendExecute =
            (String prompt, {Uint8List? imageBytes, bool isUser = false}) {
              final c = Completer<String?>();
              replies.add(c);
              return c.future;
            };
        final c = _container(_active(_bankQ));
        final quiz = c.read(wasteQuizProvider.notifier);
        WasteQuizUiState s() => c.read(wasteQuizProvider);
        Future<void> tick() =>
            Future<void>.delayed(const Duration(milliseconds: 30));

        quiz.selectOption(1);
        unawaited(quiz.loadExplanation()); // a rebuild asking again
        unawaited(quiz.loadExplanation());
        await tick();
        expect(replies, hasLength(1), reason: 'one request per key');
        expect(s().explanationLoading, isTrue);

        // Retry while the first is still out: the newer request owns the page.
        final retry = quiz.retryExplanation();
        await tick();
        // The single AI slot may answer the first before taking the second.
        if (replies.length == 1) replies[0].complete(_reply('Versi lama.'));
        await tick();
        if (replies.length > 1 && !replies[0].isCompleted) {
          replies[0].complete(_reply('Versi lama.'));
        }
        await tick();
        expect(
          s().currentExplanation?.summary,
          isNot('Versi lama.'),
          reason: 'a reply from an older request is never shown',
        );
        if (replies.length > 1) replies[1].complete(_reply('Versi baru.'));
        await retry;
        expect(s().explanationLoading, isFalse);
        expect(s().currentExplanation!.summary, isNot('Versi lama.'));
      },
    );

    test('the voice reads the explanation that is shown', () async {
      AiQuizService.instance.mockSendExecute =
          (String prompt, {Uint8List? imageBytes, bool isUser = false}) async =>
              _reply('Kaca bisa dilebur lagi.');
      final c = _container(_active(_bankQ, voiceOn: true));
      c.read(wasteQuizProvider.notifier).selectOption(1);
      for (
        var i = 0;
        i < 50 && c.read(wasteQuizProvider).explanationLoading;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final shown = c.read(wasteQuizProvider).currentExplanation!.summary;
      expect(shown, 'Kaca bisa dilebur lagi.');
      expect(spoken, hasLength(1));
      expect(spoken.single, contains(shown));
      expect(spoken.single, isNot(contains(_bankQ.explanation)));
    });

    test(
      'AI failure or timeout: the bank explanation is shown and saved',
      () async {
        // Fails.
        var c = _container(_active(_bankQ));
        c.read(wasteQuizProvider.notifier).selectOption(0);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        var s = c.read(wasteQuizProvider);
        expect(s.explanationLoading, isFalse);
        expect(s.currentExplanation!.summary, _bankQ.explanation);
        expect(
          s.recordedQuestions.single.explanation!.summary,
          _bankQ.explanation,
        );

        // Never answers.
        WasteQuizNotifier.explanationTimeout = const Duration(milliseconds: 40);
        AiQuizService.instance.mockSendExecute =
            (_, {imageBytes, isUser = false}) => Completer<String?>().future;
        c = _container(_active(_bankQ));
        c.read(wasteQuizProvider.notifier).selectOption(0);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        s = c.read(wasteQuizProvider);
        expect(s.explanationLoading, isFalse);
        expect(s.currentExplanation!.summary, _bankQ.explanation);
        await AiQuizService.instance.cancel();
      },
    );

    testWidgets('no explanation anywhere: the retry state, never a blank', (
      t,
    ) async {
      final c = _container(_active(_bareQ));
      await _pumpPages(t, c);
      await t.runAsync(() async {
        c.read(wasteQuizProvider.notifier).selectOption(0);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await _settle(t);
      await _settle(t);
      expect(
        c.read(wasteQuizProvider).currentExplanation!.isUnavailable,
        isTrue,
      );
      expect(find.text('Explanation not available yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan_review_retry')), findsOneWidget);

      // Retry asks again; while it runs the stable loading block shows.
      final gate = Completer<String?>();
      AiQuizService.instance.mockSendExecute =
          (_, {imageBytes, isUser = false}) => gate.future;
      await t.tap(find.byKey(const ValueKey('scan_review_retry')));
      await t.pump();
      expect(find.byKey(const ValueKey('scan_review_loading')), findsOneWidget);
      expect(find.text('Explanation not available yet'), findsNothing);
      await t.runAsync(() async {
        gate.complete(
          jsonEncode({
            'correct_option': 'Recycling',
            'why_correct': 'Glass melts and is used again.',
            'why_wrong': '',
            'key_idea': 'Glass is recycled.',
            'steps': <String>[],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await _settle(t);
      expect(find.text('Glass melts and is used again.'), findsOneWidget);
    });

    testWidgets(
      'while loading, the question text is not shown as explanation',
      (t) async {
        final c = _container(
          _active(_bankQ).copyWith(
            phase: WasteQuizPhase.explaining,
            selectedOption: 1,
            explanationLoading: true,
          ),
        );
        await _pumpPages(t, c);
        expect(
          find.byKey(const ValueKey('scan_review_loading')),
          findsOneWidget,
        );
        expect(find.text(_bankQ.explanation), findsNothing);
      },
    );

    test('essay explanations are in the record, also when skipped', () async {
      SharedPreferences.setMockInitialValues({
        'app_preferences_v1': jsonEncode(
          const AppPreferences(skipAllowed: true).toMap(),
        ),
      });
      var c = _container(_active(_essayQ));
      c.read(appPreferencesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.read(wasteQuizProvider.notifier).skipQuestion();
      final skipped = c.read(wasteQuizProvider).recordedQuestions.single;
      expect(skipped.isEssay, isTrue);
      expect(skipped.explanation, isNotNull);
      expect(skipped.explanation!.isUnavailable, isFalse);
      expect(skipped.explanation!.summary, _essayQ.explanation);

      c = _container(_active(_essayQ));
      await c
          .read(wasteQuizProvider.notifier)
          .submitEssay('Kaca dilebur lalu dipakai lagi.', score: 6);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final answered = c.read(wasteQuizProvider).recordedQuestions.single;
      expect(answered.explanation, isNotNull);
      expect(answered.explanation!.essayScore, 6);
      expect(answered.explanation!.isUnavailable, isFalse);
    });
  });
}
