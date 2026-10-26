// U1 (Figma 43:30, decision 0026): at every supported window size, with no
// quiz, a quiz open or minimised, and with the STOPPED strip, nothing
// overflows and every control is reachable (scrolling if needed) and on top.
// `flutter test --dart-define=U1_PNG=true test/widgets/control_layout_test.dart`
// also saves one PNG per size to docs/test-results/u1-control-layout/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elio/models/chat_message.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:elio/widgets/drive_pad.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _savePngs = bool.fromEnvironment('U1_PNG');

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

const _sizes = {
  '1366x768': Size(1366, 768),
  '1024x768': Size(1024, 768),
  '800x632': Size(800, 632),
  '770x553': Size(770, 553), // the owner's Mac window
  '844x390': Size(844, 390), // phone landscape (iPhone / modern Android)
  '800x360': Size(800, 360), // Android compact landscape (Figma 52:52)
  '390x844': Size(390, 844), // phone portrait
};

enum _Quiz { none, open, minimised }

final _taps = <String, int>{};
void _tap(String what) => _taps[what] = (_taps[what] ?? 0) + 1;
final _shot = GlobalKey();

Future<void> _pump(WidgetTester tester, Size size, {_Quiz quiz = _Quiz.none, bool stopped = false, bool debugBuild = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  _taps.clear();
  final seed = switch (quiz) {
    _Quiz.none => const WasteQuizUiState(),
    _Quiz.open => _quiz,
    _Quiz.minimised => _quiz.copyWith(minimized: true),
  };
  await tester.pumpWidget(RepaintBoundary(
    key: _shot,
    child: ProviderScope(
      overrides: [wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(seed))],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: ControlLayout(
            stoppedBanner: stopped ? StoppedBanner(reason: 'link_lost', onResume: () => _tap('resume')) : null,
            exitButton: ControlPill(icon: Icons.arrow_back_rounded, label: 'Exit', onTap: () => _tap('exit')),
            debugScanButton: ControlPill(icon: Icons.bug_report_outlined, label: 'Debug Scan', onTap: () => _tap('debug')),
            debugBuild: debugBuild,
            historyButton: const HistoryPill(),
            armHeight: (c) => ArmSlider(compact: c, label: 'UP/DOWN', sublabel: 'ARM HEIGHT', value: 0.2, enabled: true, onChanged: (_) => _tap('height')),
            drivePad: (c) => DrivePad(
              compact: c,
              speed: 75,
              enabled: true,
              onForward: () => _tap('forward'),
              onBack: () {},
              onLeft: () {},
              onRight: () {},
              onStop: () => _tap('wheels stop'),
            ),
            camera: const ColoredBox(color: Color(0xFFD9D9D9)),
            actions: GripperButtons(enabled: true, width: 30, onWidthChanged: (_) => _tap('width'),
                onPickUp: () => _tap('pick up'), onRelease: () => _tap('release')),
            speed: (c) => SpeedSlider(compact: c, speed: 75, enabled: true, onChanged: (_) => _tap('speed')),
            stopButton: EmergencyStopButton(onStop: () => _tap('stop')),
            armReach: (c) => ArmSlider(compact: c, label: 'FORWARD/BACKWARD', sublabel: 'ARM REACH', value: 0.3, enabled: true, onChanged: (_) => _tap('reach')),
            launcher: const QuizLauncherButton(),
            quiz: WasteQuizPopup(onStop: () => _tap('quiz stop'), showLauncher: false),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scrolled into view, then on top at its centre: its own render object (or
/// a descendant) is on the hit-test path there, not something covering it.
Future<void> _expectTappable(WidgetTester tester, Finder finder, String what, {bool scroll = true}) async {
  expect(finder, findsOneWidget, reason: what);
  if (scroll) {
    await tester.ensureVisible(finder);
    await tester.pump();
  }
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

/// One tap reaches [what]'s callback.
Future<void> _tapOnce(WidgetTester tester, Finder finder, String what) async {
  await _expectTappable(tester, finder, what);
  await tester.tap(finder);
  await tester.pump();
  expect(_taps[what], 1, reason: 'one tap on $what');
}

/// The STOP label is one line and fits its button.
void _expectOneLine(WidgetTester tester, Finder label, Finder button) {
  expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
  final text = tester.getRect(label);
  expect(text.height, lessThan(text.width), reason: 'wider than high: one line, not "STO" / "P"');
  final box = tester.getRect(button);
  expect(box.contains(text.topLeft) && box.contains(text.bottomRight), isTrue, reason: 'the label fits the button');
}

Future<void> _savePng(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/test-results/u1-control-layout/control-$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Real glyphs instead of the test font's boxes, for the PNGs only.
Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (_savePngs) await _loadFonts();
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final quiz in _Quiz.values) {
      for (final stopped in [false, true]) {
        testWidgets('$name, quiz ${quiz.name}${stopped ? ', STOPPED' : ''}: no overflow, every control one tap away',
            (tester) async {
          await _pump(tester, size, quiz: quiz, stopped: stopped);
          final scrollable = find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable));
          expect(tester.state<ScrollableState>(scrollable.first).position.maxScrollExtent, 0,
              reason: 'the extra gripper slider must fit without scrolling at $name');
          if (_savePngs && quiz == _Quiz.minimised && !stopped) await _savePng(tester, name);
          expect(tester.takeException(), isNull);
          expect(tester.renderObject<RenderParagraph>(find.text('Speed (PWM)')).didExceedMaxLines, isFalse,
              reason: 'the full speed label remains visible in compact controls');
          expect(find.textContaining('LIVE SCAN'), findsNothing, reason: 'the debug panel is off the screen');

          // Above the fold, before any scrolling: STOP at every size (the quiz's own STOP while the
          // quiz is open), and down to 770x553 the D-pad and both arm sliders too.
          final screen = Offset.zero & size;
          void onScreen(Finder f, String what) {
            expect(f, findsOneWidget, reason: what);
            final r = tester.getRect(f);
            expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue,
                reason: '$what at $r is not fully on the ${size.width.toInt()}x${size.height.toInt()} screen');
          }

          if (quiz == _Quiz.open) {
            onScreen(find.ancestor(of: find.descendant(of: find.byType(WasteQuizPopup), matching: find.text('STOP')), matching: find.byType(InkWell)).first, 'quiz-header STOP');
          } else {
            onScreen(find.byType(EmergencyStopButton), 'STOP');
            await _expectTappable(tester, find.byType(EmergencyStopButton), 'STOP (unscrolled)', scroll: false);
          }
          if (size.width >= 770) { // 770x553, 800x632, 1024x768 and 1366x768
            for (final key in [Icons.arrow_upward, Icons.arrow_back, Icons.hexagon_outlined, Icons.arrow_forward, Icons.arrow_downward]) {
              onScreen(find.byIcon(key), 'D-pad $key');
            }
            onScreen(find.byType(ArmSlider).first, 'UP/DOWN slider');
            onScreen(find.byType(ArmSlider).last, 'FORWARD/BACKWARD slider');
          }

          if (stopped) await _tapOnce(tester, find.text('Lanjutkan'), 'resume');

          if (quiz == _Quiz.open) {
            final quizStop = find.descendant(of: find.byType(WasteQuizPopup), matching: find.text('STOP'));
            _expectOneLine(tester, quizStop, find.ancestor(of: quizStop, matching: find.byType(InkWell)).first);
            await _expectTappable(tester, find.byTooltip('Tutup'), 'quiz close (X)');
            await _expectTappable(tester, find.text('Dibilas lalu dikeringkan'), 'a quiz answer');
            await _tapOnce(tester, quizStop, 'quiz stop');
            // Minimise, then the leaf brings it back.
            await _expectTappable(tester, find.byTooltip('Kecilkan'), 'quiz minimise');
            await tester.tap(find.byTooltip('Kecilkan'));
            await tester.pump(const Duration(milliseconds: 300));
            await _expectTappable(tester, find.byTooltip('Buka kuis'), 'leaf');
            await tester.tap(find.byTooltip('Buka kuis'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byTooltip('Buka kuis'), findsNothing, reason: 'no leaf while the quiz is open');
            await _expectTappable(tester, find.byTooltip('Tutup'), 'quiz reopened');
            return;
          }

          final stop = find.byType(EmergencyStopButton);
          _expectOneLine(tester, find.descendant(of: stop, matching: find.text('STOP')), stop);
          await _tapOnce(tester, stop, 'stop');
          await _expectTappable(tester, find.byIcon(Icons.arrow_upward), 'D-pad forward');
          final pad = await tester.startGesture(tester.getCenter(find.byIcon(Icons.arrow_upward)));
          await pad.up();
          expect((_taps['forward'], _taps['wheels stop']), (1, 1), reason: 'motor on press, 0,0 on release');
          await _tapOnce(tester, find.descendant(of: find.byType(ArmSlider).first, matching: find.byType(Slider)), 'height');
          await _tapOnce(tester, find.descendant(of: find.byType(ArmSlider).last, matching: find.byType(Slider)), 'reach');
          await _tapOnce(tester, find.descendant(of: find.byType(SpeedSlider), matching: find.byType(Slider)), 'speed');
          final gripperSlider = find.descendant(of: find.byType(GripperButtons), matching: find.byType(Slider));
          expect(tester.widget<Slider>(gripperSlider).max, 100);
          expect(tester.widget<Slider>(gripperSlider).value, 30);
          await _tapOnce(tester, gripperSlider, 'width');
          await _tapOnce(tester, find.text('PICK UP'), 'pick up');
          await _tapOnce(tester, find.text('RELEASE'), 'release');
          await _tapOnce(tester, find.text('Exit'), 'exit');
          await _tapOnce(tester, find.text('Debug Scan'), 'debug');
          await _expectTappable(tester, find.text('History'), 'History');
          if (quiz == _Quiz.minimised) {
            await _expectTappable(tester, find.byTooltip('Buka kuis'), 'leaf');
          } else {
            expect(find.byTooltip('Buka kuis'), findsNothing, reason: 'no leaf without a minimised quiz');
          }
        });
      }
    }
  }

  testWidgets('STOPPED: the open quiz stays usable (answer, then close with X)', (tester) async {
    await _pump(tester, const Size(800, 632), quiz: _Quiz.open, stopped: true);
    final container = ProviderScope.containerOf(tester.element(find.byType(WasteQuizPopup)));
    await tester.tap(find.text('Dibilas lalu dikeringkan'));
    await tester.pump();
    expect(container.read(wasteQuizProvider).selectedOption, isNotNull, reason: 'answering is not motion');
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
  });

  testWidgets('release build: no Debug Scan', (tester) async {
    await _pump(tester, const Size(1366, 768), debugBuild: false);
    expect(find.text('Debug Scan'), findsNothing);
    expect(find.text('History'), findsOneWidget);
  });
}
