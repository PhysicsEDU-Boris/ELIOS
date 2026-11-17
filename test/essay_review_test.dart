// Essay answer review (decision 0227, Figma "16 · Essay answer review"):
// the 0/10, 6/10 and 10/10 states in light and dark, EN and ID, at 360 dp with
// large text, reduce motion, no replay, the grading fields and the cues.
// ESSAY_RENDER=<dir> writes a PNG of every state.
import 'dart:convert';
import 'dart:typed_data';

import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/essay_grade.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/history_ui.dart';
import 'package:elio/widgets/quiz/essay_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/r2_control_harness.dart' show loadFonts, savePng, shotKey;

const _png = String.fromEnvironment('ESSAY_RENDER');

const _question =
    'Bagaimana panas matahari dan oksigen membuat gelas plastik menjadi rapuh?';
const _reference =
    'Panas matahari melemahkan ikatan antarmolekul polimer plastik, sementara '
    'oksigen memicu reaksi oksidasi yang membuat plastik lebih rapuh.';

/// The grading reply of one side, as the AI returns it.
Map<String, dynamic> _side(List<int> scores) => {
  'accuracy': scores[0],
  'keyTerms': scores[1],
  'completeness': scores[2],
  'clarity': scores[3],
  'total': scores.reduce((a, b) => a + b),
  'feedback': 'Tambahkan peran oksigen agar jawabanmu lengkap.',
  'improvement': 'Sebut oksidasi.',
  'accuracyHint': 'Panas memang merusak plastik, tapi bukan karena meleleh.',
  'keyTermsHint': 'Sudah: panas. Kurang: polimer, oksidasi.',
  'completenessHint': 'Peran oksigen belum disebut.',
  'clarityHint': 'Kalimatmu jelas dan mudah dipahami.',
  'why': 'Plastik tersusun dari rantai polimer yang sangat panjang.',
  'keyIdea': 'Panas + oksigen = plastik menua.',
  'tips': [
    'Sebut penyebabnya: panas dan sinar UV matahari.',
    'Jelaskan efeknya: ikatan polimer melemah.',
    'Tambahkan peran oksigen: oksidasi membuat plastik rapuh.',
  ],
};

QuizExplanation _explanation(List<int> scores) {
  final g = EssayGrade.parse(jsonEncode(_side(scores)))!;
  return QuizExplanation(
    summary: g.feedback,
    correctAnswerReason: g.why,
    keyIdea: g.keyIdea,
    steps: g.tips,
    essayScore: g.score,
    essayFeedback: g.feedback,
    rubricRows: g.rubricRows,
    groundingStatus: GroundingStatus.gemmaUngrounded,
  );
}

const _states = {
  0: [0, 0, 0, 0],
  6: [3, 1, 1, 1],
  10: [4, 3, 2, 1],
};

Future<void> _pump(
  WidgetTester t,
  int score, {
  bool dark = false,
  String lang = 'id',
  double width = 390,
  double textScale = 1,
  bool reduceMotion = false,
  String answer =
      'Karena panas matahari bikin plastiknya meleleh terus jadi rusak.',
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 3400);
  addTearDown(t.view.reset);
  debugSetL10n(Locale(lang));
  addTearDown(() => debugSetL10n(const Locale('en')));
  await t.pumpWidget(
    RepaintBoundary(
      key: shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: (dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap)(
          Builder(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: EssayReview(
                  question: _question,
                  answer: answer,
                  reference: _reference,
                  explanation: _explanation(_states[score]!),
                  score: score,
                  index: 1,
                  total: 3,
                  playing: null,
                  onListen: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadFonts();
  });

  for (final dark in [false, true]) {
    for (final lang in ['id', 'en']) {
      final id = lang == 'id';
      final mode = '${dark ? 'dark' : 'light'} $lang';

      testWidgets('0/10 not quite, $mode', (t) async {
        await _pump(t, 0, dark: dark, lang: lang, answer: 'Apa si');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text(id ? 'Belum tepat!' : 'Not quite!'), findsOneWidget);
        expect(find.text(id ? 'KURANG TEPAT' : 'NOT QUITE'), findsOneWidget);
        expect(find.text('0 / 10'), findsOneWidget);
        expect(find.text('0/4'), findsOneWidget);
        expect(
          find.text(
            id ? 'JAWABANMU · KURANG TEPAT' : 'YOUR ANSWER · NOT QUITE',
          ),
          findsOneWidget,
        );
        expect(
          find.text(id ? 'JAWABAN YANG BENAR' : 'THE RIGHT ANSWER'),
          findsOneWidget,
        );
        expect(
          find.text(id ? 'Masukan untuk jawabanmu' : 'Feedback on your answer'),
          findsOneWidget,
        );
        expect(
          find.text(id ? 'Tips skor penuh' : 'Tips for full marks'),
          findsOneWidget,
        );
        if (_png.isNotEmpty) {
          await savePng(t, _png, 'essay_0_${dark ? 'dark' : 'light'}_$lang');
        }
      });

      testWidgets('6/10 partly right, $mode', (t) async {
        await _pump(t, 6, dark: dark, lang: lang);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(
          find.text(id ? 'Hampir tepat!' : 'Almost there!'),
          findsOneWidget,
        );
        expect(
          find.text(id ? 'SEBAGIAN TEPAT' : 'PARTLY RIGHT'),
          findsOneWidget,
        );
        expect(find.text('6 / 10'), findsOneWidget);
        expect(find.text('+6 XP'), findsOneWidget);
        expect(
          find.text(id ? 'PERTANYAAN · ESAI' : 'THE QUESTION · ESSAY'),
          findsOneWidget,
        );
        for (final row in ['3/4', '1/3', '1/2', '1/1']) {
          expect(find.text(row), findsOneWidget);
        }
        expect(find.text('Peran oksigen belum disebut.'), findsOneWidget);
        expect(
          find.text(id ? 'Mengapa begitu' : 'Why it is so'),
          findsOneWidget,
        );
        expect(find.text('Panas + oksigen = plastik menua.'), findsOneWidget);
        // The empty segments use the medium border token, also in dark.
        final palette = t
            .widgetList<Container>(
              find.descendant(
                of: find.byType(HistoryEssayScore),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<ShapeDecoration>()
            .map((d) => d.color)
            .toSet();
        expect(palette.length, greaterThanOrEqualTo(3));
        if (_png.isNotEmpty) {
          await savePng(t, _png, 'essay_6_${dark ? 'dark' : 'light'}_$lang');
        }
      });

      testWidgets('10/10 full marks, $mode', (t) async {
        await _pump(t, 10, dark: dark, lang: lang);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text(id ? 'Sempurna!' : 'Perfect!'), findsOneWidget);
        expect(find.text(id ? 'TEPAT' : 'RIGHT'), findsOneWidget);
        expect(find.text('10 / 10'), findsOneWidget);
        expect(
          find.text(id ? 'JAWABANMU · TEPAT' : 'YOUR ANSWER · RIGHT'),
          findsOneWidget,
        );
        // Hidden on full marks: right answer, personal feedback, tips.
        expect(
          find.text(id ? 'JAWABAN YANG BENAR' : 'THE RIGHT ANSWER'),
          findsNothing,
        );
        expect(
          find.text(id ? 'Masukan untuk jawabanmu' : 'Feedback on your answer'),
          findsNothing,
        );
        expect(
          find.text(id ? 'Tips skor penuh' : 'Tips for full marks'),
          findsNothing,
        );
        expect(
          find.text(
            id ? 'Mengapa jawabanmu tepat' : 'Why your answer is right',
          ),
          findsOneWidget,
        );
        if (_png.isNotEmpty) {
          await savePng(t, _png, 'essay_10_${dark ? 'dark' : 'light'}_$lang');
        }
      });
    }
  }

  testWidgets('360 dp, text scale 1.3, long answer and words: no overflow', (
    t,
  ) async {
    for (final score in [0, 6, 10]) {
      await _pump(
        t,
        score,
        width: 360,
        textScale: 1.3,
        answer:
            'Pertanggungjawabannya ketidakseimbangan mempertanggungjawabkan '
            '${'plastik menjadi rapuh karena panas dan oksigen ' * 12}',
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'score $score');
    }
  });

  testWidgets('a skipped answer says so', (t) async {
    await _pump(t, 0, answer: '(dilewati)');
    await t.pumpAndSettle();
    expect(find.text('Kamu melewati soal ini'), findsOneWidget);
    expect(find.text('“(dilewati)”'), findsNothing);
  });

  testWidgets('missing fields hide their sections, no placeholders', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 2400);
    addTearDown(t.view.reset);
    debugSetL10n(const Locale('id'));
    addTearDown(() => debugSetL10n(const Locale('en')));
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ElioLightTheme.wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: EssayReview(
                question: _question,
                answer: 'Panas.',
                reference: '',
                // A score-only grade: no rubric, feedback, why, idea or tips.
                explanation: const QuizExplanation(
                  summary: '',
                  correctAnswerReason: '',
                  essayScore: 6,
                ),
                score: 6,
                index: 0,
                total: 1,
                playing: null,
                onListen: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('6 / 10'), findsOneWidget);
    for (final hidden in [
      'RINCIAN NILAI',
      'JAWABAN YANG BENAR',
      'Yuk pelajari alasannya',
      'Masukan untuk jawabanmu',
      'Mengapa begitu',
      'Tips skor penuh',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
  });

  group('motion', () {
    testWidgets('the score counts up and the cards rise in', (t) async {
      await _pump(t, 6);
      await t.pump(); // first frame: nothing has moved yet
      expect(find.text('0 / 10'), findsOneWidget);
      final score = t.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(HistoryEssayScore),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(score.opacity, lessThan(1));
      await t.pumpAndSettle();
      expect(find.text('6 / 10'), findsOneWidget);
    });

    testWidgets('reduce motion: no count-up, stagger or bounce', (t) async {
      await _pump(t, 6, reduceMotion: true);
      await t.pump();
      // The final score is there on the first frame.
      expect(find.text('6 / 10'), findsOneWidget);
      expect(find.text('+6 XP'), findsOneWidget);
      // Everything arrives together (one short fade, no 40 ms stagger).
      await t.pump(const Duration(milliseconds: 200));
      for (final o in t.widgetList<Opacity>(find.byType(Opacity))) {
        expect(o.opacity, 1);
      }
    });

    testWidgets('nothing replays on a rebuild or a language switch', (t) async {
      await _pump(t, 6);
      await t.pumpAndSettle();
      // The same page, now in English.
      await _pump(t, 6, lang: 'en');
      await t.pump();
      expect(find.text('Almost there!'), findsOneWidget);
      expect(find.text('6 / 10'), findsOneWidget, reason: 'no second count-up');
      expect(find.text('+6 XP'), findsOneWidget);
      for (final o in t.widgetList<Opacity>(find.byType(Opacity))) {
        expect(o.opacity, 1, reason: 'no second entrance');
      }
    });
  });

  group('grading data', () {
    test('the parser reads hints, why, key idea and tips', () {
      final g = EssayGrade.parse(jsonEncode(_side([3, 1, 1, 1])))!;
      expect(g.score, 6);
      expect(g.rubricRows.map((r) => r.comment), [
        'Panas memang merusak plastik, tapi bukan karena meleleh.',
        'Sudah: panas. Kurang: polimer, oksidasi.',
        'Peran oksigen belum disebut.',
        'Kalimatmu jelas dan mudah dipahami.',
      ]);
      expect(g.why, startsWith('Plastik tersusun'));
      expect(g.keyIdea, 'Panas + oksigen = plastik menua.');
      expect(g.tips, hasLength(3));
    });

    test('missing or malformed new fields are empty, the grade survives', () {
      final old = _side([3, 1, 1, 1])
        ..removeWhere(
          (k, _) => k.endsWith('Hint') || k == 'why' || k == 'keyIdea',
        )
        ..['tips'] = 'bukan daftar';
      final g = EssayGrade.parse(jsonEncode(old))!;
      expect(g.score, 6);
      expect(g.rubricRows.every((r) => r.comment.isEmpty), isTrue);
      expect(g.why, isEmpty);
      expect(g.keyIdea, isEmpty);
      expect(g.tips, isEmpty);
    });

    test('a graded essay saves the new fields in the record', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      debugSetL10n(const Locale('id'));
      addTearDown(() => debugSetL10n(const Locale('en')));
      QuizTtsService.instance
        ..mockSpeak = (_) async {}
        ..mockStop = () async {};
      ElioSound.instance.sink = (_, _) {};
      final prompts = <String>[];
      AiQuizService.instance.mockSendExecute =
          (String prompt, {Uint8List? imageBytes, bool isUser = false}) async {
            prompts.add(prompt);
            return jsonEncode({
              'id': _side([3, 1, 1, 1]),
              'en': _side([3, 1, 1, 1]),
            });
          };
      addTearDown(() {
        AiQuizService.instance.mockSendExecute = null;
        QuizTtsService.instance
          ..mockSpeak = null
          ..mockStop = null;
        ElioSound.instance.sink = null;
      });
      final c = ProviderContainer(
        overrides: [
          wasteQuizProvider.overrideWith(
            () => _Seeded(
              WasteQuizUiState(
                phase: WasteQuizPhase.active,
                scan: ScannedWaste.fromLabel('gelas-plastik'),
                voiceOn: false,
                question: const GeneratedQuestion(
                  type: QuizQuestionType.essay,
                  question: _question,
                  explanation: _reference,
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(wasteQuizProvider.notifier).submitEssay('Karena panas.');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The request asks for the new fields.
      expect(prompts.single, contains('accuracyHint'));
      expect(prompts.single, contains('tips'));
      final saved = QuizExplanation.fromJson(
        c
            .read(wasteQuizProvider)
            .recordedQuestions
            .single
            .explanation!
            .toJson(),
      );
      expect(saved.essayScore, 6);
      expect(saved.rubricRows!.first.comment, startsWith('Panas memang'));
      expect(saved.essayFeedback, startsWith('Tambahkan peran oksigen'));
      expect(saved.correctAnswerReason, startsWith('Plastik tersusun'));
      expect(saved.keyIdea, 'Panas + oksigen = plastik menua.');
      expect(saved.steps, hasLength(3));
    });
  });

  group('reveal cues', () {
    test('one cue per result, silent while muted', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final played = <ElioSfx>[];
      final sound = ElioSound.instance;
      sound.sink = (s, _) {
        played.add(s);
      };
      sound.isSilent = () async => false;
      // Each cue a second apart, so the 120 ms throttle never drops one.
      sound.clock = () =>
          DateTime(2026, 1, 1).add(Duration(seconds: played.length));
      addTearDown(() {
        ElioSound.instance
          ..sink = null
          ..quizMuted = false
          ..clock = DateTime.now;
      });
      for (final r in QuizReveal.values) {
        quizRevealCue(r);
        await Future<void>.delayed(Duration.zero);
      }
      expect(played, [ElioSfx.chime, ElioSfx.pop, ElioSfx.knock]);
      played.clear();
      ElioSound.instance.quizMuted = true;
      quizRevealCue(QuizReveal.correct);
      await Future<void>.delayed(Duration.zero);
      expect(played, isEmpty);
    });
  });
}

class _Seeded extends WasteQuizNotifier {
  _Seeded(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}
