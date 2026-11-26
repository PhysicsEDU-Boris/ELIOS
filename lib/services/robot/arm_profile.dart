/// Per-joint speed profile (decision 0240 section 1): robotic_hand_sim arm-hil-toolkit-2.py's
/// `clean_axis`, `complete_profile` and `ProfiledMotion` ramp. Each joint speeds up over the first
/// `accel` share of a move, cruises at `vmax` and slows down over the last `decel` share; all
/// joints still start and arrive together. The MaixCAM2 plays the moves (firmware/maixcam2
/// arm_bridge.py); the app stores the profile, sends it in CONFIG and times its moves with it.
/// Pinned to the sim by test/fixtures/arm_profile_golden.json. Pure Dart.
library;

import 'dart:math' as math;

import 'arm_pose.dart' show armAxes, armSpeedMargin;

/// Ramps are a share of the move, 5 .. 95 %; 33 % each by default (the sim's FRAC_*).
const profileFracMin = 0.05, profileFracMax = 0.95, profileFracDefault = 0.33;

class ArmAxisProfile {
  const ArmAxisProfile(this.vmax, this.accel, this.decel);

  /// Top speed, servo deg/s.
  final double vmax;

  /// Share of the move spent speeding up / slowing down.
  final double accel, decel;

  Map<String, double> toMap() => {'vmax': vmax, 'accel': accel, 'decel': decel};

  @override
  bool operator ==(Object other) =>
      other is ArmAxisProfile && other.vmax == vmax && other.accel == accel && other.decel == decel;

  @override
  int get hashCode => Object.hash(vmax, accel, decel);

  @override
  String toString() => 'ArmAxisProfile($vmax, $accel, $decel)';
}

/// Axis name -> profile, in [armAxes] order (Gripper, Wrist Yaw, Wrist Pitch, Arm B, Arm A, Arm Base).
typedef ArmProfile = Map<String, ArmAxisProfile>;

double _round(double v, int places) {
  final k = math.pow(10, places);
  return (v * k).round() / k;
}

/// Fastest allowed top speed of axis [i]: the firmware limit times the margin (the sim's vmax_cap).
double vmaxCap(int i) => (armAxes[i].speed * armSpeedMargin * 10).floor() / 10;

/// One axis clamped like the sim: vmax 1 .. cap, ramps 5 .. 95 %, scaled down when they overlap.
/// Throws [ArgumentError] on a non-finite value.
ArmAxisProfile cleanAxis(int i, double vmax, double accel, double decel) {
  if (![vmax, accel, decel].every((v) => v.isFinite)) throw ArgumentError('not a number');
  vmax = vmax.clamp(1.0, vmaxCap(i)).toDouble();
  accel = accel.clamp(profileFracMin, profileFracMax).toDouble();
  decel = decel.clamp(profileFracMin, profileFracMax).toDouble();
  if (accel + decel > 1.0) {
    final k = 1.0 / (accel + decel);
    accel *= k;
    decel *= k;
  }
  return ArmAxisProfile(_round(vmax, 1), _round(accel, 3), _round(decel, 3));
}

/// The defaults: every joint at its cap with 33 % ramps (72, 36, 36, 24, 24, 32 deg/s).
const defaultArmProfile = <String, ArmAxisProfile>{
  'Gripper': ArmAxisProfile(72.0, 0.33, 0.33),
  'Wrist Yaw': ArmAxisProfile(36.0, 0.33, 0.33),
  'Wrist Pitch': ArmAxisProfile(36.0, 0.33, 0.33),
  'Arm B': ArmAxisProfile(24.0, 0.33, 0.33),
  'Arm A': ArmAxisProfile(24.0, 0.33, 0.33),
  'Arm Base': ArmAxisProfile(32.0, 0.33, 0.33),
};

/// Any stored, pasted or partial profile ({axis name: {vmax, accel, decel}}) -> a full, clamped
/// one. Missing or bad axes get the defaults (the sim's complete_profile).
ArmProfile completeArmProfile(Object? raw) => {
  for (var i = 0; i < armAxes.length; i++) armAxes[i].name: _axisFrom(i, raw is Map ? raw[armAxes[i].name] : null),
};

ArmAxisProfile _axisFrom(int i, Object? g) {
  if (g is ArmAxisProfile) g = g.toMap();
  if (g is Map) {
    final v = [g['vmax'], g['accel'], g['decel']];
    if (v.every((x) => x is num && x.isFinite)) {
      return cleanAxis(i, (v[0] as num).toDouble(), (v[1] as num).toDouble(), (v[2] as num).toDouble());
    }
  }
  return defaultArmProfile[armAxes[i].name]!;
}

/// JSON form, as CONFIG sends it and the sim saves it in a sequence step's "motion".
Map<String, Map<String, double>> armProfileToMap(ArmProfile p) => {for (final e in p.entries) e.key: e.value.toMap()};

/// Peak speed over mean speed of a move with ramps [accel] and [decel].
double peakOverMean(double accel, double decel) => 1.0 / (1.0 - (accel + decel) / 2.0);

/// Share of the move done at time share [u] (0..1) for one joint: trapezoid speed.
double profileRamp(double u, double accel, double decel) {
  final vp = peakOverMean(accel, decel);
  if (u < accel) return vp * u * u / (2 * accel);
  if (u > 1 - decel) return 1 - vp * (1 - u) * (1 - u) / (2 * decel);
  return vp * (accel / 2 + u - accel);
}
