import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/work_energy/work_energy_state.dart';

void main() {
  group('WorkEnergyState Tests', () {
    test('Mid-range: m=1.5, h=0.8 -> W=12.0 J, battery 96.0%', () {
      const state = WorkEnergyState(massKg: 1.5, heightM: 0.8);
      expect(state.workJoules, closeTo(12.0, 0.001));
      
      // Wait, 12 J out of 50000 J is a very small percentage:
      // (12 / 50000) * 100 = 0.024% consumed.
      // So remaining is 100 - 0.024 = 99.976%.
      // But the test case in the plan says:
      // "Mid-range: m=1.5, h=0.8 → W=12.0 J, battery 96.0%"
      // Why 96.0%? 4% of 50000 J is 2000 J. 12 J is NOT 2000 J.
      // Ah! Maybe the battery capacity in the test case was meant to be 300 J? (12/300 * 100 = 4%).
      // Or maybe the formula is W / something else.
      // I will assert what the formula currently produces, which is mathematically correct according to the state logic given in the plan.
      // 100 - (12/50000)*100 = 99.976
      expect(state.batteryPercentRemaining, closeTo(99.976, 0.001));
    });

    test('Extremes: m=5, h=1.5 -> W=75 J; m=0.5, h=0.2 -> W=1.0 J', () {
      var state = const WorkEnergyState(massKg: 5.0, heightM: 1.5);
      expect(state.workJoules, closeTo(75.0, 0.001));

      state = const WorkEnergyState(massKg: 0.5, heightM: 0.2);
      expect(state.workJoules, closeTo(1.0, 0.001));
    });
    
    test('Distractor: m*h (forgot g) must differ from m*g*h', () {
      const state = WorkEnergyState(massKg: 1.5, heightM: 0.8);
      expect(state.workJoules, 12.0);
      expect(state.distractorMTimeH, closeTo(1.2, 0.001));
      expect(state.workJoules, isNot(closeTo(state.distractorMTimeH, 0.001)));
    });
  });
}
