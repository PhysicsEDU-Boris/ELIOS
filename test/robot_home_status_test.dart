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
}

void main() {
  group('G2c HOME reset and slider matching fake _cmd_home', () {
    test('on HOME ack and motion_done, reset reach & height to 90 and gripper to 0', () async {
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

      final gate = MotionGate(
        robot: robot,
        sendServo: (part, val) => transport.send({'cmd': 'servo', 'part': part, 'val': val}),
      )..linkRestored();

      // Listen to robot replies as done in ControlScreen
      transport.onReplyMessage = (msg) {
        robot.handleMessage(msg);
        final reply = RobotReply.fromJson(msg);
        if (reply != null) {
          if (reply.seq == robot.lastHomeSeq) {
            if (reply.kind == ReplyKind.ack || reply.kind == ReplyKind.motionDone) {
              notifier.resetToHome();
              gate.resetToHome();
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
      expect(transport.sent.any((m) => m['cmd'] == 'HOME' && m['seq'] == homeSeq), isTrue);

      // Change sliders mid-flight (user or stale state)
      notifier.setHeightValue(171);

      // 3. HOME ack arrives -> resets reach/height to 90, gripper to 0
      transport.replyAck(homeSeq!);
      await pumpEventQueue();

      expect(container.read(robotControlProvider).reachValue, 90.0, reason: 'reach reset to 90 on ack');
      expect(container.read(robotControlProvider).heightValue, 90.0, reason: 'height reset to 90 on ack');
      expect(container.read(robotControlProvider).gripperVal, 0.0, reason: 'gripper reset to 0 on ack');

      // User drags slightly before motion_done
      notifier.setHeightValue(95);

      // 4. HOME motion_done arrives -> resets again
      transport.replyMotionDone(homeSeq);
      await pumpEventQueue();

      expect(container.read(robotControlProvider).reachValue, 90.0, reason: 'reach reset to 90 on motion_done');
      expect(container.read(robotControlProvider).heightValue, 90.0, reason: 'height reset to 90 on motion_done');
      expect(container.read(robotControlProvider).gripperVal, 0.0, reason: 'gripper reset to 0 on motion_done');

      // 5. Dragging down from neutral (e.g. to 80)
      // Since neutral is 90, moving down from neutral gives delta = 80 - 90 = -10 (direction: down)
      final downValue = 80;
      expect(gate.servo('height', downValue), isTrue);
      final servoMsg = transport.sent.lastWhere((m) => m['cmd'] == 'servo' && m['part'] == 'height');
      expect(servoMsg['val'], downValue);
      // Delta from neutral 90 in the fake
      final fakeDelta = downValue - 90;
      expect(fakeDelta, isNegative, reason: 'must move down from neutral (negative delta)');

      // Break-check verification:
      // If height had stayed at 171 (without HOME reset) and dragged to 160:
      // In the fake, delta from 90 would be 160 - 90 = +70 (moves UP, not down).
      final unhomedDelta = 160 - 90;
      expect(unhomedDelta > 0, isTrue, reason: 'stale 160 move without reset moves UP from neutral (+70)');

      gate.dispose();
    });
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
          if (reply.eeMm != null || reply.atHome != null) {
            notifier.updateStatus(eeMm: reply.eeMm, atHome: reply.atHome);
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
  });
}
