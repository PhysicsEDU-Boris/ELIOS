enum WasteCategory { plastic, glass, metal, outOfRange }

class DensityState {
  final double massGrams; // m, 100–2000 g
  final double volumeCm3; // V, 100–1000 cm³

  const DensityState({this.massGrams = 1250, this.volumeCm3 = 500});

  double get density => massGrams / volumeCm3;

  WasteCategory get classification {
    final rho = density;
    // plastic 0.9–1.4, glass 2.4–2.6, metal ≥2.7
    // Using small epsilon for floating point comparison issues in boundaries
    if (rho >= 0.9 - 1e-6 && rho <= 1.4 + 1e-6) return WasteCategory.plastic;
    if (rho >= 2.4 - 1e-6 && rho <= 2.6 + 1e-6) return WasteCategory.glass;
    if (rho >= 2.7 - 1e-6) return WasteCategory.metal;
    return WasteCategory.outOfRange;
  }

  // Miskonsepsi distractor
  double get distractorVPerM => volumeCm3 / massGrams;

  DensityState copyWith({double? massGrams, double? volumeCm3}) => DensityState(
        massGrams: massGrams ?? this.massGrams,
        volumeCm3: volumeCm3 ?? this.volumeCm3,
      );
}
