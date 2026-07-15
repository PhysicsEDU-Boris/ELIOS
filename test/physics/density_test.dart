import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/density/density_state.dart';

void main() {
  group('DensityState Tests', () {
    test('Mid-range: m=1250, V=500 -> ρ=2.50 (glass)', () {
      const state = DensityState(massGrams: 1250, volumeCm3: 500);
      expect(state.density, closeTo(2.50, 0.001));
      expect(state.classification, WasteCategory.glass);
    });

    test('Boundaries: ρ=0.9, 1.4, 2.4, 2.6, 2.7 exactly', () {
      // 0.9 (plastic)
      var state = const DensityState(massGrams: 900, volumeCm3: 1000);
      expect(state.density, closeTo(0.9, 0.001));
      expect(state.classification, WasteCategory.plastic);

      // 1.4 (plastic)
      state = const DensityState(massGrams: 1400, volumeCm3: 1000);
      expect(state.density, closeTo(1.4, 0.001));
      expect(state.classification, WasteCategory.plastic);

      // 2.4 (glass)
      state = const DensityState(massGrams: 2400, volumeCm3: 1000);
      expect(state.density, closeTo(2.4, 0.001));
      expect(state.classification, WasteCategory.glass);

      // 2.6 (glass)
      state = const DensityState(massGrams: 2600, volumeCm3: 1000);
      expect(state.density, closeTo(2.6, 0.001));
      expect(state.classification, WasteCategory.glass);

      // 2.7 (metal)
      state = const DensityState(massGrams: 2700, volumeCm3: 1000);
      expect(state.density, closeTo(2.7, 0.001));
      expect(state.classification, WasteCategory.metal);
    });

    test('Extremes: m=100/V=1000 (ρ=0.1, out of range), m=2000/V=100 (ρ=20, metal)', () {
      // m=100, V=1000 -> 0.1
      var state = const DensityState(massGrams: 100, volumeCm3: 1000);
      expect(state.density, closeTo(0.1, 0.001));
      expect(state.classification, WasteCategory.outOfRange);

      // m=2000, V=100 -> 20.0
      state = const DensityState(massGrams: 2000, volumeCm3: 100);
      expect(state.density, closeTo(20.0, 0.001));
      expect(state.classification, WasteCategory.metal);
    });

    test('Distractor: V/m (swapped) must differ from m/V whenever m!=V', () {
      const state = DensityState(massGrams: 1250, volumeCm3: 500);
      final correct = state.density;
      final distractor = state.distractorVPerM;
      
      expect(correct, isNot(closeTo(distractor, 0.001)));
      expect(correct, 2.5);
      expect(distractor, 0.4);
    });
  });
}
