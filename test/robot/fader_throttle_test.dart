import 'package:elio/services/robot/fader_throttle.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a 1 s drag at 60 Hz sends about 10 poses, first at once and the last one always', () {
    fakeAsync((async) {
      final sent = <int>[];
      final t = FaderThrottle();
      for (var i = 0; i < 60; i++) {
        t(() => sent.add(i));
        async.elapse(const Duration(milliseconds: 16));
      }
      async.elapse(const Duration(milliseconds: 200));
      expect(sent.first, 0);
      expect(sent.last, 59);
      expect(sent.length, inInclusiveRange(9, 11));
    });
  });

  test('a lone call runs at once; cancel drops the waiting one', () {
    fakeAsync((async) {
      final sent = <int>[];
      final t = FaderThrottle();
      t(() => sent.add(1));
      expect(sent, [1]);
      t(() => sent.add(2));
      t.cancel();
      async.elapse(const Duration(seconds: 1));
      expect(sent, [1]);
      t(() => sent.add(3));
      expect(sent, [1, 3]);
    });
  });
}
