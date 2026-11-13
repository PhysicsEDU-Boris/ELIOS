// Full-screen Scan & quiz pages (decision 0216, Figma 629:90773 / 629:90816):
// result page → Start quiz → full-screen question, answer feedback, no
// overflow in portrait and landscape, light/dark, EN/ID.
// SCAN_RENDER=<dir> writes PNGs of every state.
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/r2_control_harness.dart' show loadFonts, savePng, shotKey;

const _png = String.fromEnvironment('SCAN_RENDER');

/// Answers without the explanation services.
class _Quiz extends WasteQuizNotifier {
  _Quiz(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
  @override
  void selectOption(int index) => state = state.copyWith(
    selectedOption: index,
    phase: WasteQuizPhase.explaining,
  );
  void set(WasteQuizUiState s) => state = s;
  String? essay;
  @override
  Future<void> submitEssay(String answerText, {int? score}) async =>
      essay = answerText;
  @override
  void logRescanTapped() {}
}

final _scan = ScannedWaste.fromLabel('botol-plastik');
const _q = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question:
      'Why should a PET plastic bottle not be heated or filled with boiling water?',
  options: [
    'High heat weakens the plastic so it deforms',
    'It makes the bottle heavier',
    'It changes the label colour',
    'It makes the plastic magnetic',
  ],
  correctIndex: 0,
);
final _identifying = const WasteQuizUiState(phase: WasteQuizPhase.identifying);
final _writing = WasteQuizUiState(
  phase: WasteQuizPhase.loadingQuestion,
  scan: _scan,
);
final _ready = WasteQuizUiState(
  phase: WasteQuizPhase.active,
  scan: _scan,
  question: _q,
);

const _essayQ = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Why should you rinse a plastic bottle before recycling it?',
);
final _essay = WasteQuizUiState(
  phase: WasteQuizPhase.active,
  scan: _scan,
  question: _essayQ,
  questionIndex: 1,
);
final _essayReview = _essay.copyWith(
  phase: WasteQuizPhase.explaining,
  essaySubmitted: true,
  essayAnswer: 'Rinse it first so food does not spoil the batch.',
  currentExplanation: const QuizExplanation(
    summary: '',
    correctAnswerReason: '',
    essayScore: 8,
    essayFeedback: 'Add landfill time for full marks.',
    rubricRows: [
      RubricRow(criterion: 'Accuracy', maxScore: 4, awardedScore: 4),
      RubricRow(criterion: 'Key terms', maxScore: 3, awardedScore: 2),
    ],
  ),
);

Future<_Quiz> _pump(
  WidgetTester t,
  WasteQuizUiState seed, {
  bool robot = false,
  VoidCallback? onStop,
  VoidCallback? onRescan,
  double keyboard = 0,
  Size size = const Size(390, 844),
  bool dark = false,
  String lang = 'en',
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  debugSetL10n(Locale(lang));
  addTearDown(() => debugSetL10n(const Locale('en')));
  final quiz = _Quiz(seed);
  await t.pumpWidget(
    RepaintBoundary(
      key: shotKey,
      child: ProviderScope(
        overrides: [wasteQuizProvider.overrideWith(() => quiz)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: (dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap)(
            // Filled like on the camera screen (Positioned.fill).
            Scaffold(
              body: SizedBox.expand(
                child: ScanQuizPages(
                  robot: robot,
                  onStop: onStop,
                  onRescan: onRescan,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(t);
  return quiz;
}

/// Delayed entrances start on a later frame: a few pumps, not one long one.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
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

  testWidgets('identifying shows the result page without a name or ticket', (
    t,
  ) async {
    await _pump(t, _identifying);
    expect(find.text('Scan result'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan_identifying')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan_quiz_ticket')), findsNothing);
    expect(find.byKey(const ValueKey('quiz_popup')), findsNothing);
  });

  testWidgets('result page waits for Start quiz, then the question fills '
      'the screen', (t) async {
    final quiz = await _pump(t, _writing);
    expect(find.text(_scan.displayName), findsOneWidget);
    expect(find.text('Recyclable bin (Anorganik)'), findsOneWidget);
    // The page starts at the top of the screen, not centred.
    expect(t.getTopLeft(find.text('Scan result')).dy, lessThan(40));
    expect(find.text('Writing your quiz…'), findsOneWidget);
    final start = find.byKey(const ValueKey('scan_start_quiz'));
    expect(t.widget<FilledButton>(start).onPressed, isNull);

    quiz.set(_ready);
    await _settle(t);
    expect(find.text('Your quiz is ready'), findsOneWidget);
    // The question is ready but stays hidden until Start quiz.
    expect(find.byKey(const ValueKey('answer_0')), findsNothing);

    await t.tap(start);
    await _settle(t);
    expect(find.byKey(const ValueKey('scan_question_card')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('answer_$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('quiz_popup')), findsNothing);
    expect(find.textContaining('0:5'), findsOneWidget); // timer chip, m:ss
  });

  testWidgets('Retake leaves the result page', (t) async {
    final quiz = await _pump(t, _ready);
    await t.tap(find.byKey(const ValueKey('scan_retake')));
    await _settle(t);
    expect(quiz.state.phase, WasteQuizPhase.idle);
    expect(find.text('Scan result'), findsNothing);
  });

  testWidgets('an answer shows its feedback on the question before the '
      'review opens', (t) async {
    await _pump(t, _ready);
    await t.tap(find.byKey(const ValueKey('scan_start_quiz')));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('answer_1'))); // wrong
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('scan_question_card')), findsOneWidget);
    await _settle(t);
    expect(find.byKey(const ValueKey('scan_question_card')), findsNothing);
    // The answer review is a full page with the coach behind one tap.
    expect(find.byKey(const ValueKey('scan_review')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_popup')), findsNothing);
    expect(find.text('Not quite'.toUpperCase()), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('scan_coach_entry')));
    await _settle(t);
    expect(find.byKey(const ValueKey('scan_coach')), findsOneWidget);
  });

  testWidgets('the review shows one explanation, in the app language, and '
      'XP', (t) async {
    const en = QuizExplanation(
      summary: 'Heat softens PET.',
      correctAnswerReason: 'Heat softens PET.',
      selectedAnswerFeedback: 'Weight does not change.',
      lang: 'en',
    );
    await _pump(
      t,
      _ready.copyWith(
        phase: WasteQuizPhase.explaining,
        selectedOption: 1,
        currentExplanation: const QuizExplanation(
          summary: 'Panas melunakkan PET.',
          correctAnswerReason: 'Panas melunakkan PET.',
          selectedAnswerFeedback: 'Berat tidak berubah.',
          lang: 'id',
          alt: en,
        ),
      ),
    );
    expect(find.text('Heat softens PET.'), findsOneWidget);
    expect(find.textContaining('Panas'), findsNothing);
    expect(find.textContaining('Weight does not change'), findsNothing);
    expect(find.text('+0 XP'), findsOneWidget);
  });

  group('robot control (Figma 815:31496 / 815:31579 / 821:28687)', () {
    const land = Size(915, 412);
    testWidgets('robot wording, STOP in the header, Scan again rescans', (
      t,
    ) async {
      var stops = 0, rescans = 0;
      final quiz = await _pump(
        t,
        _ready,
        size: land,
        robot: true,
        onStop: () => stops++,
        onRescan: () => rescans++,
      );
      expect(find.text('Robot scan'), findsOneWidget);
      expect(find.text('Just now · Robot camera'), findsOneWidget);
      expect(find.text('Scan result'), findsNothing);
      await t.tap(find.byKey(const ValueKey('quiz_stop')));
      expect(stops, 1);
      await t.tap(find.text('Scan again'));
      await _settle(t);
      expect(rescans, 1);
      expect(quiz.state.phase, WasteQuizPhase.idle);
    });

    testWidgets('STOP stays on the question; close minimises, not ends', (
      t,
    ) async {
      var stops = 0;
      final quiz = await _pump(
        t,
        _ready,
        size: land,
        robot: true,
        onStop: () => stops++,
      );
      await t.tap(find.byKey(const ValueKey('scan_start_quiz')));
      await _settle(t);
      await t.tap(find.byKey(const ValueKey('quiz_stop')));
      expect(stops, 1);
      await t.tap(find.byTooltip('Close'));
      await _settle(t);
      expect(quiz.state.phase, WasteQuizPhase.active);
      expect(quiz.state.minimized, isTrue);
      expect(find.byKey(const ValueKey('scan_question_card')), findsNothing);
    });

    testWidgets('the phone pages have no STOP', (t) async {
      await _pump(t, _ready, size: land);
      expect(find.byKey(const ValueKey('quiz_stop')), findsNothing);
    });
  });

  group('essay (Figma 821:28687, 8 Essay review)', () {
    testWidgets('full-page essay: type, count words, submit', (t) async {
      final quiz = await _pump(t, _essay, size: const Size(915, 412));
      expect(find.byKey(const ValueKey('quiz_popup')), findsNothing);
      expect(find.textContaining('ESSAY'), findsOneWidget);
      final submit = find.byKey(const ValueKey('quiz_essay_submit'));
      expect(t.widget<FilledButton>(submit).onPressed, isNull);
      await t.enterText(find.byType(TextField), 'Rinse it first');
      await t.pump();
      expect(find.text('3 / 150 words'), findsOneWidget);
      await t.tap(submit);
      await t.pump();
      expect(quiz.essay, 'Rinse it first');
    });

    testWidgets('over the word limit does not submit', (t) async {
      final quiz = await _pump(t, _essay, size: const Size(915, 412));
      await t.enterText(
        find.byType(TextField),
        List.filled(151, 'word').join(' '),
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('quiz_essay_submit')));
      await t.pump(const Duration(milliseconds: 500));
      expect(quiz.essay, isNull);
    });

    for (final (size, name) in const [
      (Size(915, 412), 'landscape'),
      (Size(800, 360), 'landscape-small'),
      (Size(390, 844), 'portrait'),
    ]) {
      testWidgets('keyboard open ($name): field and Submit stay visible, '
          'text kept', (t) async {
        await _pump(t, _essay, size: size);
        await t.enterText(find.byType(TextField), 'Rinse it');
        t.view.viewInsets = const FakeViewPadding(bottom: 280);
        await _settle(t);
        expect(t.takeException(), isNull);
        final field = find.byType(TextField);
        final submit = find.byKey(const ValueKey('quiz_essay_submit'));
        expect(field, findsOneWidget);
        expect(find.text('Rinse it'), findsOneWidget);
        // Still focused: a rebuilt field would drop the keyboard again.
        expect(t.testTextInput.hasAnyClients, isTrue);
        final limit = size.height - 280;
        expect(t.getRect(field).bottom, lessThanOrEqualTo(limit));
        expect(t.getRect(submit).bottom, lessThanOrEqualTo(limit));
        if (_png.isNotEmpty) await savePng(t, _png, 'essay-keyboard-$name');
      });
    }

    testWidgets('essay review: score, the answer, rubric, no bins', (t) async {
      await _pump(t, _essayReview, size: const Size(915, 412));
      expect(t.takeException(), isNull);
      expect(find.text('Essay review'), findsOneWidget);
      expect(find.text('SCORE 8 / 10'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan_essay_answer')), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('+8 XP'), findsOneWidget);
      expect(find.text('Organik'), findsNothing);
      // Landscape: the coach chat sits next to the review.
      expect(find.byKey(const ValueKey('scan_coach_inline')), findsOneWidget);
    });

    testWidgets('coach keyboard in landscape: the ask field stays visible', (
      t,
    ) async {
      await _pump(t, _essayReview, size: const Size(915, 412));
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(t.testTextInput.hasAnyClients, isTrue);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await _settle(t);
      expect(t.takeException(), isNull);
      final ask = find.byType(TextField);
      expect(ask, findsOneWidget);
      // Still focused: a rebuilt field would drop the keyboard again.
      expect(t.testTextInput.hasAnyClients, isTrue);
      expect(t.getRect(ask).bottom, lessThanOrEqualTo(412 - 280));
    });
  });

  testWidgets('a failed scan offers Retake', (t) async {
    final quiz = await _pump(
      t,
      const WasteQuizUiState(
        phase: WasteQuizPhase.finished,
        notice: 'Not recognised yet.',
      ),
    );
    expect(find.text('Scan did not work'), findsOneWidget);
    await t.tap(find.byKey(const Key('result_card_close_button')));
    await _settle(t);
    expect(quiz.state.phase, WasteQuizPhase.idle);
  });

  testWidgets('the finished quiz is a full page with score and XP', (t) async {
    final quiz = await _pump(
      t,
      WasteQuizUiState(
        phase: WasteQuizPhase.finished,
        scan: _scan,
        correctCount: 2,
      ),
    );
    expect(find.byKey(const ValueKey('scan_done')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_popup')), findsNothing);
    expect(find.text('2 of 3 correct'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    await t.tap(find.byKey(const Key('result_card_rescan_button')));
    await _settle(t);
    expect(quiz.state.phase, WasteQuizPhase.idle);
  });

  final states = {
    'essay': _essay,
    'essay-review': _essayReview,
    'identifying': _identifying,
    'writing': _writing,
    'identified': _ready,
    'done': WasteQuizUiState(
      phase: WasteQuizPhase.finished,
      scan: _scan,
      correctCount: 2,
    ),
  };
  for (final (size, shape) in const [
    (Size(390, 844), 'portrait'),
    (Size(360, 640), 'small'),
    (Size(915, 412), 'landscape'),
    (Size(800, 360), 'landscape-small'),
  ]) {
    for (final dark in [false, true]) {
      for (final lang in ['en', 'id']) {
        final tag = '$shape-${dark ? 'dark' : 'light'}-$lang';
        for (final st in states.entries) {
          testWidgets('no overflow: ${st.key} $tag', (t) async {
            await _pump(t, st.value, size: size, dark: dark, lang: lang);
            expect(t.takeException(), isNull);
            if (_png.isNotEmpty) await savePng(t, _png, '${st.key}-$tag');
          });
          testWidgets('no overflow: robot ${st.key} $tag', (t) async {
            await _pump(
              t,
              st.value,
              size: size,
              dark: dark,
              lang: lang,
              robot: true,
              onStop: () {},
            );
            expect(t.takeException(), isNull);
            if (_png.isNotEmpty) {
              await savePng(t, _png, 'robot-${st.key}-$tag');
            }
          });
        }
        testWidgets('no overflow: question + answered $tag', (t) async {
          await _pump(t, _ready, size: size, dark: dark, lang: lang);
          // Small phones scroll to the ticket.
          await t.ensureVisible(find.byKey(const ValueKey('scan_start_quiz')));
          await t.pump();
          await t.tap(find.byKey(const ValueKey('scan_start_quiz')));
          await _settle(t);
          expect(t.takeException(), isNull);
          if (_png.isNotEmpty) await savePng(t, _png, 'question-$tag');
          await t.ensureVisible(find.byKey(const ValueKey('answer_0')));
          await t.tap(find.byKey(const ValueKey('answer_0')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull);
          if (_png.isNotEmpty) await savePng(t, _png, 'answered-$tag');
          await _settle(t);
          expect(t.takeException(), isNull);
          if (_png.isNotEmpty) await savePng(t, _png, 'review-$tag');
        });
      }
    }
  }
}
