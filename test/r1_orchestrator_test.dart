// R1 orchestration (decisions 0021, 0023), on the simulated robot.
import 'package:elio/l10n/l10n.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/robot/r1_constants.dart';
import 'package:elio/services/robot/r1_orchestrator.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:elio/services/robot/simulated_robot.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);
const _lockBox = TrackedDetection(label: 'Plastic', x: 320, y: 300, w: 120, h: 160, score: 0.9);
const _armCmds = {'PICK', 'MOVE_TO_BIN', 'DROP', 'HOLD'};

class _Rig {
  _Rig({bool connect = true, void Function(SimulatedRobot)? setup}) {
    robot = SimulatedRobot(clock);
    setup?.call(robot);
    r1 = R1Orchestrator(robot, clock: clock, onResume: resumes.add, onEvent: (e, d) {
      if (e == 'r1_state') states.add(d['state'] as String);
    });
    if (connect) {
      r1.linkUp();
      run(300);
    }
  }

  int now = 0;
  DateTime clock() => _t0.add(Duration(milliseconds: now));
  late final SimulatedRobot robot;
  late final R1Orchestrator r1;
  final resumes = <String>[];
  final states = <String>[];

  /// Advances [ms] in 100 ms frames: replies delivered, the sim's frame analysed.
  void run(int ms, {bool frames = true}) {
    for (final end = now + ms; now < end;) {
      now += 100;
      robot.tick();
      frames ? r1.onFrame(robot.frame(), armTags: robot.armTags()) : r1.tick();
    }
  }

  List<String> get cmds => robot.commands;
  int count(String cmd) => cmds.where((c) => c == cmd).length;

  /// Lock -> identified -> student answer -> revealed -> POSITION.
  void toPosition({Bin bin = Bin.anorganik, Bin student = Bin.organik}) {
    expect(r1.onLock(_lockBox), isTrue);
    run(300);
    r1.onIdentified(bin);
    r1.onStudentBin(student);
    run(revealDuration.inMilliseconds + 200);
  }

  void toSorting() {
    toPosition();
    expect(r1.state, R1State.ready);
    r1.onAmbil();
  }

  void answerQuestions() {
    for (var i = 0; i < objectQuestionCount; i++) {
      r1.onQuestionShown();
      run(500);
      r1.onQuestionAnswered();
    }
  }

  /// The safe state every exit must reach.
  void expectSafeExit(String reason, {required bool stopped}) {
    expect(resumes.last, reason);
    expect(r1.state, R1State.searching);
    expect(robot.driveLocked, isFalse, reason: 'the app sends DRIVE again');
    expect(robot.nudgeOnly, isFalse);
    expect(cmds.last, 'UNLOCK_DRIVE', reason: 'the MaixCAM2 drops DRIVE no more');
    expect(cmds.contains('STOP'), stopped);
  }
}

void main() {
  group('happy path', () {
    test('every state in order; the student never changes the bin; drive unlocked at the end', () {
      final r = _Rig();
      expect(r.r1.robotConnected, isTrue);
      r.toSorting();
      expect(r.robot.driveLocked, isTrue);
      expect(r.count('UNLOCK_DRIVE'), 0, reason: 'dist_cm 24 is inside the band: no nudging');
      r.answerQuestions();
      r.run(15000);
      expect(r.states, [
        'objectInView', 'identifying', 'askBin', 'reveal', 'position', 'ready', 'sorting', 'waitBoth', 'resume',
        'searching',
      ]);
      expect(r.cmds, ['STATUS', 'LOCK_DRIVE', 'PICK', 'MOVE_TO_BIN', 'DROP', 'UNLOCK_DRIVE']);
      final move = r.robot.sent.firstWhere((m) => m['cmd'] == 'MOVE_TO_BIN');
      expect(move['bin'], 'anorganik', reason: 'the student answered organik; the robot uses its own bin');
      expect(r.r1.feedback.motionDoneSeq, isNotNull);
      r.expectSafeExit('done', stopped: false);
    });

    test('messages carry a rising seq; PICK carries the distance', () {
      final r = _Rig();
      r.toSorting();
      final seqs = [for (final m in r.robot.sent) m['seq'] as int];
      expect(seqs, [1, 2, 3]);
      expect(r.robot.sent.last, {'cmd': 'PICK', 'seq': 3, 'dist_cm': 24.0, 'lateral_cm': null});
    });

    test('B3: CONFIRM first; the confirmed bin is used', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      r.run(300);
      r.r1.onIdentified(Bin.anorganik, needsConfirm: true);
      expect(r.r1.state, R1State.confirm);
      r.r1.onStudentBin(Bin.organik);
      expect(r.r1.state, R1State.confirm, reason: 'no bin question before the confirmation');
      r.r1.onConfirmed(Bin.b3);
      expect(r.r1.state, R1State.askBin);
      r.r1.onStudentBin(Bin.organik);
      r.run(revealDuration.inMilliseconds + 200);
      r.r1.onAmbil();
      r.run(5000);
      expect(r.robot.sent.firstWhere((m) => m['cmd'] == 'MOVE_TO_BIN')['bin'], 'b3');
    });

    test('identification can finish before LOCK_DRIVE is acknowledged', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      r.r1.onIdentified(Bin.organik);
      expect(r.r1.state, R1State.objectInView, reason: 'driving is not locked yet');
      r.run(300);
      expect(r.r1.state, R1State.askBin);
    });
  });

  group('POSITION', () {
    test('0182: AprilTags are wanted only from POSITION through the grip', () {
      final r = _Rig(setup: (s) => s.objectDistCm = null);
      expect(r.r1.wantsArmTags, isFalse); // searching
      r.toPosition();
      expect(r.r1.wantsArmTags, isTrue);
      r.r1.onPositionConfirmed();
      expect((r.r1.state, r.r1.wantsArmTags), (R1State.ready, true));
    });

    test('no dist_cm (current firmware): the manual button, then READY', () {
      final r = _Rig(setup: (s) => s.objectDistCm = null);
      r.toPosition();
      expect(r.r1.state, R1State.position);
      expect(r.r1.showPositionButton, isTrue);
      expect(r.r1.message, 'Is the position right?');
      r.r1.onPositionConfirmed();
      expect(r.r1.state, R1State.ready);
      expect(r.count('UNLOCK_DRIVE'), 0);
    });

    test('too far: "Maju sedikit", nudges at capped speed, re-locked inside the band', () {
      final r = _Rig(setup: (s) => s.objectDistCm = 31);
      r.toPosition();
      expect(r.r1.message, 'Forward a little');
      expect(r.cmds.last, 'UNLOCK_DRIVE');
      expect(r.robot.driveLocked, isFalse);
      r.run(300);
      for (var i = 0; i < 3; i++) {
        expect(r.robot.drive(75, 75), isTrue);
        r.run(200);
      }
      expect(r.robot.motorSent.first, (40, 40), reason: 'nudges only');
      expect(r.r1.state, R1State.ready);
      expect(r.cmds.last, 'LOCK_DRIVE');
      expect(r.robot.drive(75, 75), isFalse, reason: 'locked again: the app sends nothing');
      expect(r.robot.motorSent.length, 3);
    });

    test('too close: "Mundur"', () {
      final r = _Rig(setup: (s) => s.objectDistCm = 17);
      r.toPosition();
      expect(r.r1.message, 'Back up');
    });

    test('driving stays locked from the lock to READY: DRIVE is never sent', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      expect(r.robot.drive(75, 75), isFalse);
      r.run(300);
      r.r1.onIdentified(Bin.organik);
      expect(r.robot.drive(75, 75), isFalse);
      expect(r.robot.motorSent, isEmpty);
    });
  });

  group('timeouts (each ends in the safe state)', () {
    test('BIN_TIMEOUT: no answer, reveal anyway', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      r.run(300);
      r.r1.onIdentified(Bin.organik);
      r.run(binTimeout.inMilliseconds - 200);
      expect(r.r1.state, R1State.askBin);
      r.run(300);
      expect(r.r1.state, R1State.reveal);
      expect(r.r1.studentBin, isNull);
    });

    test('IDENTIFY timeout', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      r.run(identifyTimeout.inMilliseconds + 500);
      r.expectSafeExit('timeout_identify', stopped: false);
    });

    test('CONFIRM timeout', () {
      final r = _Rig();
      r.r1.onLock(_lockBox);
      r.run(300);
      r.r1.onIdentified(Bin.b3, needsConfirm: true);
      r.run(confirmTimeout.inMilliseconds + 200);
      r.expectSafeExit('timeout_confirm', stopped: false);
    });

    test('POSITION_TIMEOUT, also while nudging', () {
      final r = _Rig(setup: (s) => s.objectDistCm = 40);
      r.toPosition();
      r.run(positionTimeout.inMilliseconds);
      r.expectSafeExit('timeout_position', stopped: false);
    });

    test('POSITION_TIMEOUT covers READY (no "Ambil")', () {
      final r = _Rig();
      r.toPosition();
      r.run(positionTimeout.inMilliseconds);
      r.expectSafeExit('timeout_position', stopped: false);
    });

    test('ack timeout: LOCK_DRIVE never acknowledged', () {
      final r = _Rig(setup: (s) => s.dropReplies['LOCK_DRIVE'] = 'ack');
      r.r1.onLock(_lockBox);
      r.run(ackTimeout.inMilliseconds + 200);
      r.expectSafeExit('robot_unreachable', stopped: false);
      expect(r.r1.robotConnected, isFalse);
    });

    test('ARM_TIMEOUT: motion_done never comes; the arm is stopped', () {
      final r = _Rig(setup: (s) => s.dropReplies['PICK'] = 'motion_done');
      r.toSorting();
      r.run(armTimeout.inMilliseconds + 500);
      r.expectSafeExit('robot_error', stopped: true);
    });

    test('QUESTION_TIMEOUT: unanswered questions end on their own', () {
      final r = _Rig();
      r.toSorting();
      r.run(objectQuestionCount * questionTimeout.inMilliseconds + armSettle.inMilliseconds + 500);
      expect(r.resumes, ['done']);
    });

    test('WAIT_CAP: a hand that never leaves', () {
      final r = _Rig();
      r.toSorting();
      r.robot.handInView = true;
      r.run(waitCap.inMilliseconds + 200);
      r.expectSafeExit('timeout_wait_cap', stopped: true);
    });
  });

  group('the arm', () {
    test('never moves before REVEAL: "Ambil", hands and frames before READY send no arm command', () {
      final r = _Rig();
      void poke() {
        r.r1.onAmbil();
        r.robot.handInView = true;
        r.run(200);
        r.robot.handInView = false;
        r.run(1200);
        expect(r.cmds.where(_armCmds.contains), isEmpty, reason: r.r1.state.name);
      }

      r.r1.onLock(_lockBox);
      poke();
      r.r1.onIdentified(Bin.organik, needsConfirm: true);
      poke();
      r.r1.onConfirmed(Bin.organik);
      poke();
      r.r1.onStudentBin(Bin.organik);
      expect(r.r1.state, R1State.reveal);
      r.r1.onAmbil();
      expect(r.cmds.where(_armCmds.contains), isEmpty);
      r.run(revealDuration.inMilliseconds);
      expect(r.r1.state, R1State.ready);
      r.r1.onAmbil();
      expect(r.cmds.last, 'PICK');
    });

    test('the object never leaves the floor: pick failed, arm stopped, drive unlocked', () {
      final r = _Rig(setup: (s) => s.pickMisses = true);
      r.toSorting();
      r.run(6000); // PICK done at 4.1 s; the spot may still clear until 6.1 s
      expect(r.resumes, isEmpty);
      r.run(300);
      expect(r.r1.feedback.objectLeftFloor, isFalse);
      expect(r.count('MOVE_TO_BIN'), 0);
      r.expectSafeExit('pick_failed', stopped: true);
    });

    test('motion_done alone is not enough: the floor spot must be empty', () {
      final r = _Rig();
      r.toSorting();
      r.run(4300); // PICK done at 4.1 s (ack 0.1 + motion 4)
      expect(r.count('MOVE_TO_BIN'), 0, reason: 'the spot was seen empty for less than 0.6 s');
      r.run(600);
      expect(r.count('MOVE_TO_BIN'), 1);
      expect(r.r1.feedback.objectLeftFloor, isTrue);
    });

    test('an error reply stops the arm', () {
      final r = _Rig(setup: (s) => s.failures['MOVE_TO_BIN'] = 'busy');
      r.toSorting();
      r.run(6000);
      r.expectSafeExit('robot_error', stopped: true);
    });

    test('Human_Hand pauses the arm (HOLD) and the step restarts 1 s after it leaves', () {
      final r = _Rig();
      r.toSorting();
      r.run(1000);
      r.robot.handInView = true;
      r.run(300);
      expect(r.cmds.last, 'HOLD');
      r.run(5000);
      expect(r.count('PICK'), 1, reason: 'still paused');
      r.robot.handInView = false;
      r.run(1200);
      expect(r.count('PICK'), 2);
      r.answerQuestions();
      r.run(15000);
      expect(r.resumes, ['done']);
    });

    test('a hand in view when "Ambil" is pressed: the arm waits for it to leave', () {
      final r = _Rig();
      r.toPosition();
      r.robot.handInView = true;
      r.run(200);
      r.r1.onAmbil();
      expect(r.count('PICK'), 0);
      r.robot.handInView = false;
      r.run(1200);
      expect(r.count('PICK'), 1);
    });
  });

  group('bin tag check at the bin state point (0233)', () {
    // PICK 4.1 s + floor check ~0.7 s + MOVE_TO_BIN 3.1 s: the arm is at the state point by 8.5 s.
    _Rig atBin({int? Function(Bin bin)? seen}) {
      final r = _Rig(setup: (s) => s.binTagSeen = seen ?? s.binTagSeen);
      r.toSorting();
      r.answerQuestions();
      r.run(8500 - 1000);
      expect(r.count('MOVE_TO_BIN'), 1);
      return r;
    }

    test('right tag: DROP after it was seen for binTagSeenFor', () {
      final r = atBin();
      expect(r.count('DROP'), 1, reason: 'tag 2 (anorganik) was seen at the state point');
      expect(r.r1.message, l10n.r1BinOk);
      r.run(5000);
      expect(r.cmds, ['STATUS', 'LOCK_DRIVE', 'PICK', 'MOVE_TO_BIN', 'DROP', 'UNLOCK_DRIVE']);
      r.expectSafeExit('done', stopped: false);
    });

    test('no tag: one more look, then end without DROP for HOME', () {
      final r = atBin(seen: (_) => null);
      r.run(binLookTimeout.inMilliseconds);
      expect(r.r1.message, l10n.r1BinLookAgain);
      expect(r.resumes, isEmpty, reason: 'the first failed look is retried');
      r.run(binLookTimeout.inMilliseconds);
      expect(r.count('DROP'), 0);
      expect(r.r1.message, l10n.r1BinCheckFailed);
      r.expectSafeExit('bin_check_failed', stopped: false);
    });

    test('wrong tag twice: no DROP', () {
      final r = atBin(seen: (_) => Bin.b3.tagId);
      r.run(2000);
      expect(r.count('DROP'), 0);
      r.expectSafeExit('bin_check_failed', stopped: false);
    });

    test('wrong tag, then the right one on the retry: DROP', () {
      var looks = 0;
      final r = atBin(seen: (bin) => looks++ < 8 ? Bin.organik.tagId : bin.tagId);
      r.run(5000);
      expect(r.count('DROP'), 1);
      expect(r.resumes, ['done']);
    });

    test('a hand during the look holds the arm and does not use the retry', () {
      final r = atBin(seen: (_) => null);
      r.robot.handInView = true;
      r.run(binLookTimeout.inMilliseconds + 500);
      expect(r.count('HOLD'), 1);
      expect(r.resumes, isEmpty);
      r.robot.handInView = false;
      r.run(handClearFor.inMilliseconds + 300);
      expect(r.r1.message, l10n.r1BinChecking, reason: 'the look starts over, not as the retry');
    });
  });

  group('camera turns with J1', () {
    test('locks ignored while SORTING, WAIT_BOTH and ARM_SETTLE after an arm stop', () {
      final r = _Rig(setup: (s) => s.failures['DROP'] = 'busy');
      r.toSorting();
      expect(r.r1.onLock(_lockBox), isFalse);
      r.run(9000); // PICK, verify, MOVE_TO_BIN, bin tag look, DROP fails: stop, safe exit
      expect(r.resumes, ['robot_error']);
      expect(r.r1.ignoresLiveScanLocks, isTrue, reason: 'settling');
      expect(r.r1.onLock(_lockBox), isFalse);
      r.run(armSettle.inMilliseconds);
      expect(r.r1.onLock(_lockBox), isTrue);
    });

    test('RESUME waits for ARM_SETTLE after the last motion', () {
      final r = _Rig();
      r.toSorting();
      r.answerQuestions();
      r.run(10000); // PICK 4.1 s, verify ~0.7 s, MOVE 3.1 s, bin tag ~0.6 s, DROP 2.1 s
      expect(r.r1.state, R1State.waitBoth);
      r.run(armSettle.inMilliseconds + 200);
      expect(r.resumes, ['done']);
    });

    test('boxes over the arm region are dropped for the live scan while sorting; a hand never', () {
      final r = _Rig();
      const overArm = Detection(x: 40, y: 240, w: 60, h: 60, label: 'Plastic', score: 0.9);
      const hand = Detection(x: 40, y: 240, w: 60, h: 60, label: 'Human_Hand', score: 0.9);
      const elsewhere = Detection(x: 400, y: 240, w: 60, h: 60, label: 'Metal', score: 0.9);
      final all = [overArm, hand, elsewhere];
      expect(r.r1.filterForLiveScan(all, 640, 480), all);
      r.toSorting();
      expect(r.r1.filterForLiveScan(all, 640, 480), [hand, elsewhere]);
    });
  });

  group('link', () {
    test('old firmware without the command link: "robot tidak terhubung", no lock taken', () {
      final r = _Rig(connect: false, setup: (s) => s.commandLink = false);
      r.r1.linkUp();
      expect(r.r1.onLock(_lockBox), isFalse, reason: 'still probing');
      r.run(ackTimeout.inMilliseconds + 200);
      expect(r.r1.robotConnected, isFalse);
      expect(r.r1.message, 'robot not connected');
      expect(r.r1.onLock(_lockBox), isFalse);
      expect(r.cmds, ['STATUS']);
      expect(r.robot.drive(75, 75), isTrue, reason: 'driving works as today');
    });

    test('link lost while sorting: safe state at once, UNLOCK_DRIVE at the reconnect', () {
      final r = _Rig();
      r.toSorting();
      r.run(1000);
      r.robot.linkUp = false;
      r.r1.linkDown();
      expect(r.resumes, ['link_lost']);
      expect(r.r1.state, R1State.searching);
      expect(r.robot.driveLocked, isFalse);
      final sentBefore = r.robot.sent.length;
      r.run(3000);
      expect(r.robot.sent.length, sentBefore, reason: 'nothing can be sent while the link is down');
      r.robot.linkUp = true;
      r.r1.linkUp();
      expect(r.cmds.sublist(sentBefore), ['UNLOCK_DRIVE', 'STATUS']);
      r.run(300);
      expect(r.r1.robotConnected, isTrue);
    });

    test('link lost in every state before SORTING also unlocks driving', () {
      for (final reach in [1, 2, 3, 4, 5]) {
        final r = _Rig(setup: (s) => s.objectDistCm = 35);
        r.r1.onLock(_lockBox);
        r.run(300);
        if (reach >= 2) r.r1.onIdentified(Bin.organik);
        if (reach >= 3) r.r1.onStudentBin(Bin.organik);
        if (reach >= 4) r.run(revealDuration.inMilliseconds + 200); // POSITION, nudging
        if (reach >= 5) r.robot.objectDistCm = 25;
        r.run(500);
        r.r1.linkDown();
        expect(r.resumes, ['link_lost'], reason: 'reach $reach');
        expect(r.robot.driveLocked, isFalse);
        expect(r.robot.nudgeOnly, isFalse);
      }
    });

    test('late or unknown replies are ignored', () {
      final r = _Rig();
      r.robot.onReply!(const RobotReply(ReplyKind.motionDone, 99));
      r.robot.onReply!(const RobotReply(ReplyKind.error, 98, reason: 'x'));
      expect(r.r1.state, R1State.searching);
      expect(r.resumes, isEmpty);
    });
  });

  group('MaixCamRobot (0023 wire format)', () {
    test('sends seq-numbered commands and parses only replies', () {
      final out = <Map<String, Object?>>[];
      final motor = <(int, int)>[];
      final replies = <RobotReply>[];
      final robot = MaixCamRobot(sink: out.add, motor: (l, r) => motor.add((l, r)))..onReply = replies.add;
      robot
        ..status()
        ..lockDrive()
        ..moveToBin(Bin.b3)
        ..hold();
      expect(out, [
        {'cmd': 'STATUS', 'seq': 1},
        {'cmd': 'LOCK_DRIVE', 'seq': 2},
        {'cmd': 'MOVE_TO_BIN', 'seq': 3, 'bin': 'b3'},
        {'cmd': 'HOLD', 'seq': 4},
      ]);
      for (final m in [
        {'event': 'ack', 'seq': 2},
        {'event': 'motion_done', 'seq': 3},
        {'event': 'error', 'seq': 4, 'reason': 'busy'},
        {'event': 'pong', 'firmware_version': 'm2c-clean-v1'}, // old firmware
        {'event': 'ack', 'cmd': 'HOLD', 'id': 4}, // the old fake's placeholder shape
        {'event': 'ack', 'seq': '2'},
        {'frame_id': 3, 'detections': []},
      ]) {
        robot.handleMessage(m);
      }
      expect(replies.map((r) => r.toString()), ['RobotReply(ack #2)', 'RobotReply(motionDone #3)', 'RobotReply(error #4 busy)']);
      robot.driveLocked = true;
      expect(robot.drive(50, 50), isFalse);
      robot.driveLocked = false;
      expect(robot.drive(50, -50), isTrue);
      expect(motor, [(50, -50)]);
    });

    test('bins from waste category ids', () {
      expect([for (final id in ['organic', 'inorganic', 'hazardous', 'x', null]) Bin.fromCategoryId(id)],
          [Bin.organik, Bin.anorganik, Bin.b3, null, null]);
    });

    test('R1 SORTING ignores HOME (decision 0027)', () {
      final r = _Rig();
      r.toSorting();
      expect(r.r1.state, R1State.sorting);
      final countBefore = r.count('HOME');

      expect(r.r1.home(), isFalse, reason: 'HOME ignored while sorting');
      expect(r.count('HOME'), countBefore);

      // When searching (not sorting), HOME is allowed
      final r2 = _Rig();
      expect(r2.r1.state, R1State.searching);
      expect(r2.r1.home(), isTrue, reason: 'HOME accepted while idle');
      expect(r2.count('HOME'), 1);

      // When hand is in view, HOME triggers hand pause
      final r3 = _Rig();
      r3.robot.handInView = true;
      r3.run(200);
      expect(r3.r1.handInView, isTrue);
      expect(r3.r1.home(), isFalse, reason: 'hand in view pauses HOME');
      expect(r3.r1.message, contains('A hand!'));
      expect(r3.count('HOLD'), greaterThanOrEqualTo(1));
    });
  });
}
