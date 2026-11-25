// The manual arm keys as sim-style planned moves (decision 0234).
import 'package:elio/services/robot/arm_kinematics.dart';
import 'package:elio/services/robot/arm_pose.dart';
import 'package:elio/services/robot/arm_profile.dart';
import 'package:flutter_test/flutter_test.dart';

ArmPose _arm() => ArmPose();

void main() {
  test('STATUS says whether the arm\'s ESP32 is heard (0240)', () {
    expect(ArmPose.esp32SilentFrom({'event': 'ack'}), isNull, reason: 'older firmware: no warning');
    expect(ArmPose.esp32SilentFrom({'esp32_age_s': null}), isTrue, reason: 'never heard');
    expect(ArmPose.esp32SilentFrom({'esp32_age_s': 7.5}), isTrue);
    expect(ArmPose.esp32SilentFrom({'esp32_age_s': 0.4}), isFalse);
  });

  group('replies while a fader is dragged (0240: the slider moved on its own)', () {
    test('an older move\'s motion_done or a STATUS mid-move does not pull the goal back', () {
      final arm = _arm();
      final first = arm.gripper(30);
      arm.commit(first, 7);
      final second = arm.gripper(80);
      arm.commit(second, 8);
      expect(arm.onServo(first.goal!, seq: 7, done: true), isFalse, reason: 'superseded move');
      expect(arm.onServo([...armHome], seq: 9, done: false), isFalse, reason: 'STATUS mid-move');
      expect(arm.gripperWidth, closeTo(80, 1e-9));
      expect(arm.onServo(second.goal!, seq: 8, done: true), isTrue, reason: 'the latest move ended');
      expect(arm.movingSeq, isNull);
      expect(arm.onServo([...armHome], seq: 10, done: false), isTrue, reason: 'at rest: STATUS is the truth');
      expect(arm.gripperWidth, 0);
    });

    test('STOP and HOME forget the move on its way', () {
      final arm = _arm()..commit(_arm().gripper(50), 3);
      arm.markUnknown();
      expect(arm.onServo([...armHome], seq: 4, done: false), isTrue);
      arm.commit(arm.gripper(50), 5);
      arm.markHome();
      expect(arm.movingSeq, isNull);
    });
  });

  test('home: the sim home pose, safe, already there', () {
    final m = _arm().home();
    expect(m.path, [armHome]);
    expect(m.duration, Duration.zero);
    expect(armHome, [180, 90, 0, 180, 90, 90]);
  });

  test('BASIS: a quarter turn is fine, turning the low arm over the tank is refused', () {
    final arm = _arm();
    final ok = arm.base(150);
    expect(ok.refusal, isNull);
    arm.commit(ok);
    expect(arm.baseServo, 150);
    expect(arm.base(270).refusal, ArmRefusal.tank, reason: 'home arm at base 180 sim: J4 behind, z 90 < 167');
  });

  test('raised arm may turn behind; the planner keeps it clear of the tank', () {
    final arm = _arm();
    final up = arm.height(1);
    expect(up.refusal, isNull, reason: '${up.refusal}');
    arm.commit(up);
    final turn = arm.base(270);
    expect(turn.refusal, isNull, reason: '${turn.refusal}');
    for (final leg in turn.path!) {
      expect(unsafePose(armToSim(leg)), isFalse);
    }
  });

  test('servo goals are clamped to each axis range', () {
    final arm = _arm();
    arm.commit(arm.plan([...armHome]..[0] = 0));
    expect(arm.goal[0], 60, reason: 'gripper servo range 60..180');
    expect(arm.base(-200).refusal, ArmRefusal.tank, reason: 'clamped to -90 (sim -180): the low arm is behind');
  });

  test('PICK closes to 75 + offset, RELEASE opens to 180, width maps between', () {
    final arm = _arm()..gripClosedOffset = 5;
    arm.commit(arm.close());
    expect(arm.goal[0], 80);
    expect(arm.gripperWidth, 100);
    arm.commit(arm.gripper(50));
    expect(arm.goal[0], 130);
    arm.commit(arm.open());
    expect(arm.goal[0], 180);
    expect(arm.gripperWidth, 0);
  });

  test('reach and height move the end effector along one axis, keeping the other', () {
    final arm = _arm();
    final h0 = arm.heightMm;
    final m = arm.reach(0.5);
    expect(m.refusal, isNull, reason: '${m.refusal}');
    arm.commit(m);
    expect(arm.reachFraction, closeTo(0.5, 1e-3));
    expect(arm.heightMm, closeTo(h0, 0.5));
    final r0 = arm.reachMm;
    arm.commit(arm.height(0.6));
    expect(arm.heightFraction, closeTo(0.6, 1e-3));
    expect(arm.reachMm, closeTo(r0, 0.5));
  });

  test('an unreachable point is refused and nothing changes', () {
    final arm = _arm();
    final before = arm.goal;
    expect(arm.reach(1).refusal, isNotNull, reason: '320 mm forward at z 90 is outside the joint limits');
    expect(arm.goal, before);
  });

  test('after a STOP or an R1 sort only the firmware HOME may move the arm', () {
    final arm = _arm()..markUnknown();
    expect(arm.home().refusal, ArmRefusal.unknownPose);
    expect(arm.reach(0.5).refusal, ArmRefusal.unknownPose);
    arm.markHome();
    expect(arm.base(120).refusal, isNull);
  });

  test('move time follows the sim (0240): Arm B 180 deg at 24 deg/s with 33 % ramps takes 180 / 0.67 / 24 s', () {
    final to = [...armHome]..[3] = 0;
    expect(legSeconds(armHome, to), closeTo(180 / 0.67 / 24, 1e-9));
  });

  test("ArmPose times its moves with the settings' profile", () {
    final arm = _arm();
    final fast = arm.base(120).duration;
    arm.profile = {...defaultArmProfile, 'Arm Base': const ArmAxisProfile(8, 0.33, 0.33)};
    expect(arm.base(120).duration.inMilliseconds, closeTo(fast.inMilliseconds * 4, 2));
  });

  test('the pose the MaixCAM2 reports makes the arm known again (0235)', () {
    final arm = _arm()..markUnknown();
    expect(ArmPose.servoFrom(null), isNull);
    expect(ArmPose.servoFrom([1, 2, 3]), isNull);
    final reported = ArmPose.servoFrom([75, 90, 30.5, 120, 100, 90])!;
    arm.sync(reported);
    expect(arm.known, isTrue);
    expect(arm.goal, [75, 90, 30.5, 120, 100, 90]);
    expect(arm.home().refusal, isNull, reason: 'HOME is planned from the reported pose');
  });

  test('0241: a new close offset re-closes a closed gripper (the sim keeps it closed), not an open one', () {
    final arm = _arm();
    arm.commit(arm.close());
    expect(arm.setGripClosedOffset(4), isTrue, reason: 'closed at 75: follow to 79');
    expect(arm.close().goal![0], 79);
    arm.commit(arm.close());
    expect(arm.setGripClosedOffset(4), isFalse, reason: 'same offset: nothing to do');
    arm.commit(arm.open());
    expect(arm.setGripClosedOffset(-2), isFalse, reason: 'open stays open');
    expect(arm.gripClosedServo, 73);
  });

  test('0241: STATUS without a pose or a pose_unknown refusal means the robot lost the arm (ESP32 reset)', () {
    expect(ArmPose.poseUnknownFrom({'event': 'ack', 'seq': 1, 'servo': null, 'esp32_boot': 'reason=POWERON'}), isTrue);
    expect(ArmPose.poseUnknownFrom({'event': 'error', 'seq': 2, 'reason': 'pose_unknown'}), isTrue);
    expect(ArmPose.poseUnknownFrom({'event': 'ack', 'seq': 3, 'servo': [180, 90, 0, 180, 90, 90]}), isFalse);
    expect(ArmPose.poseUnknownFrom({'event': 'ack', 'seq': 4}), isFalse, reason: 'an ack without a servo field says nothing');
    expect(ArmPose.poseUnknownFrom({'event': 'error', 'seq': 5, 'reason': 'tank'}), isFalse);
  });
}
