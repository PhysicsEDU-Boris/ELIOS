import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pwm_state.dart';

class PwmNotifier extends Notifier<PwmState> {
  @override
  PwmState build() => const PwmState();

  void setDuty(double v) {
    state = state.copyWith(dutyPercent: v.clamp(0.0, 100.0));
  }
}

final pwmProvider = NotifierProvider<PwmNotifier, PwmState>(PwmNotifier.new);
