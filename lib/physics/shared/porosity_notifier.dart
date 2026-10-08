import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'porosity_state.dart';

class PorosityNotifier extends Notifier<PorosityState> {
  @override
  PorosityState build() => const PorosityState(); // Default porosity 50%

  void setPorosity(double v) {
    state = state.copyWith(porosityPercent: v.clamp(10.0, 80.0));
  }
}

final porosityProvider = NotifierProvider<PorosityNotifier, PorosityState>(PorosityNotifier.new);
