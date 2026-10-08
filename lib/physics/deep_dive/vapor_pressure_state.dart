import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class VaporPressureState {
  final double temperatureC;

  const VaporPressureState({this.temperatureC = 25.0});

  // ⚠ CATATAN AKURASI: Pendekatan kualitatif/simplifikasi, bukan kurva P-T literal.
  // Ini hanya untuk menunjukkan tren eksponensial (semakin panas = semakin menguap).
  double get relativePressure {
    final tempK = temperatureC + 273.15;
    // Simplified Clausius-Clapeyron shape
    return exp(15.0 - (4000.0 / tempK));
  }

  VaporPressureState copyWith({double? temperatureC}) {
    return VaporPressureState(temperatureC: temperatureC ?? this.temperatureC);
  }
}

class VaporPressureNotifier extends Notifier<VaporPressureState> {
  @override
  VaporPressureState build() => const VaporPressureState();

  void setTemperature(double v) {
    state = state.copyWith(temperatureC: v.clamp(0.0, 100.0));
  }
}

final vaporPressureProvider = NotifierProvider<VaporPressureNotifier, VaporPressureState>(VaporPressureNotifier.new);
