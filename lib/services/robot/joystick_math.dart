/// Joystick shaping for the Control sticks (task J1, decision 0231): deadzone with rescale,
/// quadratic-dominant curve, slew limit, differential mixer and the arm-base rate integrator.
/// Pure Dart, no Flutter. Every number in [JoystickConfig] is a starting value, tune on the robot.
library;

import 'dart:math';

class JoystickConfig {
  const JoystickConfig({
    this.deadzone = 0.08, // starting value, tune on the robot
    this.quadraticShare = 0.7, // starting value, tune on the robot
    this.slewUp = 2.0, // per second, speeding up; starting value, tune on the robot
    this.slewDown = 6.0, // per second, slowing down or reversing; starting value, tune on the robot
    this.turnGain = 0.6, // starting value, tune on the robot
    this.minDriveOutput = 0.0, // P0, starting value, measure on the robot
    this.armMaxRateDegPerSec = 40.0, // starting value, tune on the robot
    this.armBaseMinDeg = -90.0, // starting value: past ±90 the arm can hit the tank (0230)
    this.armBaseMaxDeg = 90.0, // starting value, tune on the robot
    this.armBaseCenterServo = 90, // starting value, verify that 90 is centre on the robot
    this.armDirection = 1.0, // +1 or -1, flip if the base turns the wrong way
    this.driveTurnSign = 1.0, // +1 or -1, flip if the robot turns the wrong way
    this.tickMs = 50, // starting value, tune on the robot
    this.maxDtSeconds = 0.1, // a stalled tick must not turn into a jump
  })  : assert(armMaxRateDegPerSec > 0 && armMaxRateDegPerSec <= 40,
            'the ESP32 firmware limits the base to 40 deg/s (0230)'),
        assert(deadzone >= 0 && deadzone < 0.5),
        assert(quadraticShare >= 0 && quadraticShare <= 1);

  final double deadzone;
  final double quadraticShare;
  final double slewUp;
  final double slewDown;
  final double turnGain;
  final double minDriveOutput;
  final double armMaxRateDegPerSec;
  final double armBaseMinDeg;
  final double armBaseMaxDeg;
  final int armBaseCenterServo;
  final double armDirection;
  final double driveTurnSign;
  final int tickMs;
  final double maxDtSeconds;
}

/// Deadzone with rescale, then the quadratic-dominant curve. Odd: f(-x) = -f(x).
double shapeAxis(double x, JoystickConfig c) {
  if (x.isNaN) return 0.0;
  final xc = x.clamp(-1.0, 1.0).toDouble();
  final s = xc.abs();
  if (s <= c.deadzone) return 0.0;
  final u = (s - c.deadzone) / (1.0 - c.deadzone);
  final y = (1.0 - c.quadraticShare) * u + c.quadraticShare * u * u;
  return xc < 0 ? -y : y;
}

/// A stick vector longer than 1 is scaled back onto the unit circle.
(double, double) clampToUnitCircle(double x, double y) {
  final m = sqrt(x * x + y * y);
  if (m <= 1.0) return (x, y);
  return (x / m, y / m);
}

/// Slow to speed up, fast to slow down; a reversal brakes to zero first.
class SlewLimiter {
  SlewLimiter({required this.up, required this.down});
  final double up;
  final double down;
  double _out = 0.0;

  double get value => _out;
  void reset([double value = 0.0]) => _out = value;

  double step(double target, double dt) {
    var t = target;
    if (_out != 0.0 && t != 0.0 && t.sign != _out.sign) t = 0.0;
    final rate = (t.abs() > _out.abs() ? up : down) * dt;
    final diff = t - _out;
    _out = diff.abs() <= rate ? t : _out + (diff.isNegative ? -rate : rate);
    return _out;
  }
}

class DriveOutput {
  const DriveOutput(this.left, this.right);
  final double left;
  final double right;
}

double _applyMinOutput(double a, double p0) {
  if (a == 0.0 || p0 == 0.0) return a;
  final mag = p0 + (1.0 - p0) * a.abs();
  return a < 0 ? -mag : mag;
}

/// Differential mixer: v forward, w turn. Saturation scales both sides, so the turn ratio is kept.
DriveOutput mixDrive(double v, double w, JoystickConfig c) {
  final turn = w * c.turnGain * c.driveTurnSign;
  var l = v + turn;
  var r = v - turn;
  final m = max(1.0, max(l.abs(), r.abs()));
  l /= m;
  r /= m;
  return DriveOutput(_applyMinOutput(l, c.minDriveOutput), _applyMinOutput(r, c.minDriveOutput));
}

/// Rate control for the arm base: the stick sets the speed, this integrates it into an angle
/// (degrees from centre, kept as a float; rounded only for the servo value).
class ArmBaseIntegrator {
  ArmBaseIntegrator(this.config, {double initialDeg = 0.0}) : _deg = initialDeg;
  final JoystickConfig config;
  double _deg;

  double get angleDeg => _deg;

  void syncTo(double deg) => _deg = deg.clamp(config.armBaseMinDeg, config.armBaseMaxDeg).toDouble();

  /// [rateFraction] in [-1, 1]. Returns the servo value.
  int update(double rateFraction, double dt) {
    syncTo(_deg + rateFraction * config.armDirection * config.armMaxRateDegPerSec * dt);
    return servo;
  }

  int get servo => (_deg + config.armBaseCenterServo).round().clamp(0, 180);
}
