/// The arm's part after the bin check on the Control screen (owner, 24 Nov 2026; decision 0240
/// "bin run"). The student picks the item up by hand (AMBIL / the Penjepit slider), locks and
/// scans it, answers the bin check, reads the ✓/✗ ticket with the right bin, and taps Got it.
/// Only then does the arm carry the item to the RIGHT bin (the AI's, whatever the student
/// picked): MOVE_TO_BIN plays the owner's saved sequence to the bin's state point, then DROP
/// plays the release steps (the MaixCAM2 drops only when it sees that bin's AprilTag, 0235).
/// If the gripper is still open on Got it, the run waits until the student closes it. Either way the
/// arm waits [delay] (3 s, owner 25 Nov) before it moves, so it never swings the moment the quiz ends
/// or the gripper closes. After DROP the arm goes HOME ([home]), so every run ends at home: the
/// owner's Right-Tank-New sequence ends away from it.
///
/// Errors (0240 lag guard): every command has [replyTimeout]; a missing reply, an error reply or a
/// refused send ends the run as failed, and the Control screen then sends HOLD and HOME.
///
/// Owner, 26 Nov (0243): the run starts on the quiz's Done. A DROP that fails at the bin (refused, the
/// bin tag not seen, or no reply) asks the student instead: check the hand is over the bin, adjust it,
/// press RELEASE; the gripper opens, the arm goes HOME, "Sorting successful". At most [maxHelps] sorts
/// in a row ask; after that a failed DROP ends as failed again, so the student is not asked every time.
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

  /// DROP failed at the bin: the student aligns the hand and presses RELEASE (0243).
  needsRelease,

  /// RELEASE sent: the gripper is opening.
  releasing,

  /// Dropped: the arm goes home.
  homing,
  done,
  failed,
}

/// What the bin check ticket says about the arm while it shows.
/// What the quiz pages say about the arm (0241): it will sort after the quiz, it sorted, it could not.
enum BinRunCue { none, ready, done, failed }

class BinRun {
  BinRun({
    required this.moveToBin,
    required this.drop,
    this.home,
    this.onChanged,
    this.lookFor = const Duration(seconds: 1),
    this.delay = const Duration(seconds: 3),
    this.replyTimeout = const Duration(seconds: 60),
    this.maxHelps = 2,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Sends MOVE_TO_BIN / DROP; the seq, or null when the gate refused it (STOPPED, link down).
  final int? Function(Bin bin) moveToBin;
  final int? Function() drop;

  /// Sends HOME after the drop; null: the run ends at the drop.
  final int? Function()? home;
  final void Function(BinRunState state)? onChanged;

  /// How long the arm holds at the state point before DROP: the camera needs a fresh tag
  /// (the MaixCAM2's DROP guard wants one from the last 2 s).
  final Duration lookFor;

  /// Wait between the quiz's end (or the gripper closing) and the arm moving.
  final Duration delay;
  DateTime? _moveAt;

  /// The longest wait for one command's motion_done: the longest bin sequence is ~25 s, tag centring
  /// adds up to 4 s per tagged step, a late app pauses it up to 5 s (MaixCAM2 SEQ_GRACE_S).
  final Duration replyTimeout;
  DateTime? _replyBy;

  /// Sorts in a row that may ask the student to release by hand (owner: 2).
  final int maxHelps;
  int _helps = 0;

  /// This run was finished by the student's RELEASE.
  bool helped = false;

  BinRunState _state = BinRunState.idle;
  BinRunState get state => _state;
  Bin? bin;
  int? _seq;
  String? failure;
  DateTime? _lookUntil;
  bool _dropRetried = false;

  /// The arm belongs to the run: manual arm keys and KUNCI wait.
  bool get busy =>
      const {BinRunState.countdown, BinRunState.moving, BinRunState.looking, BinRunState.dropping, BinRunState.homing}
          .contains(_state) ||
      _state == BinRunState.releasing;

  /// The item is on its way and not dropped yet ("Scan lagi" waits). While it waits for RELEASE the arm
  /// keys work (not [busy]) so the student can line the hand up with the bin.
  bool get pending => busy || _state == BinRunState.waitGrip || _state == BinRunState.needsRelease;

  /// Time left before the arm moves, while counting down.
  Duration? get countdownLeft => _state == BinRunState.countdown ? _moveAt!.difference(_clock()) : null;

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
    helped = false;
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

  void _move() => _send(moveToBin(bin!), BinRunState.moving);

  void _send(int? seq, BinRunState next) {
    _seq = seq;
    if (seq == null) return _fail('not_sent');
    _replyBy = _clock().add(replyTimeout);
    _set(next);
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
      _failAtBin(r.reason ?? 'error');
    } else if (r.kind == ReplyKind.motionDone) {
      if (_state == BinRunState.moving) {
        _lookUntil = _clock().add(lookFor);
        _set(BinRunState.looking);
      } else if (_state == BinRunState.dropping || _state == BinRunState.releasing) {
        if (_state == BinRunState.dropping) _helps = 0; // sorted by itself: the next failures may ask again
        home == null ? _set(BinRunState.done) : _send(home!(), BinRunState.homing);
      } else if (_state == BinRunState.homing) {
        _set(BinRunState.done);
      }
    }
  }

  /// Call often (the Control screen's 250 ms ticker): MOVE_TO_BIN once the countdown is over, DROP
  /// once the look is over.
  void tick() {
    final now = _clock();
    if (_state == BinRunState.countdown && !now.isBefore(_moveAt!)) return _move();
    if (const {BinRunState.moving, BinRunState.dropping, BinRunState.releasing, BinRunState.homing}.contains(_state) &&
        now.isAfter(_replyBy!)) {
      return _failAtBin('timeout'); // the reply never came (lost, or the robot is stuck)
    }
    if (_state != BinRunState.looking || now.isBefore(_lookUntil!)) return;
    _send(drop(), BinRunState.dropping);
  }

  /// RELEASE pressed: [seq] is the gripper-open ARM_POSE (null: the gate refused it, keep asking).
  void released(int? seq) {
    if (_state != BinRunState.needsRelease || seq == null) return;
    helped = true;
    _send(seq, BinRunState.releasing);
  }

  /// A failed DROP with the item over the bin asks the student, up to [maxHelps] sorts in a row.
  void _failAtBin(String reason) {
    if ((_state == BinRunState.dropping || _state == BinRunState.looking) && _helps < maxHelps) {
      _helps++;
      failure = reason;
      return _set(BinRunState.needsRelease);
    }
    _fail(reason);
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
