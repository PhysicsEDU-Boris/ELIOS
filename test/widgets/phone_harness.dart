// The R3 phone layout wired like ControlScreen._phoneLayout: every motion goes
// through a real MotionGate into the recording fake robot (reuses the R2 rig).
import 'package:elio/models/control_session.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/robot/motion_gate.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/control/phone/phone_control.dart';
import 'package:elio/widgets/control/phone/phone_guide.dart';
import 'package:elio/widgets/control/phone/phone_quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r2_control_harness.dart';

export 'r2_control_harness.dart'
    show
        openQuiz,
        Rig,
        RecordingRobot,
        expectOnScreen,
        expectTappable,
        loadFonts,
        savePng,
        shotKey,
        stubGemma,
        taps,
        tap;

const phoneSizes = [Size(915, 412), Size(800, 360), Size(932, 430)];

final _mcq = const GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Where should this plastic bottle go so it can be recycled?',
  options: [
    'Organik bin',
    'Anorganik bin',
    'B3 (hazardous) bin',
    'Throw it on the ground',
  ],
  correctIndex: 1,
  explanation:
      'A clean plastic bottle is PET. Recycling plants melt it and make new bottles or fibres.',
);

const _explanation = QuizExplanation(
  summary:
      'A clean plastic bottle is PET. Recycling plants melt it and make new bottles or fibres. Rinse it, squash it, then drop it in Anorganik.',
  correctAnswerReason: 'PET is recyclable.',
  groundingStatus: GroundingStatus.bankGrounded,
);

WasteQuizUiState explaining({required bool right}) => WasteQuizUiState(
  phase: WasteQuizPhase.explaining,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 0,
  question: _mcq,
  selectedOption: right ? 1 : 0,
  currentExplanation: _explanation,
  correctCount: right ? 1 : 0,
  messages: const [],
);

WasteQuizUiState explainingEssay() => WasteQuizUiState(
  phase: WasteQuizPhase.explaining,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 2,
  question: const GeneratedQuestion(
    type: QuizQuestionType.essay,
    question: 'Why should we rinse a plastic bottle before recycling it?',
    options: [],
    correctIndex: 0,
    explanation: 'Food leftovers spoil a batch of recycled plastic.',
  ),
  essaySubmitted: true,
  essayAnswer: 'Because food leftovers can spoil the plastic.',
  currentExplanation: const QuizExplanation(
    summary: 'Clean plastic melts into good new material.',
    correctAnswerReason: 'Leftovers contaminate the batch.',
    essayScore: 8,
    essayFeedback: 'Good answer. Mention that dirty plastic is rejected.',
    rubricRows: [
      RubricRow(
        criterion: 'Names the problem',
        maxScore: 5,
        awardedScore: 4,
        comment: 'Leftovers',
      ),
      RubricRow(
        criterion: 'Names the result',
        maxScore: 5,
        awardedScore: 4,
        comment: 'Spoils the batch',
      ),
    ],
    groundingStatus: GroundingStatus.bankGrounded,
  ),
  messages: const [],
);

class _Disposes extends StatefulWidget {
  const _Disposes(this.gate, this.child);
  final MotionGate gate;
  final Widget child;
  @override
  State<_Disposes> createState() => _DisposesState();
}

class _DisposesState extends State<_Disposes> {
  @override
  void dispose() {
    widget.gate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [guideStep] 0..4 opens the Guide on that step. [quiz] seeds the quiz provider.
Future<Rig> pumpPhone(
  WidgetTester tester,
  Size size, {
  ControlLink link = ControlLink.connected,
  bool dark = false,
  bool stopped = false,
  bool skeleton = false,
  WasteQuizUiState quiz = const WasteQuizUiState(),
  int? guideStep,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  taps.clear();
  final robot = RecordingRobot();
  final gate = MotionGate(
    robot: robot,
    sendServo: (part, v) => robot.sent.add('servo $part=$v'),
  );
  if (link == ControlLink.connected) {
    gate.linkRestored();
    if (stopped) gate.emergencyStop('button');
  } else if (stopped) {
    gate
      ..linkRestored()
      ..linkLost();
  }
  final keys = List.generate(4, (_) => GlobalKey());
  var guideOpen = guideStep != null;
  final wrap = dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap;
  await tester.pumpWidget(
    _Disposes(
      gate,
      RepaintBoundary(
        key: shotKey,
        child: ProviderScope(
          overrides: [
            wasteQuizProvider.overrideWith(() => SeededQuizNotifier(quiz)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: wrap(
              Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(robotControlProvider);
                  final notifier = ref.read(robotControlProvider.notifier);
                  final q = ref.watch(wasteQuizProvider);
                  void stop() {
                    tap('stop');
                    gate.emergencyStop('button');
                  }

                  return StatefulBuilder(
                    builder: (context, setState) => ListenableBuilder(
                      listenable: gate,
                      builder: (context, _) => Scaffold(
                        body: PhoneControlLayout(
                          link: link,
                          stopped: gate.stopped,
                          stopReason: gate.stopReason,
                          skeleton: skeleton,
                          driveLabel: (
                            gate.stopped ? 'Stopped' : 'Forward',
                            Colors.green,
                          ),
                          armLabel: (
                            gate.stopped ? 'Stopped' : 'Ready',
                            Colors.green,
                          ),
                          speed: state.pwmSpeed,
                          onSpeed: (v) {
                            tap('speed');
                            notifier.setPwmSpeed(v);
                          },
                          onDirection: (d) {
                            tap('drive');
                            driveCommand(gate, d, state.pwmSpeed.toInt());
                          },
                          onRelease: () {
                            tap('wheels stop');
                            gate.stopWheels();
                          },
                          frame: null,
                          fps: 10,
                          scanQuizOn: true,
                          onScanQuiz: (_) => tap('scan quiz'),
                          voiceOn: true,
                          onVoice: (_) => tap('voice'),
                          onHome: () {
                            tap('home');
                            gate.home();
                          },
                          onPickUp: () {
                            tap('pick up');
                            gate.servo('gripper', 100);
                          },
                          onReleaseGripper: () {
                            tap('release');
                            gate.servo('gripper', 0);
                          },
                          gripper: 40,
                          onGripper: (v) {
                            tap('gripper');
                            gate.servo('gripper', v.round());
                          },
                          height: 112,
                          onHeight: (v) {
                            tap('height');
                            gate.servo('height', (v * 180).toInt());
                          },
                          reach: 72,
                          onReach: (v) {
                            tap('reach');
                            gate.servo('reach', (v * 180).toInt());
                          },
                          onPower: () => tap('power'),
                          onConnect: () => tap('connect'),
                          onStop: stop,
                          onGo: () {
                            tap('go');
                            gate.resume();
                          },
                          missionDone: 2,
                          trophies: 222,
                          quizBadge: q.phase == WasteQuizPhase.idle ? null : 1,
                          onQuiz: () => tap('quiz'),
                          onHistory: () => tap('history'),
                          onAvatar: () => tap('avatar'),
                          onBack: () => tap('exit'),
                          onGuide: () => setState(() => guideOpen = true),
                          driveKey: keys[0],
                          stopKey: keys[1],
                          actionKey: keys[2],
                          quizKey: keys[3],
                          overlays: [
                            Positioned.fill(
                              child: PhoneQuizPopup(onStop: stop),
                            ),
                            if (guideOpen)
                              Positioned.fill(
                                child: PhoneGuide(
                                  driveKey: keys[0],
                                  stopKey: keys[1],
                                  actionKey: keys[2],
                                  quizKey: keys[3],
                                  initialStep: guideStep ?? 0,
                                  onStop: stop,
                                  onClose: () =>
                                      setState(() => guideOpen = false),
                                ),
                              ),
                          ],
                        ),
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
  await tester.pump(const Duration(milliseconds: 500));
  robot.sent.clear();
  taps.clear();
  return Rig(robot, gate);
}
