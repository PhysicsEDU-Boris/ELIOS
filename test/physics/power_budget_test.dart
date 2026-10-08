import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/power_budget/power_budget_state.dart';

void main() {
  group('PowerBudgetState Tests', () {
    test('All-off -> null runtime case (infinite)', () {
      const state = PowerBudgetState(
        cameraOn: false,
        driveOn: false,
        armOn: false,
        timeS: 600.0,
      );
      expect(state.totalPowerW, 0.0);
      expect(state.energyJoules, 0.0);
      expect(state.remainingPercent, 100.0);
      expect(state.estimatedRuntimeS, isNull);
    });

    test('Camera + Drive + Arm -> 64W / 38,400J for 600s', () {
      const state = PowerBudgetState(
        cameraOn: true,
        driveOn: true,
        armOn: true,
        timeS: 600.0,
      );
      expect(state.totalPowerW, 64.0);
      expect(state.energyJoules, 38400.0); // 64 * 600
      expect(state.estimatedRuntimeS, closeTo(50000.0 / 64.0, 0.001)); // 781.25s
      
      // remainingPercent = 100 - (38400 / 50000) * 100 = 100 - 76.8 = 23.2%
      expect(state.remainingPercent, closeTo(23.2, 0.001));
    });
  });
}
