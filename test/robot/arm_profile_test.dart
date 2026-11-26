// The Dart speed profile against robotic_hand_sim's ProfiledMotion (decision 0240 section 1).
// Golden: tools/arm_kinematics/make_profile_golden.py; the MaixCAM2 bridge is pinned to the same file.
import 'dart:convert';
import 'dart:io';

import 'package:elio/services/robot/arm_pose.dart';
import 'package:elio/services/robot/arm_profile.dart';
import 'package:flutter_test/flutter_test.dart';

final _g = jsonDecode(File('test/fixtures/arm_profile_golden.json').readAsStringSync()) as Map<String, dynamic>;
List<double> _v(Object? l) => [for (final x in l as List) (x as num).toDouble()];

void main() {
  test('axis order and the default caps', () {
    expect(_g['axes'], [for (final a in armAxes) a.name]);
    expect([for (var i = 0; i < armAxes.length; i++) vmaxCap(i)], [72.0, 36.0, 36.0, 24.0, 24.0, 32.0]);
    expect(completeArmProfile(null), defaultArmProfile);
  });

  test('clamping matches the sim', () {
    for (final MapEntry(:key, :value) in (_g['profiles'] as Map<String, dynamic>).entries) {
      final p = value as Map<String, dynamic>;
      expect(armProfileToMap(completeArmProfile(p['input'])), p['clean'], reason: key);
    }
  });

  test('leg time and positions match the sim', () {
    for (final leg in (_g['legs'] as List).cast<Map<String, dynamic>>()) {
      final prof = completeArmProfile((_g['profiles'] as Map)[leg['profile']]['input']);
      final a = _v(leg['start']), b = _v(leg['goal']);
      expect(legSeconds(a, b, prof), closeTo((leg['seconds'] as num).toDouble(), 1e-5), reason: leg['profile']);
      for (final s in (leg['samples'] as List).cast<Map<String, dynamic>>()) {
        final u = (s['u'] as num).toDouble();
        final want = _v(s['cmd']);
        for (var i = 0; i < armAxes.length; i++) {
          final g = prof[armAxes[i].name]!;
          final got = u >= 1 ? b[i] : a[i] + (b[i] - a[i]) * profileRamp(u, g.accel, g.decel);
          expect(got, closeTo(want[i], 1e-4), reason: '${leg['profile']} u=$u axis $i');
        }
      }
    }
  });

  test('pasted profiles with bad values fall back to the defaults per axis', () {
    final p = completeArmProfile({
      'Arm Base': {'vmax': double.nan, 'accel': 0.5, 'decel': 0.5},
      'Arm A': {'vmax': 'fast'},
      'Arm B': 'x',
      'Gripper': {'vmax': 10, 'accel': 0.2, 'decel': 0.2},
    });
    expect(p['Gripper'], const ArmAxisProfile(10, 0.2, 0.2));
    expect({for (final e in p.entries) if (e.key != 'Gripper') e.key: e.value},
        {for (final e in defaultArmProfile.entries) if (e.key != 'Gripper') e.key: e.value});
    expect(completeArmProfile([1, 2]), defaultArmProfile);
  });
}
