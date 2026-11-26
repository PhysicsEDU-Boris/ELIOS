// Task J1 / decision 0231: the joystick maths against the spec's test vectors.
import 'package:elio/services/robot/joystick_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = JoystickConfig();

  test('deadzone gives zero', () {
    for (final x in [0.0, 0.05, 0.08, -0.08]) {
      expect(shapeAxis(x, c), 0.0);
    }
  });

  test('shaping vectors, odd symmetry', () {
    const table = [(0.10, 0.007), (0.20, 0.051), (0.30, 0.112), (0.40, 0.189), (0.50, 0.283),
                   (0.60, 0.393), (0.70, 0.520), (0.80, 0.664), (0.90, 0.823), (1.0, 1.0)];
    for (final (x, y) in table) {
      expect(shapeAxis(x, c), closeTo(y, 0.001), reason: 'x=$x');
      expect(shapeAxis(-x, c), closeTo(-y, 0.001), reason: 'x=-$x');
    }
  });

  test('monotonic and bounded', () {
    var prev = 0.0;
    for (var i = 0; i <= 100; i++) {
      final y = shapeAxis(i / 100, c);
      expect(y, greaterThanOrEqualTo(prev));
      expect(y, lessThanOrEqualTo(1.0));
      prev = y;
    }
  });

  test('NaN and out of range inputs are safe', () {
    expect(shapeAxis(double.nan, c), 0.0);
    expect(shapeAxis(5.0, c), 1.0);
    expect(shapeAxis(-5.0, c), -1.0);
  });

  test('a stick vector is kept inside the unit circle', () {
    final (x, y) = clampToUnitCircle(1, 1);
    expect(x * x + y * y, closeTo(1, 1e-9));
    expect(clampToUnitCircle(0.3, -0.4), (0.3, -0.4));
  });

  test('slew up reaches 1.0 on tick 10', () {
    final s = SlewLimiter(up: 2.0, down: 6.0);
    for (var i = 1; i <= 10; i++) {
      expect(s.step(1.0, 0.05), closeTo(i * 0.1, 1e-9));
    }
  });

  test('slew down stops in 4 ticks', () {
    final s = SlewLimiter(up: 2.0, down: 6.0)..reset(1.0);
    final seq = [for (var i = 0; i < 4; i++) s.step(0.0, 0.05)];
    expect(seq[0], closeTo(0.7, 1e-9));
    expect(seq[1], closeTo(0.4, 1e-9));
    expect(seq[2], closeTo(0.1, 1e-9));
    expect(seq[3], 0.0);
  });

  test('slew reversal brakes fast then ramps slow', () {
    final s = SlewLimiter(up: 2.0, down: 6.0)..reset(1.0);
    final seq = [for (var i = 0; i < 14; i++) s.step(-1.0, 0.05)];
    expect(seq[3], 0.0);
    expect(seq[4], closeTo(-0.1, 1e-9));
    expect(seq[13], closeTo(-1.0, 1e-9));
  });

  test('mixer vectors', () {
    void check(double v, double w, double l, double r) {
      final o = mixDrive(v, w, c);
      expect(o.left, closeTo(l, 0.001), reason: '($v, $w) left');
      expect(o.right, closeTo(r, 0.001), reason: '($v, $w) right');
    }
    check(1, 0, 1.0, 1.0);
    check(0.5, 0, 0.5, 0.5);
    check(-0.5, 0, -0.5, -0.5);
    check(0, 1, 0.6, -0.6);
    check(0.5, 0.5, 0.8, 0.2);
    check(1, 1, 1.0, 0.25);
    check(0.8, -0.4, 0.538, 1.0);
  });

  test('turn sign flips the turn only', () {
    final o = mixDrive(0, 1, const JoystickConfig(driveTurnSign: -1));
    expect(o.left, closeTo(-0.6, 1e-9));
    expect(o.right, closeTo(0.6, 1e-9));
  });

  test('minimum drive output only applies to non-zero values', () {
    const cm = JoystickConfig(minDriveOutput: 0.2);
    expect(mixDrive(0, 0, cm).left, 0.0);
    expect(mixDrive(0.5, 0, cm).left, closeTo(0.6, 0.001)); // 0.2 + 0.8 * 0.5
  });

  test('arm base clamps and stays a float', () {
    final a = ArmBaseIntegrator(c);
    for (var i = 0; i < 400; i++) {
      a.update(1.0, 0.05);
    }
    expect(a.angleDeg, 90.0);
    expect(a.servo, 180);
    final b = ArmBaseIntegrator(c);
    for (var i = 0; i < 100; i++) {
      b.update(shapeAxis(0.12, c), 0.05);
    }
    expect(b.angleDeg, closeTo(2.87, 0.01));
    expect(b.servo, 93);
  });

  test('owner 26 Nov: at a bin pose outside the limit the stick turns both ways from there', () {
    for (final (binServo, label) in const [(243.0, 'Left-Tank / Mid-Tank Pose 2'), (-82.0, 'Right-Tank')]) {
      final a = ArmBaseIntegrator(c)..syncTo(binServo - 90);
      expect(a.servo, binServo.round(), reason: '$label: no jump back to the limit');
      a.update(1.0, 0.05);
      expect(a.servo, binServo.round() + 2, reason: '$label: right');
      a
        ..update(-1.0, 0.05)
        ..update(-1.0, 0.05);
      expect(a.servo, binServo.round() - 2, reason: '$label: left');
    }
    final top = ArmBaseIntegrator(c)..syncTo(270 - 90);
    top.update(1.0, 0.05);
    expect(top.servo, 270, reason: "Mid-Tank Pose 3 is the base's end stop: right has no room");
    final home = ArmBaseIntegrator(c)..syncTo(0);
    for (var i = 0; i < 400; i++) {
      home.update(1.0, 0.05);
    }
    expect(home.servo, 180, reason: 'from home the teacher limit still holds');
  });

  test('arm base: full push is 2 deg per tick and never exceeds the 40 deg/s firmware limit', () {
    final a = ArmBaseIntegrator(c);
    var last = a.angleDeg;
    for (var i = 0; i < 20; i++) {
      a.update(1.0, 0.05);
      expect(a.angleDeg - last, closeTo(2.0, 1e-9));
      expect((a.angleDeg - last).abs(), lessThanOrEqualTo(40 * 0.05 + 1e-9));
      last = a.angleDeg;
    }
  });

  test('config rejects a base rate above the 40 deg/s firmware limit (0230)', () {
    expect(() => JoystickConfig(armMaxRateDegPerSec: 41), throwsAssertionError);
  });
}
