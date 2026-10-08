import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'density_state.dart';

class DensityNotifier extends Notifier<DensityState> {
  @override
  DensityState build() => const DensityState();

  void setMass(double v) =>
      state = state.copyWith(massGrams: v.clamp(100.0, 2000.0));

  void setVolume(double v) =>
      state = state.copyWith(volumeCm3: v.clamp(100.0, 1000.0));
}

final densityProvider =
    NotifierProvider<DensityNotifier, DensityState>(DensityNotifier.new);
