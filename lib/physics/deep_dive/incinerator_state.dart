import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncineratorState {
  final double temperatureC;

  const IncineratorState({this.temperatureC = 200.0});

  bool get bondsDestroyed => temperatureC >= 1000.0;

  IncineratorState copyWith({double? temperatureC}) {
    return IncineratorState(temperatureC: temperatureC ?? this.temperatureC);
  }
}

class IncineratorNotifier extends Notifier<IncineratorState> {
  @override
  IncineratorState build() => const IncineratorState();

  void setTemperature(double v) {
    state = state.copyWith(temperatureC: v.clamp(200.0, 1200.0));
  }
}

final incineratorProvider = NotifierProvider<IncineratorNotifier, IncineratorState>(IncineratorNotifier.new);
