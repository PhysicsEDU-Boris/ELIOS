import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/kinematics/kinematics_state.dart';

void main() {
  group('KinematicsState Tests', () {
    test('Mid-range: d=10, v=0.5 -> predictedTimeS=20.0s', () {
      const state = KinematicsState(distanceM: 10.0, velocityMs: 0.5);
      expect(state.predictedTimeS, closeTo(20.0, 0.001));
    });

    test('Tick Overshoot Clamp: passing dt=5.0s when only 1.0s needed to finish', () {
      // Robot is at 9.5m, moving at 0.5m/s. Needs 1.0s to reach 10.0m.
      var state = const KinematicsState(
        distanceM: 10.0,
        velocityMs: 0.5,
        robotX: 9.5,
        elapsedS: 19.0,
        isRunning: true,
      );

      // We tick with a massive 5.0 seconds. It should clamp exactly at 10.0m and 20.0s.
      final nextState = state.tick(5.0);
      
      expect(nextState.robotX, 10.0);
      expect(nextState.elapsedS, 20.0); // 19.0 + 1.0 (clamped)
      expect(nextState.isRunning, isFalse);
    });
  });
}
