// Copyright (c) Boris Agung, Irham Fajar

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey, SystemChrome, SystemUiMode;

import '../models/config_model.dart';
import '../models/scanned_waste.dart';
import '../providers/esp_config_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../services/live_scan_controller.dart';
import '../services/quiz_tts_service.dart';
import '../services/robot/motion_gate.dart';
import '../services/robot/r1_orchestrator.dart';
import '../services/robot/robot_controller.dart';
import '../services/websocket_service.dart';
import '../widgets/debug_phone_camera_sheet.dart';
import '../widgets/control_layout.dart';
import '../widgets/desktop_viewport.dart';
import '../widgets/drive_pad.dart';
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
const _pickUpQuizFlow = liveScanEnabled && bool.fromEnvironment('G1_PICKUP_QUIZ_FLOW');

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> with WidgetsBindingObserver {
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

  /// Every motor and servo command passes here (decision 0026): the
  /// emergency stop, STOPPED, R1's drive lock, the link, the heartbeat.
  late final MotionGate _gate;

  /// Set only with R1 (see [_r1Enabled]).
  R1Orchestrator? _r1;
  StreamSubscription<Map<String, dynamic>>? _r1Replies;
  Timer? _r1Ticker;
  String? _r1Status;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color primaryColor = Color(0xFF1D9E75);
  static const Color redAccent = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _enterLandscapeFullscreen();
    _robotNotifier = ref.read(robotControlProvider.notifier);

    setDesktopLandscape(true);

    if (liveScanEnabled) {
      _liveScan = LiveScanController(
        manualPickUpQuiz: _pickUpQuizFlow,
        startQuiz: (detection, frame) {
          if (ref.read(wasteQuizProvider).phase != WasteQuizPhase.idle) return false;
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

    final ws = WebSocketService();
    final robot = MaixCamRobot(
      sink: (command) {
        if (_gate.allowsCommand(command)) ws.sendRobotCommand(command);
      },
      motor: ws.sendMotorCommand,
    );
    _gate = MotionGate(
      robot: robot,
      sendServo: ws.sendServoCommand,
      onEvent: (event, data) {
        debugPrint('[Control] $event $data');
        _liveScan?.logEvent(event, data);
      },
      onStop: (reason) => _r1?.emergencyStop(reason),
      onArmCommand: (motion) => _liveScan?.onArmCommand(motion),
      armBusy: () => _r1?.ignoresLiveScanLocks ?? false,
    )..addListener(() {
        _liveScan?.setScanPaused(_gate.stopped); // no lock, identify or new quiz while STOPPED (0026)
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);

    if (_r1Enabled) {
      _r1 = R1Orchestrator(robot, onResume: (reason) {
        // A robot that misbehaved stops everything until "Lanjutkan" (0026).
        if (const {'robot_error', 'robot_unreachable', 'pick_failed'}.contains(reason)) _gate.emergencyStop('error');
      });
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
            armMoving: WebSocketService().armMoving, // same message as the frame (0026)
            capturedFrame: frame,
          );
        } else if (!_gate.stopped) {
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
        _gate.linkLost(); // STOPPED (link_lost) until "Lanjutkan" (0026)
        _streamStartedForCurrentConnection = false;
      }
    }, fireImmediately: true);

    // Connect to the robot when the control screen opens.
    unawaited(_connectAndStartStream());
    debugPrint('Robot controls enabled: true (awaiting WebSocket connection)');
  }

  /// Debug overlay: Gemma's item next to the detector class (decision 0025).
  static String? _scanLine(ScannedWaste? scan) =>
      scan == null ? null : 'gemma "${scan.displayName}"   detektor ${scan.detectorLabel ?? '-'}';

  /// Once per (re)connection, from whichever path sees it first.
  void _onNewConnection() {
    _gate.linkRestored(); // first: STOP + motor 0,0 before anything else (0026)
    _liveScan?.onLinkRestored(); // 0020: a drop can't time absence; harmless on the first connect
    _r1?.linkUp(); // 0023: probe the command link (old firmware: "robot tidak terhubung")
  }

  /// Escape, or space outside a text field: the emergency stop.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (key == LogicalKeyboardKey.escape || (key == LogicalKeyboardKey.space && !typing)) {
      _gate.emergencyStop('button');
      return true;
    }
    return false;
  }

  /// "Lanjutkan": the deliberate second action after a stop.
  void _resumeAfterStop() {
    _gate.resume();
    _r1?.resumeAfterStop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _gate.onAppLifecycle(state);

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
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _gate.dispose(); // motor 0,0, heartbeat off

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

    void stop() => _gate.emergencyStop('button');
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: kDebugMode ? _debugSheet(context) : null,
      body: SafeArea(
        child: ControlLayout(
          stoppedBanner: _gate.stopped ? StoppedBanner(reason: _gate.stopReason, onResume: _resumeAfterStop) : null,
          exitButton: ControlPill(icon: Icons.arrow_back_rounded, label: 'Exit', onTap: () => Navigator.of(context).pop()),
          debugScanButton: ControlPill(
            icon: Icons.bug_report_outlined,
            label: 'Debug Scan',
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          historyButton: const HistoryPill(),
          armHeight: (compact) => ArmSlider(
            compact: compact,
            label: 'UP/DOWN',
            sublabel: 'ARM HEIGHT',
            value: (robotState.elbowAngle / 180).clamp(0.0, 1.0),
            enabled: isOperational,
            onChanged: (value) {
              if (_gate.servo('elbow', (value * 180).toInt())) notifier.setElbowAngle(value * 180);
            },
          ),
          drivePad: (compact) => DrivePad(
            compact: compact,
            speed: speed,
            enabled: isOperational,
            onForward: () => _gate.motor(speed.toInt(), speed.toInt()),
            onBack: () => _gate.motor(-speed.toInt(), -speed.toInt()),
            onLeft: () => _gate.motor(-speed.toInt(), speed.toInt()),
            onRight: () => _gate.motor(speed.toInt(), -speed.toInt()),
            onStop: _gate.stopWheels, // also every D-pad release
          ),
          camera: _LandscapeCameraPanel(
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
          actions: GripperButtons(
            enabled: isOperational,
            width: robotState.gripperVal,
            onWidthChanged: (value) {
              final width = value.round();
              if (_gate.servo('gripper', width)) notifier.setGripperVal(width.toDouble());
            },
            onPickUp: () {
              if (_gate.servo('gripper', 100)) {
                notifier.setGripperVal(100);
                if (_pickUpQuizFlow) _liveScan?.onPickUpPressed();
              }
            },
            onRelease: () {
              if (_gate.servo('gripper', 0)) notifier.setGripperVal(0);
            },
          ),
          speed: (compact) => SpeedSlider(compact: compact, speed: speed, enabled: isOperational, onChanged: notifier.setPwmSpeed),
          stopButton: EmergencyStopButton(onStop: stop),
          armReach: (compact) => ArmSlider(
            compact: compact,
            label: 'FORWARD/BACKWARD',
            sublabel: 'ARM REACH',
            value: (robotState.reachValue / 180).clamp(0.0, 1.0),
            enabled: isOperational,
            onChanged: (value) {
              if (_gate.servo('reach', (value * 180).toInt())) notifier.setReachValue(value * 180);
            },
          ),
          launcher: const QuizLauncherButton(),
          quiz: WasteQuizPopup(onStop: stop, showLauncher: false),
        ),
      ),
    );
  }

  /// Debug Scan (debug builds only): the live-scan readout, the question
  /// source and "Reset scan (debug)", off the student's screen.
  Widget _debugSheet(BuildContext context) {
    return Drawer(
      width: 380,
      backgroundColor: const Color(0xFF2B2B2B),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Base', style: TextStyle(color: Colors.white)),
              IconButton(onPressed: () => _nudgeBase(-2), icon: const Icon(Icons.chevron_left, color: Colors.white), tooltip: 'Base left'),
              IconButton(onPressed: () => _nudgeBase(2), icon: const Icon(Icons.chevron_right, color: Colors.white), tooltip: 'Base right'),
            ]),
            if (_liveScan != null)
              LiveScanDebugOverlay(
                  controller: _liveScan!,
                  scanLine: [
                    ?_scanLine(ref.watch(wasteQuizProvider).scan),
                    'gerak diblokir ${_gate.blocked}${_gate.stopped ? '   STOPPED (${_gate.stopReason})' : ''}',
                  ].join('\n')),
            if (_r1 != null) ...[
              const SizedBox(height: 6),
              Text('R1: ${_r1Status ?? 'memeriksa robot...'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, backgroundColor: Colors.black54)),
            ],
            const SizedBox(height: 6),
            const Align(alignment: Alignment.centerLeft, child: QuestionSourceSwitch()), // 0018: from the next scan
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                // Gemma on a phone-camera photo, without the MaixCAM2.
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => const DebugPhoneCameraSheet(),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Scan dengan kamera HP'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nudgeBase(double delta) {
    final angle = (ref.read(robotControlProvider).baseAngle + delta).clamp(0.0, 180.0);
    if (_gate.servo('base', angle.toInt())) _robotNotifier.setBaseAngle(angle);
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
        ? const Color(0xFFE8812A)
        : _ControlScreenState.redAccent;

    // Sized by ControlLayout (524 x 300 at most, Figma 43:63).
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D0D0)),
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
              left: 13,
              bottom: 13,
              child: _CameraDiagnosticsBadge(
                streamFps: streamFps,
                frameCount: frameCount,
                lastFrameAt: lastFrameAt,
                lastFrameBytes: lastFrameBytes,
              ),
            ),
            Positioned(
              top: 13,
              right: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.66,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF474747),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            frameAgeMs == null ? sizeLabel : '$sizeLabel • ${frameAgeMs}ms',
            style: const TextStyle(
              color: Color(0xFFDDDDDD),
              fontSize: 10,
              fontWeight: FontWeight.w500,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC4C4C4), Color(0xFFF2F2F2), Color(0xFFD9D9D9), Color(0xFFA8A8A8)],
          stops: [0, 0.45, 0.6, 1],
        ),
      ),
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
                color: Color(0xFF6B6B6B),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
