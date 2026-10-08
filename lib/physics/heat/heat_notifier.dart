import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'heat_state.dart';

class HeatNotifier extends Notifier<HeatState> {
  @override
  HeatState build() => const HeatState();

  void setMass(double v) =>
      state = state.copyWith(massKg: v.clamp(1.0, 5.0));

  void setDeltaT(double v) =>
      state = state.copyWith(deltaT: v.clamp(5.0, 40.0));
}

final heatProvider =
    NotifierProvider<HeatNotifier, HeatState>(HeatNotifier.new);
