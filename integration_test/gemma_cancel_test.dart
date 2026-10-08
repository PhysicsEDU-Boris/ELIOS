// Real (no mock) cancel and slot-rule tests for the single Gemma slot:
// M0.3, M0.4 (cancel) and M0.5 (BUSY, user request cancels a scan).
// Run on a dev machine:
//   flutter test integration_test/gemma_cancel_test.dart -d macos
//
// Evidence comes from the service's own line
//   [GemmaQuizService] generated N chars (first token: Xms, total: Yms)
// which the response stream's onDone prints even after a cancel. With the
// LiteRT-LM FFI engine, stopGeneration() makes native report CANCELLED and the
// stream closes, so that line marks the moment native stopped sampling.
import 'dart:async';
import 'dart:convert';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/phone_jpeg.dart';

final _clock = Stopwatch()..start();
final _closed = <_Closed>[];
final _serviceLines = <({int at, String text})>[];
final _closedLine =
    RegExp(r'\[GemmaQuizService\] generated (\d+) chars \(first token: (\d+)ms, total: (\d+)ms\)');

/// One response stream that closed, timed on [_clock].
class _Closed {
  _Closed(this.at, this.chars, this.firstTokenMs, this.totalMs);
  final int at, chars, firstTokenMs, totalMs;
  int get startedAt => at - totalMs;
  // The service prints 0 for "no token at all".
  int? get firstTokenAt => chars == 0 ? null : startedAt + firstTokenMs;
}

/// Timestamps every stream-closed line, then prints as usual. Returns the
/// restore callback (testWidgets fails if debugPrint is left overridden).
VoidCallback _captureLogs() {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.startsWith('[GemmaQuizService]')) {
      _serviceLines.add((at: _clock.elapsedMilliseconds, text: message));
    }
    final m = message == null ? null : _closedLine.firstMatch(message);
    if (m != null) {
      _closed.add(_Closed(_clock.elapsedMilliseconds, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
    }
    original(message, wrapWidth: wrapWidth);
  };
  return () => debugPrint = original;
}

/// Waits until [count] streams have closed since index [from], oldest start first.
Future<List<_Closed>> _waitClosed(int from, int count, {Duration timeout = const Duration(seconds: 30)}) async {
  final deadline = _clock.elapsedMilliseconds + timeout.inMilliseconds;
  while (_closed.length < from + count) {
    if (_clock.elapsedMilliseconds > deadline) {
      throw TimeoutException('only ${_closed.length - from} of $count streams closed', timeout);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return _closed.sublist(from, from + count)..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}

bool _isPhone(String? item) =>
    item != null && ['ponsel', 'hp', 'handphone', 'telepon', 'smartphone', 'phone', 'gawai'].any(item.toLowerCase().contains);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]));

  testWidgets('M0.3: cancel identify after the first token, tokens stop, slot is free, next identify is right',
      (tester) async {
    final restore = _captureLogs();
    final service = GemmaQuizService.instance;
    try {
      final photo = base64Decode(phoneJpegBase64);
      expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');

      // Control: the first identify after load is ~0.8s slower (cold), so time
      // the cancel from a second, warm one. Identify streams for only ~0.6s
      // after its first token; 250ms in lands mid-stream.
      final c0 = _closed.length;
      await service.identifyItem(photo);
      final control = await service.identifyItem(photo);
      final full = (await _waitClosed(c0, 2)).last;
      expect(_isPhone(control.item), isTrue, reason: 'control identify: ${control.item} / ${control.failure}');

      final c1 = _closed.length;
      final pending = service.identifyItem(photo);
      await Future<void>.delayed(Duration(milliseconds: full.firstTokenMs + 250));
      final cancelAt = _clock.elapsedMilliseconds;
      service.cancel();
      final cancelled = await pending;
      final releasedAt = _clock.elapsedMilliseconds;

      // Slot must be free right away: a new scan request is not rejected as busy.
      final next = await service.identifyItem(photo);
      final closed = await _waitClosed(c1, 2);
      final cut = closed[0], after = closed[1];

      debugPrint('[cancel-test] M0.3 control: ${full.chars} chars, first token ${full.firstTokenMs}ms, '
          'total ${full.totalMs}ms');
      debugPrint('[cancel-test] M0.3 cancelled: ${cut.chars} chars, first token at '
          '${cut.firstTokenAt == null ? 'none' : '${cut.firstTokenAt! - cancelAt}ms vs cancel'}, '
          'stream closed ${cut.at - cancelAt}ms after cancel, caller released ${releasedAt - cancelAt}ms after cancel');
      debugPrint('[cancel-test] M0.3 next identify: item=${next.item} failure=${next.failure}, '
          'first token ${after.firstTokenMs}ms, started ${after.startedAt - releasedAt}ms after release');

      expect(cut.firstTokenAt, isNotNull, reason: 'inconclusive: no token before cancel, re-run');
      expect(cut.firstTokenAt! < cancelAt, isTrue, reason: 'inconclusive: cancel landed before the first token, re-run');
      expect(cut.at, greaterThan(cancelAt), reason: 'inconclusive: identify had already finished before cancel, re-run');
      expect(cancelled.item, isNull, reason: 'a cancelled identify must not return an item');
      expect(cut.chars, lessThan(full.chars), reason: 'tokens did not stop: cancelled stream reached full length');
      // An identify only streams ~0.6s after its first token, so a cancel that
      // did nothing would still end ~300ms later; 150ms tells the two apart
      // (observed 6-25ms when the cancel works).
      expect(cut.at - cancelAt, lessThanOrEqualTo(150), reason: 'stream still open 150ms after cancel');
      expect(next.failure, isNot('busy'), reason: 'slot still busy after cancel');
      expect(_isPhone(next.item), isTrue, reason: 'next identify: ${next.item} / ${next.failure}');
    } finally {
      restore();
      await service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('M0.4: stopGeneration on a long generation, time until the engine is idle', (tester) async {
    final restore = _captureLogs();
    final service = GemmaQuizService.instance;
    try {
      expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
      final kardus = ScannedWaste.fromLabel('kardus', material: 'kertas karton');
      Future<GeneratedQuestion?> ask() => service.generateQuestion(
            waste: kardus,
            type: QuizQuestionType.multipleChoice,
            difficulty: QuizDifficulty.hard,
          );

      // Control: one full, uncancelled generation, for its timing and length
      // only (first attempt, in case it retries). Whether it parses is a
      // content question, not a cancel one, so it is not asserted; that the
      // first attempt produced real text is: either it parsed (a question
      // can't be empty) or the service logged its trimmed text as unparseable.
      const rejectedPrefix = 'unparseable question (attempt 1): ';
      final c0 = _closed.length;
      final l0 = _serviceLines.length;
      final parsed = await ask();
      final full = (await _waitClosed(c0, 1)).first;
      final rejected = _serviceLines.skip(l0).map((l) => l.text).where((t) => t.contains(rejectedPrefix));
      final firstText = rejected.isNotEmpty ? rejected.first.split(rejectedPrefix).last : parsed?.question ?? '';
      expect(firstText.trim(), isNotEmpty, reason: 'control generation produced no text (empty or whitespace only)');
      debugPrint('[cancel-test] M0.4 control: ${full.chars} chars, first token ${full.firstTokenMs}ms, '
          'total ${full.totalMs}ms');

      // probeParsed is a content check (Gemma sometimes returns 5 options,
      // which _parse rejects); the engine-free check is that the probe streamed.
      final rows = <({_Closed cut, _Closed probe, int cancelAt, int probeCalledAt, bool probeParsed})>[];
      for (var trial = 1; trial <= 3; trial++) {
        final c = _closed.length;
        final pending = ask();
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final cancelAt = _clock.elapsedMilliseconds;
        service.cancel();
        expect(await pending, isNull, reason: 'trial $trial: a cancelled question must return null');

        // Probe: the next request, sent at once, shows when the engine is free again.
        final probeCalledAt = _clock.elapsedMilliseconds;
        final probeParsed = await ask() != null;
        final closed = await _waitClosed(c, 2);
        final row =
            (cut: closed[0], probe: closed[1], cancelAt: cancelAt, probeCalledAt: probeCalledAt, probeParsed: probeParsed);
        rows.add(row);
        debugPrint('[cancel-test] M0.4 trial $trial: cancelled at ${cancelAt - row.cut.startedAt}ms into generation, '
            '${row.cut.chars}/${full.chars} chars, stream closed ${row.cut.at - cancelAt}ms after cancel; '
            'probe started ${row.probe.startedAt - probeCalledAt}ms after it was sent, '
            'first token ${row.probe.firstTokenMs}ms (control ${full.firstTokenMs}ms), '
            'cancel to probe first token ${row.probe.startedAt + row.probe.firstTokenMs - cancelAt}ms, '
            'probe ${row.probe.chars} chars, question parsed=$probeParsed');
      }

      for (final (i, r) in rows.indexed) {
        expect(r.cut.chars, lessThan(full.chars), reason: 'trial ${i + 1}: cancelled stream reached full length');
        expect(r.cut.at - r.cancelAt, lessThanOrEqualTo(1000), reason: 'trial ${i + 1}: stream still open 1s after cancel');
        expect(r.probe.chars, greaterThan(0), reason: 'trial ${i + 1}: request after cancel produced no text');
      }
    } finally {
      restore();
      await service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('M0.5a: a scan request while busy gets BUSY at once and is not queued', (tester) async {
    final restore = _captureLogs();
    final service = GemmaQuizService.instance;
    try {
      final photo = base64Decode(phoneJpegBase64);
      expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
      final kardus = ScannedWaste.fromLabel('kardus', material: 'kertas karton');

      final c0 = _closed.length;
      final running = service.identifyItem(photo);
      await Future<void>.delayed(const Duration(milliseconds: 1500)); // mid-request

      // Both scan entry points, while the first identify is still generating.
      var t = _clock.elapsedMilliseconds;
      final busyIdentify = await service.identifyItem(photo);
      final identifyRejectMs = _clock.elapsedMilliseconds - t;
      t = _clock.elapsedMilliseconds;
      final busyQuestion = await service.generateQuestion(
        waste: kardus,
        type: QuizQuestionType.multipleChoice,
        difficulty: QuizDifficulty.hard,
      );
      final questionRejectMs = _clock.elapsedMilliseconds - t;

      final first = await running;
      // Not queued: give a queued request time to start, then count generations.
      await Future<void>.delayed(const Duration(seconds: 3));
      final generations = _closed.length - c0;

      debugPrint('[cancel-test] M0.5a busy identify: failure=${busyIdentify.failure} in ${identifyRejectMs}ms; '
          'busy question: ${busyQuestion == null ? 'null' : 'a question'} in ${questionRejectMs}ms; '
          'running identify: item=${first.item}; generations since start: $generations (1 means nothing was queued)');

      expect(busyIdentify.failure, 'busy');
      expect(identifyRejectMs, lessThan(100), reason: 'BUSY must come back at once, not after waiting');
      expect(busyQuestion, isNull);
      expect(questionRejectMs, lessThan(100), reason: 'BUSY must come back at once, not after waiting');
      expect(_isPhone(first.item), isTrue, reason: 'the running identify was disturbed: ${first.item} / ${first.failure}');
      expect(generations, 1, reason: 'a rejected scan request was queued and ran later');
    } finally {
      restore();
      await service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('M0.5b: a user request (discuss) cancels a running scan request', (tester) async {
    final restore = _captureLogs();
    final service = GemmaQuizService.instance;
    try {
      expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
      final kardus = ScannedWaste.fromLabel('kardus', material: 'kertas karton');

      final c0 = _closed.length;
      final l0 = _serviceLines.length;
      final scan = service.generateQuestion(
        waste: kardus,
        type: QuizQuestionType.multipleChoice,
        difficulty: QuizDifficulty.hard,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1500)); // scan is mid-generation

      final userAt = _clock.elapsedMilliseconds;
      final reply = service.discuss(
        quizContext: 'Konteks kuis tentang "kardus".\nSoal: Ke mana kardus bekas sebaiknya dibuang?',
        history: const [],
        message: 'Kenapa kardus bisa didaur ulang?',
      );
      final scanResult = await scan;
      final scanReturnedMs = _clock.elapsedMilliseconds - userAt;
      final replyText = await reply;

      final closed = await _waitClosed(c0, 2);
      final cut = closed[0], answer = closed[1];
      final yielded = _serviceLines
          .skip(l0)
          .where((l) => l.text.contains('canceling active scan request to yield to user request'))
          .toList();

      debugPrint('[cancel-test] M0.5b scan returned ${scanResult == null ? 'null' : 'a question'} '
          '${scanReturnedMs}ms after the user request; yield log lines: ${yielded.length}; '
          'scan stream closed ${cut.at - userAt}ms after the user request with ${cut.chars} chars; '
          'discuss started ${answer.startedAt - userAt}ms after the user request, first token '
          '${answer.startedAt + answer.firstTokenMs - userAt}ms after it; reply ${replyText?.length ?? 0} chars');

      expect(yielded, hasLength(1), reason: 'the service did not take the yield-to-user path');
      expect(scanResult, isNull, reason: 'the cancelled scan must not return a question');
      expect(scanReturnedMs, lessThan(100), reason: 'the scan caller must be released at once');
      expect(cut.chars, greaterThan(0), reason: 'the scan had not started generating; inconclusive, re-run');
      expect(cut.at - userAt, lessThanOrEqualTo(1000), reason: 'scan stream still open 1s after the user request');
      expect(replyText, isNotNull, reason: 'discuss returned no reply');
      expect(replyText!.trim(), isNotEmpty);
      expect(replyText.contains('{'), isFalse, reason: 'discuss reply leaked JSON');
    } finally {
      restore();
      await service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
