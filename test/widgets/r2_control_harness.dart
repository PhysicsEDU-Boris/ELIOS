// The R2 Control layout wired like ControlScreen.build: every motion goes
// through a real MotionGate into a recording RobotController (the fake), so
// tests can count the commands that would reach the MaixCAM2.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elio/models/chat_message.dart';
import 'package:elio/models/control_session.dart';
import 'package:elio/models/home_stats.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/robot/motion_gate.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/control/control_panels.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fake robot: every message the gate lets through.
class RecordingRobot extends RobotController {
  final sent = <String>[];

  @override
  void transmit(Map<String, Object?> message) => sent.add('${message['cmd']}');

  @override
  void transmitMotor(int left, int right) => sent.add('motor $left,$right');

  /// Everything but the 4 Hz heartbeat.
  List<String> get commands => sent.where((c) => c != 'HEARTBEAT').toList();
}

class SeededQuizNotifier extends WasteQuizNotifier {
  SeededQuizNotifier(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

final openQuiz = WasteQuizUiState(
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

enum Quiz { none, open, minimised }

final taps = <String, int>{};
void tap(String what) => taps[what] = (taps[what] ?? 0) + 1;
final shotKey = GlobalKey();

/// Disposes the gate with the tree, as ControlScreen does (heartbeat off).
class _DisposesGate extends StatefulWidget {
  const _DisposesGate({required this.gate, required this.child});
  final MotionGate gate;
  final Widget child;

  @override
  State<_DisposesGate> createState() => _DisposesGateState();
}

class _DisposesGateState extends State<_DisposesGate> {
  @override
  void dispose() {
    widget.gate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class Rig {
  Rig(this.robot, this.gate);
  final RecordingRobot robot;
  final MotionGate gate;
}

/// Pumps the layout at [size]. [link] sets the gate's link; [stopped] adds
/// STOPPED (link_lost when the link is down).
Future<Rig> pumpControl(
  WidgetTester tester,
  Size size, {
  ControlLink link = ControlLink.connected,
  bool dark = false,
  Quiz quiz = Quiz.none,
  bool stopped = false,
  bool debugBuild = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  taps.clear();
  final robot = RecordingRobot();
  final gate = MotionGate(robot: robot, sendServo: (part, v) => robot.sent.add('servo $part=$v'));
  if (link == ControlLink.connected) {
    gate.linkRestored();
    if (stopped) gate.emergencyStop('button');
  } else if (stopped) {
    gate
      ..linkRestored()
      ..linkLost();
  }
  final seed = switch (quiz) {
    Quiz.none => const WasteQuizUiState(),
    Quiz.open => openQuiz,
    Quiz.minimised => openQuiz.copyWith(minimized: true),
  };
  final enabled = link == ControlLink.connected;
  void stop() {
    tap('stop');
    gate.emergencyStop('button');
  }

  final wrap = dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap;
  await tester.pumpWidget(
    _DisposesGate(
      gate: gate,
      child: RepaintBoundary(
        key: shotKey,
        child: ProviderScope(
          overrides: [wasteQuizProvider.overrideWith(() => SeededQuizNotifier(seed))],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: wrap(
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(robotControlProvider);
                  final notifier = ref.read(robotControlProvider.notifier);
                  final speed = state.pwmSpeed;
                  final p = Theme.of(context).brightness;
                  return ListenableBuilder(
                    listenable: gate,
                    builder: (context, _) => Scaffold(
                      backgroundColor: p == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      body: ControlLayout(
                        debugBuild: debugBuild,
                        stoppedBanner: gate.stopped
                            ? StoppedBanner(reason: gate.stopReason, onResume: () => tap('resume'))
                            : null,
                        stoppedPill: gate.stopped ? StoppedPill(reason: gate.stopReason) : null,
                        exitButton: ControlPill(
                          icon: Icons.arrow_back_rounded,
                          label: 'Exit',
                          onTap: () => tap('exit'),
                        ),
                        debugScanButton: ControlPill(
                          icon: Icons.bug_report_outlined,
                          label: 'Debug Scan',
                          dashed: true,
                          onTap: () => tap('debug'),
                        ),
                        historyButton: const HistoryPill(trophies: 222),
                        avatar: IconButton(
                          tooltip: 'Open profile menu',
                          onPressed: () => tap('avatar'),
                          icon: const Icon(Icons.person),
                        ),
                        driveStatus: const ControlStatusChip(label: 'Ready', color: Colors.green),
                        joystick: controlEnabled(
                          enabled,
                          DriveJoystick(
                            enabled: enabled,
                            onDirection: (d) {
                              tap('drive');
                              driveCommand(gate, d, speed.toInt());
                            },
                            onRelease: () {
                              tap('wheels stop');
                              gate.stopWheels();
                            },
                          ),
                        ),
                        driveHint: const Text('Push to drive · let go to stop'),
                        speed: controlEnabled(
                          enabled,
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: ControlCaps('SPEED (PWM)')),
                                  Text('${speed.toInt()}%'),
                                ],
                              ),
                              SizedBox(
                                height: 40,
                                child: ControlFader(
                                  key: const ValueKey('speed_fader'),
                                  value: speed,
                                  max: 100,
                                  onChanged: enabled
                                      ? (v) {
                                          tap('speed');
                                          notifier.setPwmSpeed(v);
                                        }
                                      : null,
                                ),
                              ),
                              GearChips(speed: speed, onSelect: enabled ? notifier.setPwmSpeed : null),
                            ],
                          ),
                        ),
                        camera: ControlCameraHud(
                          key: const ValueKey('control_camera'),
                          frame: null,
                          imageSize: Size.zero,
                          detections: const [],
                          link: link,
                          fps: 10,
                          retry: const RetryInfo(attempt: 2, maxAttempts: 30, nextRetryAt: null, autoReconnect: true),
                          onReconnect: () => tap('reconnect'),
                          onWifiSettings: () => tap('wifi'),
                          quizButton: const QuizReopenButton(),
                        ),
                        actions: controlEnabled(
                          enabled,
                          LayoutBuilder(
                            builder: (context, c) {
                              final key = (c.maxHeight - 26).clamp(36.0, 64.0);
                              return Row(
                                children: [
                                  HomeButton(
                                    onConfirmed: () => tap('home') /* gate.home() in the screen */,
                                    enabled: enabled,
                                    size: key,
                                  ),
                                  const SizedBox(width: 10),
                                  TransportKey(
                                    icon: Icons.back_hand_outlined,
                                    label: 'PICK UP',
                                    primary: true,
                                    size: key,
                                    onTap: enabled
                                        ? () {
                                            tap('pick up');
                                            gate.servo('gripper', 100);
                                          }
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  TransportKey(
                                    icon: Icons.front_hand_outlined,
                                    label: 'RELEASE',
                                    size: key,
                                    onTap: enabled
                                        ? () {
                                            tap('release');
                                            gate.servo('gripper', 0);
                                          }
                                        : null,
                                  ),
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: ControlFader(
                                        key: const ValueKey('gripper_fader'),
                                        value: 30,
                                        max: 100,
                                        onChanged: enabled
                                            ? (v) {
                                                tap('width');
                                                gate.servo('gripper', v.round());
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        armStatus: const ControlStatusChip(label: 'Ready', color: Colors.green),
                        armHeight: controlEnabled(
                          enabled,
                          Column(
                            children: [
                              Expanded(
                                child: ControlFader(
                                  key: const ValueKey('height_fader'),
                                  vertical: true,
                                  value: 0.2,
                                  onChanged: enabled
                                      ? (v) {
                                          tap('height');
                                          gate.servo('height', (v * 180).toInt());
                                        }
                                      : null,
                                ),
                              ),
                              const ControlCaps('HEIGHT'),
                            ],
                          ),
                        ),
                        armReach: controlEnabled(
                          enabled,
                          Column(
                            children: [
                              Expanded(
                                child: ControlFader(
                                  key: const ValueKey('reach_fader'),
                                  vertical: true,
                                  value: 0.3,
                                  onChanged: enabled
                                      ? (v) {
                                          tap('reach');
                                          gate.servo('reach', (v * 180).toInt());
                                        }
                                      : null,
                                ),
                              ),
                              const ControlCaps('REACH'),
                            ],
                          ),
                        ),
                        power: PowerGlowButton(
                          link: link,
                          size: size.height >= 700 ? 64 : 52,
                          onTap: () => tap('power'),
                        ),
                        stopButton: EmergencyStopButton(onStop: stop),
                        armTip: const Text('Slide up to lift.'),
                        bottomCards: [
                          const MissionCard(done: 2),
                          const DriveTallyCard(
                            bins: {HomeBin.organik: 1, HomeBin.anorganik: 1, HomeBin.b3: 0},
                            trophies: 30,
                          ),
                          ElioTipCard(
                            text: controlTip(link: link, stopped: gate.stopped, quizOpen: quiz == Quiz.open).text,
                            mood: TipMood.happy,
                          ),
                          ControlTogglesCard(
                            scanQuiz: true,
                            voice: true,
                            onScanQuiz: (_) => tap('scan quiz'),
                            onVoice: (_) => tap('voice'),
                          ),
                        ],
                        compactStrip: ControlCompactStrip(
                          missionDone: 2,
                          bins: const {HomeBin.organik: 1, HomeBin.anorganik: 1, HomeBin.b3: 0},
                          tip: controlTip(link: link, stopped: gate.stopped, quizOpen: quiz == Quiz.open).text,
                          scanQuiz: true,
                          voice: true,
                          onScanQuiz: (_) => tap('scan quiz'),
                          onVoice: (_) => tap('voice'),
                        ),
                        quiz: WasteQuizPopup(onStop: () => tap('quiz stop'), showLauncher: false),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500)); // the stop repeats
  robot.sent.clear();
  taps.clear();
  return Rig(robot, gate);
}

/// On top at its centre: its own render object (or a descendant) is on the
/// hit-test path there, not something covering it.
void expectTappable(WidgetTester tester, Finder finder, String what) {
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

/// Fully inside the window.
void expectOnScreen(WidgetTester tester, Finder f, Size size, String what) {
  expect(f, findsOneWidget, reason: what);
  final r = tester.getRect(f);
  final screen = Offset.zero & size;
  expect(
    screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(0.01, 0.01)),
    isTrue,
    reason: '$what at $r is not fully on the ${size.width.toInt()}x${size.height.toInt()} screen',
  );
}

Future<void> savePng(WidgetTester tester, String dir, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Real glyphs instead of the test font's boxes, for the PNGs only.
Future<void> loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter'}'
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
  final inter = FontLoader('Inter')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-Variable.ttf').readAsBytesSync())));
  if (File('assets/fonts/Inter-Variable.ttf').existsSync()) await inter.load();
}

/// No Gemma in widget tests.
void stubGemma() {
  AiQuizService.instance.mockSendExecute = (p, {imageBytes, isUser = false}) async => null;
}
