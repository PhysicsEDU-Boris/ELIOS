enum CompostPhase { mesophilic, thermophilic, overheated }

class HeatState {
  final double massKg;
  final double deltaT;
  static const c = 4000.0;
  static const t0 = 25.0;

  const HeatState({this.massKg = 2.0, this.deltaT = 20.0});

  double get heatJoules => massKg * c * deltaT;
  
  double get finalTemp => t0 + deltaT;
  
  CompostPhase get phase {
    final t = finalTemp;
    // Using a tiny epsilon for float comparison reliability
    if (t > 60.0 + 1e-6) return CompostPhase.overheated;
    if (t >= 55.0 - 1e-6) return CompostPhase.thermophilic;
    return CompostPhase.mesophilic;
  }

  // Miskonsepsi distractor test (m + deltaT instead of m*c*deltaT)
  double get distractorMPlusDeltaT => massKg + deltaT;

  HeatState copyWith({double? massKg, double? deltaT}) {
    return HeatState(
      massKg: massKg ?? this.massKg,
      deltaT: deltaT ?? this.deltaT,
    );
  }
}
