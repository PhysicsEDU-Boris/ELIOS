// E1b (decision 0026): STOP, the quiz's close and minimise, the D-pad and
// "Scan lagi" are never covered, at the sizes the app supports, with a quiz
// open and with the STOPPED banner shown.
import 'package:elio/models/chat_message.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:elio/widgets/drive_pad.dart';
import 'package:elio/widgets/live_scan_debug_overlay.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SeededQuizNotifier extends WasteQuizNotifier {
  _SeededQuizNotifier(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

final _quiz = WasteQuizUiState(
  phase: WasteQuizPhase.active,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  question: const GeneratedQuestion(
    type: QuizQuestionType.multipleChoice,
    question: 'Botol plastik bekas sebaiknya diperlakukan bagaimana sebelum dibuang?',
    options: ['Dibilas lalu dikeringkan', 'Dibakar', 'Dikubur', 'Dibuang ke sungai'],
    correctIndex: 0,
  ),
  messages: [ChatMessage(isUser: false, text: 'Pilih satu jawaban.')],
);

const _sizes = {'macOS 800x632': Size(800, 632), 'phone portrait 390x844': Size(390, 844), 'tablet 1024x768': Size(1024, 768)};

class _Taps {
  int stop = 0, resume = 0, forward = 0, release = 0;
}

Future<_Taps> _pump(WidgetTester tester, Size size, {required bool stopped}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final taps = _Taps();
  final scan = LiveScanController(startQuiz: (_) => false, onEvent: (_, _) {});
  addTearDown(scan.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_quiz))],
    child: MaterialApp(
      home: Scaffold(
        body: ControlLayout(
          stoppedBanner: stopped ? StoppedBanner(reason: 'link_lost', onResume: () => taps.resume++) : null,
          stopButton: EmergencyStopButton(onStop: () => taps.stop++),
          drivePad: DrivePad(
            speed: 75,
            enabled: true,
            onForward: () => taps.forward++,
            onBack: () {},
            onLeft: () {},
            onRight: () {},
            onStop: () => taps.release++,
          ),
          debugPanel: LiveScanDebugOverlay(controller: scan, scanLine: 'gemma "Label"   detektor Plastic'),
          content: const Stack(children: [SizedBox.expand(child: ColoredBox(color: Colors.white)), WasteQuizPopup()]),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return taps;
}

/// The widget is on top at its centre: its own render object (or a
/// descendant) is on the hit-test path there, not something covering it.
void _expectNotCovered(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsOneWidget, reason: what);
  final target = tester.renderObject(finder);
  final hits = tester.hitTestOnBinding(tester.getCenter(finder)).path.map((e) => e.target).whereType<RenderObject>();
  bool inside(RenderObject r) {
    for (RenderObject? n = r; n != null; n = n.parent) {
      if (n == target) return true;
    }
    return false;
  }

  expect(hits.any(inside), isTrue, reason: '$what is covered');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final stopped in [false, true]) {
      testWidgets('$name, quiz open${stopped ? ', STOPPED banner' : ''}: nothing covers anything', (tester) async {
        final taps = await _pump(tester, size, stopped: stopped);
        _expectNotCovered(tester, find.byType(EmergencyStopButton), 'STOP');
        _expectNotCovered(tester, find.byTooltip('Tutup'), 'quiz close (X)');
        _expectNotCovered(tester, find.byTooltip('Kecilkan'), 'quiz minimise');
        _expectNotCovered(tester, find.byIcon(Icons.arrow_upward), 'D-pad forward');
        _expectNotCovered(tester, find.text('Scan lagi'), 'Scan lagi');
        _expectNotCovered(tester, find.text('Dibilas lalu dikeringkan'), 'a quiz answer');
        if (stopped) _expectNotCovered(tester, find.text('Lanjutkan'), 'Lanjutkan');

        // STOP on one line: "STOP" is one line high and fits the button.
        final label = tester.renderObject<RenderParagraph>(find.text('STOP'));
        expect(label.didExceedMaxLines, isFalse);
        final onScreen = tester.getRect(find.text('STOP'));
        final button = tester.getRect(find.byType(EmergencyStopButton));
        expect(onScreen.height, lessThan(40), reason: 'one line, not "STO" / "P"');
        expect(onScreen.height, lessThan(onScreen.width), reason: 'wider than high: one line');
        expect(button.contains(onScreen.topLeft) && button.contains(onScreen.bottomRight), isTrue,
            reason: 'the label fits inside the button');

        // One tap each, and they reach their own callbacks.
        await tester.tap(find.byType(EmergencyStopButton));
        final pad = await tester.startGesture(tester.getCenter(find.byIcon(Icons.arrow_upward)));
        await pad.up();
        if (stopped) await tester.tap(find.text('Lanjutkan'));
        expect((taps.stop, taps.forward, taps.release, taps.resume), (1, 1, 1, stopped ? 1 : 0));
      });
    }
  }

  testWidgets('STOPPED: the open quiz stays usable (answer, then close with X)', (tester) async {
    await _pump(tester, const Size(800, 632), stopped: true);
    final container = ProviderScope.containerOf(tester.element(find.byType(WasteQuizPopup)));
    await tester.tap(find.text('Dibilas lalu dikeringkan'));
    await tester.pump();
    expect(container.read(wasteQuizProvider).selectedOption, isNotNull, reason: 'answering is not motion');
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
  });
}
