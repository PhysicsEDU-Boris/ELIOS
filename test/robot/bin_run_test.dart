// The arm's part after the bin check (owner, 24 Nov 2026; decision 0240 "bin run").
import 'package:elio/services/robot/bin_run.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late List<String> sent;
  late BinRun run;
  var seq = 0;

  setUp(() {
    now = DateTime(2026, 11, 24, 10);
    sent = [];
    run = BinRun(
      clock: () => now,
      delay: Duration.zero, // the 3 s wait has its own tests below
      moveToBin: (b) {
        sent.add('MOVE_TO_BIN ${b.wire}');
        return ++seq;
      },
      drop: () {
        sent.add('DROP');
        return ++seq;
      },
    );
  });

  RobotReply done() => RobotReply(ReplyKind.motionDone, seq);

  group('3 s after the quiz (owner, 25 Nov)', () {
    late BinRun slow;
    setUp(() => slow = BinRun(
          clock: () => now,
          moveToBin: (b) {
            sent.add('MOVE_TO_BIN ${b.wire}');
            return ++seq;
          },
          drop: () => ++seq,
        ));

    test('holding on Got it: nothing moves for 3 s, manual keys wait, then MOVE_TO_BIN', () {
      slow.start(Bin.organik, holding: true);
      expect(slow.state, BinRunState.countdown);
      expect(slow.busy, isTrue);
      now = now.add(const Duration(milliseconds: 2900));
      slow.tick();
      expect(sent, isEmpty);
      now = now.add(const Duration(milliseconds: 100));
      slow.tick();
      expect(sent, ['MOVE_TO_BIN organik']);
      expect(slow.state, BinRunState.moving);
    });

    test('gripper open: the 3 s start when it closes', () {
      slow.start(Bin.b3, holding: false);
      now = now.add(const Duration(seconds: 10));
      slow.onGripClosed();
      slow.tick();
      expect(sent, isEmpty);
      now = now.add(const Duration(seconds: 3));
      slow.tick();
      expect(sent, ['MOVE_TO_BIN b3']);
    });

    test('STOP during the countdown: the arm never moves', () {
      slow.start(Bin.anorganik, holding: true);
      slow.cancel('stopped');
      now = now.add(const Duration(seconds: 5));
      slow.tick();
      expect(sent, isEmpty);
      expect(slow.failure, 'stopped');
    });
  });

  test('holding on Got it: MOVE_TO_BIN to the right bin, a look, then DROP', () {
    run.start(Bin.organik, holding: true);
    expect(sent, ['MOVE_TO_BIN organik']);
    expect((run.state, run.busy, run.wantsTags), (BinRunState.moving, true, false));
    run.onReply(RobotReply(ReplyKind.ack, seq));
    expect(run.state, BinRunState.moving, reason: 'ack is not arrival');
    run.onReply(done());
    expect((run.state, run.wantsTags), (BinRunState.looking, true));
    run.tick();
    expect(sent, hasLength(1), reason: 'the camera gets a moment to see the bin tag');
    now = now.add(const Duration(seconds: 1));
    run.tick();
    expect(sent.last, 'DROP');
    run.onReply(done());
    expect((run.state, run.busy, run.pending), (BinRunState.done, false, false));
  });

  test('gripper open on Got it: nothing moves until AMBIL closes it', () {
    run.start(Bin.b3, holding: false);
    expect((run.state, run.pending, run.busy), (BinRunState.waitGrip, true, false));
    expect(sent, isEmpty);
    run.onGripClosed();
    expect(sent, ['MOVE_TO_BIN b3']);
  });

  test('a missed bin tag gets one more look, then the run fails without dropping', () {
    run.start(Bin.anorganik, holding: true);
    run.onReply(done());
    now = now.add(const Duration(seconds: 1));
    run.tick();
    run.onReply(RobotReply(ReplyKind.error, seq, reason: 'bin_not_confirmed'));
    expect(run.state, BinRunState.looking);
    now = now.add(const Duration(seconds: 1));
    run.tick();
    run.onReply(RobotReply(ReplyKind.error, seq, reason: 'bin_not_confirmed'));
    expect((run.state, run.failure), (BinRunState.failed, 'bin_not_confirmed'));
    expect(sent.where((s) => s == 'DROP'), hasLength(2));
  });

  test('a refused command, an error or STOP ends the run; old replies are ignored', () {
    final refused = BinRun(moveToBin: (_) => null, drop: () => null, delay: Duration.zero);
    refused.start(Bin.organik, holding: true);
    expect((refused.state, refused.failure), (BinRunState.failed, 'not_sent'));

    run.start(Bin.organik, holding: true);
    run.onReply(RobotReply(ReplyKind.motionDone, seq - 1));
    expect(run.state, BinRunState.moving, reason: 'another command\'s reply');
    run.onReply(RobotReply(ReplyKind.error, seq, reason: 'tank'));
    expect((run.state, run.failure), (BinRunState.failed, 'tank'));

    run.reset();
    run.start(Bin.organik, holding: true);
    run.cancel('stopped');
    expect((run.state, run.failure), (BinRunState.failed, 'stopped'));
  });
}
