import 'package:flutter_riverpod/flutter_riverpod.dart';

class HookeSpringState {
  final double compressionCm;
  static const double k = 50.0; // N/m

  const HookeSpringState({this.compressionCm = 5.0});

  double get compressionM => compressionCm / 100.0;
  double get forceN => k * compressionM;

  HookeSpringState copyWith({double? compressionCm}) {
    return HookeSpringState(compressionCm: compressionCm ?? this.compressionCm);
  }
}

class HookeSpringNotifier extends Notifier<HookeSpringState> {
  @override
  HookeSpringState build() => const HookeSpringState();

  void setCompression(double v) {
    state = state.copyWith(compressionCm: v.clamp(2.0, 20.0));
  }
}

final hookeSpringProvider = NotifierProvider<HookeSpringNotifier, HookeSpringState>(HookeSpringNotifier.new);
