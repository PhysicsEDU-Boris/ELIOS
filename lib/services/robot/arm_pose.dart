/// The arm pose the app commands, in servo degrees, and the moves to change it (decision 0234):
/// the app side of robotic_hand_sim's `MainWindow._request` + `Motion`. Every manual arm key
/// (BASIS stick, height, reach, gripper, PICK, RELEASE, HOME) asks for a goal pose; the
/// planner checks it against the joint limits and the tank and returns the path to send, or why
/// not. Pure Dart.
library;

import 'dart:math' as math;

import 'arm_kinematics.dart';
import 'arm_profile.dart';

/// Six servo angles in the firmware's field order F0..F5 (hil/config.py AXES).
typedef ServoPose = List<double>;

class ArmAxis {
  const ArmAxis(this.name, this.joint, this.home, this.servoLo, this.servoHi, this.speed);
  final String name;

  /// Sim joint index; null for the gripper.
  final int? joint;
  final double home, servoLo, servoHi;

  /// Firmware speed limit, servo deg/s.
  final double speed;
}

const armAxes = [
  ArmAxis('Gripper', null, 180, 60, 180, 90),
  ArmAxis('Wrist Yaw', 4, 90, 0, 180, 45),
  ArmAxis('Wrist Pitch', 3, 0, 0, 180, 45),
  ArmAxis('Arm B', 2, 180, 0, 180, 30),
  ArmAxis('Arm A', 1, 90, 0, 180, 30),
  ArmAxis('Arm Base', 0, 90, -90, 270, 40),
];

const _gripper = 0, _base = 5;
const gripOpenServo = 180.0;
final ServoPose armHome = [for (final a in armAxes) a.home];

/// Fader ranges (0234): forward reach and height of the end effector, mm. Points inside the
/// range the arm cannot reach are refused, as in the sim's "Go to point".
const reachRangeMm = (40.0, 320.0);
const heightRangeMm = (40.0, 370.0);

/// hil/config.py SPEED_MARGIN: no joint is asked for more than 80 % of its speed limit.
const armSpeedMargin = 0.8;

Joints armToSim(ServoPose s) {
  final j = List<double>.filled(5, 0);
  for (var i = 0; i < armAxes.length; i++) {
    final joint = armAxes[i].joint;
    if (joint != null) j[joint] = s[i] - armAxes[i].home;
  }
  return j;
}

ServoPose armFromSim(Joints j, double gripper) =>
    [for (final a in armAxes) a.joint == null ? gripper : a.home + j[a.joint!]];

/// Servo range per axis: the sim limits (joints) or the servo range (gripper).
(double, double) _servoRange(int i) {
  final a = armAxes[i];
  final j = a.joint;
  return j == null ? (a.servoLo, a.servoHi) : (a.home + armJointLimits[j].$1, a.home + armJointLimits[j].$2);
}

/// Seconds one leg takes with speed [profile] (0240; the sim's ProfiledMotion and the MaixCAM2's
/// leg_seconds): the slowest joint at its own top speed.
double legSeconds(ServoPose a, ServoPose b, [ArmProfile profile = defaultArmProfile]) {
  var t = 0.0;
  for (var i = 0; i < armAxes.length; i++) {
    final g = profile[armAxes[i].name] ?? defaultArmProfile[armAxes[i].name]!;
    t = math.max(t, (b[i] - a[i]).abs() * peakOverMean(g.accel, g.decel) / g.vmax);
  }
  return t > 1e-9 ? math.max(t, 0.15) : 0.0;
}

/// A planned move: [path] to send (servo poses, one per leg), or [refusal].
class ArmMove {
  const ArmMove._(this.path, this.refusal, this.duration);
  const ArmMove.refused(ArmRefusal r) : this._(null, r, Duration.zero);
  final List<ServoPose>? path;
  final ArmRefusal? refusal;
  final Duration duration;
  ServoPose? get goal => path?.last;
}

class ArmPose {
  /// Gripper closed angle offset (Advanced settings, 0232): closed = 75 + offset.
  double gripClosedOffset = 0;

  /// Speed profile the MaixCAM2 plays manual moves with (Advanced settings, 0240): times [plan].
  ArmProfile profile = defaultArmProfile;

  ServoPose _goal = [...armHome];
  bool _known = true;

  /// The last commanded pose. Not meaningful while [known] is false.
  ServoPose get goal => List.unmodifiable(_goal);

  /// False after a STOP or an R1 sort: where the arm stopped is unknown, so only HOME (the
  /// firmware's own) is allowed until the arm is home again.
  bool get known => _known;
  void markUnknown() {
    _known = false;
    movingSeq = null;
  }

  /// Seq of the manual ARM_POSE still on its way. A reply to an older, superseded command, or a
  /// STATUS mid-move, carries a pose the arm is only passing through: taking it as the goal pulled
  /// the sliders back while the student dragged them ("moves on its own", 0240).
  int? movingSeq;

  /// The MaixCAM2 reported the pose it last sent to the ESP32 (0235: motion_done, STATUS).
  void sync(ServoPose servo) {
    _goal = [...servo];
    _known = true;
    movingSeq = null;
  }

  /// A reply's `servo`: taken while no manual move is on its way, or as that move's own end.
  /// True when it was taken.
  bool onServo(ServoPose servo, {required int? seq, required bool done}) {
    if (movingSeq != null && !(done && seq == movingSeq)) return false;
    sync(servo);
    return true;
  }

  /// From a STATUS reply (0240): true when the MaixCAM2 has heard nothing from the arm's ESP32 for
  /// over 3 s (it sends STAT every second), so arm moves go out but reach no servo; null when the
  /// firmware does not say (older than m2c-arm-v3).
  static bool? esp32SilentFrom(Map<String, dynamic> msg) {
    if (!msg.containsKey('esp32_age_s')) return null;
    final age = msg['esp32_age_s'];
    return age is! num || age > 3;
  }

  /// [sync]'s input from a reply's `servo` field, or null when it has none (old firmware, ESP32 reset).
  static ServoPose? servoFrom(Object? raw) =>
      raw is List && raw.length == armAxes.length && raw.every((v) => v is num)
          ? [for (final v in raw) (v as num).toDouble()]
          : null;
  void markHome() {
    _goal = [...armHome];
    _known = true;
    movingSeq = null;
  }

  double get gripClosedServo => 75 + gripClosedOffset;

  /// Plans a move to [servoGoal] (clamped to each axis' range). Nothing changes until [commit].
  ArmMove plan(ServoPose servoGoal) {
    if (!_known) return const ArmMove.refused(ArmRefusal.unknownPose);
    final g = [
      for (var i = 0; i < armAxes.length; i++) servoGoal[i].clamp(_servoRange(i).$1, _servoRange(i).$2).toDouble()
    ];
    final p = planPath(armToSim(_goal), armToSim(g));
    if (p.path == null) return ArmMove.refused(p.refusal!);
    final path = [for (final w in p.path!) armFromSim(w, g[_gripper])];
    var s = 0.0, from = _goal;
    for (final leg in path) {
      s += legSeconds(from, leg, profile);
      from = leg;
    }
    return ArmMove._(path, null, Duration(milliseconds: (s * 1000).round()));
  }

  /// The move was sent (as [seq]): it is the new goal.
  void commit(ArmMove m, [int? seq]) {
    _goal = [...m.goal!];
    movingSeq = seq;
  }

  ArmMove _with(int axis, double servo) => plan([..._goal]..[axis] = servo);

  ArmMove base(double servo) => _with(_base, servo);
  double get baseServo => _goal[_base];

  /// Gripper width 0 (open) .. 100 (closed), the app's existing scale.
  ArmMove gripper(double width) =>
      _with(_gripper, gripOpenServo - (gripOpenServo - gripClosedServo) * width.clamp(0, 100) / 100);
  ArmMove close() => _with(_gripper, gripClosedServo);
  ArmMove open() => _with(_gripper, gripOpenServo);
  double get gripperWidth =>
      ((gripOpenServo - _goal[_gripper]) / (gripOpenServo - gripClosedServo) * 100).clamp(0, 100).toDouble();

  ArmMove home() => plan(armHome);

  // Height and reach: the end effector straight up/down or along the arm's heading, the tool's
  // angle to the floor kept (the sim's "Go to point" with keep pitch).
  (double, double, double) _heading() {
    final t = armToSim(_goal)[0] * math.pi / 180;
    final e = fk(armToSim(_goal));
    return (math.sin(t), -math.cos(t), e[0] * math.sin(t) - e[1] * math.cos(t)); // forward x, y and reach
  }

  double get reachMm => _heading().$3;
  double get heightMm => fk(armToSim(_goal))[2];
  double get reachFraction => _fraction(reachMm, reachRangeMm);
  double get heightFraction => _fraction(heightMm, heightRangeMm);

  ArmMove reach(double fraction) => _goTo(_lerp(reachRangeMm, fraction), heightMm);
  ArmMove height(double fraction) => _goTo(reachMm, _lerp(heightRangeMm, fraction));

  ArmMove _goTo(double reach, double z) {
    if (!_known) return const ArmMove.refused(ArmRefusal.unknownPose);
    final (fx, fy, _) = _heading();
    final s = solve([reach * fx, reach * fy, z], armToSim(_goal));
    if (s.angles == null) return ArmMove.refused(s.refusal!);
    return plan(armFromSim(s.angles!, _goal[_gripper]));
  }

  static double _lerp((double, double) r, double f) => r.$1 + (r.$2 - r.$1) * f.clamp(0, 1);
  static double _fraction(double v, (double, double) r) => ((v - r.$1) / (r.$2 - r.$1)).clamp(0, 1).toDouble();
}
