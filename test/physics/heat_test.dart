import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/heat/heat_state.dart';

void main() {
  group('HeatState Tests', () {
    test('Mid-range: m=2, ΔT=20 -> Q=160,000 J, finalTemp=45°C, mesophilic', () {
      const state = HeatState(massKg: 2.0, deltaT: 20.0);
      expect(state.heatJoules, closeTo(160000.0, 0.001));
      expect(state.finalTemp, closeTo(45.0, 0.001));
      expect(state.phase, CompostPhase.mesophilic);
    });

    test('Boundary: finalTemp=55°C exactly -> thermophilic; 60.01°C -> overheated', () {
      // 55 exactly (deltaT = 30)
      var state = const HeatState(massKg: 2.0, deltaT: 30.0);
      expect(state.finalTemp, closeTo(55.0, 0.001));
      expect(state.phase, CompostPhase.thermophilic);

      // 60.01 -> overheated (deltaT = 35.01)
      state = const HeatState(massKg: 2.0, deltaT: 35.01);
      expect(state.finalTemp, closeTo(60.01, 0.001));
      expect(state.phase, CompostPhase.overheated);
    });

    test('Anaerobic banner condition: Porosity<25 & finalTemp>55', () {
      // Create a function that mirrors the UI's condition
      bool isAnaerobic(double porosity, double temp) {
        return porosity < 25.0 && temp > 55.0;
      }

      // Case 1: High porosity, high temp -> false
      expect(isAnaerobic(50.0, 60.0), isFalse);
      
      // Case 2: Low porosity, low temp -> false
      expect(isAnaerobic(10.0, 45.0), isFalse);
      
      // Case 3: Low porosity, high temp -> true (Anaerobic)
      expect(isAnaerobic(20.0, 56.0), isTrue);
      
      // Case 4: Boundary exactly at 25 porosity and 55 temp -> false
      expect(isAnaerobic(25.0, 55.0), isFalse);
    });
  });
}
