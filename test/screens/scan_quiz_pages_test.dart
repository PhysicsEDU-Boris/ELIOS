// Full-screen Scan & quiz pages (decision 0216, Figma 629:90773 / 629:90816):
// result page → Start quiz → full-screen question, answer feedback, no
// overflow in portrait and landscape, light/dark, EN/ID.
// SCAN_RENDER=<dir> writes PNGs of every state.
import 'package:elio/l10n/l10n.dart';
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

Future<_Quiz> _pump(
  WidgetTester t,
  WasteQuizUiState seed, {
  Size size = const Size(390, 844),
  bool dark = false,
  String lang = 'en',
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
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
            const Scaffold(body: SizedBox.expand(child: ScanQuizPages())),
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
    expect(find.byKey(const ValueKey('quiz_popup')), findsOneWidget);
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

  final states = {
    'identifying': _identifying,
    'writing': _writing,
    'identified': _ready,
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
        });
      }
    }
  }
}
