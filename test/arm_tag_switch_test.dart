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

  test('without R1, PICK UP or HOME turns tags on for 5 s, then off', () {
    at(0);
    expect(sent, [{'cmd': 'arm_tags', 'on': false}]);
    tags.press(t0.add(const Duration(seconds: 1)));
    at(1000);
    at(1250);
    at(5900);
    expect(sent.skip(1), [{'cmd': 'arm_tags', 'on': true}]); // once, not every frame
    at(6000);
    expect(sent.last, {'cmd': 'arm_tags', 'on': false});
  });

  test('an R1 grip keeps tags on past the manual window', () {
    tags.press(t0);
    at(0, r1: true);
    at(9000, r1: true);
    expect(sent, [{'cmd': 'arm_tags', 'on': true}]);
    at(9250);
    expect(sent.last, {'cmd': 'arm_tags', 'on': false});
  });

  test('nothing is sent while disconnected; a new link says it again', () {
    tags.press(t0);
    at(0, connected: false);
    expect(sent, isEmpty);
    at(100);
    tags.linkUp();
    at(200);
    expect(sent, [{'cmd': 'arm_tags', 'on': true}, {'cmd': 'arm_tags', 'on': true}]);
  });
}
