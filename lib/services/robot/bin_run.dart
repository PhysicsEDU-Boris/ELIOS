/// The arm's part after the bin check on the Control screen (owner, 24 Nov 2026; decision 0240
/// "bin run"). The student picks the item up by hand (AMBIL / the Penjepit slider), locks and
/// scans it, answers the bin check, reads the ✓/✗ ticket with the right bin, and taps Got it.
/// Only then does the arm carry the item to the RIGHT bin (the AI's, whatever the student
/// picked): MOVE_TO_BIN plays the owner's saved sequence to the bin's state point, then DROP
/// plays the release steps (the MaixCAM2 drops only when it sees that bin's AprilTag, 0235).
/// If the gripper is still open on Got it, the run waits until the student closes it. Either way the
/// arm waits [delay] (3 s, owner 25 Nov) before it moves, so it never swings the moment the quiz ends
/// or the gripper closes.
///
/// Pure logic: commands go out through [send]; replies come in through [onReply]. R1 builds keep
/// their own orchestrator (0023) and do not use this.
library;

import 'robot_controller.dart';

enum BinRunState {
  idle,

  /// Got it was tapped with the gripper open: waiting for AMBIL.
  waitGrip,

  /// The [BinRun.delay] before MOVE_TO_BIN.
  countdown,
  moving,

  /// At the bin's state point: a short look so the camera sees the bin's tag before DROP.
  looking,
  dropping,
  done,
  failed,
}

/// What the bin check ticket says about the arm while it shows.
enum BinRunCue { none, needGrip, ready }

class BinRun {
  BinRun({
    required this.moveToBin,
    required this.drop,
    this.onChanged,
    this.lookFor = const Duration(seconds: 1),
    this.delay = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Sends MOVE_TO_BIN / DROP; the seq, or null when the gate refused it (STOPPED, link down).
  final int? Function(Bin bin) moveToBin;
  final int? Function() drop;
  final void Function(BinRunState state)? onChanged;

  /// How long the arm holds at the state point before DROP: the camera needs a fresh tag
  /// (the MaixCAM2's DROP guard wants one from the last 2 s).
  final Duration lookFor;

  /// Wait between the quiz's end (or the gripper closing) and the arm moving.
  final Duration delay;
  DateTime? _moveAt;

  BinRunState _state = BinRunState.idle;
  BinRunState get state => _state;
  Bin? bin;
  int? _seq;
  String? failure;
  DateTime? _lookUntil;
  bool _dropRetried = false;

  /// The arm belongs to the run: manual arm keys and KUNCI wait.
  bool get busy =>
      const {BinRunState.countdown, BinRunState.moving, BinRunState.looking, BinRunState.dropping}.contains(_state);

  /// The item is on its way and not dropped yet ("Scan lagi" waits).
  bool get pending => busy || _state == BinRunState.waitGrip;

  /// The camera should search for AprilTags (the bin's tag before DROP).
  bool get wantsTags => _state == BinRunState.looking || _state == BinRunState.dropping;

  void _set(BinRunState s) {
    _state = s;
    onChanged?.call(s);
  }

  /// Got it on the bin check ticket. [holding]: the gripper is closed (on the item, we trust).
  void start(Bin target, {required bool holding}) {
    if (busy) return;
    bin = target;
    failure = null;
    _dropRetried = false;
    holding ? _countdown() : _set(BinRunState.waitGrip);
  }

  /// The gripper finished closing (an ARM_POSE motion_done with the gripper closed).
  void onGripClosed() {
    if (_state == BinRunState.waitGrip) _countdown();
  }

  void _countdown() {
    if (delay <= Duration.zero) return _move();
    _moveAt = _clock().add(delay);
    _set(BinRunState.countdown);
  }

  void _move() {
    _seq = moveToBin(bin!);
    _seq == null ? _fail('not_sent') : _set(BinRunState.moving);
  }

  void onReply(RobotReply r) {
    if (r.seq != _seq || !busy) return;
    if (r.kind == ReplyKind.error) {
      // The tag was not seen yet: look once more, then give up (the bridge keeps the item).
      if (_state == BinRunState.dropping && r.reason == 'bin_not_confirmed' && !_dropRetried) {
        _dropRetried = true;
        _lookUntil = _clock().add(lookFor);
        _set(BinRunState.looking);
        return;
      }
      _fail(r.reason ?? 'error');
    } else if (r.kind == ReplyKind.motionDone) {
      if (_state == BinRunState.moving) {
        _lookUntil = _clock().add(lookFor);
        _set(BinRunState.looking);
      } else if (_state == BinRunState.dropping) {
        _set(BinRunState.done);
      }
    }
  }

  /// Call often (the Control screen's 250 ms ticker): MOVE_TO_BIN once the countdown is over, DROP
  /// once the look is over.
  void tick() {
    if (_state == BinRunState.countdown && !_clock().isBefore(_moveAt!)) return _move();
    if (_state != BinRunState.looking || _clock().isBefore(_lookUntil!)) return;
    _seq = drop();
    _seq == null ? _fail('not_sent') : _set(BinRunState.dropping);
  }

  /// STOP, link lost or a new scan: the run ends where it is.
  void cancel([String reason = 'cancelled']) {
    if (_state == BinRunState.idle || _state == BinRunState.done || _state == BinRunState.failed) return;
    _fail(reason);
  }

  void _fail(String reason) {
    failure = reason;
    _set(BinRunState.failed);
  }

  /// Back to idle for the next item.
  void reset() {
    _state = BinRunState.idle;
    bin = null;
    _seq = null;
    failure = null;
  }
}
