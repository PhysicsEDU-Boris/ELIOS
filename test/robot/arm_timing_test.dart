// Decision 0230: R1 timeouts must fit the ESP32 firmware's per-joint speed limits.
import 'package:elio/services/robot/r1_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AXIS_MAX_SPEED_DEG_PER_SEC for Arm A / Arm B in robotic_hand_sim 75ab797.
  const slowestJointDegPerSec = 30;
  const pickSegments = 4; // approach, descend, grip, lift
  final fullTravel = Duration(milliseconds: 180 * 1000 ~/ slowestJointDegPerSec);

  test('armTimeout covers a PICK of four full Arm B travels', () {
    expect(armTimeout, greaterThanOrEqualTo(fullTravel * pickSegments));
  });

  test('waitCap covers three arm commands and two 20 s questions', () {
    expect(waitCap, greaterThanOrEqualTo(armTimeout * 3 + const Duration(seconds: 40)));
  });
}
