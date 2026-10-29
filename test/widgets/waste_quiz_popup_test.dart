import 'package:elio/models/chat_message.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SeededQuizNotifier extends WasteQuizNotifier {
  _SeededQuizNotifier(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

final _scan = ScannedWaste.fromLabel('botol-plastik');

const _longQuestion =
    'Botol plastik bekas minuman yang baru saja discan oleh robot ini sebaiknya '
    'diperlakukan bagaimana sebelum dimasukkan ke tempat sampah daur ulang agar '
    'tidak mencemari sampah lain di dalam satu batch?';

final _longChat = [
  for (var i = 0; i < 8; i++) ...[
    ChatMessage(isUser: true, text: 'Boleh minta petunjuk nomor $i?'),
    ChatMessage(
      isUser: false,
      text: 'Pikirkan sisa minuman di dalam botol: apa yang terjadi pada satu '
          'batch daur ulang jika tercampur kotoran, minyak, atau sisa makanan? '
          'Plastik yang kotor sering ditolak oleh pabrik daur ulang.',
    ),
  ],
];

final _mcQuestion = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: _longQuestion,
  options: const [
    'Langsung dibuang bersama sisa makanan di tempat sampah organik',
    'Dibilas, dikeringkan, lalu dimasukkan ke tempat sampah daur ulang',
    'Dibakar di halaman rumah agar volumenya berkurang',
    'Dikubur di tanah supaya cepat terurai',
  ],
  correctIndex: 1,
  explanation: 'Plastik bersih lebih mudah didaur ulang.',
);

const _essayQuestion = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: _longQuestion,
);

final _states = <String, WasteQuizUiState>{
  'identifying': const WasteQuizUiState(phase: WasteQuizPhase.identifying),
  'hazard': WasteQuizUiState(phase: WasteQuizPhase.confirmingHazard, scan: ScannedWaste.fromLabel('E_Waste')),
  'mismatch': WasteQuizUiState(phase: WasteQuizPhase.confirmingMismatch,
      scan: ScannedWaste.fromLabel('kardus', categoryHint: 'organik'), mismatchDetector: 'Cardboard'),
  'loading': WasteQuizUiState(phase: WasteQuizPhase.loadingQuestion, scan: _scan),
  'mc-unanswered': WasteQuizUiState(
    phase: WasteQuizPhase.active,
    scan: _scan,
    question: _mcQuestion,
    messages: [ChatMessage(isUser: false, text: 'Pilih satu jawaban.')],
  ),
  'mc-answered-long-chat': WasteQuizUiState(
    phase: WasteQuizPhase.active,
    scan: _scan,
    question: _mcQuestion,
    selectedOption: 0,
    mcAnswered: 1,
    messages: _longChat,
    sendingChat: true,
  ),
  'essay': WasteQuizUiState(
    phase: WasteQuizPhase.active,
    scan: _scan,
    questionIndex: 1,
    question: _essayQuestion,
    messages: [ChatMessage(isUser: false, text: 'Tulis jawabanmu lalu kirim.')],
  ),
  'essay-submitted': WasteQuizUiState(
    phase: WasteQuizPhase.active,
    scan: _scan,
    questionIndex: 1,
    question: _essayQuestion,
    essaySubmitted: true,
    messages: _longChat,
  ),
  'finished': WasteQuizUiState(
    phase: WasteQuizPhase.finished,
    scan: _scan,
    questionIndex: 4,
    question: _mcQuestion,
    correctCount: 2,
    mcAnswered: 3,
    messages: _longChat,
  ),
};

/// Logical (dp) screen sizes: small/medium/large phones in landscape (the
/// control screen is landscape-locked), split-screen, portrait, and tablet.
const _screens = <String, Size>{
  'small-phone-landscape 640x320': Size(640, 320),
  'phone-landscape 760x360': Size(760, 360),
  'pixel7-landscape 915x412': Size(915, 412),
  'split-screen 560x320': Size(560, 320),
  'portrait 360x740': Size(360, 740),
  'tablet 1280x800': Size(1280, 800),
};

Future<void> _pump(WidgetTester tester, Size size, WasteQuizUiState state, {double keyboard = 0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(state))],
      child: const MaterialApp(
        home: Scaffold(body: Stack(children: [SizedBox.expand(), WasteQuizPopup()])),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('level chip names the session while bank items start Mudah-first', (tester) async {
    await _pump(tester, const Size(760, 360), WasteQuizUiState(
      phase: WasteQuizPhase.active, scan: _scan, question: _mcQuestion, difficulty: QuizDifficulty.hard,
    ));
    expect(find.text('Soal 1/5 · Sesi Sulit'), findsOneWidget);
  });

  testWidgets('identification shows Looking and no quiz answers', (tester) async {
    await _pump(tester, const Size(760, 360), _states['identifying']!);
    expect(find.text('Looking…'), findsOneWidget);
    expect(find.text('Lanjut kuis'), findsNothing);
  });

  testWidgets('hazard can be rejected before quiz generation', (tester) async {
    await _pump(tester, const Size(760, 360), _states['hazard']!);
    expect(find.textContaining('Kemungkinan limbah B3'), findsOneWidget);
    expect(find.text('Lanjut kuis'), findsOneWidget);
    await tester.tap(find.text('Scan ulang'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lanjut kuis'), findsNothing);
  });

  for (final screen in _screens.entries) {
    for (final st in _states.entries) {
      testWidgets('no overflow: ${st.key} @ ${screen.key}', (tester) async {
        await _pump(tester, screen.value, st.value);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('multiple-choice question and all 4 options fit without scrolling on a 760x360 phone',
      (tester) async {
    // Realistic lengths: Gemma is prompted for options of max 6 words.
    const shortQuestion = GeneratedQuestion(
      type: QuizQuestionType.multipleChoice,
      question: 'Ke tempat sampah mana botol plastik yang discan ini harus dibuang?',
      options: ['Sampah organik', 'Daur ulang (anorganik)', 'Sampah residu', 'Limbah B3'],
      correctIndex: 1,
    );
    await _pump(
      tester,
      const Size(760, 360),
      WasteQuizUiState(phase: WasteQuizPhase.active, scan: _scan, question: shortQuestion),
    );
    for (final option in shortQuestion.options) {
      final rect = tester.getRect(find.text(option));
      expect(rect.bottom, lessThanOrEqualTo(360), reason: '"$option" is cut off');
      expect(rect.left, greaterThanOrEqualTo(0));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('essay field and submit button are reachable on the smallest landscape phone',
      (tester) async {
    await _pump(tester, const Size(640, 320), _states['essay']!);
    await tester.ensureVisible(find.text('Kirim Jawaban'));
    await tester.pump();
    final rect = tester.getRect(find.text('Kirim Jawaban'));
    expect(rect.bottom, lessThanOrEqualTo(320));
    expect(find.byType(TextField), findsNWidgets(2)); // essay + chat input
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup stays usable with the keyboard open (landscape)', (tester) async {
    await _pump(tester, const Size(800, 360), _states['essay']!, keyboard: 180);
    await tester.ensureVisible(find.text('Kirim Jawaban'));
    await tester.pump();
    expect(tester.getRect(find.text('Kirim Jawaban')).bottom, lessThanOrEqualTo(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long AI chat scrolls inside the chat panel instead of growing the popup',
      (tester) async {
    await _pump(tester, const Size(760, 360), _states['mc-answered-long-chat']!);
    final chatList = find.byType(ListView);
    expect(chatList, findsOneWidget);
    expect(tester.getRect(chatList).bottom, lessThanOrEqualTo(360));
    await tester.drag(chatList, const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screens switch to Soal / Asisten AI tabs', (tester) async {
    await _pump(tester, const Size(360, 740), _states['mc-answered-long-chat']!);
    expect(find.text('Soal'), findsOneWidget);
    await tester.tap(find.textContaining('Asisten AI'));
    await tester.pump();
    expect(find.text('Tanya AI untuk koreksi...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('scan labels map to the right waste category', () {
    expect(ScannedWaste.fromLabel('botol-plastik').category?.id, 'inorganic');
    expect(ScannedWaste.fromLabel('botol-plastik').displayName, 'Botol plastik');
    expect(ScannedWaste.fromLabel('kulit_pisang').category?.id, 'organic');
    expect(ScannedWaste.fromLabel('baterai').category?.id, 'hazardous');
    expect(ScannedWaste.fromLabel('Plastic Bottle').category?.id, 'inorganic');
    expect(ScannedWaste.fromLabel('unknown-thing').category, isNull);
  });
}
