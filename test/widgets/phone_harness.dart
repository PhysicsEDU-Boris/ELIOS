import 'dart:typed_data';
// The R3 phone layout wired like ControlScreen._phoneLayout: every motion goes
// through a real MotionGate into the recording fake robot (reuses the R2 rig).
import 'package:elio/models/chat_message.dart';
import 'package:elio/models/control_session.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/robot/motion_gate.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/control/phone/phone_control.dart';
import 'package:elio/widgets/control/phone/phone_guide.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
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

QuizExplanation _explanation({required bool right, bool why = true, bool long = false}) => QuizExplanation(
  summary: 'Modul menyebut botol plastik minuman sebagai PET; HDPE dan PVC dipakai untuk produk lain.' * (long ? 12 : 1),
  correctAnswerReason: 'Botol minuman umumnya PET, yang didaur ulang menjadi botol atau serat baru.',
  selectedAnswerFeedback: !right && why ? 'Sisa organik terurai; botol PET tidak.' : '',
  comparisonRows: right
      ? const [
          ComparisonRow(bin: 'Sampah Organik', material: 'Sisa makanan, daun', accepted: 'Bahan yang terurai secara alami'),
          ComparisonRow(bin: 'Daur Ulang (Anorganik)', material: 'Plastik, kertas, logam', accepted: 'Bahan yang dapat diproses ulang', isCorrect: true),
          ComparisonRow(bin: 'Limbah B3', material: 'Baterai, HP', accepted: 'Bahan berbahaya'),
        ]
      : const [],
  learningTakeaway: 'Ingat: Botol plastik masuk ke Daur Ulang (Anorganik).',
  sourceTitle: 'Bank Soal ELIO',
  sourceSection: '4.2',
  sourcePage: '21',
  quote: 'Botol minuman umumnya terbuat dari PET.',
  bankId: 'plastic-mc-04',
  groundingStatus: GroundingStatus.bankGrounded,
);

WasteQuizUiState explaining({required bool right, bool why = true, bool long = false}) => WasteQuizUiState(
  phase: WasteQuizPhase.explaining,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 0,
  question: _mcq,
  selectedOption: right ? 1 : 0,
  currentExplanation: _explanation(right: right, why: why, long: long),
  correctCount: right ? 1 : 0,
  messages: [
    ChatMessage(isUser: false, text: 'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.'),
    ChatMessage(isUser: true, text: 'Kenapa bukan organik?'),
    ChatMessage(isUser: false, text: 'Botol PET tidak terurai oleh mikroorganisme.'),
  ],
);

const _essayQ = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Jelaskan mengapa botol plastik perlu dibilas sebelum didaur ulang.',
  explanation: 'Sisa makanan merusak satu batch plastik daur ulang.',
  bankId: 'plastic-essay-01',
);

WasteQuizUiState explainingEssay({bool pending = false}) => WasteQuizUiState(
  phase: WasteQuizPhase.explaining,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 2,
  question: _essayQ,
  essaySubmitted: true,
  essayAnswer: 'Karena sisa makanan bisa merusak plastik.',
  currentExplanation: pending
      ? const QuizExplanation(summary: 'Jawaban tersimpan.', correctAnswerReason: '', essayFeedback: 'Menunggu penilaian', groundingStatus: GroundingStatus.gemmaUngrounded)
      : const QuizExplanation(
          summary: 'Jawaban bagus.',
          correctAnswerReason: '',
          essayScore: 8,
          essayFeedback: 'Jawaban bagus. Sebutkan bahwa plastik kotor ditolak.',
          rubricRows: [
            RubricRow(criterion: 'Menyebut masalahnya', maxScore: 5, awardedScore: 5, comment: 'Sisa makanan'),
            RubricRow(criterion: 'Menyebut akibatnya', maxScore: 5, awardedScore: 3, comment: 'Batch rusak'),
          ],
          quote: 'Plastik harus bersih dan kering sebelum didaur ulang.',
          sourceSection: '4.3',
          sourcePage: '22',
          groundingStatus: GroundingStatus.gemmaUngrounded,
        ),
  messages: const [],
);

/// The loading popup: identifying (no scan yet) or writing the question.
WasteQuizUiState loading({bool identifying = false}) => WasteQuizUiState(
  phase: identifying ? WasteQuizPhase.identifying : WasteQuizPhase.loadingQuestion,
  scan: identifying ? null : ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 0,
);

/// The popup with no question yet: the skeleton.
const skeletonQuiz = WasteQuizUiState(phase: WasteQuizPhase.active);

WasteQuizUiState essayInput() => WasteQuizUiState(
  phase: WasteQuizPhase.active,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  questionIndex: 1,
  question: _essayQ,
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
  Uint8List? frame,
  Rect? lockBox,
  double frameAspect = 4 / 3,
  bool locked = false,
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
                          frame: frame,
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
                          onBase: (dir) {
                            tap('base');
                            gate.servo('base', 90 + dir * 2);
                          },
                          onBaseRelease: () => tap('base stop'),
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
                          quizWaiting: q.phase == WasteQuizPhase.identifying || q.phase == WasteQuizPhase.loadingQuestion,
                          onQuiz: () => tap('quiz'),
                          onHistory: () => tap('history'),
                          onAvatar: () => tap('avatar'),
                          onBack: () => tap('exit'),
                          onGuide: () => setState(() => guideOpen = true),
                          driveKey: keys[0],
                          stopKey: keys[1],
                          actionKey: keys[2],
                          quizKey: keys[3],
                          onLock: () => tap('lock'),
                          locked: locked,
                          onScan: () => tap('scan'),
                          lockBox: lockBox,
                          lockLabel: lockBox == null ? null : 'Kardus',
                          frameAspect: frameAspect,
                          overlays: [
                            Positioned.fill(
                              child: WasteQuizPopup(onStop: stop, showLauncher: false),
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
