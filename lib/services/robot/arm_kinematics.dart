/// The arm's geometry, joint limits, tank keep-out, move planner and closed-form IK, ported
/// from robotic_hand_sim `hil/kinematics.py` + `hil/config.py` (sim 75ab797, decision 0234).
/// Pinned to the sim by test/fixtures/arm_kinematics_golden.json
/// (tools/arm_kinematics/make_golden.py). Pure Dart.
///
/// Angles are "sim" degrees per joint (J1 base, J2 Arm A, J3 Arm B, J4 wrist pitch, J5 wrist
/// yaw), 0 at home. Positions are world mm: x right, y back (the tank is at y > 0), z up.
library;

import 'dart:math' as math;

typedef Vec3 = List<double>;
typedef Joints = List<double>;

/// Why a move was refused, as the sim words it.
enum ArmRefusal { outOfReach, jointLimits, baseLimit, tank, tankPath, unknownPose }

/// Link offsets J1→J2, J2→J3, J3→J4, J4→J5 (arm-sim-end.py D_OFFSETS), mm.
const _d = <Vec3>[
  [0.0, 5.0, 35.5],
  [0.0, -47.5, 194.5],
  [0.0, 0.0, -140.0],
  [0.0, -24.5, 0.0],
];

/// Effective sim limits per joint: the sim's limit ∩ the servo range (hil/config.py joint_limits()).
const armJointLimits = <(double, double)>[(-180, 180), (-50, 50), (-180, 0), (0, 180), (-90, 90)];

/// A point behind the base (y > 0) and lower than this is over the tank.
const tankZMm = 167.0;

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Rz(base) · Rx(tilt) · v.
Vec3 _rot(double base, double tilt, Vec3 v) {
  final ct = math.cos(_rad(tilt)), st = math.sin(_rad(tilt));
  final x = v[0], y = ct * v[1] - st * v[2], z = st * v[1] + ct * v[2];
  final cb = math.cos(_rad(base)), sb = math.sin(_rad(base));
  return [cb * x - sb * y, sb * x + cb * y, z];
}

Vec3 _add(Vec3 a, Vec3 b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];

/// World positions of J1..J5. J2, J3 and J4 all turn about the arm's X axis, so their
/// rotations add up.
List<Vec3> jointPoints(Joints a) {
  final j2 = _rot(a[0], 0, _d[0]);
  final j3 = _add(j2, _rot(a[0], a[1], _d[1]));
  final j4 = _add(j3, _rot(a[0], a[1] + a[2], _d[2]));
  final j5 = _add(j4, _rot(a[0], a[1] + a[2] + a[3], _d[3]));
  return [
    [0.0, 0.0, 0.0],
    j2,
    j3,
    j4,
    j5,
  ];
}

/// The end effector (J4), world mm.
Vec3 fk(Joints a) => jointPoints(a)[3];

bool _inTank(Vec3 p) => p[1] > 1e-3 && p[2] < tankZMm;

/// True when the elbow (J3), the end effector (J4) or the wrist (J5) is over the tank.
bool unsafePose(Joints a) {
  final p = jointPoints(a);
  return _inTank(p[2]) || _inTank(p[3]) || _inTank(p[4]);
}

Joints _lerp(Joints a, Joints b, double s) => [for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * s];

/// True when the straight joint-space move a → b passes over the tank.
bool pathUnsafe(Joints a, Joints b, {double step = 2.0}) {
  var big = 0.0;
  for (var i = 0; i < a.length; i++) {
    big = math.max(big, (b[i] - a[i]).abs());
  }
  final n = math.max(1, (big / step).ceil());
  for (var k = 0; k <= n; k++) {
    if (unsafePose(_lerp(a, b, k / n))) return true;
  }
  return false;
}

/// Joint-space waypoints from [a] to [b] that keep clear of the tank: the straight move, else
/// arm first (lift in place, then turn), else base first (turn, then lower).
({List<Joints>? path, ArmRefusal? refusal}) planPath(Joints a, Joints b) {
  if (unsafePose(b)) return (path: null, refusal: ArmRefusal.tank);
  if (!pathUnsafe(a, b)) return (path: [b], refusal: null);
  final armFirst = [...b]..[0] = a[0];
  final baseFirst = [...a]..[0] = b[0];
  for (final via in [armFirst, baseFirst]) {
    if (!unsafePose(via) && !pathUnsafe(a, via) && !pathUnsafe(via, b)) return (path: [via, b], refusal: null);
  }
  return (path: null, refusal: ArmRefusal.tankPath);
}

double _wrap(double a) => (a + 180.0) % 360.0 - 180.0;

double? _fit(double angle, (double, double) lim, {double tol = 1e-6}) {
  for (final k in const [0.0, -360.0, 360.0]) {
    final a = angle + k;
    if (lim.$1 - tol <= a && a <= lim.$2 + tol) return a.clamp(lim.$1, lim.$2).toDouble();
  }
  return null;
}

// The arm plane as complex numbers y + i·z (kinematics.py).
final _c1 = (_d[0][1], _d[0][2]);
final _d2 = (_d[1][1], _d[1][2]);
final _d3 = (_d[2][1], _d[2][2]);
final _l1 = math.sqrt(_d2.$1 * _d2.$1 + _d2.$2 * _d2.$2);
final _l2 = math.sqrt(_d3.$1 * _d3.$1 + _d3.$2 * _d3.$2);
final _phi2 = math.atan2(_d2.$2, _d2.$1);
final _phi3 = math.atan2(_d3.$2, _d3.$1);

/// Joints that put the end effector at [target] (world mm), of all solutions inside [limits]
/// the one closest to [current]. With [keepPitch] the tool's angle to the floor stays.
({Joints? angles, ArmRefusal? refusal}) solve(Vec3 target, Joints current,
    {List<(double, double)> limits = armJointLimits, bool keepPitch = true}) {
  final x = target[0], y = target[1], z = target[2];
  final r = math.sqrt(x * x + y * y);
  (double, Joints)? best;
  var reason = ArmRefusal.outOfReach;
  for (final (yLocal, base) in [(-r, _deg(math.atan2(x, -y))), (r, _deg(math.atan2(-x, y)))]) {
    final t1 = _fit(r < 1e-9 ? current[0] : base, limits[0]);
    if (t1 == null) {
      reason = ArmRefusal.baseLimit;
      continue;
    }
    final vy = yLocal - _c1.$1, vz = z - _c1.$2;
    final c = (vy * vy + vz * vz - _l1 * _l1 - _l2 * _l2) / (2 * _l1 * _l2);
    if (c < -1 - 1e-9 || c > 1 + 1e-9) continue;
    final g0 = math.acos(c.clamp(-1.0, 1.0));
    final psi = math.atan2(vz, vy);
    for (final g in [g0, -g0]) {
      final t3 = _fit(_wrap(_deg(g + _phi2 - _phi3)), limits[2]);
      final t2 = _fit(_wrap(_deg(psi - math.atan2(_l2 * math.sin(g), _l1 + _l2 * math.cos(g)) - _phi2)), limits[1]);
      if (t2 == null || t3 == null) {
        reason = ArmRefusal.jointLimits;
        continue;
      }
      final a = [...current];
      a[0] = t1;
      a[1] = t2;
      a[2] = t3;
      if (keepPitch) {
        a[3] = (current[1] + current[2] + current[3] - t2 - t3).clamp(limits[3].$1, limits[3].$2).toDouble();
      }
      final e = fk(a);
      final dx = e[0] - x, dy = e[1] - y, dz = e[2] - z;
      if (math.sqrt(dx * dx + dy * dy + dz * dz) > 0.5) continue;
      if (unsafePose(a)) {
        reason = ArmRefusal.tank;
        continue;
      }
      var cost = 0.0;
      for (var i = 0; i < a.length; i++) {
        cost += (a[i] - current[i]).abs();
      }
      if (best == null || cost < best.$1) best = (cost, a);
    }
  }
  return best == null ? (angles: null, refusal: reason) : (angles: best.$2, refusal: null);
}
