import 'package:elio/services/robot/arm_tag_switch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 4, 21);
  late List<Map<String, Object?>> sent;
  late ArmTagSwitch tags;
  void at(int ms, {bool connected = true, bool r1 = false}) =>
      tags.sync(t0.add(Duration(milliseconds: ms)), connected: connected, r1Grips: r1, send: sent.add);

  setUp(() {
    sent = [];
    tags = ArmTagSwitch();
  });

  test('off without an R1 grip or bin run: PICK UP and HOME no longer search (owner, 26 Nov)', () {
    at(0);
    at(1000);
    expect(sent, [{'cmd': 'arm_tags', 'on': false}]); // once, not every frame
    expect(tags.wanted(t0), isFalse);
  });

  test('an R1 grip or bin run turns tags on, then off when it ends', () {
    at(0, r1: true);
    at(9000, r1: true);
    expect(sent, [{'cmd': 'arm_tags', 'on': true}]);
    at(9250);
    expect(sent.last, {'cmd': 'arm_tags', 'on': false});
  });

  test('nothing is sent while disconnected; a new link says it again', () {
    at(0, connected: false, r1: true);
    expect(sent, isEmpty);
    at(100, r1: true);
    tags.linkUp();
    at(200, r1: true);
    expect(sent, [{'cmd': 'arm_tags', 'on': true}, {'cmd': 'arm_tags', 'on': true}]);
  });
}
