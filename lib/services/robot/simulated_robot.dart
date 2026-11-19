/// A simulated MaixCAM2 + arm + wheels for R1 tests (decision 0023): fake
/// ack / motion_done timing, a fake dist_cm that drives with the wheels,
/// dropped replies, failures and old firmware. Time comes from [clock];
/// replies are delivered by [tick].
library;

import '../websocket_service.dart' show Detection;
import 'robot_controller.dart';

class SimulatedRobot extends RobotController {
  SimulatedRobot(this.clock) {
    eeMm = const [0.0, -42.5, 90.0];
    atHome = true;
  }

  final DateTime Function() clock;

  /// Old firmware: no command link, so no reply to any command ever.
  bool commandLink = true;

  /// The WiFi link is up; while down, nothing is delivered either way.
  bool linkUp = true;

  Duration ackDelay = const Duration(milliseconds: 100);

  /// Time from ack to motion_done (the firmware knows it from its per-joint speed limits, 0230).
  Map<String, Duration> motionTime = {
    'PICK': const Duration(seconds: 4),
    'MOVE_TO_BIN': const Duration(seconds: 3),
    'DROP': const Duration(seconds: 2),
    'HOME': const Duration(seconds: 2),
    'HOLD': Duration.zero,
  };

  /// Commands whose replies are lost: 'ack' drops everything, 'motion_done' only the latter.
  Map<String, String> dropReplies = {};

  /// Commands answered with an error carrying this reason instead of an ack.
  Map<String, String> failures = {};

  /// The gripper closes on nothing: the object stays on the floor.
  bool pickMisses = false;

  /// Fake world: the locked object's floor distance (null = old firmware / uncalibrated).
  double? objectDistCm = 24;
  bool objectOnFloor = true;
  bool handInView = false;

  /// Each drive message moves the robot this far (forward shortens the distance).
  double cmPerDriveMessage = 1;

  /// MaixCAM2 side of the drive lock (LOCK_DRIVE / UNLOCK_DRIVE).
  bool firmwareDriveLocked = false;

  final sent = <Map<String, Object?>>[];
  final motorSent = <(int, int)>[];
  int motorApplied = 0;
  final _due = <(DateTime, RobotReply)>[];

  /// Names of the commands sent so far, in order.
  List<String> get commands => [for (final m in sent) m['cmd'] as String];

  @override
  void transmit(Map<String, Object?> message) {
    sent.add(message);
    if (!linkUp || !commandLink || message['cmd'] == 'HEARTBEAT') return; // HEARTBEAT: no seq, no reply
    final cmd = message['cmd'] as String;
    final seq = message['seq'] as int;
    final now = clock();
    final failure = failures[cmd];
    if (failure != null) {
      _due.add((now.add(ackDelay), RobotReply(ReplyKind.error, seq, reason: failure)));
      return;
    }
    if (cmd == 'LOCK_DRIVE') firmwareDriveLocked = true;
    if (cmd == 'UNLOCK_DRIVE') firmwareDriveLocked = false;
    if (dropReplies[cmd] == 'ack') return;
    final reply = cmd == 'STATUS'
        ? RobotReply(ReplyKind.ack, seq, eeMm: eeMm, atHome: atHome)
        : RobotReply(ReplyKind.ack, seq);
    _due.add((now.add(ackDelay), reply));
    final motion = motionTime[cmd];
    if (motion == null || dropReplies[cmd] == 'motion_done') return;
    final done = now.add(ackDelay + motion);
    _due.add((done, RobotReply(ReplyKind.motionDone, seq)));
    if (cmd == 'PICK' && !pickMisses) _pickedAt = done;
    if (cmd == 'HOME') {
      atHome = false;
      _homedAt = done;
    }
  }

  DateTime? _pickedAt;
  DateTime? _homedAt;

  @override
  void transmitMotor(int left, int right) {
    motorSent.add((left, right));
    if (!linkUp || firmwareDriveLocked) return; // the MaixCAM2 drops DRIVE while locked
    motorApplied++;
    final d = objectDistCm;
    if (d != null && left == right && left != 0) objectDistCm = d - cmPerDriveMessage * left.sign;
  }

  /// Delivers every reply that is due by now.
  void tick() {
    final now = clock();
    final picked = _pickedAt;
    if (picked != null && !now.isBefore(picked)) {
      objectOnFloor = false;
      _pickedAt = null;
    }
    final homed = _homedAt;
    if (homed != null && !now.isBefore(homed)) {
      atHome = true;
      eeMm = const [0.0, -42.5, 90.0];
      _homedAt = null;
    }
    final ready = [for (final r in _due) if (!r.$1.isAfter(now)) r];
    _due.removeWhere(ready.contains);
    for (final (_, reply) in ready) {
      if (linkUp) onReply?.call(reply);
    }
  }

  /// One analysed frame: the object on its floor spot (centred, at [objectDistCm]), and a hand.
  List<Detection> frame() => [
        if (objectOnFloor)
          Detection(x: 320, y: 300, w: 120, h: 160, label: 'Plastic', score: 0.9, distCm: objectDistCm),
        if (handInView) const Detection(x: 300, y: 200, w: 200, h: 220, label: 'Human_Hand', score: 0.95),
      ];
}
