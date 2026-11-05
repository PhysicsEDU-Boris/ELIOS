import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../models/essay_grade.dart';
import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../models/scanned_waste.dart';
import '../services/detection_crop.dart';
import '../services/detection_stabilizer.dart';
import '../services/frame_source/frame_source.dart';
import '../services/ai_quiz_service.dart';
import '../services/question_bank.dart';
import '../services/quiz_explanation_service.dart';
import '../services/quiz_tts_service.dart';
import '../services/scan_diagnostics.dart';
import '../services/scan_record_store.dart';
import '../services/tester_log.dart';
import '../services/websocket_service.dart';
import 'app_preferences_provider.dart';

enum WasteQuizPhase { idle, identifying, confirmingHazard, confirmingMismatch, loadingQuestion, active, explaining, finished }

/// Where the waste-detection label driving the popup quiz comes from.
/// MaixCAM2 is the real hardware path; phone camera is a debug-only
/// stand-in for testing without the robot.
enum WasteQuizSource { maixCam2, phoneCamera }

/// Essay questions are off by default: sessions are multiple choice only (decision 0017).
// The tester build always asks essays (A1: the essay grade needs measuring).
const essayQuestionsEnabled = bool.fromEnvironment('ESSAY_QUESTIONS') || testerBuild;

/// Question order within one scan session: alternate the two types, or
/// multiple choice only when essays are off.
QuizQuestionType questionTypeFor(int index, {bool essays = true}) =>
    !essays || index.isEven ? QuizQuestionType.multipleChoice : QuizQuestionType.essay;

@immutable
class WasteQuizUiState {
  final WasteQuizPhase phase;
  final bool minimized;
  final ScannedWaste? scan;
  final QuizDifficulty difficulty;
  final int questionIndex;
  final GeneratedQuestion? question;
  final bool isFallback;
  final int? selectedOption;
  final bool essaySubmitted;
  final String? essayAnswer;
  final int correctCount;
  final int mcAnswered;
  final int skippedCount;
  final List<ChatMessage> messages;
  final bool sendingChat;
  final bool voiceOn;

  /// Why a session ended early (e.g. the photo couldn't be identified).
  final String? notice;

  /// The detector class AI disagreed with (confirmingMismatch only).
  final String? mismatchDetector;

  /// The question source this session uses (decision 0018), for the header.
  final QuestionSource questionSource;

  /// Questions answered or skipped in the current scan session (decision 0030).
  final List<RecordQuestion> recordedQuestions;

  /// The cropped JPEG bytes of the detected waste item.
  final Uint8List? cropBytes;

  /// The photo file saved to Scan History for this session, so the result card's PDF can embed it.
  final String? historyPhotoPath;

  /// The structured explanation for the current question (phase: explaining).
  final QuizExplanation? currentExplanation;

  /// True while [QuizExplanationService] is generating the explanation.
  final bool explanationLoading;

  const WasteQuizUiState({
    this.phase = WasteQuizPhase.idle,
    this.minimized = false,
    this.scan,
    this.difficulty = QuizDifficulty.medium,
    this.questionIndex = 0,
    this.question,
    this.isFallback = false,
    this.selectedOption,
    this.essaySubmitted = false,
    this.essayAnswer,
    this.correctCount = 0,
    this.mcAnswered = 0,
    this.skippedCount = 0,
    this.messages = const [],
    this.sendingChat = false,
    this.voiceOn = true,
    this.notice,
    this.mismatchDetector,
    this.questionSource = QuestionSource.bank,
    this.recordedQuestions = const [],
    this.cropBytes,
    this.historyPhotoPath,
    this.currentExplanation,
    this.explanationLoading = false,
  });

  int get totalQuestions => difficulty.questionCount;

  bool get answered => question?.type == QuizQuestionType.multipleChoice
      ? selectedOption != null
      : essaySubmitted;

  /// "Bukan ini?" is offered from the moment the object is named until the
  /// first question is answered.
  bool get canCorrectItem =>
      scan != null &&
      questionIndex == 0 &&
      !answered &&
      const {
        WasteQuizPhase.confirmingHazard,
        WasteQuizPhase.confirmingMismatch,
        WasteQuizPhase.loadingQuestion,
        WasteQuizPhase.active,
      }.contains(phase);

  bool get isLastQuestion => questionIndex >= totalQuestions - 1;

  WasteQuizUiState copyWith({
    WasteQuizPhase? phase,
    bool? minimized,
    ScannedWaste? scan,
    QuizDifficulty? difficulty,
    int? questionIndex,
    GeneratedQuestion? question,
    bool? isFallback,
    QuestionSource? questionSource,
    int? selectedOption,
    bool clearSelection = false,
    bool? essaySubmitted,
    String? essayAnswer,
    int? correctCount,
    int? mcAnswered,
    int? skippedCount,
    List<ChatMessage>? messages,
    bool? sendingChat,
    bool? voiceOn,
    String? notice,
    String? mismatchDetector,
    List<RecordQuestion>? recordedQuestions,
    Uint8List? cropBytes,
    String? historyPhotoPath,
    bool clearCropBytes = false,
    QuizExplanation? currentExplanation,
    bool clearExplanation = false,
    bool? explanationLoading,
  }) {
    return WasteQuizUiState(
      phase: phase ?? this.phase,
      minimized: minimized ?? this.minimized,
      scan: scan ?? this.scan,
      difficulty: difficulty ?? this.difficulty,
      questionIndex: questionIndex ?? this.questionIndex,
      question: question ?? this.question,
      isFallback: isFallback ?? this.isFallback,
      selectedOption: clearSelection ? null : (selectedOption ?? this.selectedOption),
      essaySubmitted: essaySubmitted ?? this.essaySubmitted,
      essayAnswer: clearSelection ? null : (essayAnswer ?? this.essayAnswer),
      correctCount: correctCount ?? this.correctCount,
      mcAnswered: mcAnswered ?? this.mcAnswered,
      skippedCount: skippedCount ?? this.skippedCount,
      messages: messages ?? this.messages,
      sendingChat: sendingChat ?? this.sendingChat,
      voiceOn: voiceOn ?? this.voiceOn,
      notice: notice ?? this.notice,
      mismatchDetector: mismatchDetector ?? this.mismatchDetector,
      questionSource: questionSource ?? this.questionSource,
      recordedQuestions: recordedQuestions ?? this.recordedQuestions,
      cropBytes: clearCropBytes ? null : (cropBytes ?? this.cropBytes),
      historyPhotoPath: historyPhotoPath ?? this.historyPhotoPath,
      currentExplanation: clearExplanation ? null : (currentExplanation ?? this.currentExplanation),
      explanationLoading: explanationLoading ?? this.explanationLoading,
    );
  }
}

/// Minimum detection confidence before a scan can trigger a popup quiz.
const _confidenceThreshold = 0.55;

/// Minimum time between automatically-triggered quizzes for the SAME label,
/// so a steady camera feed doesn't spam the popup every frame.
const _sameLabelCooldown = Duration(seconds: 25);

class WasteQuizNotifier extends Notifier<WasteQuizUiState> {
  ScanDiagnostics? _diagnostics;
  ScannedWaste? _detectorChoice; // AI's item in the detector's bin, for the mismatch card
  String? _lastLabel;
  DateTime? _lastShownAt;
  int _generation = 0;
  final _askedQuestions = <String>[];

  /// Test overrides: a fixed question source, and the essay build flag.
  @visibleForTesting
  static QuestionSource? sourceOverride;
  @visibleForTesting
  static bool essayQuestions = essayQuestionsEnabled;

  // Captured when a session starts, so a switch only affects the next scan (decision 0018).
  QuestionSource _sessionSource = QuestionSource.bank;
  bool get _ai => _sessionSource == QuestionSource.ai;

  // From the scan result (the object known) to each question shown, for the per-question log.
  Stopwatch? _scanClock;

  // This session's remaining bank questions per type (decision 0017).
  Map<QuizQuestionType, List<GeneratedQuestion>>? _bankQueues;

  // Physics angles AI questions already used this session, so none repeats (decision 0019).
  final _usedAngles = <String>[];

  // The text last spoken automatically (decision 0009: "one TTS slot, keyed
  // by object"), so the same quiz text isn't re-spoken if the message that
  // triggered it is appended again or the popup rebuilds. The manual
  // "Listen" button (listen(), below) is unaffected: a user pressing it
  // again should hear it again.
  String? _lastAutoSpokenText;

  // Background prefetch (decision 0011, M2b part 3): questions 2..N are
  // generated through the single AI slot as soon as question 1 shows, one
  // at a time, into these completers (keyed by index) -- "Soal berikutnya"
  // just awaits the one it needs, instant if it's already done.
  final _prefetchCompleters = <int, Completer<GeneratedQuestion?>>{};
  int _prefetchSessionGen = 0;
  static const _prefetchRetryDelay = Duration(milliseconds: 300);
  int? _lastNextWaitMs;

  /// Time the last "Soal berikutnya" tap waited for its question (0 when it
  /// came straight from the prefetch buffer), for the live-scan debug
  /// overlay (decision 0011).
  int? get lastNextWaitMs => _lastNextWaitMs;

  // The recorded question answers for the current session (decision 0030).
  final _recordedQuestions = <RecordQuestion>[];

  // The cropped JPEG bytes of the current waste item.
  Uint8List? _cropBytes;
  Uint8List? _historyPhotoBytes;

  @override
  WasteQuizUiState build() => const WasteQuizUiState();

  /// Difficulty is read from Config Settings → Quiz at the start of each
  /// scan session, so a change applies to the next scan.
  WasteQuizUiState _freshSession({ScannedWaste? scan, required WasteQuizPhase phase}) {
    final difficulty = QuizDifficulty.fromSetting(ref.read(appPreferencesProvider).quizDifficulty);
    QuizTtsService.instance.volume = ref.read(appPreferencesProvider).masterVolume;
    _diagnostics = null;
    _lastAutoSpokenText = null; // a new object/quiz: nothing spoken for it yet
    _sessionSource = sourceOverride ?? ref.read(appPreferencesProvider).questionSource;
    _scanClock = scan == null ? null : (Stopwatch()..start());
    _recordedQuestions.clear();
    return WasteQuizUiState(phase: phase, scan: scan, difficulty: difficulty, voiceOn: state.voiceOn,
        questionSource: _sessionSource, recordedQuestions: const [], cropBytes: _cropBytes);
  }

  /// Called from the control screen's MaixCAM2 detections listener.
  void onDetections(List<Detection> detections) {
    if (state.phase != WasteQuizPhase.idle) return;

    Detection? best;
    for (final d in detections) {
      if (d.score < _confidenceThreshold || d.label.trim().isEmpty) continue;
      if (best == null || d.score > best.score) best = d;
    }
    if (best == null) return;

    final label = best.label.trim();
    final now = DateTime.now();
    final cooledDown =
        _lastShownAt == null || now.difference(_lastShownAt!) > _sameLabelCooldown;
    if (label == _lastLabel && !cooledDown) return;

    _lastLabel = label;
    _lastShownAt = now;
    AiQuizService.instance.cancel();
    _startSession(ScannedWaste.fromLabel(label));
  }

  /// Device-camera path: first ask AI what the object is (on its own,
  /// unbiased), then generate the questions about that object.
  void onPhotoCaptured(Uint8List imageBytes) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastShownAt = DateTime.now();
    _askedQuestions.clear();
    _recordedQuestions.clear();
    _cropBytes = imageBytes;
    _historyPhotoBytes = imageBytes;
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    final generation = ++_generation;
    AiQuizService.instance.cancel();
    loadingSince = DateTime.now();
    state = _freshSession(phase: WasteQuizPhase.identifying);
    unawaited(_identifyThenQuiz(imageBytes, generation));
  }

  /// The live lock's box and JPEG belong to the same stream frame.
  void onRobotLocked(CapturedFrame frame, TrackedDetection detection) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastLabel = detection.label;
    _lastShownAt = DateTime.now();
    _askedQuestions.clear();
    _recordedQuestions.clear();
    _cropBytes = null;
    _historyPhotoBytes = null;
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    final generation = ++_generation;
    AiQuizService.instance.cancel();
    loadingSince = DateTime.now();
    state = _freshSession(phase: WasteQuizPhase.identifying);
    final diagnostics = kDebugMode ? ScanDiagnostics() : null;
    _diagnostics = diagnostics;
    diagnostics?.event('lock', {'detectorLabel': detection.label, 'confidence': detection.score,
      'frameReceivedAt': frame.timestamp.toUtc().toIso8601String(),
      'frameAgeAtLockMs': DateTime.now().difference(frame.timestamp).inMilliseconds,
      'captureTimestamp': null, 'detectionTimestamp': null,
      'frameId': frame.frameId, 'detectionFrameId': frame.detectionFrameId,
      'firmwareSha256': frame.firmwareSha256,
      'imageSource': frame.hasPairedCleanImage ? 'clean_image' : 'unavailable',
      'frameWidth': frame.width, 'frameHeight': frame.height,
      'boxCenterXYWH': [detection.x, detection.y, detection.w, detection.h]});
    unawaited(_cropThenIdentify(frame, detection, generation, diagnostics));
  }

  /// LOCK (0181): the AI names and boxes the main item in the whole frame. Opens no quiz; the
  /// result is shown on the video and can start one with [scanLocked]. Prefers the paired clean image.
  Future<({LockedItem? lock, String? failure})> lockItem(CapturedFrame frame) async {
    final bytes = frame.hasPairedCleanImage ? frame.cleanBytes! : frame.bytes;
    TesterLog.instance.log('scan', 'lock frame=${frame.frameId} image=${frame.hasPairedCleanImage ? 'clean' : 'preview'}');
    final result = await AiQuizService.instance.identifyItem(bytes, wholeFrame: true);
    if (result.item == null) return (lock: null, failure: result.failure);
    final box = result.box;
    final crop = box == null ? null : await compute(cropToBox, (bytes, box));
    return (lock: LockedItem(result, crop ?? bytes, box), failure: null);
  }

  /// SCAN (0181): the quiz for a locked item, from its LOCK answer (no second identify call).
  void scanLocked(LockedItem lock) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastShownAt = DateTime.now();
    _askedQuestions.clear();
    _recordedQuestions.clear();
    _cropBytes = lock.photo;
    _historyPhotoBytes = lock.photo;
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    final generation = ++_generation;
    loadingSince = DateTime.now();
    state = _freshSession(phase: WasteQuizPhase.identifying);
    final diagnostics = kDebugMode ? ScanDiagnostics() : null;
    _diagnostics = diagnostics;
    diagnostics?.event('scan_locked', {'item': lock.result.item, 'category': lock.result.category});
    _quizFor(lock.result, lock.result.item!, generation, diagnostics: diagnostics);
  }

  Future<void> _cropThenIdentify(CapturedFrame frame, TrackedDetection detection, int generation, ScanDiagnostics? diagnostics) async {
    final timing = kDebugMode ? (Stopwatch()..start()) : null;
    final crop = await compute(prepareDetectionCrop, (frame, detection));
    final bytes = crop.bytes;
    diagnostics?.event('crop_complete', {...crop.details, 'cropPreparationMs': timing?.elapsedMilliseconds,
      'valid': bytes != null, 'stale': generation != _generation});
    if (generation != _generation) return;
    if (bytes == null) {
      state = state.copyWith(phase: WasteQuizPhase.finished,
          notice: frame.hasPairedCleanImage
              ? 'Benda belum bisa dipotong dari foto. Coba scan lagi.'
              : 'Foto asli tanpa anotasi belum tersedia. Perbarui firmware kamera, lalu scan lagi.');
      return;
    }
    _cropBytes = bytes;
    _historyPhotoBytes = crop.historyBytes ?? bytes;
    await _identifyThenQuiz(crop.identifyBytes ?? bytes, generation, detectorLabel: detection.label,
        detectorScore: detection.score, frameId: frame.frameId, diagnostics: diagnostics, refineCrop: true);
  }

  /// [refineCrop]: the photo is a padded robot crop, so Gemini's box replaces the detector's crop (0180).
  Future<void> _identifyThenQuiz(Uint8List imageBytes, int generation,
      {String? detectorLabel, double? detectorScore, int? frameId, ScanDiagnostics? diagnostics,
      bool refineCrop = false}) async {
    final result = await AiQuizService.instance.identifyItem(imageBytes, diagnostics: diagnostics);
    diagnostics?.event('identify_result', {'item': result.item, 'material': result.material,
      'category': result.category, 'failure': result.failure, 'stale': generation != _generation});
    if (generation != _generation) return;
    if (result.failure == 'busy') {
      state = state.copyWith(phase: WasteQuizPhase.idle);
      return;
    }
    final item = result.item;
    if (item == null) {
      // Not dismissed, so the cancel came from a chat request taking the slot.
      final reason = result.failure == 'cancelled'
          ? AiQuizService.notReadyMessage
          : result.failure ?? 'Benda di foto belum dikenali.';
      state = state.copyWith(
        phase: WasteQuizPhase.finished,
        notice: reason,
        messages: [...state.messages, ChatMessage(isUser: false, text: reason)],
      );
      return;
    }
    final box = result.box;
    if (refineCrop && box != null) {
      final refined = await compute(cropToBox, (imageBytes, box));
      diagnostics?.event('ai_box', {'box': [box.left, box.top, box.right, box.bottom], 'valid': refined != null});
      if (generation != _generation) return;
      if (refined != null) {
        _cropBytes = refined;
        _historyPhotoBytes = refined;
        state = state.copyWith(cropBytes: refined);
      }
    }
    _quizFor(result, item, generation, detectorLabel: detectorLabel, detectorScore: detectorScore,
        frameId: frameId, diagnostics: diagnostics);
  }

  /// From an identified item to the hazard card, the mismatch card or the first question.
  void _quizFor(PhotoIdentification result, String item, int generation,
      {String? detectorLabel, double? detectorScore, int? frameId, ScanDiagnostics? diagnostics}) {
    final detectorHazard = detectorLabel != null &&
        ScannedWaste.fromLabel(detectorLabel).category?.id == 'hazardous';
    // 0180 (owner, 3 Nov): an AI answer with an explicit non-B3 bin and no hazard words in its item
    // clears the detector's E_Waste (a cardboard box printed with a camera was locked as E_Waste).
    final aiClearsHazard = detectorHazard &&
        const {'organik', 'anorganik', 'residu'}.contains(result.category?.toLowerCase().trim()) &&
        ScannedWaste.fromLabel(item, categoryHint: result.category).category?.id != 'hazardous';
    if (aiClearsHazard) {
      TesterLog.instance.log('scan', 'detector $detectorLabel cleared by AI "$item" (${result.category})');
    }
    final scan = ScannedWaste.fromLabel(item, material: result.material, categoryHint: result.category,
        hazardousEvidence: detectorHazard && !aiClearsHazard, detectorLabel: detectorLabel);
    diagnostics?.event('resolved', {'item': scan.displayName, 'category': scan.category?.id,
      'detectorHazard': detectorHazard, 'aiClearedHazard': aiClearsHazard, 'hazard': scan.category?.id == 'hazardous'});
    state = state.copyWith(scan: scan);
    _scanClock = Stopwatch()..start();
    if (scan.category?.id == 'hazardous') {
      state = state.copyWith(phase: WasteQuizPhase.confirmingHazard);
      return;
    }
    // Hazard wins above; any other detector/AI disagreement waits for the user.
    if (!aiClearsHazard && detectorLabel != null && ScannedWaste.categoryMismatch(detectorLabel, result.category)) {
      final detectorChoice = ScannedWaste.fromLabel(item, material: result.material,
          categoryHint: ScannedWaste.detectorCategory(detectorLabel), detectorLabel: detectorLabel);
      _detectorChoice = detectorChoice;
      diagnostics?.event('category_mismatch', {'hardExample': true, 'frameId': frameId,
        'detectorLabel': detectorLabel, 'detectorScore': detectorScore,
        'gemmaItem': result.item, 'gemmaCategory': result.category,
        'resolvedBin': scan.category?.id, 'detectorBin': detectorChoice.category?.id,
        'identifyJpeg': '${diagnostics.id}-identify.jpg'});
      state = state.copyWith(phase: WasteQuizPhase.confirmingMismatch, mismatchDetector: detectorLabel);
      return;
    }
    _loadQuestion(0);
  }

  /// The user says the named object is wrong and picks the right one: the quiz
  /// restarts for it (hazard rules apply to the new item), the photo stays
  /// the History photo.
  void correctItem(String label, {String? category}) {
    if (!state.canCorrectItem) return;
    TesterLog.instance.log('scan', 'item corrected "${state.scan!.displayName}" -> "$label"');
    _diagnostics?.event('item_corrected', {'from': state.scan!.displayName, 'to': label});
    _generation++;
    _detectorChoice = null;
    AiQuizService.instance.cancel();
    unawaited(QuizTtsService.instance.stop());
    _startSession(ScannedWaste.fromLabel(label, categoryHint: category));
  }

  void confirmHazard() {
    if (state.phase != WasteQuizPhase.confirmingHazard) return;
    _diagnostics?.event('hazard_continue');
    _loadQuestion(0);
  }

  /// The user picks the bin after a detector/AI mismatch; only then the quiz runs.
  void resolveMismatch({required bool useDetector}) {
    final detectorChoice = _detectorChoice;
    if (state.phase != WasteQuizPhase.confirmingMismatch || detectorChoice == null) return;
    final scan = useDetector ? detectorChoice : state.scan!;
    _diagnostics?.event('mismatch_choice', {'choice': useDetector ? 'detector' : 'gemma',
      'resolvedBin': scan.category?.id});
    state = state.copyWith(scan: scan);
    _loadQuestion(0);
  }

  /// Starts a quiz for a known label without any camera (test mode).
  /// [photo] is a captured shot kept for Scan History when the model can't name it.
  void startForLabel(String label, {Uint8List? photo}) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastLabel = label;
    _lastShownAt = DateTime.now();
    _cropBytes = photo;
    _historyPhotoBytes = photo; // the retained phone shot is also the History photo (D1 + A1)
    _recordedQuestions.clear();
    AiQuizService.instance.cancel();
    _startSession(ScannedWaste.fromLabel(label));
  }

  void _startSession(ScannedWaste scan) {
    _savedExplanationRecordId = null;
    _askedQuestions.clear();
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    if (scan.category?.id == 'hazardous') {
      state = _freshSession(scan: scan, phase: WasteQuizPhase.confirmingHazard);
      return;
    }
    loadingSince = DateTime.now();
    state = _freshSession(scan: scan, phase: WasteQuizPhase.loadingQuestion);
    _loadQuestion(0);
  }

  /// Loads question 1 only (the only question allowed to make the student
  /// wait, owner's M2b part 3 decision). Later questions go through
  /// [_consumeQuestion], served from the background prefetch started below.
  Future<void> _loadQuestion(int index) async {
    // The question is changing: any voice still reading out the previous
    // question's verdict/chat/essay-grading reply must not play over it.
    unawaited(QuizTtsService.instance.stop());
    final generation = ++_generation;
    final scan = state.scan!;
    final type = questionTypeFor(index, essays: essayQuestions);
    final total = state.totalQuestions;
    loadingSince = DateTime.now();
    state = state.copyWith(
      phase: WasteQuizPhase.loadingQuestion,
      questionIndex: index,
      clearSelection: true,
      essaySubmitted: false,
      sendingChat: false,
    );

    final diagnostics = _diagnostics;
    diagnostics?.event('question_request', {'requestId': '${diagnostics.id}/question-${index + 1}'});
    final sw = kDebugMode ? (Stopwatch()..start()) : null;
    final loadClock = Stopwatch()..start();
    var generated = _ai
        ? await AiQuizService.instance.generateQuestion(
            waste: scan,
            type: type,
            difficulty: state.difficulty,
            avoid: List.of(_askedQuestions),
            usedAngles: List.of(_usedAngles),
          )
        : await _fromBank(scan, type);
    // AI mode with no AI answer (offline, every model capped): the rest of the
    // session comes from the bank, said out loud, not silently (decision 0179).
    String? bankNotice;
    if (generated == null && _ai && generation == _generation) {
      _sessionSource = QuestionSource.bank;
      generated = await _fromBank(scan, type);
      if (generated != null) bankNotice = _bankNotice;
    }
    if (generated?.angle != null) _usedAngles.add(generated!.angle!);
    diagnostics?.event('question_complete', {'question': index + 1, 'generationMs': sw?.elapsedMilliseconds,
      'replyMs': AiQuizService.instance.lastReplyMs.value, 'model': AiQuizService.instance.lastModel,
      'fallback': generated == null, 'stale': generation != _generation, 'bankId': generated?.bankId});
    if (sw != null) {
      // One line per question load, so a slow session (decision 0009) shows
      // exactly which question was slow and whether it fell back.
      debugPrint('[WasteQuiz] ${scan.displayName}: question ${index + 1}/$total '
          '(${type.name}) in ${sw.elapsedMilliseconds}ms, reply '
          '${AiQuizService.instance.lastReplyMs.value ?? '-'}ms, '
          'fallback=${generated == null}');
    }
    if (generation != _generation) return; // dismissed or superseded

    final question = generated ?? _fallbackQuestion(scan, type);
    if (question == null) {
      unawaited(_finish());
      return;
    }
    _askedQuestions.add(question.question);
    final intro = bankNotice ??
        (generated == null
            ? _fallbackIntro()
            : type == QuizQuestionType.multipleChoice
                ? 'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.'
                : 'Tulis jawabanmu lalu kirim. Setelah dikoreksi, kamu bisa bertanya lebih lanjut.');
    state = state.copyWith(
      phase: WasteQuizPhase.active,
      question: question,
      isFallback: generated == null,
      questionSource: _sessionSource,
      messages: [...state.messages, ChatMessage(isUser: false, text: intro)],
    );
    _announceReady();
    diagnostics?.event('question_shown', {'question': index + 1, 'totalLockToQuestionMs': diagnostics.clock.elapsedMilliseconds});
    _logQuestion(index, scan, generated, loadClock.elapsedMilliseconds);
    if (index == 0 && _ai) _startPrefetch();
  }

  /// The next bank question of [type] not yet asked this session: the object's
  /// own, then its pool's; null when the bank has nothing left (decision 0017).
  Future<GeneratedQuestion?> _fromBank(ScannedWaste scan, QuizQuestionType type) async {
    final bank = await QuestionBank.load();
    if (_bankQueues == null) _logClassMismatch(bank, scan);
    final queue = (_bankQueues ??= {})[type] ??= bank.questionsFor(scan, type);
    while (queue.isNotEmpty) {
      final q = queue.removeAt(0);
      if (!_askedQuestions.contains(q.question)) return q;
    }
    return null;
  }

  /// Same bin, different class (decision 0025): logged once per session, no card.
  void _logClassMismatch(QuestionBank bank, ScannedWaste scan) {
    final gemmaPool = bank.classMismatch(scan);
    if (gemmaPool == null) return;
    final fields = <String, Object?>{
      'detectorLabel': scan.detectorLabel,
      'gemmaItem': scan.displayName,
      'gemmaMaterial': scan.material,
      'gemmaPool': gemmaPool,
      'chosenPool': bank.selection(scan).pool,
    };
    debugPrint('[WasteQuiz] class_mismatch ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    _diagnostics?.event('class_mismatch', fields);
  }

  String _fallbackIntro() => _ai
      ? 'Ini soal cadangan karena AI belum bisa membuat soal. ${_aiUnavailableReason()}'
      : 'Ini soal umum karena benda ini belum ada di bank soal.';

  static const _bankNotice = 'AI tidak tersambung, jadi soal ini dari bank soal. Periksa internet.';

  /// Starts filling questions 2..N in the background through the single
  /// AI slot, one at a time, the instant question 1 shows.
  void _startPrefetch() {
    final total = state.totalQuestions;
    if (total <= 1) return;
    final scan = state.scan!;
    final gen = _prefetchSessionGen;
    for (var i = 1; i < total; i++) {
      _prefetchCompleters[i] = Completer<GeneratedQuestion?>();
    }
    unawaited(_runPrefetch(scan, total, gen));
  }

  Future<void> _runPrefetch(ScannedWaste scan, int total, int gen) async {
    for (var i = 1; i < total; i++) {
      if (gen != _prefetchSessionGen) return; // closed or superseded
      final q = await _generateForBuffer(scan, i, gen);
      if (gen != _prefetchSessionGen) return;
      if (q != null) _askedQuestions.add(q.question); // so index i+1 avoids it too
      if (q?.angle != null) _usedAngles.add(q!.angle!); // and gets another angle
      _prefetchCompleters[i]?.complete(q);
    }
  }

  /// Keeps retrying while the slot is only busy or cancelled by a
  /// higher-priority request (a chat message or essay grading, decision
  /// 0003) -- never surfacing that as a failure -- and stops once this
  /// session is closed or superseded.
  Future<GeneratedQuestion?> _generateForBuffer(ScannedWaste scan, int index, int gen) async {
    final type = questionTypeFor(index, essays: essayQuestions);
    final diagnostics = _diagnostics;
    var attempt = 0;
    while (gen == _prefetchSessionGen) {
      final timing = kDebugMode ? (Stopwatch()..start()) : null;
      final requestId = '${diagnostics?.id}/question-${index + 1}/attempt-${++attempt}';
      diagnostics?.event('prefetch_request', {'requestId': requestId});
      final result = await AiQuizService.instance.generateQuestionBackground(
        waste: scan,
        type: type,
        difficulty: state.difficulty,
        avoid: List.of(_askedQuestions),
        usedAngles: List.of(_usedAngles),
      );
      diagnostics?.event('prefetch_complete', {'requestId': requestId,
        'generationMs': timing?.elapsedMilliseconds, 'retry': result.retry,
        'fallback': !result.retry && result.question == null,
        'stale': gen != _prefetchSessionGen});
      if (!result.retry) return result.question; // success, or a real failure
      await Future<void>.delayed(_prefetchRetryDelay);
    }
    return null;
  }

  /// Closing the quiz (or starting a new one) cancels any in-flight or
  /// still-queued prefetch and clears the buffer.
  void _cancelPrefetch() {
    _prefetchSessionGen++;
    for (final c in _prefetchCompleters.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _prefetchCompleters.clear();
  }

  /// Shows question [index] (>=1): instant if already prefetched, otherwise
  /// waits for the one background generation already in flight for it --
  /// never starts a second, redundant generation for the same index.
  Future<void> _consumeQuestion(int index) async {
    // Same reason as _loadQuestion: "Soal berikutnya" or skip must cut off
    // whatever voice was still reading the previous question's reply.
    unawaited(QuizTtsService.instance.stop());
    final generation = ++_generation;
    final scan = state.scan!;
    final type = questionTypeFor(index, essays: essayQuestions);
    final total = state.totalQuestions;
    loadingSince = DateTime.now();
    state = state.copyWith(
      phase: WasteQuizPhase.loadingQuestion,
      questionIndex: index,
      clearSelection: true,
      essaySubmitted: false,
      sendingChat: false,
    );

    final sw = Stopwatch()..start();
    var generated = _ai ? await _prefetchCompleters[index]?.future : await _fromBank(scan, type);
    String? bankNotice;
    if (generated == null && _ai && generation == _generation) {
      generated = await _fromBank(scan, type); // the prefetch got no AI answer: offline fallback
      if (generated != null) bankNotice = _bankNotice;
    }
    final waitedMs = sw.elapsedMilliseconds;
    _lastNextWaitMs = waitedMs;
    if (kDebugMode) {
      debugPrint('[WasteQuiz] ${scan.displayName}: question ${index + 1}/$total '
          '(${type.name}) waited ${waitedMs}ms, reply '
          '${AiQuizService.instance.lastReplyMs.value ?? '-'}ms, '
          'fallback=${generated == null}');
    }
    if (generation != _generation) return; // dismissed or superseded while waiting

    final question = generated ?? _fallbackQuestion(scan, type);
    if (question == null) {
      unawaited(_finish());
      return;
    }
    _askedQuestions.add(question.question);
    final intro = bankNotice ?? (generated == null
        ? _fallbackIntro()
        : type == QuizQuestionType.multipleChoice
            ? 'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.'
            : 'Tulis jawabanmu lalu kirim. Setelah dikoreksi, kamu bisa bertanya lebih lanjut.');
    state = state.copyWith(
      phase: WasteQuizPhase.active,
      question: question,
      isFallback: generated == null,
      messages: [...state.messages, ChatMessage(isUser: false, text: intro)],
    );
    _announceReady();
    _logQuestion(index, scan, generated, waitedMs);
  }

  /// One line per question shown, in both modes, so robot runs can be compared
  /// (decision 0018). No question text.
  void _logQuestion(int index, ScannedWaste scan, GeneratedQuestion? generated, int loadMs) {
    final chosen = QuestionBank.loaded?.selection(scan);
    final fields = <String, Object?>{
      'question': index + 1,
      'source': _sessionSource.name,
      'item': scan.displayName,
      'detector': scan.detectorLabel ?? '-',
      'object': _ai ? '-' : chosen?.object ?? '-',
      'pool': _ai ? 'ai' : chosen?.pool ?? '-',
      'angle': generated?.angle ?? '-',
      'fromScanMs': _scanClock?.elapsedMilliseconds,
      'loadMs': loadMs,
      'fallback': generated == null ? 'yes' : 'no',
    };
    debugPrint('[WasteQuiz] question_source ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    _diagnostics?.event('question_source', fields);
  }

  /// The first fixed fallback of [type] not yet shown this session, so a
  /// session never repeats a question (decision 0011 leftover, 0017).
  // ponytail: three MC and two essay variants; an object with no bank entry
  // and no pool ends its session after those instead of repeating one.
  GeneratedQuestion? _fallbackQuestion(ScannedWaste scan, QuizQuestionType type) {
    for (final q in fallbackQuestions(scan, type)) {
      if (!_askedQuestions.contains(q.question)) return q;
    }
    return null; // all used: the session ends early rather than repeat one
  }

  @visibleForTesting
  static List<GeneratedQuestion> fallbackQuestions(ScannedWaste scan, QuizQuestionType type) {
    final name = scan.displayName.toLowerCase();
    if (type == QuizQuestionType.essay) {
      return [
        GeneratedQuestion(
          type: type,
          question: 'Analisis bagaimana $name sebaiknya dikelola setelah dibuang, '
              'dan jelaskan dampak lingkungannya jika salah dikelola.',
        ),
        GeneratedQuestion(
          type: type,
          question: 'Jelaskan bagaimana prinsip 3R (reduce, reuse, recycle) dapat diterapkan pada $name, '
              'mulai dari yang paling diutamakan.',
          explanation: 'Reduce lebih utama daripada reuse, dan reuse lebih utama daripada recycle.',
        ),
      ];
    }
    final bins = ['Sampah organik', 'Daur ulang (anorganik)', 'Limbah B3', 'Sampah residu'];
    final correct = switch (scan.category?.id) {
      'organic' => 0,
      'inorganic' => 1,
      'hazardous' => 2,
      _ => 3,
    };
    return [
      GeneratedQuestion(
        type: type,
        question: 'Ke aliran pengelolaan mana $name seharusnya masuk?',
        options: bins,
        correctIndex: correct,
        explanation: 'Jawaban yang tepat: ${bins[correct]}.',
      ),
      GeneratedQuestion(
        type: type,
        question: 'Pemilahan sampah di sumber yang baik memakai berapa kelompok?',
        options: const ['Dua: organik dan non-organik', 'Empat: organik, plastik, kertas, dan logam',
          'Tiga: organik, non-organik, dan B3', 'Satu: semua dicampur lalu dipilah di TPA'],
        correctIndex: 2,
        explanation: 'Modul (1.6) memakai tiga kelompok: organik, non-organik, dan B3.',
      ),
      GeneratedQuestion(
        type: type,
        question: 'Dalam prinsip 3R, tindakan mana yang paling diutamakan?',
        options: const ['Recycle (mendaur ulang)', 'Reduce (mengurangi)', 'Menimbun di TPA',
          'Reuse (memakai kembali)'],
        correctIndex: 1,
        explanation: 'Modul (4.1): reduce lebih utama daripada reuse, dan reuse lebih utama daripada recycle.',
      ),
    ];
  }

  void selectOption(int index) {
    final q = state.question;
    if (state.phase != WasteQuizPhase.active || q == null) return;
    if (q.type != QuizQuestionType.multipleChoice || state.selectedOption != null) return;
    final correct = index == q.correctIndex;
    _recordedQuestions.add(RecordQuestion(
      question: q.question,
      options: q.options,
      bankExplanation: q.bankId == null || !q.bankReviewed ? '' : q.explanation,
      wrongWhy: q.bankReviewed ? q.wrongWhy : const {},
      explanation: QuizExplanationService.bankExplanation(q, selectedIndex: index),
      yourAnswer: q.options[index],
      rightAnswer: q.options[q.correctIndex],
      isCorrect: correct,
      trophies: correct ? 10 : 0,
      isEssay: false,
    ));
    state = state.copyWith(
      selectedOption: index,
      mcAnswered: state.mcAnswered + 1,
      correctCount: state.correctCount + (correct ? 1 : 0),
      recordedQuestions: List.unmodifiable(_recordedQuestions),
      phase: WasteQuizPhase.explaining,
      explanationLoading: true,
      clearExplanation: true,
    );
    final verdict = correct
        ? 'Benar!'
        : 'Kurang tepat. Jawaban yang benar: ${q.options[q.correctIndex]}.';
    _appendAiReply(q.explanation.isEmpty || (q.bankId != null && !q.bankReviewed)
        ? verdict : '$verdict ${q.explanation}');
    unawaited(loadExplanation());
  }

  Future<void> submitEssay(String answerText, {int? score}) async {
    final trimmed = answerText.trim();
    final q = state.question;
    if (trimmed.isEmpty || state.sendingChat || q == null || q.type != QuizQuestionType.essay) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(
      essaySubmitted: true,
      essayAnswer: trimmed,
      sendingChat: true,
      messages: [...state.messages, ChatMessage(isUser: true, text: trimmed, caption: 'Jawaban Essay')],
    );
    final reply = score == null
        ? await AiQuizService.instance.reviewEssay(
            question: q.question,
            expectedPoints: q.explanation,
            answer: trimmed,
          )
        : null;
    if (generation != _generation) return;

    final grade = score == null
        ? EssayGrade.parse(reply)
        : (score >= 0 && score <= 10 ? EssayGrade(score: score) : null);
    final essayScore = grade?.score;
    final isCorrect = (essayScore ?? 0) >= 6;
    _recordedQuestions.add(RecordQuestion(
      question: q.question,
      yourAnswer: trimmed,
      rightAnswer: q.explanation,
      isCorrect: isCorrect,
      trophies: essayScore ?? 0,
      isEssay: true,
      essayScore: essayScore,
    ));
    state = state.copyWith(
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      recordedQuestions: List.unmodifiable(_recordedQuestions),
      phase: WasteQuizPhase.explaining,
      explanationLoading: true,
      clearExplanation: true,
    );
    _appendAiReply(grade == null
        ? 'Jawaban tersimpan, tapi AI belum bisa mengoreksi. ${_aiUnavailableReason()}'
        : [
            if (grade.feedback.isNotEmpty) grade.feedback,
            if (grade.improvement.isNotEmpty) 'Untuk nilai penuh: ${grade.improvement}',
            if (grade.feedback.isEmpty && grade.improvement.isEmpty) 'Skor: ${grade.score}/10.',
          ].join(' '));
    unawaited(loadExplanation(essayGrade: grade));
  }

  /// Chat is for discussing an answered question; before answering, the
  /// assistant asks the student to answer first (no hints or spoilers).
  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sendingChat) return;
    final history = [for (final m in state.messages) (isUser: m.isUser, text: m.text)];
    state = state.copyWith(messages: [...state.messages, ChatMessage(isUser: true, text: trimmed)]);

    final q = state.question;
    if (state.phase == WasteQuizPhase.active && q != null && !state.answered) {
      _appendAiReply(q.type == QuizQuestionType.multipleChoice
          ? 'Jawab soalnya dulu, ya. Setelah kamu memilih jawaban, aku akan menjelaskan '
              'dan menjawab pertanyaanmu tentang soal ini.'
          : 'Kirim jawaban essay-mu dulu, ya. Setelah itu aku koreksi dan kita bisa membahasnya.');
      return;
    }
    if (q == null) {
      _appendAiReply('Scan sampah dulu untuk memulai kuis, lalu kita bisa berdiskusi.');
      return;
    }

    final generation = _generation;
    state = state.copyWith(sendingChat: true);
    final reply = await AiQuizService.instance.discuss(
      quizContext: _quizContext(q),
      history: history,
      message: trimmed,
    );
    if (generation != _generation) return;
    _appendAiReply(reply ?? 'AI belum bisa menjawab. ${_aiUnavailableReason()}');
  }

  String _quizContext(GeneratedQuestion q) {
    final scan = state.scan?.displayName ?? '';
    if (q.type == QuizQuestionType.essay) {
      return 'Konteks kuis tentang "$scan".\n'
          'Soal essay: ${q.question}\n'
          '${q.explanation.isEmpty ? '' : 'Poin jawaban yang diharapkan: ${q.explanation}\n'}'
          'Jawaban mahasiswa: ${state.essayAnswer ?? '(dilewati)'}';
    }
    const letters = ['A', 'B', 'C', 'D'];
    final options = [for (var i = 0; i < q.options.length; i++) '${letters[i]}. ${q.options[i]}'].join('; ');
    final selected = state.selectedOption;
    final chosen = selected == null ? '(dilewati)' : q.options[selected];
    return 'Konteks kuis tentang "$scan".\n'
        'Soal: ${q.question}\n'
        'Pilihan: $options\n'
        'Jawaban benar: ${q.options[q.correctIndex]}\n'
        'Jawaban mahasiswa: $chosen${selected == null ? '' : (selected == q.correctIndex ? ' (benar)' : ' (salah)')}\n'
        '${q.explanation.isEmpty ? '' : 'Penjelasan kunci: ${q.explanation}'}';
  }

  /// Short, specific reason shown when the AI couldn't answer.
  String _aiUnavailableReason() => AiQuizService.instance.status.value == AiStatus.offline
      ? 'Periksa koneksi internet, lalu coba lagi.'
      : 'Coba lagi.';

  /// Only allowed when Config Settings → Quiz → Skip Allowed is on.
  void skipQuestion() {
    final q = state.question;
    if (state.phase != WasteQuizPhase.active || state.answered || q == null) return;
    if (!ref.read(appPreferencesProvider).skipAllowed) return;
    final isEssay = q.type == QuizQuestionType.essay;
    _recordedQuestions.add(RecordQuestion(
      question: q.question,
      yourAnswer: '(dilewati)',
      rightAnswer: isEssay
          ? (q.explanation.isNotEmpty ? q.explanation : '-')
          : (q.options.isNotEmpty ? q.options[q.correctIndex] : '-'),
      isCorrect: false,
      trophies: 0,
      isEssay: isEssay,
      essayScore: isEssay ? 0 : null,
    ));
    state = state.copyWith(
      skippedCount: state.skippedCount + 1,
      messages: [...state.messages, ChatMessage(isUser: false, text: 'Soal ${state.questionIndex + 1} dilewati.')],
      recordedQuestions: List.unmodifiable(_recordedQuestions),
    );
    _advance();
  }

  void nextQuestion() {
    if (state.phase != WasteQuizPhase.explaining) return;
    _advance();
  }

  /// Loads/generates the explanation for the most-recently-answered question.
  /// Sets [explanationLoading] while running; updates [currentExplanation] on completion.
  /// Saves the explanation into the last [RecordQuestion] in [_recordedQuestions].
  String? _savedExplanationRecordId;

  Future<void> loadExplanation({EssayGrade? essayGrade}) async {
    final q = state.question;
    final scan = state.scan;
    if (q == null || scan == null) {
      state = state.copyWith(explanationLoading: false);
      return;
    }
    final generation = _generation;
    final answeredIndex = _recordedQuestions.length - 1;
    final saved = answeredIndex >= 0 ? _recordedQuestions[answeredIndex].explanation : null;
    if (saved != null && (saved.isComplete || saved.generatedAt != null)) {
      state = state.copyWith(currentExplanation: saved, explanationLoading: false);
      return;
    }
    final explanation = await QuizExplanationService.generate(
      question: q,
      scan: scan,
      selectedIndex: state.selectedOption,
      essayGrade: essayGrade,
      difficulty: state.difficulty.name,
      onlyWhenIdle: true,
    );
    if (generation != _generation) return; // session changed while generating
    // Attach to the answered question even if the student has advanced.
    if (answeredIndex >= 0 && answeredIndex < _recordedQuestions.length) {
      final answered = _recordedQuestions[answeredIndex];
      _recordedQuestions[answeredIndex] = answered.copyWith(explanation: explanation);
    }
    final savedId = _savedExplanationRecordId;
    if (savedId != null && answeredIndex >= 0) {
      try {
        await ScanRecordStore.instance.saveExplanation(savedId, answeredIndex, explanation);
      } catch (e) {
        debugPrint('[WasteQuiz] Explanation could not be saved: $e');
      }
    }
    if (state.question != q) return;
    state = state.copyWith(
      currentExplanation: explanation,
      explanationLoading: false,
      recordedQuestions: List.unmodifiable(_recordedQuestions),
    );
  }

  void _advance() {
    if (state.isLastQuestion) {
      unawaited(_finish());
      return;
    }
    _consumeQuestion(state.questionIndex + 1);
  }

  Future<void> _finish() async {
    final sessionTrophies = _recordedQuestions.fold<int>(0, (sum, q) => sum + q.trophies);

    String? photoPath;
    final photoBytes = _historyPhotoBytes ?? _cropBytes;
    // ponytail: legacy/device crops lack a paired clean frame; keep their bytes until recaptured.
    if (photoBytes != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${dir.path}/$scanPhotosDirName');
        if (!scansDir.existsSync()) scansDir.createSync(recursive: true);
        final file = File('${scansDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
        file.writeAsBytesSync(photoBytes, flush: true);
        photoPath = file.path;
      } catch (e) {
        debugPrint('[WasteQuiz] Failed to save crop photo: $e');
      }
    }

    if (_recordedQuestions.isNotEmpty) {
      final scan = state.scan;
      final record = ScanRecord(
        id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        itemName: scan?.displayName ?? 'Sampah',
        category: ScanCategory.fromString(scan?.category?.id),
        cropPhotoPath: photoPath,
        difficulty: state.difficulty,
        questions: List.unmodifiable(_recordedQuestions),
        trophies: sessionTrophies,
      );
      try {
        _savedExplanationRecordId = record.id;
        await ScanRecordStore.instance.addRecord(record);
      } catch (e) {
        debugPrint('[WasteQuiz] Failed to add record to store: $e');
      }
    }

    _diagnostics?.event('session_result', {
      'correct': state.correctCount,
      'total': state.totalQuestions,
      'trophies': sessionTrophies,
    });
    debugPrint('[WasteQuiz] session_result correct=${state.correctCount} total=${state.totalQuestions} trophies=$sessionTrophies');

    state = state.copyWith(
      phase: WasteQuizPhase.finished,
      recordedQuestions: List.unmodifiable(_recordedQuestions),
      cropBytes: _cropBytes,
      historyPhotoPath: photoPath,
    );
    final skipped = state.skippedCount > 0 ? ' ${state.skippedCount} soal dilewati.' : '';
    _appendAiReply('Sesi selesai! Jawaban benar: '
        '${state.correctCount} dari ${state.totalQuestions}.$skipped Scan sampah lain untuk soal baru.');
  }

  void logRescanTapped() {
    _diagnostics?.event('rescan_tapped', {});
    debugPrint('[WasteQuiz] rescan_tapped');
  }

  void _appendAiReply(String text) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(isUser: false, text: text)],
      sendingChat: false,
    );
    if (state.voiceOn && text != _lastAutoSpokenText) {
      _lastAutoSpokenText = text;
      unawaited(QuizTtsService.instance.speak(text));
    }
  }

  /// When the current wait (identify or question) started; the loading popup's timer.
  DateTime? loadingSince;

  /// A question arrived while the quiz was minimised: the Quiz button shows its badge,
  /// and with Voice on TTS says so (decision 0175).
  void _announceReady() {
    if (state.minimized && state.voiceOn) unawaited(QuizTtsService.instance.speak('Question ready'));
  }

  void listen(String text) => unawaited(QuizTtsService.instance.speak(text));

  void toggleVoice() => state = state.copyWith(voiceOn: !state.voiceOn);

  void minimize() => state = state.copyWith(minimized: true);

  void restore() => state = state.copyWith(minimized: false);

  void dismiss() {
    if (state.phase == WasteQuizPhase.confirmingMismatch) {
      _diagnostics?.event('mismatch_choice', {'choice': 'rescan', 'resolvedBin': null});
    }
    _detectorChoice = null;
    _diagnostics?.event('dismiss', {'phase': state.phase.name});
    _diagnostics = null;
    _generation++;
    _cancelPrefetch();
    AiQuizService.instance.cancel();
    unawaited(QuizTtsService.instance.stop());
    _cropBytes = null;
    _historyPhotoBytes = null;
    _recordedQuestions.clear();
    state = WasteQuizUiState(voiceOn: state.voiceOn);
  }
}

final wasteQuizProvider = NotifierProvider<WasteQuizNotifier, WasteQuizUiState>(
  WasteQuizNotifier.new,
);

/// Debug-only indicator of which camera feeds the popup quiz.
final debugQuizSourceProvider = StateProvider<WasteQuizSource>(
  (ref) => WasteQuizSource.maixCam2,
);

/// A LOCK answer (0181): the AI's item, the photo cut to its box (else the whole frame), and the
/// box as fractions (0..1) of the frame.
class LockedItem {
  const LockedItem(this.result, this.photo, this.box);
  final PhotoIdentification result;
  final Uint8List photo;
  final Rect? box;
}
