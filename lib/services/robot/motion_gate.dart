/// The one place every motion command passes (decision 0026): the emergency
/// stop, the STOPPED state, the drive lock (0023), the link, the app
/// heartbeat, and the arm-motion estimate for the J1 guard (0020).
/// Pure Dart; the transport is injected.
library;

import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';

import 'robot_controller.dart';

/// Joint speed limit of the ESP32 firmware (0021e).
const servoDegPerSecond = 60.0;

/// The app heartbeat to the MaixCAM2 (0026: ~4 Hz while connected).
const heartbeatInterval = Duration(milliseconds: 250);

/// Extra motor 0,0 after a stop, fire-and-forget: the WiFi link is lossy.
const stopRepeats = 4;
const stopRepeatInterval = Duration(milliseconds: 100);

/// Commands that still pass while STOPPED: the stop itself, the link probe, the heartbeat.
const _allowedWhileStopped = {'STOP', 'STATUS', 'HEARTBEAT'};

class MotionGate extends ChangeNotifier {
  MotionGate({
    required this.robot,
    required this.sendServo,
    this.onEvent,
    this.onStop,
    this.onArmCommand,
    this.armBusy,
    this.handPaused,
    this.onHomeTimeout,
    this.homeTimeoutDuration = const Duration(seconds: 5),
  });

  /// The MaixCAM2 client: STOP (with seq), HEARTBEAT, and motor through [RobotController.drive].
  final RobotController robot;
  final void Function(String part, int value) sendServo;

  /// Diagnostics (the live-scan JSONL): `emergency_stop`, `emergency_resume`, `motion_blocked`.
  final void Function(String event, Map<String, Object?> data)? onEvent;

  /// R1's safe exit, on every stop.
  final void Function(String reason)? onStop;

  /// A servo command was sent; its estimated motion time (J1 guard, 0020).
  final void Function(Duration motion)? onArmCommand;

  /// R1 is moving the arm itself: manual servo commands wait.
  final bool Function()? armBusy;

  /// A hand is in view: arm commands paused by existing Human_Hand -> HOLD behavior (0027).
  final bool Function()? handPaused;

  /// Called when an in-flight HOME command times out without motion_done.
  final void Function()? onHomeTimeout;

  /// Maximum time to wait for motion_done after HOME is sent.
  final Duration homeTimeoutDuration;

  bool _linkUp = false;
  bool _stopped = false;
  String? _stopReason;
  int _blocked = 0;
  Timer? _heartbeat;
  final _lastAngle = <String, int>{};
  int? _lastHomeSeq;
  int? _pendingHomeSeq;
  bool _homeAcked = false;
  Timer? _homeTimeoutTimer;

  bool get stopped => _stopped;
  String? get stopReason => _stopReason;
  bool get linkUp => _linkUp;
  int? get lastHomeSeq => _lastHomeSeq;
  int? get pendingHomeSeq => _pendingHomeSeq;
  bool get isHoming => _pendingHomeSeq != null;
  bool get homeAcked => _homeAcked;

  @visibleForTesting
  Map<String, int> get lastAngles => Map.unmodifiable(_lastAngle);

  /// Motion commands dropped so far (debug overlay).
  int get blocked => _blocked;

  // ── Motion ────────────────────────────────────────────────────────────────

  /// Wheels. Motor 0,0 always passes while the link is up; anything else is
  /// dropped while STOPPED, while R1 holds the drive lock, or without a link.
  bool motor(int left, int right) {
    if (left == 0 && right == 0) return stopWheels();
    if (_stopped || !_linkUp || robot.driveLocked) return _block('motor', {'left': left, 'right': right});
    return robot.drive(left, right);
  }

  /// Arm sliders and gripper buttons.
  bool servo(String part, int value) {
    if (_stopped || !_linkUp || (armBusy?.call() ?? false)) return _block('servo', {'part': part, 'val': value});
    final last = _lastAngle[part];
    _lastAngle[part] = value;
    // Unknown start angle: assume the full 180 deg travel.
    final degrees = last == null ? 180 : (value - last).abs();
    onArmCommand?.call(Duration(milliseconds: (degrees / servoDegPerSecond * 1000).round()));
    sendServo(part, value);
    return true;
  }

  /// A planned manual arm move (0234, [RobotController.armPose]) taking about [motion].
  /// Blocked like [servo]; a hand in view holds the arm instead.
  bool armPose(List<List<double>> path, Duration motion) {
    if (_stopped || !_linkUp || (armBusy?.call() ?? false)) return _block('arm_pose', {});
    if (handPaused?.call() ?? false) {
      robot.hold();
      return _block('arm_pose', {'reason': 'hand_paused'});
    }
    onArmCommand?.call(motion);
    robot.armPose(path);
    return true;
  }

  /// Arm HOME request (student screen with hold-to-confirm, debug sheet instant).
  /// With [path] (0234) the app's planned way home is sent as ARM_POSE, tracked like HOME;
  /// without it the firmware's own HOME (the arm's pose is unknown).
  /// Blocked while STOPPED, without link, while arm is busy (e.g. R1 sorting),
  /// or paused by hand (decision 0027).
  bool home({List<List<double>>? path, Duration motion = const Duration(seconds: 2)}) {
    if (_stopped || !_linkUp || (armBusy?.call() ?? false)) return _block('home', {});
    if (handPaused?.call() ?? false) {
      robot.hold();
      return _block('home', {'reason': 'hand_paused'});
    }
    onArmCommand?.call(motion);
    _homeTimeoutTimer?.cancel();
    final seq = path == null ? robot.home() : robot.armPose(path);
    _lastHomeSeq = seq;
    _pendingHomeSeq = seq;
    _homeAcked = false;
    robot.atHome = false;
    _homeTimeoutTimer = Timer(homeTimeoutDuration + (path == null ? Duration.zero : motion), () {
      if (_pendingHomeSeq == seq) {
        _pendingHomeSeq = null;
        _homeAcked = false;
        robot.atHome = false;
        onEvent?.call('home_timeout', {'seq': seq});
        onHomeTimeout?.call();
        notifyListeners();
      }
    });
    return true;
  }

  /// Handles command replies relevant to HOME.
  /// Returns true only on verified successful completion (motion_done with matching seq).
  bool onHomeReply(RobotReply reply) {
    if (_pendingHomeSeq == null || reply.seq != _pendingHomeSeq) {
      return false;
    }
    if (reply.kind == ReplyKind.ack) {
      _homeAcked = true;
      // ack means accepted by controller; motion is underway. Do NOT reset cache or mark done.
      return false;
    }
    if (reply.kind == ReplyKind.motionDone) {
      _homeTimeoutTimer?.cancel();
      _pendingHomeSeq = null;
      _homeAcked = false;
      resetToHome();
      robot.atHome = true;
      return true;
    }
    if (reply.kind == ReplyKind.error) {
      _homeTimeoutTimer?.cancel();
      _pendingHomeSeq = null;
      _homeAcked = false;
      robot.atHome = false;
      return false;
    }
    return false;
  }

  /// Cancels in-flight HOME if interrupted (by STOP, disconnect, error).
  void cancelHome({String reason = 'cancelled'}) {
    if (_pendingHomeSeq != null) {
      _homeTimeoutTimer?.cancel();
      onEvent?.call('home_interrupted', {'seq': _pendingHomeSeq, 'reason': reason});
      _pendingHomeSeq = null;
      _homeAcked = false;
      robot.atHome = false;
    }
  }

  /// Resets internal servo angles to neutral home values (decision 0027/G2c).
  void resetToHome() {
    _lastAngle['reach'] = 90;
    _lastAngle['height'] = 90;
    _lastAngle['gripper'] = 0;
  }

  /// Sends STATUS query through to robot (allowed while stopped).
  int status() => robot.status();

  /// Motor 0,0: D-pad release, leaving the screen, the app going to the
  /// background, a disconnect. Never blocked (only lost without a link).
  bool stopWheels() {
    if (!_linkUp) return false;
    robot.transmitMotor(0, 0);
    return true;
  }

  /// The app is paused, hidden or about to be killed: wheels off.
  void onAppLifecycle(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopWheels();
  }

  bool _block(String kind, Map<String, Object?> data) {
    _blocked++;
    final reason = data['reason'] ??
        (_stopped
            ? 'stopped'
            : !_linkUp
                ? 'no_link'
                : kind == 'motor'
                    ? 'drive_locked'
                    : 'arm_busy');
    onEvent?.call('motion_blocked', {
      'kind': kind,
      ...data,
      'reason': reason,
    });
    notifyListeners();
    return false;
  }

  /// The R1 transport (MaixCamRobot.sink): while STOPPED only STOP, STATUS and HEARTBEAT pass.
  bool allowsCommand(Map<String, Object?> message) {
    final ok = !_stopped || _allowedWhileStopped.contains(message['cmd']);
    if (!ok) _block('command', {'cmd': message['cmd']});
    return ok;
  }

  // ── Emergency stop ────────────────────────────────────────────────────────

  /// STOP (button, link_lost, error): 0023 STOP and motor 0,0 now, motor 0,0
  /// again a few times, R1's safe exit, then STOPPED until [resume].
  void emergencyStop(String reason) {
    _stopped = true;
    _stopReason = reason;
    cancelHome(reason: reason);
    onEvent?.call('emergency_stop', {'reason': reason, 'linkUp': _linkUp});
    _sendStop();
    onStop?.call(reason);
    notifyListeners();
  }

  void _sendStop() {
    if (!_linkUp) return;
    robot.stop();
    robot.transmitMotor(0, 0);
    for (var i = 1; i <= stopRepeats; i++) {
      Timer(stopRepeatInterval * i, stopWheels);
    }
  }

  /// "Lanjutkan": the deliberate second action that ends STOPPED.
  void resume() {
    if (!_stopped) return;
    onEvent?.call('emergency_resume', {'reason': _stopReason});
    _stopped = false;
    _stopReason = null;
    notifyListeners();
  }

  // ── Link and heartbeat ────────────────────────────────────────────────────

  /// The link dropped (the WebSocket watchdog): STOPPED with reason link_lost.
  void linkLost() {
    if (!_linkUp) return;
    _linkUp = false;
    _heartbeat?.cancel();
    cancelHome(reason: 'link_lost');
    if (!_stopped) emergencyStop('link_lost');
    notifyListeners();
  }

  /// A (re)connection: STOP and motor 0,0 before anything else (the last
  /// command may still be in force), then the heartbeat. STOPPED stays until [resume].
  void linkRestored() {
    _linkUp = true;
    _sendStop();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      if (_linkUp) robot.heartbeat();
    });
    notifyListeners();
  }

  /// Leaving the screen: wheels off, heartbeat off.
  @override
  void dispose() {
    _homeTimeoutTimer?.cancel();
    stopWheels();
    _heartbeat?.cancel();
    super.dispose();
  }
}
