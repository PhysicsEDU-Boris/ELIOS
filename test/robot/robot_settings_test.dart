// Decision 0232: robot settings model, persistence and the joystick mapping.
import 'dart:convert';

import 'package:elio/services/robot/arm_profile.dart';
import 'package:elio/services/robot/joystick_controller.dart';
import 'package:elio/services/robot/robot_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('0240: the speed profile survives JSON and goes out in CONFIG', () {
    final s = RobotSettings(profile: {...defaultArmProfile, 'Arm Base': const ArmAxisProfile(20, 0.72, 0.18)});
    final m = jsonDecode(jsonEncode(s.toMap())) as Map<String, dynamic>;
    expect(m['profile']['Arm Base'], {'vmax': 20.0, 'accel': 0.72, 'decel': 0.18});
    expect(RobotSettings.fromMap(m), s);
    expect(const RobotSettings().profile, defaultArmProfile);
  });

  test('0240: a pasted profile is clamped per axis, never rejected', () {
    final s = RobotSettings.fromMap({
      'profile': {
        'Arm Base': {'vmax': 500, 'accel': 0.9, 'decel': 0.9}, // over the cap, ramps overlap
        'Arm A': {'vmax': 'x'},
      },
    });
    expect(s.profile['Arm Base'], const ArmAxisProfile(32, 0.5, 0.5));
    expect(s.profile['Arm A'], defaultArmProfile['Arm A']);
  });

  test('defaults match the 0231 joystick constants', () {
    final j = const RobotSettings().joystick;
    expect((j.deadzone, j.quadraticShare, j.turnGain, j.slewUp, j.slewDown), (0.08, 0.7, 0.6, 2.0, 6.0));
    expect((j.armMaxRateDegPerSec, j.armBaseMinDeg, j.armBaseMaxDeg), (40.0, -90.0, 90.0));
    expect((j.driveTurnSign, j.armDirection), (1.0, 1.0));
  });

  test('flips and base limit reach the joystick config', () {
    final j = const RobotSettings(flipTurn: true, flipBase: true, baseLimit: 60, baseRate: 20).joystick;
    expect(
      (j.driveTurnSign, j.armDirection, j.armBaseMinDeg, j.armBaseMaxDeg, j.armMaxRateDegPerSec),
      (-1.0, -1.0, -60.0, 60.0, 20.0),
    );
  });

  test('round trip through JSON keeps every value', () {
    const s = RobotSettings(
      trims: [1.5, -2, 0, 15, -15],
      inverted: [true, false, true, false, false],
      gripClosedOffset: 3,
      gripInverted: true,
      deadzone: 0.12,
      slewDown: 8,
      flipTurn: true,
    );
    final back = RobotSettings.fromMap(jsonDecode(jsonEncode(s.toMap())) as Map<String, dynamic>);
    expect(back, s);
  });

  test('pasted values out of range, wrong type or wrong length fall back to defaults', () {
    final s = RobotSettings.fromMap({
      'trims': [0, 0, 0, 0, 99], // a trim past ±15
      'inverted': [true], // wrong length
      'deadzone': 5,
      'baseRate': 60, // above the firmware's 40 deg/s
      'baseLimit': 'x',
      'gripClosedOffset': double.nan,
    });
    expect(s, const RobotSettings());
  });

  test('the PIN is never part of the shared map', () {
    expect(const RobotSettings(teacherPin: '1234').toMap().containsKey('pin'), isFalse);
    expect(const RobotSettings(teacherPin: '1234').toMap().values, isNot(contains('1234')));
  });

  test('gripper map: 0 % opens at 180, 100 % closes at 75 plus the offset', () {
    expect(const RobotSettings().gripServo(0), 180);
    expect(const RobotSettings().gripServo(100), 75);
    expect(const RobotSettings(gripClosedOffset: 3).gripServo(100), 78);
  });

  test('saved settings and PIN survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final a = ProviderContainer();
    a.read(robotSettingsProvider.notifier).save(const RobotSettings(deadzone: 0.2, teacherPin: '4321'));
    await Future<void>.delayed(Duration.zero);
    a.dispose();
    final b = ProviderContainer();
    b.read(robotSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(b.read(robotSettingsProvider).deadzone, 0.2);
    expect(b.read(robotSettingsProvider).teacherPin, '4321');
    b.dispose();
  });

  test('a new config applies on the next tick without a jump', () {
    final drive = <(double, double)>[];
    final j = JoystickController(
      sendDrive: (l, r) => drive.add((l, r)),
      sendArmBase: (_) {},
      driveLocked: () => false,
      armLocked: () => true,
      baseServo: () => 90,
    )..setDriveStick(0, -1);
    for (var i = 0; i < 5; i++) {
      j.tick(0.05);
    }
    expect(drive.last.$1, closeTo(0.5, 1e-9));
    j.config = const RobotSettings(slewUp: 4).joystick;
    j.tick(0.05);
    expect(drive.last.$1, closeTo(0.7, 1e-9), reason: 'continues from 0.5 at the new 4 /s');
  });
}
