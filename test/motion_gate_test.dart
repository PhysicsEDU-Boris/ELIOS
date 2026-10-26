// Emergency stop, motion gate, link loss and heartbeat (decision 0026).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/robot/motion_gate.dart';
import 'package:elio/services/robot/r1_orchestrator.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:elio/services/robot/simulated_robot.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every message on the wire, in order: 0023 commands as maps, motor as "motor l,r", servo as "servo part=v".
class _Wire {
  final sent = <String>[];
  final events = <(String, Map<String, Object?>)>[];
  final stops = <String>[];
  final armMotions = <Duration>[];
  late final MaixCamRobot robot = MaixCamRobot(
    sink: (m) {
      if (gate.allowsCommand(m)) sent.add(m['cmd'] as String);
    },
    motor: (l, r) => sent.add('motor $l,$r'),
  );
  late final MotionGate gate = MotionGate(
    robot: robot,
    sendServo: (part, v) => sent.add('servo $part=$v'),
    onEvent: (e, d) => events.add((e, d)),
    onStop: stops.add,
    onArmCommand: armMotions.add,
  );

  List<String> since(int n) => sent.sublist(n);
  int count(String s) => sent.where((x) => x == s).length;
}

void main() {
  testWidgets('STOP: STOP + motor 0,0 at once, 0,0 repeated, everything blocked until Lanjutkan', (tester) async {
    final w = _Wire()..gate.linkRestored();
    await tester.pump(const Duration(milliseconds: 600));
    expect(w.gate.motor(75, 75), isTrue);
    expect(w.gate.servo('base', 120), isTrue);
    final before = w.sent.length;
    w.gate.emergencyStop('button');
    expect(w.since(before).take(2), ['STOP', 'motor 0,0'], reason: 'immediately, in this order');
    expect(w.stops, ['button'], reason: "R1's safe exit");
    expect(w.events.last.$1, 'emergency_stop');
    expect(w.events.last.$2, {'reason': 'button', 'linkUp': true});
    await tester.pump(const Duration(milliseconds: 500));
    expect(w.since(before).where((s) => s == 'motor 0,0').length, 5, reason: 'once now, 4 repeats');
    expect(w.gate.motor(75, 75), isFalse);
    expect(w.gate.servo('elbow', 30), isFalse);
    expect(w.gate.servo('reach', 90), isFalse);
    expect(w.gate.servo('height', 90), isFalse);
    expect(w.gate.home(), isFalse);
    expect(w.gate.servo('gripper', 100), isFalse);
    expect(w.gate.blocked, 6);
    w.robot.pick(distCm: 24);
    w.robot.home();
    w.robot.unlockDrive();
    expect(w.since(before).where((s) => !s.startsWith('motor') && s != 'HEARTBEAT'), ['STOP'],
        reason: 'R1 commands blocked too (only STOP, STATUS, HEARTBEAT pass)');
    expect(w.gate.stopWheels(), isTrue, reason: 'motor 0,0 always passes');
    w.gate.resume();
    expect(w.gate.stopped, isFalse);
    expect(w.gate.motor(75, 75), isTrue);
    expect(w.events.map((e) => e.$1), contains('emergency_resume'));
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1)); // the stop repeats run out
  });

  testWidgets('the drive lock blocks wheels but never motor 0,0; no link blocks everything', (tester) async {
    final w = _Wire()..gate.linkRestored();
    w.robot.driveLocked = true;
    expect(w.gate.motor(50, 50), isFalse);
    expect(w.gate.motor(0, 0), isTrue);
    expect(w.events.where((e) => e.$1 == 'motion_blocked').single.$2['reason'], 'drive_locked');
    w.robot.driveLocked = false;
    w.gate.linkLost();
    final before = w.sent.length;
    expect(w.gate.motor(50, 50), isFalse);
    expect(w.gate.servo('base', 10), isFalse);
    expect(w.gate.stopWheels(), isFalse, reason: 'nothing can go out without a link');
    expect(w.sent.length, before);
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1)); // the stop repeats run out
  });

  testWidgets('link loss: STOPPED (link_lost); the reconnect sends STOP + 0,0 first; Lanjutkan needed', (tester) async {
    final w = _Wire()..gate.linkRestored();
    w.gate.motor(75, 75); // driving when the link dies: that command stays in force on the robot
    w.gate.linkLost();
    expect(w.gate.stopped, isTrue);
    expect(w.gate.stopReason, 'link_lost');
    expect(w.stops, ['link_lost']);
    await tester.pump(const Duration(seconds: 2));
    final before = w.sent.length;
    w.gate.linkRestored();
    expect(w.since(before).take(2), ['STOP', 'motor 0,0'], reason: 'before anything else');
    expect(w.gate.stopped, isTrue, reason: 'still STOPPED after the reconnect');
    expect(w.gate.motor(75, 75), isFalse);
    w.gate.resume();
    expect(w.gate.motor(75, 75), isTrue);
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1)); // the stop repeats run out
  });

  testWidgets('heartbeat ~4 Hz while connected, also while STOPPED, none without a link', (tester) async {
    final w = _Wire()..gate.linkRestored();
    await tester.pump(const Duration(seconds: 2));
    expect(w.count('HEARTBEAT'), 8);
    w.gate.emergencyStop('button');
    await tester.pump(const Duration(seconds: 1));
    expect(w.count('HEARTBEAT'), 12);
    w.gate.linkLost();
    await tester.pump(const Duration(seconds: 2));
    expect(w.count('HEARTBEAT'), 12);
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1)); // the stop repeats run out
  });

  testWidgets('leaving the screen (dispose) sends motor 0,0 and stops the heartbeat', (tester) async {
    final w = _Wire()..gate.linkRestored();
    w.gate.motor(75, 75);
    w.gate.dispose();
    expect(w.sent.last, 'motor 0,0');
    final n = w.count('HEARTBEAT');
    await tester.pump(const Duration(seconds: 1));
    expect(w.count('HEARTBEAT'), n);
  });

  testWidgets('the app going to the background sends motor 0,0; coming back sends nothing', (tester) async {
    final w = _Wire()..gate.linkRestored();
    w.gate.motor(75, 75);
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
        AppLifecycleState.detached]) {
      final n = w.sent.length;
      w.gate.onAppLifecycle(state);
      expect(w.since(n), ['motor 0,0'], reason: state.name);
    }
    final n = w.sent.length;
    w.gate.onAppLifecycle(AppLifecycleState.resumed);
    expect(w.since(n).where((s) => s.startsWith('motor')), isEmpty);
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  test('a disconnect sends motor 0,0 before the disconnect message (every disconnect path)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <String>[];
    final done = Completer<void>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(jsonEncode({'status': 'Connected'}));
      socket.listen((m) {
        received.add(m as String);
        if (m.contains('"disconnect"') && !done.isCompleted) done.complete();
      });
    });
    final ws = WebSocketService()..configure('127.0.0.1', server.port);
    expect(await ws.connect(), isTrue);
    await ws.disconnect();
    await done.future.timeout(const Duration(seconds: 5));
    await server.close(force: true);
    final motor = received.indexWhere((m) => m.contains('"motor"'));
    expect(motor, isNonNegative);
    expect(jsonDecode(received[motor]), {'cmd': 'motor', 'left': 0, 'right': 0});
    expect(motor, lessThan(received.indexWhere((m) => m.contains('"disconnect"'))));
  });

  testWidgets('servo commands estimate the arm motion at 60 deg/s (J1 guard)', (tester) async {
    final w = _Wire()..gate.linkRestored();
    w.gate
      ..servo('base', 90)
      ..servo('base', 150)
      ..servo('base', 135);
    expect(w.armMotions, [const Duration(seconds: 3), const Duration(seconds: 1), const Duration(milliseconds: 250)],
        reason: 'unknown start: full 180 deg; then the angle change');
    expect(w.sent.where((s) => s.startsWith('servo')), ['servo base=90', 'servo base=150', 'servo base=135']);
    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1)); // the stop repeats run out
  });

  testWidgets('R1 sorting blocks manual servo commands', (tester) async {
    var busy = true;
    final sent = <String>[];
    final robot = MaixCamRobot(sink: (_) {}, motor: (l, r) {});
    final gate = MotionGate(robot: robot, sendServo: (p, v) => sent.add(p), armBusy: () => busy)..linkRestored();
    expect(gate.servo('base', 90), isFalse);
    busy = false;
    expect(gate.servo('base', 90), isTrue);
    gate.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  test('every motor and servo send in lib/ goes through the gate', () {
    final allowed = {'lib/services/websocket_service.dart', 'lib/services/robot/motion_gate.dart'};
    final direct = RegExp(r'sendMotorCommand\(|sendServoCommand\(|\.sendMotor\(|\.transmitMotor\(|\.pickUp\(|\.release\(\)');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && !allowed.contains(f.path) && !f.path.startsWith('lib/services/robot/'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (direct.hasMatch(line)) '${f.path}:${i + 1}: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });

  group('R1 on an emergency stop', () {
    final t0 = DateTime(2026);
    test('mid-sort: STOP sent, driving stays locked; only Lanjutkan unlocks it', () {
      var now = 0;
      DateTime clock() => t0.add(Duration(milliseconds: now));
      final robot = SimulatedRobot(clock);
      final r1 = R1Orchestrator(robot, clock: clock)..linkUp();
      void run(int ms) {
        for (final end = now + ms; now < end;) {
          now += 100;
          robot.tick();
          r1.onFrame(robot.frame());
        }
      }

      run(300);
      r1.onLock(const TrackedDetection(label: 'Plastic', x: 320, y: 300, w: 120, h: 160, score: 0.9));
      run(300);
      r1
        ..onIdentified(Bin.anorganik)
        ..onStudentBin(Bin.organik);
      run(4500);
      r1.onAmbil();
      run(1000);
      final before = robot.sent.length;
      r1.emergencyStop('button');
      expect(robot.commands.sublist(before), ['STOP'], reason: 'no UNLOCK_DRIVE yet');
      expect(robot.driveLocked, isTrue);
      expect(r1.state, R1State.searching);
      expect(r1.message, contains('Lanjutkan'));
      r1.linkUp(); // a reconnect alone does not unlock
      expect(robot.commands.sublist(before), ['STOP', 'STATUS']);
      r1.resumeAfterStop();
      expect(robot.commands.last, 'UNLOCK_DRIVE');
      expect(robot.driveLocked, isFalse);
    });
  });

  testWidgets('gate blocks HOME and height while STOPPED (decision 0027)', (tester) async {
    final w = _Wire()..gate.linkRestored();
    await tester.pump(const Duration(milliseconds: 600));
    expect(w.gate.home(), isTrue);
    expect(w.sent.contains('HOME'), isTrue);
    expect(w.gate.servo('height', 90), isTrue);
    expect(w.sent.contains('servo height=90'), isTrue);

    w.gate.emergencyStop('button');
    final countBefore = w.gate.blocked;
    final sentBefore = w.sent.length;

    expect(w.gate.home(), isFalse);
    expect(w.gate.servo('height', 120), isFalse);
    expect(w.gate.blocked, countBefore + 2);
    expect(w.sent.length, sentBefore, reason: 'neither HOME nor servo height sent while stopped');

    w.robot.home();
    expect(w.sent.length, sentBefore, reason: 'robot.home() blocked by allowsCommand while stopped');

    w.gate.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
