import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/scanned_waste.dart';
import '../services/detection_crop.dart';
import '../services/detection_stabilizer.dart';
import '../services/frame_source/frame_source.dart';
import '../services/gemma_quiz_service.dart';
import '../services/question_bank.dart';
import '../services/quiz_tts_service.dart';
import '../services/scan_diagnostics.dart';
import '../services/websocket_service.dart';
import 'app_preferences_provider.dart';

enum WasteQuizPhase { idle, identifying, confirmingHazard, confirmingMismatch, loadingQuestion, active, finished }

/// Where the waste-detection label driving the popup quiz comes from.
/// MaixCAM2 is the real hardware path; phone camera is a debug-only
/// stand-in for testing without the robot.
enum WasteQuizSource { maixCam2, phoneCamera }

/// `--dart-define=GEMMA_QUESTIONS=true`: the question-source switch starts on Gemma
/// (decision 0018); the default source is the reviewed bank (decision 0017).
const gemmaQuestionsEnabled = defaultQuestionSource == QuestionSource.gemma;

/// Essay questions are off by default: sessions are multiple choice only (decision 0017).
const essayQuestionsEnabled = bool.fromEnvironment('ESSAY_QUESTIONS');

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

  /// The detector class Gemma disagreed with (confirmingMismatch only).
  final String? mismatchDetector;

  /// The question source this session uses (decision 0018), for the header.
  final QuestionSource questionSource;

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
  });

  int get totalQuestions => difficulty.questionCount;

  bool get answered => question?.type == QuizQuestionType.multipleChoice
      ? selectedOption != null
      : essaySubmitted;

  bool get isLastQuestion => questionIndex >= totalQuestions - 1;

  WasteQuizUiState copyWith({
    WasteQuizPhase? phase,
    bool? minimized,
    ScannedWaste? scan,
    int? questionIndex,
    GeneratedQuestion? question,
    bool? isFallback,
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
  }) {
    return WasteQuizUiState(
      phase: phase ?? this.phase,
      minimized: minimized ?? this.minimized,
      scan: scan ?? this.scan,
      difficulty: difficulty,
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
      questionSource: questionSource,
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
  ScannedWaste? _detectorChoice; // Gemma's item in the detector's bin, for the mismatch card
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
  bool get _gemma => _sessionSource == QuestionSource.gemma;

  // From the scan result (the object known) to each question shown, for the per-question log.
  Stopwatch? _scanClock;

  // This session's remaining bank questions per type (decision 0017).
  Map<QuizQuestionType, List<GeneratedQuestion>>? _bankQueues;

  // Physics angles Gemma questions already used this session, so none repeats (decision 0019).
  final _usedAngles = <String>[];

  // The text last spoken automatically (decision 0009: "one TTS slot, keyed
  // by object"), so the same quiz text isn't re-spoken if the message that
  // triggered it is appended again or the popup rebuilds. The manual
  // "Listen" button (listen(), below) is unaffected: a user pressing it
  // again should hear it again.
  String? _lastAutoSpokenText;

  // Background prefetch (decision 0011, M2b part 3): questions 2..N are
  // generated through the single Gemma slot as soon as question 1 shows, one
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

  @override
  WasteQuizUiState build() => const WasteQuizUiState();

  /// Difficulty is read from Config Settings → Quiz at the start of each
  /// scan session, so a change applies to the next scan.
  WasteQuizUiState _freshSession({ScannedWaste? scan, required WasteQuizPhase phase}) {
    final difficulty = QuizDifficulty.fromSetting(ref.read(appPreferencesProvider).quizDifficulty);
    _diagnostics = null;
    _lastAutoSpokenText = null; // a new object/quiz: nothing spoken for it yet
    _sessionSource = sourceOverride ?? effectiveQuestionSource(ref.read(appPreferencesProvider).questionSource);
    _scanClock = scan == null ? null : (Stopwatch()..start());
    return WasteQuizUiState(phase: phase, scan: scan, difficulty: difficulty, voiceOn: state.voiceOn,
        questionSource: _sessionSource);
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
    GemmaQuizService.instance.cancel();
    _startSession(ScannedWaste.fromLabel(label));
  }

  /// Device-camera path: first ask Gemma what the object is (on its own,
  /// unbiased), then generate the questions about that object.
  void onPhotoCaptured(Uint8List imageBytes) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastShownAt = DateTime.now();
    _askedQuestions.clear();
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    final generation = ++_generation;
    GemmaQuizService.instance.cancel();
    state = _freshSession(phase: WasteQuizPhase.identifying);
    unawaited(_identifyThenQuiz(imageBytes, generation));
  }

  /// The live lock's box and JPEG belong to the same stream frame.
  void onRobotLocked(CapturedFrame frame, TrackedDetection detection) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastLabel = detection.label;
    _lastShownAt = DateTime.now();
    _askedQuestions.clear();
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    final generation = ++_generation;
    GemmaQuizService.instance.cancel();
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
    await _identifyThenQuiz(bytes, generation, detectorLabel: detection.label,
        detectorScore: detection.score, frameId: frame.frameId, diagnostics: diagnostics);
  }

  Future<void> _identifyThenQuiz(Uint8List imageBytes, int generation,
      {String? detectorLabel, double? detectorScore, int? frameId, ScanDiagnostics? diagnostics}) async {
    final result = await GemmaQuizService.instance.identifyItem(imageBytes, diagnostics: diagnostics);
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
          ? GemmaQuizService.notReadyMessage
          : result.failure ?? 'Benda di foto belum dikenali.';
      state = state.copyWith(
        phase: WasteQuizPhase.finished,
        notice: reason,
        messages: [...state.messages, ChatMessage(isUser: false, text: reason)],
      );
      return;
    }
    final detectorHazard = detectorLabel != null &&
        ScannedWaste.fromLabel(detectorLabel).category?.id == 'hazardous';
    final scan = ScannedWaste.fromLabel(item, material: result.material,
        categoryHint: result.category, hazardousEvidence: detectorHazard);
    diagnostics?.event('resolved', {'item': scan.displayName, 'category': scan.category?.id,
      'detectorHazard': detectorHazard, 'hazard': scan.category?.id == 'hazardous'});
    state = state.copyWith(scan: scan);
    _scanClock = Stopwatch()..start();
    if (scan.category?.id == 'hazardous') {
      state = state.copyWith(phase: WasteQuizPhase.confirmingHazard);
      return;
    }
    // Hazard wins above; any other detector/Gemma disagreement waits for the user.
    if (detectorLabel != null && ScannedWaste.categoryMismatch(detectorLabel, result.category)) {
      final detectorChoice = ScannedWaste.fromLabel(item, material: result.material,
          categoryHint: ScannedWaste.detectorCategory(detectorLabel));
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

  void confirmHazard() {
    if (state.phase != WasteQuizPhase.confirmingHazard) return;
    _diagnostics?.event('hazard_continue');
    _loadQuestion(0);
  }

  /// The user picks the bin after a detector/Gemma mismatch; only then the quiz runs.
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
  void startForLabel(String label) {
    if (state.phase != WasteQuizPhase.idle) return;
    _lastLabel = label;
    _lastShownAt = DateTime.now();
    GemmaQuizService.instance.cancel();
    _startSession(ScannedWaste.fromLabel(label));
  }

  void _startSession(ScannedWaste scan) {
    _askedQuestions.clear();
    _bankQueues = null;
    _usedAngles.clear();
    _cancelPrefetch();
    if (scan.category?.id == 'hazardous') {
      state = _freshSession(scan: scan, phase: WasteQuizPhase.confirmingHazard);
      return;
    }
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
    final generated = _gemma
        ? await GemmaQuizService.instance.generateQuestion(
            waste: scan,
            type: type,
            difficulty: state.difficulty,
            avoid: List.of(_askedQuestions),
            usedAngles: List.of(_usedAngles),
          )
        : await _fromBank(scan, type);
    if (generated?.angle != null) _usedAngles.add(generated!.angle!);
    diagnostics?.event('question_complete', {'question': index + 1, 'generationMs': sw?.elapsedMilliseconds,
      'firstTokenMs': GemmaQuizService.instance.lastFirstTokenMs.value,
      'fallback': generated == null, 'stale': generation != _generation, 'bankId': generated?.bankId});
    if (sw != null) {
      // One line per question load, so a slow session (decision 0009) shows
      // exactly which question was slow and whether it fell back.
      debugPrint('[WasteQuiz] ${scan.displayName}: question ${index + 1}/$total '
          '(${type.name}) in ${sw.elapsedMilliseconds}ms, first token '
          '${GemmaQuizService.instance.lastFirstTokenMs.value ?? '-'}ms, '
          'fallback=${generated == null}');
    }
    if (generation != _generation) return; // dismissed or superseded

    final question = generated ?? _fallbackQuestion(scan, type);
    if (question == null) return _finish();
    _askedQuestions.add(question.question);
    final intro = generated == null
        ? _fallbackIntro()
        : type == QuizQuestionType.multipleChoice
            ? 'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.'
            : 'Tulis jawabanmu lalu kirim. Setelah dikoreksi, kamu bisa bertanya lebih lanjut.';
    state = state.copyWith(
      phase: WasteQuizPhase.active,
      question: question,
      isFallback: generated == null,
      messages: [...state.messages, ChatMessage(isUser: false, text: intro)],
    );
    diagnostics?.event('question_shown', {'question': index + 1, 'totalLockToQuestionMs': diagnostics.clock.elapsedMilliseconds});
    _logQuestion(index, scan, generated, loadClock.elapsedMilliseconds);
    if (index == 0 && _gemma) _startPrefetch();
  }

  /// The next bank question of [type] not yet asked this session: the object's
  /// own, then its pool's; null when the bank has nothing left (decision 0017).
  Future<GeneratedQuestion?> _fromBank(ScannedWaste scan, QuizQuestionType type) async {
    final bank = await QuestionBank.load();
    final queue = (_bankQueues ??= {})[type] ??= bank.questionsFor(scan, type);
    while (queue.isNotEmpty) {
      final q = queue.removeAt(0);
      if (!_askedQuestions.contains(q.question)) return q;
    }
    return null;
  }

  String _fallbackIntro() => _gemma
      ? 'Ini soal cadangan karena AI belum bisa membuat soal. ${_aiUnavailableReason()}'
      : 'Ini soal umum karena benda ini belum ada di bank soal.';

  /// Starts filling questions 2..N in the background through the single
  /// Gemma slot, one at a time, the instant question 1 shows.
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
      final result = await GemmaQuizService.instance.generateQuestionBackground(
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
    state = state.copyWith(
      phase: WasteQuizPhase.loadingQuestion,
      questionIndex: index,
      clearSelection: true,
      essaySubmitted: false,
      sendingChat: false,
    );

    final sw = Stopwatch()..start();
    final generated = _gemma ? await _prefetchCompleters[index]?.future : await _fromBank(scan, type);
    final waitedMs = sw.elapsedMilliseconds;
    _lastNextWaitMs = waitedMs;
    if (kDebugMode) {
      debugPrint('[WasteQuiz] ${scan.displayName}: question ${index + 1}/$total '
          '(${type.name}) waited ${waitedMs}ms, first token '
          '${GemmaQuizService.instance.lastFirstTokenMs.value ?? '-'}ms, '
          'fallback=${generated == null}');
    }
    if (generation != _generation) return; // dismissed or superseded while waiting

    final question = generated ?? _fallbackQuestion(scan, type);
    if (question == null) return _finish();
    _askedQuestions.add(question.question);
    final intro = generated == null
        ? _fallbackIntro()
        : type == QuizQuestionType.multipleChoice
            ? 'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.'
            : 'Tulis jawabanmu lalu kirim. Setelah dikoreksi, kamu bisa bertanya lebih lanjut.';
    state = state.copyWith(
      phase: WasteQuizPhase.active,
      question: question,
      isFallback: generated == null,
      messages: [...state.messages, ChatMessage(isUser: false, text: intro)],
    );
    _logQuestion(index, scan, generated, waitedMs);
  }

  /// One line per question shown, in both modes, so robot runs can be compared
  /// (decision 0018). No question text.
  void _logQuestion(int index, ScannedWaste scan, GeneratedQuestion? generated, int loadMs) {
    final bank = QuestionBank.loaded;
    final fields = <String, Object?>{
      'question': index + 1,
      'source': _sessionSource.name,
      'item': scan.displayName,
      'object': _gemma ? '-' : bank?.matchObject(scan) ?? '-',
      'pool': _gemma ? 'gemma' : bank?.poolFor(scan) ?? '-',
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
    state = state.copyWith(
      selectedOption: index,
      mcAnswered: state.mcAnswered + 1,
      correctCount: state.correctCount + (correct ? 1 : 0),
    );
    final verdict = correct
        ? 'Benar!'
        : 'Kurang tepat. Jawaban yang benar: ${q.options[q.correctIndex]}.';
    _appendAiReply(q.explanation.isEmpty ? verdict : '$verdict ${q.explanation}');
  }

  Future<void> submitEssay(String answerText) async {
    final trimmed = answerText.trim();
    final q = state.question;
    if (trimmed.isEmpty || state.sendingChat || q?.type != QuizQuestionType.essay) return;
    final generation = _generation;
    state = state.copyWith(
      essaySubmitted: true,
      essayAnswer: trimmed,
      sendingChat: true,
      messages: [...state.messages, ChatMessage(isUser: true, text: trimmed, caption: 'Jawaban Essay')],
    );
    final reply = await GemmaQuizService.instance.reviewEssay(
      question: q!.question,
      expectedPoints: q.explanation,
      answer: trimmed,
    );
    if (generation != _generation) return;
    _appendAiReply(reply ?? 'Jawaban tersimpan, tapi AI belum bisa mengoreksi. ${_aiUnavailableReason()}');
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
    final reply = await GemmaQuizService.instance.discuss(
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
  String _aiUnavailableReason() {
    final p = GemmaQuizService.instance.progress.value;
    return switch (p.status) {
      GemmaStatus.error => p.error ?? 'Buka Pengaturan Koneksi untuk menyiapkan ulang AI.',
      GemmaStatus.installing || GemmaStatus.loading => 'AI masih disiapkan, coba lagi sebentar lagi.',
      _ => 'Coba lagi.',
    };
  }

  /// Only allowed when Config Settings → Quiz → Skip Allowed is on.
  void skipQuestion() {
    if (state.phase != WasteQuizPhase.active || state.answered) return;
    if (!ref.read(appPreferencesProvider).skipAllowed) return;
    state = state.copyWith(
      skippedCount: state.skippedCount + 1,
      messages: [...state.messages, ChatMessage(isUser: false, text: 'Soal ${state.questionIndex + 1} dilewati.')],
    );
    _advance();
  }

  void nextQuestion() {
    if (!state.answered) return;
    _advance();
  }

  void _advance() {
    if (state.isLastQuestion) return _finish();
    _consumeQuestion(state.questionIndex + 1);
  }

  void _finish() {
    state = state.copyWith(phase: WasteQuizPhase.finished);
    final skipped = state.skippedCount > 0 ? ' ${state.skippedCount} soal dilewati.' : '';
    _appendAiReply('Sesi selesai! Pilihan ganda benar: '
        '${state.correctCount} dari ${state.mcAnswered}.$skipped Scan sampah lain untuk soal baru.');
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
    GemmaQuizService.instance.cancel();
    unawaited(QuizTtsService.instance.stop());
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
