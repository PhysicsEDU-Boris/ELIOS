// The Dart arm kinematics against robotic_hand_sim's hil/kinematics.py (decision 0234).
// Golden: tools/arm_kinematics/make_golden.py.
import 'dart:convert';
import 'dart:io';

import 'package:elio/services/robot/arm_kinematics.dart';
import 'package:flutter_test/flutter_test.dart';

final _g = jsonDecode(File('test/fixtures/arm_kinematics_golden.json').readAsStringSync()) as Map<String, dynamic>;
Matcher _near(List<double> want, double tol) =>
    pairwiseCompare<num, num>(want, (a, b) => (a - b).abs() < tol, 'within $tol of');
List<double> _v(Object? l) => [for (final x in l as List) (x as num).toDouble()];

ArmRefusal _refusal(String why) => why.startsWith('the way there')
    ? ArmRefusal.tankPath
    : why.contains('tank')
        ? ArmRefusal.tank
        : switch (why) {
            'out of reach' => ArmRefusal.outOfReach,
            "outside the arm's joint limits" => ArmRefusal.jointLimits,
            "base can't turn that far" => ArmRefusal.baseLimit,
            _ => throw ArgumentError(why),
          };

void main() {
  test('limits and tank height match the sim', () {
    expect([for (final l in _g['limits'] as List) (_v(l)[0], _v(l)[1])], armJointLimits);
    expect(_g['tank_z_mm'], tankZMm);
  });

  test('joint points and the tank check match the sim', () {
    for (final c in _g['fk'] as List) {
      final pts = jointPoints(_v(c['angles']));
      final want = c['points'] as List;
      for (var i = 0; i < 5; i++) {
        expect(pts[i], _near(_v(want[i]), 1e-4), reason: '${c['angles']} J${i + 1}');
      }
      expect(unsafePose(_v(c['angles'])), c['unsafe'], reason: '${c['angles']}');
    }
  });

  test('IK picks the same solution or the same reason as the sim', () {
    for (final c in _g['solve'] as List) {
      final got = solve(_v(c['target']), _v(c['current']));
      if (c['angles'] == null) {
        expect(got.angles, isNull, reason: '${c['target']}');
        expect(got.refusal, _refusal(c['reason'] as String), reason: '${c['target']}');
      } else {
        expect(got.angles, _near(_v(c['angles']), 1e-3), reason: '${c['target']}');
      }
    }
  });

  test('the planner keeps the same path or refuses for the same reason', () {
    for (final c in _g['plan'] as List) {
      final got = planPath(_v(c['from']), _v(c['to']));
      if (c['path'] == null) {
        expect(got.path, isNull);
        expect(got.refusal, _refusal(c['reason'] as String));
      } else {
        final want = [for (final w in c['path'] as List) _v(w)];
        expect(got.path!.length, want.length);
        for (var i = 0; i < want.length; i++) {
          expect(got.path![i], _near(want[i], 1e-6));
        }
      }
    }
  });

  test('home is (0, -42.5, 90) and safe', () {
    expect(fk([0, 0, 0, 0, 0]), _near([0.0, -42.5, 90.0], 1e-9));
    expect(unsafePose([0, 0, 0, 0, 0]), isFalse);
  });
}
