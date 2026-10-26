import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';

// ---------------------------------------------------------------------------
// Existing providers (kept for backward compatibility)
// ---------------------------------------------------------------------------

/// Exposes the WebSocket singleton's [ValueNotifier<String>] for connection
/// status.  Prefer [robotStatusProvider] for reactive Riverpod consumption.
final robotConnectionProvider = Provider<ValueNotifier<String>>((ref) {
  return WebSocketService().connectionStatus;
});

/// Live MJPEG frame stream from the MaixCAM2 camera.
final robotFrameProvider = StreamProvider<Uint8List>((ref) {
  return WebSocketService().frames;
});

/// Connection status as a stream that immediately emits the current value,
/// then follows updates from the WebSocket service.
final robotStatusProvider = StreamProvider<String>((ref) async* {
  final ws = WebSocketService();
  yield ws.connectionStatus.value;
  yield* ws.status;
});

// ---------------------------------------------------------------------------
// Robot control state
// ---------------------------------------------------------------------------

/// Local UI state for robot control sliders.
class RobotState {
  final double pwmSpeed;
  final double baseAngle;
  final double elbowAngle;
  final double reachValue;
  final double gripperVal;

  const RobotState({
    this.pwmSpeed = 75,
    this.baseAngle = 90,
    this.elbowAngle = 45,
    this.reachValue = 90,
    this.gripperVal = 0,
  });

  RobotState copyWith({
    double? pwmSpeed,
    double? baseAngle,
    double? elbowAngle,
    double? reachValue,
    double? gripperVal,
  }) {
    return RobotState(
      pwmSpeed: pwmSpeed ?? this.pwmSpeed,
      baseAngle: baseAngle ?? this.baseAngle,
      elbowAngle: elbowAngle ?? this.elbowAngle,
      reachValue: reachValue ?? this.reachValue,
      gripperVal: gripperVal ?? this.gripperVal,
    );
  }
}

// ---------------------------------------------------------------------------
// Robot control notifier
// ---------------------------------------------------------------------------

class RobotControlNotifier extends Notifier<RobotState> {
  WebSocketService get _ws => WebSocketService();

  @override
  RobotState build() => const RobotState();

  // Connection lifecycle ──────────────────────────────────────────────────────

  Future<bool> connect({bool autoReconnect = false}) {
    return _ws.connect(autoReconnect: autoReconnect);
  }

  Future<void> disconnect() => _ws.disconnect();

  void resetConnectionState() => _ws.resetConnectionState();

  // Motion goes through the control screen's MotionGate (decision 0026); this
  // notifier keeps the slider values only.

  void startStream() => _ws.sendStartStreamCommand();

  void stopStream() => _ws.sendStopStreamCommand();

  // Slider state (the servo command itself is sent by the gate) ───────────────

  void setPwmSpeed(double v) => state = state.copyWith(pwmSpeed: v);
  void setBaseAngle(double v) => state = state.copyWith(baseAngle: v);
  void setElbowAngle(double v) => state = state.copyWith(elbowAngle: v);
  void setReachValue(double v) => state = state.copyWith(reachValue: v);
  void setGripperVal(double v) => state = state.copyWith(gripperVal: v);

  // Resolution control ────────────────────────────────────────────────────────

  void setResolution({String? preset, int? width, int? height}) =>
      _ws.sendResolutionCommand(preset: preset, width: width, height: height);
}

final robotControlProvider = NotifierProvider<RobotControlNotifier, RobotState>(
  RobotControlNotifier.new,
);

/// The most recently acknowledged resolution from the device.
/// The device may fall back to a different resolution than requested,
/// so this reflects what is *actually* active.
final resolutionAckProvider = StreamProvider<Size>((ref) {
  return WebSocketService().resolutionAcks;
});

/// R1 DROP in progress gate (UI plan U2): when R1 is enabled and sorting/dropping,
/// the Result Card shows "Robot sedang membuang ke tempat sampah..." and keeps
/// "Scan lagi" disabled until DROP finishes.
final r1DropPendingProvider = StateProvider<bool>((ref) => false);
