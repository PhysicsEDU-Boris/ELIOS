/// The app's side of the R1 command link to the MaixCAM2 (decision 0023).
/// Pure Dart: the transport is injected, time comes from the caller.
library;

import '../detection_stabilizer.dart';
import '../websocket_service.dart' show ArmTag, Detection;
import 'r1_constants.dart';

/// The robot's three bins, with their wire names (0023).
enum Bin {
  organik('organik', 3),
  anorganik('anorganik', 2),
  b3('b3', 4);

  const Bin(this.wire, this.tagId);
  final String wire;

  /// The tag36h11 id on this bin (docs/print/apriltags-bins-id2-id3-id4-A4.pdf, 0233).
  final int tagId;

  /// From a waste category id (`organic`, `inorganic`, `hazardous`); null otherwise.
  static Bin? fromCategoryId(String? id) => switch (id) {
        'organic' => organik,
        'inorganic' => anorganik,
        'hazardous' => b3,
        _ => null,
      };
}

enum ReplyKind { ack, motionDone, error }

/// One MaixCAM2 reply to a command (0023).
class RobotReply {
  const RobotReply(
    this.kind,
    this.seq, {
    this.reason,
    this.eeMm,
    this.atHome,
    this.hasEeMm = false,
  });

  final ReplyKind kind;
  final int seq;
  final String? reason;
  final List<double>? eeMm;
  final bool? atHome;
  final bool hasEeMm;

  /// Null when [msg] is not a command reply (frames, pong, old firmware's messages).
  static RobotReply? fromJson(Map<String, dynamic> msg) {
    final seq = msg['seq'];
    if (seq is! int) return null;
    final kind = switch (msg['event']) {
      'ack' => ReplyKind.ack,
      'motion_done' => ReplyKind.motionDone,
      'error' => ReplyKind.error,
      _ => null,
    };
    if (kind == null) return null;
    final reason = msg['reason'];
    final hasEe = msg.containsKey('ee_mm');
    final eeRaw = msg['ee_mm'];
    List<double>? eeMm;
    if (eeRaw is List) {
      final list = <double>[];
      for (final v in eeRaw) {
        if (v is num && v.isFinite) list.add(v.toDouble());
      }
      if (list.length == eeRaw.length) eeMm = list;
    }
    final atHome = msg['at_home'] is bool ? msg['at_home'] as bool : null;
    return RobotReply(
      kind,
      seq,
      reason: reason is String ? reason : null,
      eeMm: eeMm,
      atHome: atHome,
      hasEeMm: hasEe,
    );
  }

  @override
  String toString() => 'RobotReply(${kind.name} #$seq${reason == null ? '' : ' $reason'})';
}

/// Client of the MaixCAM2's command link. Every command gets a sequence number;
/// replies arrive through [onReply]. There is no heartbeat: the MaixCAM2 has none (0021e).
abstract class RobotController {
  int _seq = 0;

  /// Replies to commands, wired by the orchestrator.
  void Function(RobotReply reply)? onReply;

  /// Sends one command message; implementations deliver it.
  void transmit(Map<String, Object?> message);

  /// Sends the existing `motor` drive message (0023: DRIVE).
  void transmitMotor(int left, int right);

  /// The app's half of the drive lock: DRIVE is not even sent while locked.
  bool driveLocked = false;

  /// Driving is unlocked for small nudges only (POSITION): speed is capped.
  bool nudgeOnly = false;

  /// Sends [cmd] with the next sequence number and returns it.
  int send(String cmd, [Map<String, Object?> args = const {}]) {
    final seq = ++_seq;
    transmit({'cmd': cmd, 'seq': seq, ...args});
    return seq;
  }

  /// The last reported end-effector position in mm [x, y, z] (decision 0027).
  List<double>? eeMm;

  /// Whether the arm target is currently all-zero home pose (decision 0027).
  bool? atHome;

  /// The sequence number of the most recent HOME command sent.
  int? lastHomeSeq;

  /// The sequence number of the most recent STATUS command sent.
  int? lastStatusSeq;

  int status() {
    final seq = send('STATUS');
    lastStatusSeq = seq;
    return seq;
  }
  int home() {
    final seq = send('HOME');
    lastHomeSeq = seq;
    return seq;
  }
  int lockDrive() => send('LOCK_DRIVE');
  int unlockDrive() => send('UNLOCK_DRIVE');
  int pick({double? distCm, double? lateralCm}) => send('PICK', {'dist_cm': distCm, 'lateral_cm': lateralCm});
  int moveToBin(Bin bin) => send('MOVE_TO_BIN', {'bin': bin.wire});
  int drop() => send('DROP');

  /// A planned manual arm move (0234): one six-servo pose (F0..F5, servo degrees, before trim)
  /// per leg; the MaixCAM2 sends them to the ESP32 in order. Replies ack, then motion_done.
  int armPose(List<List<double>> path) =>
      send('ARM_POSE', {'path': [for (final p in path) [for (final v in p) (v * 10).round() / 10]]});

  /// Resend the current angles (freeze the arm where it is); never detaches a servo.
  int hold() => send('HOLD');
  int stop() => send('STOP');

  /// The app is alive (decision 0026): no seq, no reply; the MaixCAM2's watchdog
  /// stops the wheels and holds the arm when these stop coming.
  void heartbeat() => transmit({'cmd': 'HEARTBEAT'});

  /// The student's drive buttons. False (and nothing sent) while driving is locked.
  bool drive(int left, int right) {
    if (driveLocked) return false;
    int cap(int v) => nudgeOnly ? v.clamp(-nudgeMaxPwm, nudgeMaxPwm) : v;
    transmitMotor(cap(left), cap(right));
    return true;
  }
}

/// The real link: 0023 messages over the live-scan WebSocket to the MaixCAM2.
class MaixCamRobot extends RobotController {
  MaixCamRobot({required this.sink, required this.motor});

  /// Sends one JSON message (WebSocketService.sendRobotCommand).
  final void Function(Map<String, Object?> message) sink;
  final void Function(int left, int right) motor;

  @override
  void transmit(Map<String, Object?> message) => sink(message);

  @override
  void transmitMotor(int left, int right) => motor(left, right);

  /// Feed every decoded message from the MaixCAM2; non-replies are ignored.
  void handleMessage(Map<String, dynamic> msg) {
    final reply = RobotReply.fromJson(msg);
    if (reply != null) {
      if (reply.hasEeMm) {
        eeMm = reply.eeMm;
      } else if (reply.seq == lastStatusSeq) {
        // Status response lacked ee_mm; clear stale coordinates
        eeMm = null;
      }
      if (reply.atHome != null) atHome = reply.atHome;
      onReply?.call(reply);
    }
  }
}

/// What the app knows about the arm; all optional (0021 amendment d).
class ArmFeedback {
  /// The last command reported done.
  int? motionDoneSeq;

  /// The picked object has left its floor spot (null until checked).
  bool? objectLeftFloor;

  /// The last frame's AprilTags (P1), extra evidence at the inspect pose only.
  List<ArmTag>? tags;
}

/// Which detection is the object R1 works on: box overlap now; track_id later
/// (the stabilizer keeps matchTrackIds false until M6).
class ObjectIdentity {
  const ObjectIdentity({this.minIou = 0.3});

  final double minIou;

  static TrackedDetection box(Detection d) =>
      TrackedDetection(label: d.label, x: d.x, y: d.y, w: d.w, h: d.h, score: d.score, trackId: d.trackId);

  /// The detection in [frame] that is [ref]: same label, most overlap, at least [minIou].
  Detection? find(TrackedDetection ref, List<Detection> frame) {
    Detection? best;
    var bestIou = minIou;
    for (final d in frame) {
      if (d.label != ref.label) continue;
      final iou = intersectionOverUnion(box(d), ref);
      if (iou >= bestIou) {
        best = d;
        bestIou = iou;
      }
    }
    return best;
  }

  /// [d] still stands on [spot]: overlapping it with its bottom edge (on the floor) where it was.
  bool onFloorSpot(Detection d, TrackedDetection spot) =>
      intersectionOverUnion(box(d), spot) >= minIou &&
      ((d.y + d.h / 2) - (spot.y + spot.h / 2)).abs() <= 0.1 * spot.h;
}
