import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/pwm/pwm_state.dart';

void main() {
  group('PwmState Tests', () {
    test('D=60 -> 7.2V / ~180 RPM', () {
      const state = PwmState(dutyPercent: 60.0);
      expect(state.averageVoltage, closeTo(7.2, 0.001));
      expect(state.approxRpm, closeTo(180.0, 0.001));
    });

    test('Edge case D=0', () {
      const state = PwmState(dutyPercent: 0.0);
      expect(state.averageVoltage, 0.0);
      expect(state.approxRpm, 0.0);
    });

    test('Edge case D=100', () {
      const state = PwmState(dutyPercent: 100.0);
      expect(state.averageVoltage, closeTo(12.0, 0.001));
      expect(state.approxRpm, closeTo(300.0, 0.001));
    });
  });
}
