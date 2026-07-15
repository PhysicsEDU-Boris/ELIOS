import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

enum RadiationType { alpha, beta, gamma }

class RadiationShieldingState {
  final RadiationType selectedType;
  final double thicknessCm;
  
  const RadiationShieldingState({
    this.selectedType = RadiationType.gamma,
    this.thicknessCm = 0.0,
  });

  // ⚠ CATATAN AKURASI: Koefisien atenuasi (μ) ini bersifat ilustratif. 
  // Koefisien sungguhan sangat bergantung pada energi partikel radiasi (MeV) 
  // dan jenis material perisai spesifik. Angka ini hanya menunjukkan urutan relatif.
  double get attenuationCoefficient {
    switch (selectedType) {
      case RadiationType.alpha: return 5.0;
      case RadiationType.beta: return 1.5;
      case RadiationType.gamma: return 0.3;
    }
  }
  
  double get transmittedIntensityPercent {
    final intensity = exp(-attenuationCoefficient * thicknessCm);
    return intensity * 100.0;
  }

  RadiationShieldingState copyWith({
    RadiationType? selectedType,
    double? thicknessCm,
  }) {
    return RadiationShieldingState(
      selectedType: selectedType ?? this.selectedType,
      thicknessCm: thicknessCm ?? this.thicknessCm,
    );
  }
}

class RadiationShieldingNotifier extends Notifier<RadiationShieldingState> {
  @override
  RadiationShieldingState build() => const RadiationShieldingState();

  void setType(RadiationType type) {
    state = state.copyWith(selectedType: type);
  }

  void setThickness(double v) {
    state = state.copyWith(thicknessCm: v.clamp(0.0, 20.0));
  }
}

final radiationShieldingProvider = NotifierProvider<RadiationShieldingNotifier, RadiationShieldingState>(RadiationShieldingNotifier.new);
