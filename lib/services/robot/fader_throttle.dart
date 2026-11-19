import 'dart:async';

/// Arm fader drags (decision 0236): runs the first call at once, then at most one call per
/// [gap], always ending with the latest one. The MaixCAM2 streams only its newest target to the
/// ESP32 at 20 Hz, so every pose in between was wasted (~60 ARM_POSE per drag before).
class FaderThrottle {
  FaderThrottle([this.gap = const Duration(milliseconds: 100)]);
  final Duration gap;
  Timer? _timer;
  void Function()? _pending;

  void call(void Function() send) {
    if (_timer != null) {
      _pending = send;
      return;
    }
    send();
    _timer = Timer(gap, _tick);
  }

  void _tick() {
    _timer = null;
    final send = _pending;
    _pending = null;
    if (send != null) call(send);
  }

  /// Drops a waiting call (STOP, leaving the screen).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
