// R2 gamified Control screen (Figma 358:2358, decision 0173): the pure rules
// behind the joystick, the connection views, the "This drive" tally and the
// ELIO tip. UI-only: every command still goes through MotionGate (0026).
import 'dart:ui' show Offset;

import '../services/robot/motion_gate.dart';
import '../services/robot/r1_constants.dart' show pickBandMaxCm, pickBandMinCm;
import 'home_stats.dart' show HomeBin;
import 'scan_record.dart';

/// The four directions the D-pad had (no diagonals in the command set).
enum DriveDir { forward, back, left, right }

/// Joystick dead zone, as a fraction of the base radius.
const joystickDeadZone = 0.25;

/// The knob's offset from the centre (y down) as one of the four D-pad
/// directions, or null inside the dead zone. Ties go to forward/back.
DriveDir? quantiseJoystick(Offset d, double radius, {double deadZone = joystickDeadZone}) {
  if (radius <= 0 || d.distance < radius * deadZone) return null;
  if (d.dx.abs() > d.dy.abs()) return d.dx > 0 ? DriveDir.right : DriveDir.left;
  return d.dy < 0 ? DriveDir.forward : DriveDir.back;
}

/// The D-pad's motor command for [dir] at [speed] PWM, through the gate.
bool driveCommand(MotionGate gate, DriveDir dir, int speed) => switch (dir) {
  DriveDir.forward => gate.motor(speed, speed),
  DriveDir.back => gate.motor(-speed, -speed),
  DriveDir.left => gate.motor(-speed, speed),
  DriveDir.right => gate.motor(speed, -speed),
};

/// The speed fader's gear chips.
const speedGears = [25, 50, 75, 100];

/// Which Figma screen state the link status shows.
enum ControlLink { connected, waiting, disconnected }

/// "Connecting..." is an attempt in flight (the waiting design);
/// "Reconnecting..." is the 2 s wait before the next try and "Disconnected"
/// is no link: both the disconnected design.
ControlLink controlLink(String status) => switch (status) {
  'Connected' => ControlLink.connected,
  'Connecting...' => ControlLink.waiting,
  _ => ControlLink.disconnected,
};

/// Items in the "Sort 3 items this drive" mission.
const missionTarget = 3;

/// Real scan records saved since [since] (this Control visit), per bin, and
/// the trophies they earned. No mission reward is added (owner question).
({Map<HomeBin, int> bins, int trophies}) driveTally(Iterable<ScanRecord> records, DateTime since) {
  final bins = {for (final b in HomeBin.values) b: 0};
  var trophies = 0;
  for (final r in records) {
    if (r.time.isBefore(since)) continue;
    bins[HomeBin.of(r.category)] = bins[HomeBin.of(r.category)]! + 1;
    trophies += r.trophies;
  }
  return (bins: bins, trophies: trophies);
}

/// The ELIO tip's mood picks the illustration and card colour.
enum TipMood { happy, searching, sad, alert }

/// Rule-based ELIO tip from existing states only (no AI). [distCm] is the
/// nearest item's floor distance when the firmware sends it (0022).
({String text, TipMood mood}) controlTip({
  required ControlLink link,
  required bool stopped,
  required bool quizOpen,
  String? itemLabel,
  bool itemLocked = false,
  double? distCm,
}) {
  if (link == ControlLink.waiting) {
    return (
      text: "Hang on, I'm looking for the robot! If it takes long, check the ELIOS Wi-Fi.",
      mood: TipMood.searching,
    );
  }
  if (link == ControlLink.disconnected) {
    return (
      text: "Uh-oh, I can't hear the robot. Walk closer to it or check that it's switched on.",
      mood: TipMood.sad,
    );
  }
  if (stopped) return (text: 'The robot is STOPPED. Check the way is clear, then tap Lanjutkan.', mood: TipMood.alert);
  if (quizOpen) return (text: 'Quiz time! Answer it, then we sort the item together.', mood: TipMood.happy);
  final item = itemLabel?.toLowerCase();
  if (item == null) return (text: 'Drive around slowly and point my camera at an item to sort.', mood: TipMood.happy);
  if (distCm != null && distCm >= pickBandMinCm && distCm <= pickBandMaxCm) {
    return (text: 'Nice driving! The $item is in the pick zone. Press PICK UP to grab it.', mood: TipMood.happy);
  }
  if (itemLocked) return (text: 'Got it! I locked on the $item. Hold still while I look.', mood: TipMood.happy);
  return (text: 'I see a $item. Drive closer, slowly.', mood: TipMood.happy);
}
