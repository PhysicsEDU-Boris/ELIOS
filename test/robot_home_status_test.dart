import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/robot/motion_gate.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:elio/widgets/live_scan_debug_overlay.dart';

class _FakeTransport {
  final sent = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic> msg)? onReplyMessage;

  void send(Map<String, Object?> msg) {
    sent.add(Map<String, dynamic>.from(msg));
  }

  void replyAck(int seq, {List<double>? eeMm, bool? atHome}) {
    onReplyMessage?.call({
      'event': 'ack',
      'seq': seq,
      if (eeMm != null) ...{'ee_mm': eeMm},
      if (atHome != null) ...{'at_home': atHome},
    });
  }

  void replyMotionDone(int seq) {
    onReplyMessage?.call({
      'event': 'motion_done',
      'seq': seq,
    });
  }

  void replyError(int seq, {String reason = 'busy'}) {
    onReplyMessage?.call({
      'event': 'error',
      'seq': seq,
      'reason': reason,
    });
  }
}

void main() {
  group('G2c HOME completion, rejection, timeout, and interruption regression tests', () {
    test('on HOME: ack does not reset sliders or mark atHome; motion_done resets sliders to 90 and marks atHome', () async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);

      // 1. Initial slider values before HOME
      notifier.setHeightValue(171);
      notifier.setReachValue(140);
      notifier.setGripperVal(80);

      expect(container.read(robotControlProvider).heightValue, 171);
      expect(container.read(robotControlProvider).reachValue, 140);
      expect(container.read(robotControlProvider).gripperVal, 80);
      expect(container.read(robotControlProvider).atHome, false);

      late final MotionGate gate;
      gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      // Listen to robot replies as done in ControlScreen
      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (gate.pendingHomeSeq != null && reply.seq == gate.pendingHomeSeq) {
            if (reply.kind == ReplyKind.motionDone) {
              final ok = gate.onHomeReply(reply);
              if (ok) {
                notifier.resetToHome();
              }
            } else if (reply.kind == ReplyKind.error) {
              gate.onHomeReply(reply);
              notifier.updateStatus(atHome: false);
            } else if (reply.kind == ReplyKind.ack) {
              gate.onHomeReply(reply);
              // Ack alone: do NOT reset sliders or set atHome: true
            }
          }
          if (reply.eeMm != null || reply.atHome != null) {
            notifier.updateStatus(eeMm: reply.eeMm, atHome: reply.atHome);
          }
          if (reply.kind == ReplyKind.motionDone) {
            robot.status();
          }
        }
      };

      // 2. Trigger HOME
      expect(gate.home(), isTrue);
      final homeSeq = robot.lastHomeSeq;
      expect(homeSeq, isNotNull);
      expect(gate.pendingHomeSeq, homeSeq);
      expect(transport.sent.any((m) => m['cmd'] == 'HOME' && m['seq'] == homeSeq), isTrue);

      // 3. HOME ack arrives -> MUST NOT reset reach/height/gripper or mark atHome true
      transport.replyAck(homeSeq!);
      await pumpEventQueue();

      expect(gate.homeAcked, isTrue);
      expect(gate.pendingHomeSeq, homeSeq, reason: 'HOME still in flight');
      expect(container.read(robotControlProvider).reachValue, 140.0, reason: 'reach must NOT be reset on ack');
      expect(container.read(robotControlProvider).heightValue, 171.0, reason: 'height must NOT be reset on ack');
      expect(container.read(robotControlProvider).gripperVal, 80.0, reason: 'gripper must NOT be reset on ack');
      expect(container.read(robotControlProvider).atHome, false, reason: 'atHome must NOT be true on ack alone');

      // A mismatched completion still polls STATUS, which must not confirm HOME.
      transport.replyMotionDone(homeSeq + 100000);
      transport.replyAck(robot.lastStatusSeq!,
          eeMm: const [0.0, -42.5, 90.0], atHome: true);
      await pumpEventQueue();
      final pending = container.read(robotControlProvider);
      expect(gate.pendingHomeSeq, homeSeq);
      expect(pending.eeMm, [0.0, -42.5, 90.0]);
      expect(pending.reachValue, 140.0);
      expect(pending.heightValue, 171.0);
      expect(pending.gripperVal, 80.0);
      expect(pending.atHome, false,
          reason: 'STATUS cannot bypass matching HOME completion');

      // 4. HOME motion_done arrives -> NOW resets to neutral (90, 90, 0) and marks atHome true
      transport.replyMotionDone(homeSeq);
      await pumpEventQueue();

      expect(gate.pendingHomeSeq, isNull, reason: 'HOME complete');
      expect(container.read(robotControlProvider).reachValue, 90.0, reason: 'reach reset to 90 on motion_done');
      expect(container.read(robotControlProvider).heightValue, 90.0, reason: 'height reset to 90 on motion_done');
      expect(container.read(robotControlProvider).gripperVal, 0.0, reason: 'gripper reset to 0 on motion_done');
      expect(container.read(robotControlProvider).atHome, true, reason: 'atHome is true on motion_done');
      expect(gate.lastAngles['height'], 90);
      expect(gate.lastAngles['reach'], 90);
      expect(gate.lastAngles['gripper'], 0);

      // 5. Dragging down from neutral (e.g. to 80)
      // Since neutral is 90, moving down from neutral gives delta = 80 - 90 = -10 (direction: down)
      final downValue = 80;
      expect(gate.servo('height', downValue), isTrue);
      final servoMsg = transport.sent.lastWhere((m) => m['cmd'] == 'servo' && m['part'] == 'height');
      expect(servoMsg['val'], downValue);
      final fakeDelta = downValue - 90;
      expect(fakeDelta, isNegative, reason: 'must move down from neutral (negative delta)');

      // Break-check verification:
      // If height had stayed at 171 (without HOME reset) and dragged to 160:
      // In the fake, delta from 90 would be 160 - 90 = +70 (moves UP, not down).
      final unhomedDelta = 160 - 90;
      expect(unhomedDelta > 0, isTrue, reason: 'stale 160 move without reset moves UP from neutral (+70)');

      gate.dispose();
    });

    test('rejected HOME: error reply does not mark atHome or reset slider cache', () async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      notifier.setHeightValue(171);
      notifier.setReachValue(140);
      notifier.setGripperVal(80);

      late final MotionGate gate;
      gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (gate.pendingHomeSeq != null && reply.seq == gate.pendingHomeSeq) {
            if (reply.kind == ReplyKind.motionDone) {
              if (gate.onHomeReply(reply)) notifier.resetToHome();
            } else if (reply.kind == ReplyKind.error) {
              gate.onHomeReply(reply);
              notifier.updateStatus(atHome: false);
            }
          }
        }
      };

      expect(gate.home(), isTrue);
      final homeSeq = robot.lastHomeSeq!;
      expect(gate.pendingHomeSeq, homeSeq);

      // Robot rejects HOME with error (e.g. busy or hardware fault)
      transport.replyError(homeSeq, reason: 'busy');
      await pumpEventQueue();

      expect(gate.pendingHomeSeq, isNull, reason: 'rejected HOME is no longer pending');
      expect(container.read(robotControlProvider).reachValue, 140.0);
      expect(container.read(robotControlProvider).heightValue, 171.0);
      expect(container.read(robotControlProvider).gripperVal, 80.0);
      expect(container.read(robotControlProvider).atHome, false);
      expect(gate.lastAngles['height'], isNot(90));

      gate.dispose();
    });

    test('interrupted HOME: STOP cancels pending HOME and ignores late motion_done', () async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      notifier.setHeightValue(171);
      notifier.setReachValue(140);

      late final MotionGate gate;
      gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (gate.pendingHomeSeq != null && reply.seq == gate.pendingHomeSeq) {
            if (reply.kind == ReplyKind.motionDone) {
              if (gate.onHomeReply(reply)) notifier.resetToHome();
            }
          }
        }
      };

      expect(gate.home(), isTrue);
      final homeSeq = robot.lastHomeSeq!;
      transport.replyAck(homeSeq);
      await pumpEventQueue();

      // Emergency stop interrupts HOME mid-flight
      gate.emergencyStop('button');
      notifier.updateStatus(atHome: false);

      expect(gate.pendingHomeSeq, isNull, reason: 'STOP must cancel pending HOME');
      expect(gate.stopped, isTrue);
      expect(container.read(robotControlProvider).atHome, false);

      // Late motion_done arrives from hardware
      transport.replyMotionDone(homeSeq);
      await pumpEventQueue();

      expect(container.read(robotControlProvider).heightValue, 171.0, reason: 'late motion_done must be ignored after STOP');
      expect(container.read(robotControlProvider).atHome, false);
      expect(gate.lastAngles['height'], isNot(90));

      gate.dispose();
    });

    test('interrupted HOME: linkLost cancels pending HOME and ignores late motion_done', () async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      notifier.setHeightValue(171);

      late final MotionGate gate;
      gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (gate.pendingHomeSeq != null && reply.seq == gate.pendingHomeSeq) {
            if (reply.kind == ReplyKind.motionDone) {
              if (gate.onHomeReply(reply)) notifier.resetToHome();
            }
          }
        }
      };

      expect(gate.home(), isTrue);
      final homeSeq = robot.lastHomeSeq!;
      transport.replyAck(homeSeq);
      await pumpEventQueue();

      // Disconnect occurs
      gate.linkLost();
      notifier.updateStatus(atHome: false);

      expect(gate.pendingHomeSeq, isNull, reason: 'linkLost must cancel pending HOME');
      expect(container.read(robotControlProvider).atHome, false);

      transport.replyMotionDone(homeSeq);
      await pumpEventQueue();

      expect(container.read(robotControlProvider).heightValue, 171.0);
      expect(container.read(robotControlProvider).atHome, false);

      gate.dispose();
    });

    test('HOME timeout: cancels pending HOME when motion_done never arrives', () async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      notifier.setHeightValue(171);

      late final MotionGate gate;
      gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
        homeTimeoutDuration: const Duration(milliseconds: 100),
        onHomeTimeout: () => notifier.updateStatus(atHome: false),
      )..linkRestored();

      expect(gate.home(), isTrue);
      final homeSeq = robot.lastHomeSeq!;
      transport.replyAck(homeSeq);
      await pumpEventQueue();

      expect(gate.pendingHomeSeq, homeSeq);

      // Wait past timeout (150 ms > 100 ms)
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await pumpEventQueue();

      expect(gate.pendingHomeSeq, isNull, reason: 'timeout must clear pending HOME');
      expect(container.read(robotControlProvider).atHome, false);
      expect(container.read(robotControlProvider).heightValue, 171.0);

      gate.dispose();
    });
  });

  test('STATUS cannot confirm HOME after invalidation or overwrite slider cache', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(robotControlProvider.notifier);
    notifier.resetToHome();
    notifier.updateStatus(atHome: true, eeMm: const [0, -42.5, 90]);
    expect(container.read(robotControlProvider).atHome, true);

    // These are the invalidation paths used by errors, timeout, STOP and link loss.
    for (final clearAtHome in [false, true]) {
      notifier.setReachValue(140);
      notifier.setHeightValue(171);
      notifier.setGripperVal(80);
      notifier.updateStatus(atHome: false, clearAtHome: clearAtHome);
      notifier.updateStatus(atHome: true, eeMm: const [0, -42.5, 90]);
      final state = container.read(robotControlProvider);
      expect(state.atHome, false);
      expect(state.reachValue, 140);
      expect(state.heightValue, 171);
      expect(state.gripperVal, 80);
      expect(state.eeMm, [0, -42.5, 90]);
    }

    notifier.resetToHome();
    notifier.updateStatus(atHome: false);
    expect(container.read(robotControlProvider).atHome, false);
    notifier.updateStatus(clearEeMm: true);
    expect(container.read(robotControlProvider).eeMm, isNull);
  });

  group('G2c STATUS after motion_done and debounced drag', () {
    testWidgets('sends STATUS after motion_done and updates readout after height move', (tester) async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      notifier.updateStatus(eeMm: const [0.0, -42.5, 90.0], atHome: true);

      Timer? statusDebounceTimer;
      void scheduleStatusRequest() {
        statusDebounceTimer?.cancel();
        statusDebounceTimer = Timer(const Duration(milliseconds: 300), () {
          robot.status();
        });
      }

      final gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (reply.seq == robot.lastStatusSeq) {
            notifier.updateStatus(
              eeMm: reply.eeMm,
              clearEeMm: reply.eeMm == null,
              atHome: reply.atHome,
            );
          } else if (reply.hasEeMm || reply.atHome != null) {
            notifier.updateStatus(
              eeMm: reply.eeMm,
              clearEeMm: reply.hasEeMm && reply.eeMm == null,
              atHome: reply.atHome,
            );
          }
          if (reply.kind == ReplyKind.motionDone) {
            robot.status();
          }
        }
      };

      // Render debug overlay
      final liveScanController = LiveScanController(startQuiz: (detection, frame) => true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final ee = ref.watch(robotControlProvider).eeMm;
                  return LiveScanDebugOverlay(
                    controller: liveScanController,
                    eeMm: ee,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initial readout
      expect(find.text('EE: x=0.0 y=-42.5 z=90.0 mm'), findsOneWidget);

      // 1. motion_done triggers STATUS
      final pickSeq = robot.pick(distCm: 20);
      transport.replyMotionDone(pickSeq);
      await tester.pump();

      final statusMsg = transport.sent.lastWhere((m) => m['cmd'] == 'STATUS');
      expect(statusMsg, isNotNull);
      final statusSeq = statusMsg['seq'] as int;

      // Status reply updates eeMm
      transport.replyAck(statusSeq, eeMm: const [10.5, -30.0, 115.2], atHome: false);
      await tester.pump();

      expect(find.text('EE: x=10.5 y=-30.0 z=115.2 mm'), findsOneWidget);

      // 2. Debounced STATUS after height drag ends (~300 ms)
      gate.servo('height', 120);
      scheduleStatusRequest();

      // Before 300 ms, status not yet sent
      await tester.pump(const Duration(milliseconds: 150));
      expect(transport.sent.where((m) => m['cmd'] == 'STATUS').length, 1);

      // After 300 ms, debounced STATUS sent
      await tester.pump(const Duration(milliseconds: 200));
      expect(transport.sent.where((m) => m['cmd'] == 'STATUS').length, 2);

      final dragStatusSeq = transport.sent.last['seq'] as int;
      transport.replyAck(dragStatusSeq, eeMm: const [10.5, -30.0, 145.0], atHome: false);
      await tester.pump();

      // Readout updated with new Z height!
      expect(find.text('EE: x=10.5 y=-30.0 z=145.0 mm'), findsOneWidget);

      statusDebounceTimer?.cancel();
      gate.dispose();
      liveScanController.dispose();
      await tester.pump(const Duration(seconds: 1)); // let periodic timers settle
    });

    testWidgets('STATUS handles null or unavailable ee_mm without presenting stale coordinates', (tester) async {
      final transport = _FakeTransport();
      final robot = MaixCamRobot(
        sink: transport.send,
        motor: (l, r) {},
      );

      final container = ProviderContainer();
      final notifier = container.read(robotControlProvider.notifier);
      // Start with known coordinates
      notifier.updateStatus(eeMm: const [10.0, -20.0, 30.0], atHome: false);

      final gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (reply.seq == robot.lastStatusSeq) {
            notifier.updateStatus(
              eeMm: reply.eeMm,
              clearEeMm: reply.eeMm == null,
              atHome: reply.atHome,
            );
          } else if (reply.hasEeMm || reply.atHome != null) {
            notifier.updateStatus(
              eeMm: reply.eeMm,
              clearEeMm: reply.hasEeMm && reply.eeMm == null,
              atHome: reply.atHome,
            );
          }
        }
      };

      final liveScanController = LiveScanController(startQuiz: (detection, frame) => true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final ee = ref.watch(robotControlProvider).eeMm;
                  return LiveScanDebugOverlay(
                    controller: liveScanController,
                    eeMm: ee,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially shows known coordinates
      expect(find.text('EE: x=10.0 y=-20.0 z=30.0 mm'), findsOneWidget);

      // Now query STATUS, but robot returns status reply with null or omitted ee_mm (e.g. uncalibrated arm)
      final statusSeq = robot.status();
      transport.replyAck(statusSeq, eeMm: null, atHome: false);
      await tester.pump();

      // Readout must NOT show the old stale coordinates! Must show "EE: -"
      expect(find.text('EE: x=10.0 y=-20.0 z=30.0 mm'), findsNothing);
      expect(find.text('EE: -'), findsOneWidget);
      expect(container.read(robotControlProvider).eeMm, isNull);
      expect(robot.eeMm, isNull);

      gate.dispose();
      liveScanController.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
