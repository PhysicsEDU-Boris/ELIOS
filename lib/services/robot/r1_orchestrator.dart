/// R1: the sorting orchestration for a manually driven robot (decisions 0021,
/// 0023). Pure logic, platform independent: inputs are method calls, time
/// comes from the injected clock and [tick], output goes to the
/// [RobotController] and to the screen fields ([state], [message], ...).
library;

import '../detection_stabilizer.dart';
import '../websocket_service.dart' show ArmTag, Detection;
import 'r1_constants.dart';
import 'robot_controller.dart';
import 'package:elio/l10n/l10n.dart';

enum R1State {
  searching,
  objectInView,
  identifying,
  confirm,
  askBin,
  reveal,
  position,
  ready,
  sorting,
  waitBoth,
  resume,
}

class _Pending {
  _Pending(this.cmd, this.motion, this.deadline);
  final String cmd;
  final bool motion;
  DateTime deadline;
  bool acked = false;
}

class R1Orchestrator {
  R1Orchestrator(this.robot, {DateTime Function()? clock, this.onResume, this.onEvent, this.identity = const ObjectIdentity()})
      : _clock = clock ?? monotonicClock() {
    robot.onReply = _onReply;
  }

  final RobotController robot;
  final DateTime Function() _clock;
  final ObjectIdentity identity;

  /// A session ended (reason `done`, `link_lost`, `pick_failed`, `robot_error`,
  /// `timeout_<what>`): the host closes the quiz so the live scan re-arms per 0020.
  final void Function(String reason)? onResume;

  /// Diagnostics: `r1_state` {state}, `r1_abort` {reason, from}.
  final void Function(String event, Map<String, Object?> data)? onEvent;

  final feedback = ArmFeedback();

  R1State _state = R1State.searching;
  R1State get state => _state;

  bool? _connected; // null while the STATUS probe is out
  bool _linkUp = false;
  bool _unlockOnReconnect = false;

  /// The MaixCAM2 answered the STATUS probe. False: "robot tidak terhubung",
  /// R1 takes no lock and the live scan works as without R1.
  bool get robotConnected => _connected == true;

  /// What the screen tells the student ("Berhenti", "Maju sedikit", ...).
  String? message;

  /// The bin the robot uses (detector, the AI, hazard veto) and the student's guess.
  Bin? robotBin;
  Bin? studentBin;

  /// POSITION without a distance: show "Posisi sudah pas".
  bool get showPositionButton => _state == R1State.position && _manualPosition;
  bool get canAmbil => _state == R1State.ready;

  /// The camera's AprilTag search is on only around a grip (owner, 4 Nov; 0182): from POSITION
  /// until the arm is done. Elsewhere it would cost ~40 ms a detection frame for nothing.
  bool get wantsArmTags => const {R1State.position, R1State.ready, R1State.sorting, R1State.waitBoth}.contains(_state);

  DateTime? _settleUntil;

  /// Camera lock and re-arm events are ignored now: the arm moves the camera (J1).
  bool get ignoresLiveScanLocks =>
      _state == R1State.sorting || _state == R1State.waitBoth || _settling;

  bool get _settling => _settleUntil != null && _clock().isBefore(_settleUntil!);

  // Session.
  TrackedDetection? _target;
  double? _distCm, _lateralCm;
  DateTime? _since, _positionStart, _sortStart;
  (Bin, bool)? _bufferedIdentify;
  bool _manualPosition = false, _relocking = false;
  final _pending = <int, _Pending>{};
  int _armStep = 0;
  int? _armSeq;
  bool _armDone = false;
  TrackedDetection? _spot;
  DateTime? _verifyUntil, _spotClearSince, _handSeenAt;
  DateTime? _lookUntil, _rightTagSince, _wrongTagSince;
  bool _handPaused = false, _binLookRetried = false;
  int _questionsDone = 0;
  DateTime? _questionSlotStart;

  bool get _questionsComplete => _questionsDone >= objectQuestionCount;
  bool get _armActive => (_state == R1State.sorting || _state == R1State.waitBoth) && !_armDone;

  // ── Link ──────────────────────────────────────────────────────────────────

  /// The WebSocket to the MaixCAM2 connected (also after a reconnect): probe the command link.
  void linkUp() {
    _linkUp = true;
    if (_unlockOnReconnect) {
      _unlockOnReconnect = false;
      robot.driveLocked = false;
      robot.unlockDrive();
    }
    _connected = null;
    _await(robot.status(), 'STATUS');
  }

  /// The link dropped: nothing can be sent. The session ends; driving is
  /// unlocked in the app now and on the MaixCAM2 at the reconnect (0023: the
  /// firmware also stops the arm and unlocks driving when its client is gone).
  void linkDown() {
    _linkUp = false;
    _pending.clear();
    _connected = false;
    if (_state != R1State.searching) {
      _end('link_lost', l10n.r1LinkLost, stop: false);
    } else {
      message = l10n.r1NotConnected;
    }
  }

  /// The emergency stop (decision 0026): the safe exit now (STOP if the arm
  /// may move), but driving stays locked, in the app and on the MaixCAM2,
  /// until [resumeAfterStop] ("Lanjutkan").
  void emergencyStop(String reason) {
    if (_state != R1State.searching) {
      _end('emergency_stop', l10n.r1Stopped(reason),
          stop: _armActive, keepLocked: true);
    }
    robot.driveLocked = true;
    _unlockOnReconnect = false; // only "Lanjutkan" unlocks, not a reconnect
  }

  /// "Lanjutkan" after an emergency stop: driving is unlocked again.
  void resumeAfterStop() {
    robot.driveLocked = false;
    if (_linkUp) {
      robot.unlockDrive();
    } else {
      _unlockOnReconnect = true;
    }
  }

  // ── Inputs from the live scan and the quiz ───────────────────────────────

  /// A camera lock (stabilizer + 0020). True when R1 takes it.
  bool onLock(TrackedDetection d) {
    if (!robotConnected || _state != R1State.searching || ignoresLiveScanLocks) return false;
    _target = d;
    feedback.objectLeftFloor = null; // kept after the last session's end, for diagnostics
    robot.driveLocked = true;
    _await(robot.lockDrive(), 'LOCK_DRIVE');
    message = l10n.r1Stop;
    _enter(R1State.objectInView);
    return true;
  }

  /// Identification finished: the robot's bin, and whether a person must
  /// confirm it (B3, or detector and the AI disagree).
  void onIdentified(Bin bin, {bool needsConfirm = false}) {
    if (_state == R1State.objectInView) {
      _bufferedIdentify = (bin, needsConfirm);
    } else if (_state == R1State.identifying) {
      _identified(bin, needsConfirm);
    }
  }

  /// The confirmation card resolved the bin (the hazard veto decides, not the student).
  void onConfirmed(Bin bin) {
    if (_state != R1State.confirm) return;
    robotBin = bin;
    _askBin();
  }

  /// The student's guess. It never changes [robotBin].
  void onStudentBin(Bin bin) {
    if (_state != R1State.askBin) return;
    studentBin = bin;
    _reveal();
  }

  /// "Posisi sudah pas" (POSITION without dist_cm).
  void onPositionConfirmed() {
    if (_state != R1State.position || !_manualPosition || _relocking) return;
    _ready();
  }

  /// "Ambil".
  void onAmbil() {
    if (_state != R1State.ready) return;
    _enter(R1State.sorting);
    _sortStart = _clock();
    _spot = _target;
    _questionSlotStart = _sortStart;
    message = l10n.r1Picking;
    if (_handInView) {
      _pause();
    } else {
      _runArmStep();
    }
  }

  void onQuestionShown() {
    if (_questionsRunning) _questionSlotStart = _clock();
  }

  void onQuestionAnswered() {
    if (_questionsRunning) _completeQuestion();
  }

  /// Requests HOME pose (decision 0027). Ignored while sorting or waiting for quiz/drop,
  /// paused if a hand is in view.
  bool home() {
    if (_state == R1State.sorting || _state == R1State.waitBoth) return false;
    if (_handInView) {
      _pause();
      return false;
    }
    robot.home();
    return true;
  }

  bool get _questionsRunning =>
      (_state == R1State.sorting || _state == R1State.waitBoth) && !_questionsComplete;

  /// One analysed frame (every frame, also while nothing happens).
  void onFrame(List<Detection> detections, {List<ArmTag>? armTags}) {
    final now = _clock();
    feedback.tags = armTags;
    if (detections.any((d) => d.label == 'Human_Hand' && d.score >= handScore)) _handSeenAt = now;

    final target = _target;
    if (target != null && _state.index <= R1State.ready.index) {
      final match = identity.find(target, detections);
      if (match != null) {
        _target = ObjectIdentity.box(match);
        _distCm = match.distCm;
        _lateralCm = match.lateralCm;
      }
    }

    if (_armActive) {
      if (_handInView && !_handPaused) {
        _pause();
      } else if (_armStep == 1 && !_handPaused) {
        final spot = _spot!;
        final onSpot = detections.any((d) => d.label != 'Human_Hand' && identity.onFloorSpot(d, spot));
        if (onSpot) {
          _spotClearSince = null;
        } else if (now.difference(_spotClearSince ??= now) >= objectGoneFor) {
          feedback.objectLeftFloor = true;
          _armStep = 2;
          _runArmStep();
        }
      } else if (_armStep == 3 && !_handPaused) {
        _lookForBinTag(armTags ?? const [], now);
      }
    }
    if (_state == R1State.position) _evaluatePosition();
    tick();
  }

  /// Boxes for the live scan: while the arm moves and settles, boxes over the
  /// arm/gripper region are dropped (a hand never is: it must stay visible).
  List<Detection> filterForLiveScan(List<Detection> detections, double imgW, double imgH) {
    if (!ignoresLiveScanLocks) return detections;
    final (l, t, r, b) = armRegion;
    bool overArm(Detection d) =>
        d.x - d.w / 2 < r * imgW && d.x + d.w / 2 > l * imgW && d.y - d.h / 2 < b * imgH && d.y + d.h / 2 > t * imgH;
    return [for (final d in detections) if (d.label == 'Human_Hand' || !overArm(d)) d];
  }

  // ── Time ──────────────────────────────────────────────────────────────────

  /// Call regularly (and after each frame): timeouts and timed steps.
  void tick() {
    final now = _clock();
    for (final e in _pending.entries.toList()) {
      if (!_pending.containsKey(e.key) || now.isBefore(e.value.deadline)) continue; // gone: an abort cleared it
      _pending.remove(e.key);
      _failed(e.value.cmd, e.key, 'timeout');
    }
    final since = _since;
    if (since == null) return;
    final inState = now.difference(since);
    switch (_state) {
      case R1State.identifying when inState >= identifyTimeout:
        _abort('timeout_identify', l10n.r1NotIdentified);
      case R1State.confirm when inState >= confirmTimeout:
        _abort('timeout_confirm', l10n.r1NoConfirm);
      case R1State.askBin when inState >= binTimeout:
        _reveal(); // no answer: reveal anyway
      case R1State.reveal when inState >= revealDuration:
        _enterPosition();
      case R1State.position || R1State.ready when now.difference(_positionStart!) >= positionTimeout:
        _abort('timeout_position', l10n.r1Timeout);
      case R1State.sorting || R1State.waitBoth:
        if (now.difference(_sortStart!) >= waitCap) {
          _abort('timeout_wait_cap', l10n.r1TooLong);
          return;
        }
        if (_handPaused && !_handInView) {
          _handPaused = false;
          message = l10n.r1Resuming;
          _runArmStep(); // the interrupted step again, from its start
        }
        if (_armActive && _armStep == 1 && !_handPaused && !now.isBefore(_verifyUntil!)) {
          feedback.objectLeftFloor = false;
          _abort('pick_failed', l10n.r1PickFailed);
          return;
        }
        if (_armActive && _armStep == 3 && !_handPaused && !now.isBefore(_lookUntil!)) {
          _binLookFailed('bin_tag_not_seen');
          return;
        }
        if (_questionsRunning && now.difference(_questionSlotStart!) >= questionTimeout) _completeQuestion();
        if (_state == R1State.waitBoth && _armDone && _questionsComplete && !_settling) {
          _end('done', l10n.r1Done, stop: false);
        }
      default:
        break;
    }
  }

  bool get handInView => _handInView;
  bool get handPaused => _handPaused;
  bool get _handInView => _handSeenAt != null && _clock().difference(_handSeenAt!) < handClearFor;

  // ── Steps ─────────────────────────────────────────────────────────────────

  void _identified(Bin bin, bool needsConfirm) {
    robotBin = bin;
    if (needsConfirm) {
      message = l10n.r1ConfirmFirst;
      _enter(R1State.confirm);
    } else {
      _askBin();
    }
  }

  void _askBin() {
    message = l10n.r1WhichBin;
    _enter(R1State.askBin);
  }

  void _reveal() {
    message = l10n.r1RobotChose(robotBin!.wire);
    _enter(R1State.reveal);
  }

  void _enterPosition() {
    _positionStart = _clock();
    _enter(R1State.position);
    _evaluatePosition();
  }

  /// dist_cm inside PICK_BAND_CM: re-lock driving, READY. Outside: unlock for
  /// nudges and say which way. No dist_cm (current firmware): the manual button.
  void _evaluatePosition() {
    if (_relocking) return;
    final d = _distCm;
    _manualPosition = d == null;
    if (d == null) {
      message = l10n.r1PositionOk;
      return;
    }
    if (d >= pickBandMinCm && d <= pickBandMaxCm) {
      _ready();
      return;
    }
    message = d > pickBandMaxCm ? l10n.r1Forward : l10n.r1Back;
    if (robot.driveLocked) {
      robot
        ..driveLocked = false
        ..nudgeOnly = true;
      _await(robot.unlockDrive(), 'UNLOCK_DRIVE');
    }
  }

  void _ready() {
    if (!robot.driveLocked) {
      robot
        ..driveLocked = true
        ..nudgeOnly = false;
      _relocking = true;
      message = l10n.r1Stop;
      _await(robot.lockDrive(), 'LOCK_DRIVE');
      return;
    }
    message = l10n.r1PressPick;
    _enter(R1State.ready);
  }

  /// Arm steps: 0 PICK, 1 check the floor spot, 2 MOVE_TO_BIN (to the bin's state point),
  /// 3 look for the bin's AprilTag (0233), 4 DROP.
  void _runArmStep() {
    assert(_state == R1State.sorting || _state == R1State.waitBoth, 'the arm never moves before REVEAL');
    final now = _clock();
    switch (_armStep) {
      case 0:
        _armSeq = robot.pick(distCm: _distCm, lateralCm: _lateralCm);
        _await(_armSeq!, 'PICK', motion: true);
      case 1:
        _verifyUntil = now.add(pickVerifyTimeout);
        _spotClearSince = null;
      case 2:
        _armSeq = robot.moveToBin(robotBin!);
        _await(_armSeq!, 'MOVE_TO_BIN', motion: true);
      case 3:
        // At the state point the arm holds still (no command) while the camera looks.
        _lookUntil = now.add(binLookTimeout);
        _rightTagSince = _wrongTagSince = null;
        message = _binLookRetried ? l10n.r1BinLookAgain : l10n.r1BinChecking;
      case 4:
        _armSeq = robot.drop();
        _await(_armSeq!, 'DROP', motion: true);
    }
  }

  /// The right bin's tag for [binTagSeenFor]: DROP. Another bin's tag for as long: a failed look.
  void _lookForBinTag(List<ArmTag> tags, DateTime now) {
    final right = robotBin!.tagId;
    final others = {for (final b in Bin.values) if (b != robotBin) b.tagId};
    if (tags.any((t) => t.id == right)) {
      _wrongTagSince = null;
      if (now.difference(_rightTagSince ??= now) >= binTagSeenFor) {
        onEvent?.call('r1_bin_check', {'result': 'ok', 'bin': robotBin!.wire, 'retried': _binLookRetried});
        message = l10n.r1BinOk;
        _armStep = 4;
        _runArmStep();
      }
      return;
    }
    _rightTagSince = null;
    if (!tags.any((t) => others.contains(t.id))) {
      _wrongTagSince = null;
    } else if (now.difference(_wrongTagSince ??= now) >= binTagSeenFor) {
      _binLookFailed('wrong_bin_tag');
    }
  }

  /// First failure: look once more. Second: end without DROP; the host sends the arm HOME.
  void _binLookFailed(String why) {
    onEvent?.call('r1_bin_check', {'result': why, 'bin': robotBin!.wire, 'retried': _binLookRetried});
    if (!_binLookRetried) {
      _binLookRetried = true;
      _runArmStep();
      return;
    }
    _end('bin_check_failed', l10n.r1BinCheckFailed, stop: false);
  }

  void _pause() {
    _handPaused = true;
    final seq = _armSeq;
    if (seq != null) _pending.remove(seq); // re-sent after the hand is gone
    _armSeq = null;
    robot.hold();
    message = l10n.r1Hand;
  }

  void _armFinished() {
    _armDone = true;
    _armSeq = null;
    _settleUntil = _clock().add(armSettle);
    if (_state == R1State.sorting) _enter(R1State.waitBoth);
  }

  void _completeQuestion() {
    _questionsDone++;
    _questionSlotStart = _clock();
    if (_questionsComplete && _state == R1State.sorting) _enter(R1State.waitBoth);
  }

  // ── Commands and replies ──────────────────────────────────────────────────

  void _await(int seq, String cmd, {bool motion = false}) {
    if (!_linkUp) return;
    _pending[seq] = _Pending(cmd, motion, _clock().add(ackTimeout));
  }

  void _onReply(RobotReply reply) {
    final p = _pending[reply.seq];
    if (p == null) return; // late, unknown, or for an abandoned command
    switch (reply.kind) {
      case ReplyKind.error:
        _pending.remove(reply.seq);
        _failed(p.cmd, reply.seq, reply.reason ?? 'error');
      case ReplyKind.ack:
        if (p.motion) {
          p
            ..acked = true
            ..deadline = _clock().add(armTimeout);
        } else {
          _pending.remove(reply.seq);
          _acked(p.cmd);
        }
      case ReplyKind.motionDone:
        _pending.remove(reply.seq);
        feedback.motionDoneSeq = reply.seq;
        if (reply.seq == _armSeq) {
          _armStep++;
          if (_armStep == 5) {
            _armFinished();
          } else {
            _runArmStep();
          }
        }
    }
  }

  void _acked(String cmd) {
    switch (cmd) {
      case 'STATUS':
        _connected = true;
        if (_state == R1State.searching) message = null;
      case 'LOCK_DRIVE' when _state == R1State.objectInView:
        message = l10n.r1Stop;
        _enter(R1State.identifying);
        final buffered = _bufferedIdentify;
        if (buffered != null) _identified(buffered.$1, buffered.$2);
      case 'LOCK_DRIVE' when _relocking:
        _relocking = false;
        _ready();
    }
  }

  void _failed(String cmd, int seq, String reason) {
    if (cmd == 'STATUS') {
      _connected = false;
      message = l10n.r1NotConnected;
      return;
    }
    if (_state == R1State.searching) return;
    if (reason == 'timeout' && (cmd == 'LOCK_DRIVE' || cmd == 'UNLOCK_DRIVE')) _connected = false;
    _abort(cmd == 'LOCK_DRIVE' || cmd == 'UNLOCK_DRIVE' ? 'robot_unreachable' : 'robot_error',
        l10n.r1NoReply(cmd, reason));
  }

  // ── Exits ─────────────────────────────────────────────────────────────────

  void _abort(String reason, String text) => _end(reason, text, stop: _armActive);

  /// Every exit: stop the arm if it may move, unlock driving (app now,
  /// MaixCAM2 now or at the reconnect), tell the student, back to SEARCHING.
  void _end(String reason, String text, {required bool stop, bool keepLocked = false}) {
    final from = _state;
    if (reason != 'done') onEvent?.call('r1_abort', {'reason': reason, 'from': from.name});
    _pending.clear();
    if (stop) {
      if (_linkUp) robot.stop();
      _settleUntil = _clock().add(armSettle);
    }
    robot
      ..driveLocked = keepLocked
      ..nudgeOnly = false;
    if (keepLocked) {
      // emergency stop: [resumeAfterStop] unlocks
    } else if (_linkUp) {
      robot.unlockDrive();
    } else {
      _unlockOnReconnect = true;
    }
    message = text;
    _enter(R1State.resume);
    onResume?.call(reason);
    _target = _spot = null;
    _distCm = _lateralCm = null;
    _bufferedIdentify = null;
    _manualPosition = _relocking = _armDone = _handPaused = _binLookRetried = false;
    _armStep = _questionsDone = 0;
    _armSeq = null;
    robotBin = studentBin = null;
    _enter(R1State.searching);
    _since = null;
  }

  void _enter(R1State s) {
    _state = s;
    _since = _clock();
    onEvent?.call('r1_state', {'state': s.name});
  }
}
