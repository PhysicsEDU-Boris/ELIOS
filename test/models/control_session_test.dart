import 'package:elio/models/control_session.dart';
import 'package:elio/models/home_stats.dart';
import 'package:elio/models/scan_record.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecord _r(DateTime t, ScanCategory c, int trophies) =>
    ScanRecord(id: '$t$c', time: t, itemName: 'x', category: c, questions: const [], trophies: trophies);

void main() {
  test('joystick: dead zone, then the four D-pad directions (no diagonals)', () {
    expect(quantiseJoystick(const Offset(10, -10), 100), isNull);
    expect(quantiseJoystick(const Offset(0, -40), 100), DriveDir.forward);
    expect(quantiseJoystick(const Offset(0, 40), 100), DriveDir.back);
    expect(quantiseJoystick(const Offset(-40, 10), 100), DriveDir.left);
    expect(quantiseJoystick(const Offset(40, -39), 100), DriveDir.right);
    expect(quantiseJoystick(const Offset(40, -40), 100), DriveDir.forward, reason: 'a tie is forward/back');
  });

  test('link views: Connecting is waiting; Reconnecting and Disconnected are disconnected', () {
    expect(controlLink('Connected'), ControlLink.connected);
    expect(controlLink('Connecting...'), ControlLink.waiting);
    expect(controlLink('Reconnecting...'), ControlLink.disconnected);
    expect(controlLink('Disconnected'), ControlLink.disconnected);
  });

  test('this drive: only records since the screen opened, per bin, residu in Anorganik', () {
    final open = DateTime(2026, 11, 2, 10);
    final t = driveTally([
      _r(open.subtract(const Duration(minutes: 1)), ScanCategory.organic, 3),
      _r(open, ScanCategory.organic, 2),
      _r(open.add(const Duration(minutes: 1)), ScanCategory.residu, 1),
      _r(open.add(const Duration(minutes: 2)), ScanCategory.b3, 3),
    ], open);
    expect(t.bins, {HomeBin.organik: 1, HomeBin.anorganik: 1, HomeBin.b3: 1});
    expect(t.trophies, 6, reason: 'record trophies only, no mission reward');
  });

  test('ELIO tip: link first, then STOPPED, quiz, pick band only with dist_cm', () {
    String tip({
      ControlLink link = ControlLink.connected,
      bool stopped = false,
      bool quiz = false,
      String? item,
      bool locked = false,
      double? cm,
    }) =>
        controlTip(link: link, stopped: stopped, quizOpen: quiz, itemLabel: item, itemLocked: locked, distCm: cm).text;
    expect(tip(link: ControlLink.waiting, stopped: true), contains('looking for the robot'));
    expect(tip(link: ControlLink.disconnected), contains("can't hear the robot"));
    expect(tip(stopped: true, quiz: true), contains('STOPPED'));
    expect(tip(quiz: true, item: 'Plastic'), contains('Quiz'));
    expect(tip(), contains('point my camera'));
    expect(tip(item: 'Plastic', cm: 24), contains('pick zone'));
    expect(tip(item: 'Plastic', cm: 40), isNot(contains('pick zone')));
    expect(tip(item: 'Plastic'), isNot(contains('pick zone')), reason: 'never a distance without dist_cm');
    expect(tip(item: 'Plastic', locked: true), contains('locked'));
  });
}
