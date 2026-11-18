// Task J1 / decision 0231: JoystickController with a fake sink, ticked by hand.
import 'package:elio/services/robot/joystick_controller.dart';
import 'package:elio/services/robot/joystick_math.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rig {
  _Rig({JoystickConfig config = const JoystickConfig()}) {
    j = JoystickController(
      config: config,
      sendDrive: (l, r) => drive.add((l, r)),
      sendArmBase: (v) {
        arm.add(v);
        base = v.toDouble();
      },
      driveLocked: () => driveLocked,
      armLocked: () => armLocked,
      baseServo: () => base,
    );
  }
  late final JoystickController j;
  final drive = <(double, double)>[];
  final arm = <int>[];
  bool driveLocked = false, armLocked = false;
  double base = 90;

  void run(int ticks) {
    for (var i = 0; i < ticks; i++) {
      j.tick(0.05);
    }
  }
}

void main() {
  test('drive follows the stick: full forward reaches (1, 1) on tick 10', () {
    final r = _Rig()..j.setDriveStick(0, -1);
    r.run(10);
    expect(r.drive.first.$1, closeTo(0.1, 1e-9));
    expect(r.drive.last.$1, closeTo(1.0, 1e-9));
    expect(r.drive.last.$2, closeTo(1.0, 1e-9));
  });

  test('let go: (0, 0) within 4 ticks, then nothing more', () {
    final r = _Rig()..j.setDriveStick(0, -1);
    r.run(10);
    r.drive.clear();
    r.j.setDriveStick(0, 0);
    r.run(10);
    expect(r.drive.length, 4);
    expect(r.drive.last, (0.0, 0.0));
  });

  test('a still stick inside the dead zone sends nothing', () {
    final r = _Rig()..j.setDriveStick(0.05, -0.05);
    r.run(20);
    expect(r.drive, isEmpty);
  });

  test('drive lock: nothing while locked; after unlock it ramps from 0, no jump', () {
    final r = _Rig()
      ..driveLocked = true
      ..j.setDriveStick(0, -1);
    r.run(10);
    expect(r.drive, isEmpty);
    r.driveLocked = false;
    r.run(1);
    expect(r.drive.single.$1, closeTo(0.1, 1e-9));
  });

  test('lock resets the ramp: push, lock, unlock with the stick held restarts from 0.1', () {
    final r = _Rig()..j.setDriveStick(0, -1);
    r.run(10);
    r.driveLocked = true;
    r.run(3);
    expect(r.drive.last, (0.0, 0.0), reason: 'one stop on lock');
    r.drive.clear();
    r.run(3);
    expect(r.drive, isEmpty, reason: 'silent while locked');
    r.driveLocked = false;
    r.run(1);
    expect(r.drive.single.$1, closeTo(0.1, 1e-9));
  });

  test('letGo() (app in background) zeroes the stick and the ramp', () {
    final r = _Rig()..j.setDriveStick(0, -1);
    r.run(10);
    r.j.letGo();
    r.drive.clear();
    r.run(5);
    expect(r.drive, isEmpty);
  });

  test('arm moves 2 deg per tick at steady state', () {
    final r = _Rig()..j.setArmStick(1);
    r.run(20);
    final steady = r.arm.skip(10).toList();
    for (var i = 1; i < steady.length; i++) {
      expect(steady[i] - steady[i - 1], 2);
    }
  });

  test('arm hold on release: eases off, one final hold, then silence', () {
    final r = _Rig()..j.setArmStick(1);
    r.run(20);
    r.arm.clear();
    r.j.setArmStick(0);
    r.run(10);
    expect(r.arm.length, lessThanOrEqualTo(4));
    expect(r.arm[r.arm.length - 1], r.arm[r.arm.length - 2], reason: 'the hold repeats the stopped angle');
    final n = r.arm.length;
    r.run(10);
    expect(r.arm.length, n);
  });

  test('arm locked (SORTING, hand in view, STOPPED): no base command at all', () {
    final r = _Rig()
      ..armLocked = true
      ..j.setArmStick(1);
    r.run(20);
    expect(r.arm, isEmpty);
  });

  test('arm resync: after someone else moves the base, the next push starts from there', () {
    final r = _Rig()..j.setArmStick(1);
    r.run(20);
    r.j.setArmStick(0);
    r.run(10);
    r.base = 60; // e.g. HOME or the debug chevrons
    r.arm.clear();
    r.j.setArmStick(1);
    r.run(1);
    expect(r.arm.first, inInclusiveRange(60, 61));
  });

  test('arm direction flip: a positive stick lowers the servo value', () {
    final r = _Rig(config: const JoystickConfig(armDirection: -1))..j.setArmStick(1);
    r.run(20);
    expect(r.arm.last, lessThan(90));
  });

  test('arm never leaves the configured range', () {
    final r = _Rig()..j.setArmStick(1);
    r.run(200);
    expect(r.arm.last, 180);
  });
}
