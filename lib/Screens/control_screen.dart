// Copyright (c) Boris Agung, Irham Fajar

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, SystemUiMode;

import '../models/config_model.dart';
import '../providers/esp_config_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../services/live_scan_controller.dart';
import '../services/quiz_tts_service.dart';
import '../services/robot/r1_orchestrator.dart';
import '../services/robot/robot_controller.dart';
import '../services/websocket_service.dart';
import '../widgets/debug_phone_camera_sheet.dart';
import '../widgets/desktop_viewport.dart';
import '../widgets/live_scan_debug_overlay.dart';
import '../widgets/question_source_switch.dart';
import '../widgets/segmentation_overlay_painter.dart';
import '../widgets/waste_quiz_popup.dart';
import '../services/frame_source/maix_cam_source.dart';
import '../services/frame_source/frame_source.dart';

/// The MaixCAM2 already draws its box, mask and label into the video, so the
/// app's own box is a debug aid, shown with the live-scan debug overlay only.
const _showAppDetectionBoxes = kDebugMode && liveScanEnabled;

/// `--dart-define=R1=true` (with LIVE_SCAN): R1 probes the MaixCAM2 command
/// link (decision 0023) and shows the result in the debug overlay. The
/// student flow (bin question, "Ambil") is not on screen yet (M4).
const _r1Enabled = liveScanEnabled && bool.fromEnvironment('R1');

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  final MaixCamSource _source = MaixCamSource();
  CapturedFrame? _latestFrame;
  StreamSubscription<CapturedFrame>? _frameSubscription;
  ProviderSubscription<AsyncValue<String>>? _statusSubscription;
  late final RobotControlNotifier _robotNotifier;
  bool? _lastLoggedRobotControlsEnabled;
  int _frameCount = 0;
  int _fpsFrameCount = 0;
  double _streamFps = 0;
  DateTime _fpsWindowStart = DateTime.now();
  DateTime? _lastFrameAt;
  int _lastFrameBytes = 0;
  bool _streamStartedForCurrentConnection = false;

  /// Set only when built with --dart-define=LIVE_SCAN=true (M2a).
  LiveScanController? _liveScan;

  /// Set only with R1 (see [_r1Enabled]).
  R1Orchestrator? _r1;
  StreamSubscription<Map<String, dynamic>>? _r1Replies;
  Timer? _r1Ticker;
  String? _r1Status;

  static const Color textPrimary = Color(0xFF1C2833);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color primaryColor = Color(0xFF1D9E75);
  static const Color orangeAccent = Color(0xFFE67E22);
  static const Color redAccent = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _enterLandscapeFullscreen();
    _robotNotifier = ref.read(robotControlProvider.notifier);

    setDesktopLandscape(true);

    if (liveScanEnabled) {
      _liveScan = LiveScanController(
        startQuiz: (detection) {
          if (ref.read(wasteQuizProvider).phase != WasteQuizPhase.idle) return false;
          final frame = _latestFrame;
          if (frame == null) return false;
          ref.read(wasteQuizProvider.notifier).onRobotLocked(frame, detection);
          return true;
        },
        firstTokenMs: () => GemmaQuizService.instance.lastFirstTokenMs.value,
        ttsCount: () => QuizTtsService.instance.startedCount,
        nextWaitMs: () => ref.read(wasteQuizProvider.notifier).lastNextWaitMs,
      )..onQuizPhase(ref.read(wasteQuizProvider).phase); // a quiz may already be open (minimized)

      // M2b: preload Gemma now, so the first quiz is fast instead of showing
      // "Memuat model Gemma ke memori...". Fire-and-forget: ensureReady is
      // single-flight and returns at once if already loading or loaded, and
      // a failed preload just leaves the model to load as today, on the
      // first quiz (see GemmaQuizService.warmUp/ensureReady).
      GemmaQuizService.instance.warmUp(vision: true);
    }

    if (_r1Enabled) {
      final ws = WebSocketService();
      final robot = MaixCamRobot(sink: ws.sendRobotCommand, motor: ws.sendMotorCommand);
      _r1 = R1Orchestrator(robot);
      _r1Replies = ws.robotReplies.listen(robot.handleMessage);
      _r1Ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final r1 = _r1!..tick();
        final text = r1.robotConnected ? 'robot terhubung' : r1.message ?? 'memeriksa robot...';
        if (mounted && text != _r1Status) setState(() => _r1Status = text);
      });
    }

    // Subscribe to robot frames outside of build to avoid re-registering
    // the listener on every rebuild.
    _source.initialize();
    _frameSubscription = _source.frames.listen((frame) {
      if (!mounted) return;
      final now = DateTime.now();

      _frameCount++;
      _fpsFrameCount++;
      _lastFrameAt = now;
      _lastFrameBytes = frame.bytes.length;

      final elapsedMs = now.difference(_fpsWindowStart).inMilliseconds;
      if (elapsedMs >= 1000) {
        _streamFps = (_fpsFrameCount * 1000) / elapsedMs;
        _fpsFrameCount = 0;
        _fpsWindowStart = now;
      }

      setState(() => _latestFrame = frame);
      
      // Auto-generated waste quiz: only fed by the real MaixCAM2 stream, the
      // debug phone-camera path triggers it manually instead.
      if (frame.detections != null && ref.read(debugQuizSourceProvider) == WasteQuizSource.maixCam2) {
        final liveScan = _liveScan;
        if (liveScan != null) {
          liveScan.onDetections(
            frame.detections!,
            frameSize: Size(frame.width.toDouble(), frame.height.toDouble()),
          );
        } else {
          ref.read(wasteQuizProvider.notifier).onDetections(frame.detections!);
        }
      }
    });
    _statusSubscription = ref.listenManual(robotStatusProvider, (_, next) {
      final status = next.valueOrNull;

      if (status == 'Connected') {
        if (!_streamStartedForCurrentConnection) {
          _streamStartedForCurrentConnection = true;
          debugPrint('[Control] Connected status observed, starting stream');
          _onNewConnection();
          _robotNotifier.startStream();

          // Apply the user's chosen resolution preset on connect.
          final preset =
              ref.read(espConfigProvider).valueOrNull?.resolutionPreset ?? '480p';
          ref.read(robotControlProvider.notifier).setResolution(preset: preset);
        }
        return;
      }

      if (status == 'Disconnected' ||
          status == 'Reconnecting...' ||
          status == 'Connecting...') {
        if (_streamStartedForCurrentConnection) _r1?.linkDown();
        _streamStartedForCurrentConnection = false;
      }
    }, fireImmediately: true);

    // Connect to the robot when the control screen opens.
    unawaited(_connectAndStartStream());
    debugPrint('Robot controls enabled: true (awaiting WebSocket connection)');
  }

  /// Once per (re)connection, from whichever path sees it first.
  void _onNewConnection() {
    _liveScan?.onLinkRestored(); // 0020: a drop can't time absence; harmless on the first connect
    _r1?.linkUp(); // 0023: probe the command link (old firmware: "robot tidak terhubung")
  }

  void _enterLandscapeFullscreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (error) {
        debugPrint('Unable to enter landscape fullscreen: $error');
      }
    });
  }

  Future<void> _connectAndStartStream() async {
    final autoReconnect =
        ref.read(espConfigProvider).valueOrNull?.autoReconnect ?? true;
    final connected = await _robotNotifier.connect(autoReconnect: autoReconnect);

    if (!mounted) return;

    if (connected) {
      debugPrint('[Control] WebSocket connected');

      if (!_streamStartedForCurrentConnection) {
        _streamStartedForCurrentConnection = true;
        debugPrint('[Control] Starting stream after connect result');
        _onNewConnection();
        _robotNotifier.startStream();
      }
    } else {
      debugPrint('[Control] WebSocket connect failed, stream not started');
    }
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _statusSubscription?.close();
    _r1Ticker?.cancel();
    _r1Replies?.cancel();

    // Disconnect when leaving the control screen (not a quiz pause: the
    // stream stays up for the whole visit, M2b).
    debugPrint('[Control] Stopping MaixCAM2 stream');
    _robotNotifier.stopStream();

    // Dismiss quiz if it was left open so it doesn't block future scans.
    ref.read(wasteQuizProvider.notifier).dismiss();

    debugPrint('[Control] Leaving robot control, disconnecting WebSocket');
    unawaited(_robotNotifier.disconnect());
    unawaited(GemmaQuizService.instance.dispose());
    setDesktopLandscape(false);
    _liveScan?.dispose(); // last: dismiss() above can still report a phase change
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // M2b: the MaixCAM2 video and the live-scan machine both keep running
    // while the quiz popup is open (previously the stream was stopped and
    // restarted for every quiz, which is what caused the camera badge's
    // ~3 s drop to 0.2-0.4 fps after every close while it reconnected). The
    // state machine itself already refuses to lock or ask during ASKING/QUIZ
    // (decision 0008), so nothing new can be asked; this only keeps presence
    // tracking and the preview current.
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      if (prev?.phase != next.phase) _liveScan?.onQuizPhase(next.phase);
    });

    // Resend resolution to the device whenever the user changes it mid-session.
    ref.listen<AsyncValue<EspConfig>>(espConfigProvider, (previous, next) {
      final prevPreset = previous?.valueOrNull?.resolutionPreset;
      final nextPreset = next.valueOrNull?.resolutionPreset;
      if (nextPreset != null && nextPreset != prevPreset) {
        ref.read(robotControlProvider.notifier).setResolution(preset: nextPreset);
      }
    });

    final robotState = ref.watch(robotControlProvider);
    final status = ref.watch(robotStatusProvider).value ?? 'Disconnected';

    final isConnected = status == 'Connected';
    final isReconnecting = status == 'Reconnecting...';
    final isOperational = isConnected;

    if (_lastLoggedRobotControlsEnabled != isOperational) {
      _lastLoggedRobotControlsEnabled = isOperational;
      debugPrint('Robot controls ${isOperational ? 'enabled' : 'disabled'}');
    }

    final notifier = _robotNotifier;
    final speed = robotState.pwmSpeed;
    final statusLabel = isConnected
        ? 'LIVE'
        : isReconnecting
        ? 'RECONNECTING'
        : 'OFFLINE';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 960,
                        height: 380,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _VerticalControlSlider(
                              label: 'UP/DOWN',
                              sublabel: 'ARM HEIGHT',
                              value: (robotState.elbowAngle / 180).clamp(
                                0.0,
                                1.0,
                              ),
                              enabled: isOperational,
                              labelOnLeft: true,
                              onChanged: (value) =>
                                  notifier.setElbowAngle(value * 180),
                            ),
                            const SizedBox(width: 12),
                            _LandscapeDriveControls(
                              speed: speed,
                              enabled: isOperational,
                              onForward: () => notifier.sendMotor(
                                speed.toInt(),
                                speed.toInt(),
                              ),
                              onBack: () => notifier.sendMotor(
                                -speed.toInt(),
                                -speed.toInt(),
                              ),
                              onLeft: () => notifier.sendMotor(
                                -speed.toInt(),
                                speed.toInt(),
                              ),
                              onRight: () => notifier.sendMotor(
                                speed.toInt(),
                                -speed.toInt(),
                              ),
                              onStop: () => notifier.sendMotor(0, 0),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 400,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LandscapeCameraPanel(
                                    currentFrame: _latestFrame?.bytes,
                                    statusLabel: statusLabel,
                                    streamFps: _streamFps,
                                    frameCount: _frameCount,
                                    lastFrameAt: _lastFrameAt,
                                    lastFrameBytes: _lastFrameBytes,
                                    detections: _latestFrame?.detections ?? const [],
                                    detectionImageSize: Size(
                                      _latestFrame?.width.toDouble() ?? 0,
                                      _latestFrame?.height.toDouble() ?? 0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _LandscapeActionButtons(
                                    enabled: isOperational,
                                    onPickUp: notifier.pickUp,
                                    onRelease: notifier.release,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            _LandscapeSpeedPanel(
                              speed: speed,
                              enabled: isOperational,
                              onChanged: notifier.setPwmSpeed,
                            ),
                            const SizedBox(width: 12),
                            _VerticalControlSlider(
                              label: 'FORWARD/BACKWARD',
                              sublabel: 'ARM REACH',
                              value: (robotState.baseAngle / 180).clamp(
                                0.0,
                                1.0,
                              ),
                              enabled: isOperational,
                              labelOnLeft: false,
                              onChanged: (value) =>
                                  notifier.setBaseAngle(value * 180),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: _ExitControlButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (kDebugMode)
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: _DebugQuizSourceToggle(
                  onScanWithPhone: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => const DebugPhoneCameraSheet(),
                  ),
                ),
              ),
            ),
          const WasteQuizPopup(),
          if (kDebugMode && _liveScan != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveScanDebugOverlay(controller: _liveScan!),
                    if (_r1 != null) ...[
                      const SizedBox(height: 6),
                      Text('R1: ${_r1Status ?? 'memeriksa robot...'}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, backgroundColor: Colors.black54)),
                    ],
                    const SizedBox(height: 6),
                    const QuestionSourceSwitch(), // decision 0018: applies from the next scan
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Debug-only control for testing the auto-generated waste quiz without the
/// physical MaixCAM2 hardware connected — opens the phone's own camera and
/// feeds a captured photo straight to Gemma.
class _DebugQuizSourceToggle extends StatelessWidget {
  const _DebugQuizSourceToggle({required this.onScanWithPhone});

  final VoidCallback onScanWithPhone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onScanWithPhone,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBEC9C2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 18,
                color: _ControlScreenState.textPrimary,
              ),
              SizedBox(width: 6),
              Text(
                'Debug Scan',
                style: TextStyle(
                  color: _ControlScreenState.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitControlButton extends StatelessWidget {
  const _ExitControlButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBEC9C2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: _ControlScreenState.textPrimary,
              ),
              SizedBox(width: 6),
              Text(
                'Exit',
                style: TextStyle(
                  color: _ControlScreenState.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalControlSlider extends StatelessWidget {
  const _VerticalControlSlider({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.labelOnLeft = false,
  });

  final String label;
  final String sublabel;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final bool labelOnLeft;

  @override
  Widget build(BuildContext context) {
    final labels = FittedBox(
      fit: BoxFit.scaleDown,
      child: RotatedBox(
        quarterTurns: 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ControlScreenState.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ControlScreenState.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );

    final slider = Container(
      width: 58,
      height: 260,
      decoration: BoxDecoration(
        color: _ControlScreenState.primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.45),
            trackHeight: 4,
            thumbColor: _ControlScreenState.primaryColor,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 0,
            ),
          ),
          child: Slider(value: value, onChanged: enabled ? onChanged : null),
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: SizedBox(
        width: 90,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: labelOnLeft
              ? [
                  Expanded(child: Center(child: labels)),
                  const SizedBox(width: 4),
                  slider,
                ]
              : [
                  slider,
                  const SizedBox(width: 4),
                  Expanded(child: Center(child: labels)),
                ],
        ),
      ),
    );
  }
}

class _LandscapeDriveControls extends StatelessWidget {
  const _LandscapeDriveControls({
    required this.speed,
    required this.enabled,
    required this.onForward,
    required this.onBack,
    required this.onLeft,
    required this.onRight,
    required this.onStop,
  });

  final double speed;
  final bool enabled;
  final VoidCallback onForward;
  final VoidCallback onBack;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: SizedBox(
          width: 158,
          height: 270,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'DRIVE CONTROLS',
                style: TextStyle(
                  color: Color(0xFF3F4943),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 158,
                height: 180,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _DpadButton(
                        icon: Icons.arrow_upward,
                        onPressed: onForward,
                        onReleased: onStop,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _DpadButton(
                        icon: Icons.arrow_back,
                        onPressed: onLeft,
                        onReleased: onStop,
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: _DpadButton(
                        icon: Icons.hexagon_outlined,
                        onPressed: onStop,
                        onReleased: onStop,
                        isStop: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _DpadButton(
                        icon: Icons.arrow_forward,
                        onPressed: onRight,
                        onReleased: onStop,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _DpadButton(
                        icon: Icons.arrow_downward,
                        onPressed: onBack,
                        onReleased: onStop,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${speed.toInt()}% PWM',
                style: const TextStyle(
                  color: _ControlScreenState.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  const _DpadButton({
    required this.icon,
    required this.onPressed,
    required this.onReleased,
    this.isStop = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final bool isStop;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: 52,
        height: 56,
        decoration: BoxDecoration(
          color: isStop ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(isStop ? 26 : 12),
          border: Border.all(
            color: isStop ? const Color(0xFFFECACA) : const Color(0xFFBEC9C2),
          ),
        ),
        child: Icon(
          icon,
          color: isStop
              ? _ControlScreenState.redAccent
              : _ControlScreenState.textPrimary,
          size: isStop ? 30 : 28,
        ),
      ),
    );
  }
}

class _LandscapeCameraPanel extends StatelessWidget {
  const _LandscapeCameraPanel({
    required this.currentFrame,
    required this.statusLabel,
    required this.streamFps,
    required this.frameCount,
    required this.lastFrameAt,
    required this.lastFrameBytes,
    required this.detections,
    required this.detectionImageSize,
  });

  final Uint8List? currentFrame;
  final String statusLabel;
  final double streamFps;
  final int frameCount;
  final DateTime? lastFrameAt;
  final int lastFrameBytes;
  final List<Detection> detections;
  final Size detectionImageSize;

  @override
  Widget build(BuildContext context) {
    final statusColor = statusLabel == 'LIVE'
        ? _ControlScreenState.primaryColor
        : statusLabel == 'RECONNECTING'
        ? _ControlScreenState.orangeAccent
        : _ControlScreenState.redAccent;

    return Container(
      width: 400,
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (currentFrame != null)
              Image.memory(
                currentFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              _CameraFallback(
                isLoading: true,
                message: statusLabel == 'LIVE'
                    ? 'Connected. Waiting for camera frames...'
                    : 'Waiting for MaixCAM2 stream...',
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Colors.transparent,
                    Color(0x55000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            if (_showAppDetectionBoxes &&
                detections.isNotEmpty &&
                detectionImageSize.width > 0 &&
                detectionImageSize.height > 0)
              CustomPaint(
                painter: SegmentationOverlayPainter(
                  detections: detections,
                  imageSize: detectionImageSize,
                ),
              ),
            Positioned(
              left: 10,
              bottom: 10,
              child: _CameraDiagnosticsBadge(
                streamFps: streamFps,
                frameCount: frameCount,
                lastFrameAt: lastFrameAt,
                lastFrameBytes: lastFrameBytes,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraDiagnosticsBadge extends ConsumerWidget {
  final double streamFps;
  final int frameCount;
  final DateTime? lastFrameAt;
  final int lastFrameBytes;

  const _CameraDiagnosticsBadge({
    required this.streamFps,
    required this.frameCount,
    required this.lastFrameAt,
    required this.lastFrameBytes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(resolutionAckProvider).valueOrNull;
    final frameAgeMs = lastFrameAt == null
        ? null
        : DateTime.now().difference(lastFrameAt!).inMilliseconds;
    final sizeLabel = lastFrameBytes > 0
        ? '${(lastFrameBytes / 1024).toStringAsFixed(1)} KB'
        : 'No frame';

    final resLabel = resolution != null
        ? '${resolution.width.toInt()}x${resolution.height.toInt()}'
        : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FPS ${streamFps.toStringAsFixed(1)} • F $frameCount • $resLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            frameAgeMs == null ? sizeLabel : '$sizeLabel • ${frameAgeMs}ms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.isLoading, required this.message});

  final bool isLoading;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0F3F2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _ControlScreenState.primaryColor,
                  strokeWidth: 3,
                ),
              )
            else
              const Icon(
                Icons.videocam_off_outlined,
                color: _ControlScreenState.textSecondary,
                size: 28,
              ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ControlScreenState.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeActionButtons extends StatelessWidget {
  const _LandscapeActionButtons({
    required this.enabled,
    required this.onPickUp,
    required this.onRelease,
  });

  final bool enabled;
  final VoidCallback onPickUp;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: enabled ? onPickUp : null,
                icon: const Icon(Icons.pinch, size: 20),
                label: const Text('PICK UP'),
                style: FilledButton.styleFrom(
                  backgroundColor: _ControlScreenState.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _ControlScreenState.primaryColor,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: enabled ? onRelease : null,
                icon: const Icon(Icons.back_hand_outlined, size: 20),
                label: const Text('RELEASE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ControlScreenState.textPrimary,
                  disabledForegroundColor: _ControlScreenState.textPrimary,
                  side: const BorderSide(color: Color(0xFFBEC9C2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeSpeedPanel extends StatelessWidget {
  const _LandscapeSpeedPanel({
    required this.speed,
    required this.enabled,
    required this.onChanged,
  });

  final double speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: Container(
        width: 170,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBEC9C2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Speed (PWM)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF3F4943),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${speed.toInt()}%',
                  style: const TextStyle(
                    color: _ControlScreenState.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _ControlScreenState.primaryColor,
                inactiveTrackColor: const Color(0xFFE5E7EB),
                trackHeight: 4,
                thumbColor: _ControlScreenState.primaryColor,
                overlayColor: _ControlScreenState.primaryColor.withValues(
                  alpha: 0.12,
                ),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: speed.clamp(0, 100),
                min: 0,
                max: 100,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
