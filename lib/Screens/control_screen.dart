// Copyright (c) Boris Agung, Irham Fajar

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey, MethodChannel, SystemChrome, SystemUiMode;

import '../models/config_model.dart';
import '../models/control_session.dart';
import '../models/scanned_waste.dart';
import '../providers/config_link_provider.dart';
import '../providers/esp_config_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../services/live_scan_controller.dart';
import '../services/live_scan_state_machine.dart' show LiveScanState;
import '../services/quiz_tts_service.dart';
import '../services/robot/motion_gate.dart';
import '../services/robot/r1_orchestrator.dart';
import '../services/robot/robot_controller.dart';
import '../services/scan_record_store.dart';
import '../services/websocket_service.dart';
import '../theme/elio_theme.dart';
import '../widgets/control/control_panels.dart';
import '../widgets/control/r2_controls.dart';
import '../widgets/debug_phone_camera_sheet.dart';
import '../widgets/control_layout.dart';
import '../widgets/desktop_viewport.dart';
import '../widgets/elio_drawer_host.dart';
import '../widgets/elio_sidebar.dart';
import '../widgets/elio_top_bar.dart' show ElioAvatar;
import '../widgets/learn/learn_ui.dart' show LearnTheme;
import '../widgets/live_scan_debug_overlay.dart';
import '../widgets/question_source_switch.dart';
import '../widgets/segmentation_overlay_painter.dart';
import '../widgets/waste_quiz_popup.dart';
import '../services/frame_source/maix_cam_source.dart';
import '../services/frame_source/frame_source.dart';
import 'login_screen.dart';

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
  // Read once: `ref` can't be used inside dispose() (A1 phone log, 29 Oct).
  late final WasteQuizNotifier _quizNotifier;
  late final StateController<bool> _dropPending;
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
  StreamSubscription<Map<String, dynamic>>? _robotReplies;
  Timer? _statusDebounceTimer;
  Timer? _r1Ticker;
  String? _r1Status;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _drawerKey = GlobalKey<ElioDrawerHostState>();

  /// The R2 "Scan quiz" toggle: session-only (decision 0173).
  bool _scanQuizOn = true;

  /// "This drive" counts records saved from here on.
  final DateTime _openedAt = DateTime.now();

  /// The joystick's current direction, for the drive card's status chip.
  DriveDir? _driveDir;

  @override
  void initState() {
    super.initState();
    _enterLandscapeFullscreen();
    _robotNotifier = ref.read(robotControlProvider.notifier);
    _quizNotifier = ref.read(wasteQuizProvider.notifier);
    _dropPending = ref.read(r1DropPendingProvider.notifier);

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
      onHomeTimeout: () {
        if (mounted) {
          ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
        }
      },
      armBusy: () => _r1?.ignoresLiveScanLocks ?? false,
      handPaused: () => _r1?.handInView ?? false,
    )..addListener(() {
        _applyScanPause(); // no lock, identify or new quiz while STOPPED (0026)
        if (_gate.stopped && mounted) {
          ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
        }
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);

    _robotReplies = ws.robotReplies.listen((msg) {
      robot.handleMessage(msg);
      final reply = RobotReply.fromJson(msg);
      if (reply != null) {
        if (_gate.pendingHomeSeq != null && reply.seq == _gate.pendingHomeSeq) {
          if (reply.kind == ReplyKind.motionDone) {
            final homeSuccess = _gate.onHomeReply(reply);
            if (homeSuccess) {
              ref.read(robotControlProvider.notifier).resetToHome();
            }
          } else if (reply.kind == ReplyKind.error) {
            _gate.onHomeReply(reply);
            ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
          } else if (reply.kind == ReplyKind.ack) {
            _gate.onHomeReply(reply);
            // Ack alone means accepted; do not mark successful or reset slider cache.
          }
        }
        if (reply.seq == robot.lastStatusSeq) {
          ref.read(robotControlProvider.notifier).updateStatus(
                eeMm: reply.eeMm,
                clearEeMm: reply.eeMm == null,
                atHome: reply.atHome,
              );
        } else if (reply.hasEeMm || reply.atHome != null) {
          ref.read(robotControlProvider.notifier).updateStatus(
                eeMm: reply.eeMm,
                clearEeMm: reply.hasEeMm && reply.eeMm == null,
                atHome: reply.atHome,
              );
        }
        if (reply.kind == ReplyKind.motionDone) {
          robot.status();
        }
      }
    });

    if (_r1Enabled) {
      _r1 = R1Orchestrator(robot, onResume: (reason) {
        // A robot that misbehaved stops everything until "Lanjutkan" (0026).
        if (const {'robot_error', 'robot_unreachable', 'pick_failed'}.contains(reason)) _gate.emergencyStop('error');
      });
      _r1Ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final r1 = _r1!..tick();
        final text = r1.robotConnected ? 'robot terhubung' : r1.message ?? 'memeriksa robot...';
        if (mounted && text != _r1Status) setState(() => _r1Status = text);
        final dropPending = r1.state == R1State.sorting || r1.state == R1State.waitBoth;
        if (ref.read(r1DropPendingProvider) != dropPending) {
          ref.read(r1DropPendingProvider.notifier).state = dropPending;
        }
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
        } else if (!_gate.stopped && _scanQuizOn) {
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
        ref.read(robotControlProvider.notifier).updateStatus(
              clearEeMm: true,
              clearAtHome: true,
            );
      }
    }, fireImmediately: true);

    // Connect to the robot when the control screen opens.
    unawaited(_connectAndStartStream());
    debugPrint('Robot controls enabled: true (awaiting WebSocket connection)');
  }

  /// STOPPED (0026) or the Scan quiz toggle off (0173): frames still stream,
  /// none starts a lock or a quiz. Never touches the stream or the robot.
  void _applyScanPause() => _liveScan?.setScanPaused(_gate.stopped || !_scanQuizOn);

  /// Debug overlay: Gemma's item next to the detector class (decision 0025).
  static String? _scanLine(ScannedWaste? scan) =>
      scan == null ? null : 'gemma "${scan.displayName}"   detektor ${scan.detectorLabel ?? '-'}';

  /// Once per (re)connection, from whichever path sees it first.
  void _onNewConnection() {
    _gate.linkRestored(); // first: STOP + motor 0,0 before anything else (0026)
    _liveScan?.onLinkRestored(); // 0020: a drop can't time absence; harmless on the first connect
    _r1?.linkUp(); // 0023: probe the command link (old firmware: "robot tidak terhubung")
    _gate.robot.status();
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
    _robotReplies?.cancel();
    _statusDebounceTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _gate.dispose(); // motor 0,0, heartbeat off

    // Disconnect when leaving the control screen (not a quiz pause: the
    // stream stays up for the whole visit, M2b).
    debugPrint('[Control] Stopping MaixCAM2 stream');
    _robotNotifier.stopStream();

    debugPrint('[Control] Leaving robot control, disconnecting WebSocket');
    unawaited(_robotNotifier.disconnect());
    unawaited(GemmaQuizService.instance.dispose());
    setDesktopLandscape(false);
    _liveScan?.dispose();

    // Riverpod refuses provider writes while the tree unmounts, and the throw
    // used to skip the disconnect above: clear the drop flag and any open quiz
    // (so it doesn't block future scans) once the tree is unlocked.
    final quiz = _quizNotifier;
    final dropPending = _dropPending;
    Future.microtask(() {
      dropPending.state = false;
      quiz.dismiss();
    });
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
    final quizState = ref.watch(wasteQuizProvider);

    final isConnected = status == 'Connected';
    final isOperational = isConnected;
    final link = controlLink(status);

    if (_lastLoggedRobotControlsEnabled != isOperational) {
      _lastLoggedRobotControlsEnabled = isOperational;
      debugPrint('Robot controls ${isOperational ? 'enabled' : 'disabled'}');
    }

    final notifier = _robotNotifier;
    final speed = robotState.pwmSpeed;
    final detections = _latestFrame?.detections ?? const <Detection>[];
    final target = isConnected ? hudTarget(detections) : null;
    final tip = controlTip(
      link: link,
      stopped: _gate.stopped,
      quizOpen: quizState.phase != WasteQuizPhase.idle && !quizState.minimized,
      itemLabel: target?.label,
      itemLocked: _liveScan?.machine.state == LiveScanState.asking,
      distCm: target?.distCm,
    );
    final ws = WebSocketService();
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

    void stop() => _gate.emergencyStop('button');
    void reconnect() => unawaited(_connectAndStartStream());

    return ElioTheme.wrap(Builder(builder: (context) {
      final p = context.elio;
      final tall = MediaQuery.sizeOf(context).height >= 700;
      final (driveWord, driveColor) = switch (link) {
        ControlLink.waiting => ('Waiting', p.secondaryText),
        ControlLink.disconnected => ('Offline', p.errorText),
        _ when _gate.stopped => ('Stopped', p.errorText),
        _ => (switch (_driveDir) {
            DriveDir.forward => 'Forward',
            DriveDir.back => 'Back',
            DriveDir.left => 'Left',
            DriveDir.right => 'Right',
            null => 'Ready',
          }, p.primaryText),
      };
      final (armWord, armColor) = switch (link) {
        ControlLink.waiting => ('Waiting', p.secondaryText),
        ControlLink.disconnected => ('Offline', p.errorText),
        _ when _gate.stopped => ('Stopped', p.errorText),
        _ => (_gate.isHoming ? 'Homing' : 'Ready', p.primaryText),
      };
      Widget hint(String art, String text) => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: p.surfaceRaised, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              controlArt(art, height: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary, fontSize: 12)),
              ),
            ]),
          );
      Widget armFader(String label, String sub, double value, ValueChanged<double> onChanged) => Column(children: [
            Text('${(value * 100).round()}%', style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Expanded(
              child: SizedBox(
                width: 56,
                child: ControlFader(vertical: true, value: value, semanticLabel: label, onChanged: isOperational ? onChanged : null),
              ),
            ),
            const SizedBox(height: 4),
            ControlCaps(label),
            if (tall) Text(sub, maxLines: 1, style: TextStyle(color: p.textTertiary, fontSize: 11)),
          ]);
      final tally = driveTally(ScanRecordStore.instance.records, _openedAt);
      final missionDone = tally.bins.values.fold(0, (a, b) => a + b);
      void onScanQuiz(bool on) => setState(() {
            _scanQuizOn = on;
            _applyScanPause();
          });
      void onVoice(bool _) => ref.read(wasteQuizProvider.notifier).toggleVoice();

      return ElioDrawerHost(
        key: _drawerKey,
        drawer: Material(
          color: p.surface,
          child: ElioSidebar(
            user: user,
            currentIndex: -1, // Control is not a tab
            onClose: () => _drawerKey.currentState?.close(),
            onSelect: (index) {
              final nav = ref.read(navigationIndexProvider.notifier);
              _drawerKey.currentState?.close();
              Navigator.of(context).pop(); // leaving Control disconnects (dispose)
              nav.state = index;
            },
            onSignOut: () async {
              final nav = Navigator.of(context, rootNavigator: true);
              _drawerKey.currentState?.close();
              await FirebaseAuth.instance.signOut();
              nav.pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => LoginScreen(auth: FirebaseAuth.instance)),
                (_) => false,
              );
            },
          ),
        ),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: p.background,
          endDrawerEnableOpenDragGesture: false,
          endDrawer: kDebugMode ? _debugSheet(context) : null,
          body: SafeArea(
            child: AnimatedBuilder(
              animation: ScanRecordStore.instance, // the tally and History follow new records
              builder: (context, _) => ControlLayout(
                stoppedBanner: _gate.stopped ? StoppedBanner(reason: _gate.stopReason, onResume: _resumeAfterStop) : null,
                stoppedPill: _gate.stopped ? StoppedPill(reason: _gate.stopReason) : null,
                exitButton: ControlPill(icon: Icons.arrow_back_rounded, label: 'Exit', onTap: () => Navigator.of(context).pop()),
                debugScanButton: ControlPill(
                  icon: Icons.bug_report_outlined,
                  label: 'Debug Scan',
                  dashed: true,
                  onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
                historyButton: const HistoryPill(),
                avatar: ElioAvatar(photoUrl: user?.photoURL, onTap: () => _drawerKey.currentState?.open()),
                driveStatus: ControlStatusChip(label: driveWord, color: driveColor),
                joystick: controlEnabled(
                  isOperational,
                  DriveJoystick(
                    enabled: isOperational,
                    onDirection: (dir) {
                      driveCommand(_gate, dir, speed.toInt());
                      setState(() => _driveDir = dir);
                    },
                    onRelease: () {
                      _gate.stopWheels(); // motor 0,0, as every D-pad release
                      setState(() => _driveDir = null);
                    },
                  ),
                ),
                driveHint: hint('tyre_buddy', isOperational ? 'Push to drive · let go to stop' : 'Unlocks when the robot connects'),
                speed: controlEnabled(
                  isOperational,
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Expanded(child: ControlCaps('SPEED (PWM)')),
                      Text('${speed.toInt()}%', style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    SizedBox(
                      height: 40,
                      child: ControlFader(value: speed, max: 100, semanticLabel: 'Speed', onChanged: isOperational ? notifier.setPwmSpeed : null),
                    ),
                    const SizedBox(height: 4),
                    GearChips(speed: speed, onSelect: isOperational ? notifier.setPwmSpeed : null),
                  ]),
                ),
                camera: _LandscapeCameraPanel(
                  currentFrame: _latestFrame?.bytes,
                  link: link,
                  streamFps: _streamFps,
                  frameCount: _frameCount,
                  lastFrameAt: _lastFrameAt,
                  lastFrameBytes: _lastFrameBytes,
                  detections: detections,
                  detectionImageSize: Size(
                    _latestFrame?.width.toDouble() ?? 0,
                    _latestFrame?.height.toDouble() ?? 0,
                  ),
                  retry: RetryInfo(
                    attempt: ws.retryCount,
                    maxAttempts: ws.maxRetries,
                    nextRetryAt: ws.nextRetryAt,
                    autoReconnect: ws.autoReconnectEnabled,
                  ),
                  onReconnect: reconnect,
                  onWifiSettings: defaultTargetPlatform == TargetPlatform.android
                      ? () => const MethodChannel('elio/device_health').invokeMethod<void>('wifiSettings')
                      : null,
                ),
                actions: controlEnabled(
                  isOperational,
                  LayoutBuilder(builder: (context, c) {
                    final key = (c.maxHeight - 26).clamp(36.0, 64.0);
                    return Row(children: [
                      HomeButton(onConfirmed: _gate.home, enabled: isOperational, size: key),
                      const SizedBox(width: 10),
                      TransportKey(
                        icon: Icons.back_hand_outlined,
                        label: 'PICK UP',
                        primary: true,
                        size: key,
                        onTap: isOperational
                            ? () {
                                if (_gate.servo('gripper', 100)) {
                                  notifier.setGripperVal(100);
                                  if (_pickUpQuizFlow) _liveScan?.onPickUpPressed();
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 10),
                      TransportKey(
                        icon: Icons.front_hand_outlined,
                        label: 'RELEASE',
                        size: key,
                        onTap: isOperational
                            ? () {
                                if (_gate.servo('gripper', 0)) notifier.setGripperVal(0);
                              }
                            : null,
                      ),
                      VerticalDivider(width: 24, color: p.borderSubtle),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Row(children: [
                            const Expanded(child: ControlCaps('GRIPPER')),
                            Text('${robotState.gripperVal.round()}%',
                                style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                          SizedBox(
                            height: 36,
                            child: ControlFader(
                              value: robotState.gripperVal,
                              max: 100,
                              semanticLabel: 'Gripper',
                              onChanged: isOperational
                                  ? (value) {
                                      final width = value.round();
                                      if (_gate.servo('gripper', width)) notifier.setGripperVal(width.toDouble());
                                    }
                                  : null,
                            ),
                          ),
                          if (c.maxHeight >= 90)
                            Row(children: [
                              Text('Open', style: TextStyle(color: p.textTertiary, fontSize: 11)),
                              const Spacer(),
                              Text('Closed', style: TextStyle(color: p.textTertiary, fontSize: 11)),
                            ]),
                        ]),
                      ),
                    ]);
                  }),
                ),
                armStatus: ControlStatusChip(label: armWord, color: armColor),
                armHeight: controlEnabled(
                  isOperational,
                  armFader('HEIGHT', 'Up / Down', (robotState.heightValue / 180).clamp(0.0, 1.0), (value) {
                    if (_gate.servo('height', (value * 180).toInt())) {
                      notifier.setHeightValue(value * 180);
                      _scheduleStatusRequest();
                    }
                  }),
                ),
                armReach: controlEnabled(
                  isOperational,
                  armFader('REACH', 'Fwd / Back', (robotState.reachValue / 180).clamp(0.0, 1.0), (value) {
                    if (_gate.servo('reach', (value * 180).toInt())) {
                      notifier.setReachValue(value * 180);
                      _scheduleStatusRequest();
                    }
                  }),
                ),
                power: PowerGlowButton(
                  link: link,
                  size: tall ? 64 : 52,
                  onTap: link == ControlLink.disconnected
                      ? reconnect
                      : () => unawaited(ref.read(configLinkProvider.notifier).disconnect()),
                ),
                stopButton: EmergencyStopButton(onStop: stop),
                armTip: hint(
                  'gear_buddy',
                  isOperational
                      ? 'Slide up to lift, slide forward to reach. The arm only moves when the robot is not STOPPED.'
                      : 'Arm controls unlock when the robot is connected. STOP always works.',
                ),
                bottomCards: [
                  MissionCard(done: missionDone),
                  DriveTallyCard(bins: tally.bins, trophies: tally.trophies),
                  ElioTipCard(text: tip.text, mood: tip.mood),
                  ControlTogglesCard(scanQuiz: _scanQuizOn, voice: quizState.voiceOn, onScanQuiz: onScanQuiz, onVoice: onVoice),
                ],
                compactStrip: ControlCompactStrip(
                  missionDone: missionDone,
                  bins: tally.bins,
                  tip: tip.text,
                  scanQuiz: _scanQuizOn,
                  voice: quizState.voiceOn,
                  onScanQuiz: onScanQuiz,
                  onVoice: onVoice,
                ),
                quiz: WasteQuizPopup(
                  onStop: stop,
                  showLauncher: false,
                  onRescan: () {
                    _liveScan?.logEvent('rescan_tapped', {});
                    _liveScan?.rescan();
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }));
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('debug_home_button'),
                onPressed: () => _gate.home(),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('HOME'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ]),
            if (_liveScan != null)
              LiveScanDebugOverlay(
                controller: _liveScan!,
                scanLine: [
                  ?_scanLine(ref.watch(wasteQuizProvider).scan),
                  'gerak diblokir ${_gate.blocked}${_gate.stopped ? '   STOPPED (${_gate.stopReason})' : ''}',
                ].join('\n'),
                armTags: WebSocketService().armTags,
                eeMm: ref.watch(robotControlProvider).eeMm,
              ),
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

  void _scheduleStatusRequest() {
    _statusDebounceTimer?.cancel();
    _statusDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _gate.status();
      }
    });
  }

  void _nudgeBase(double delta) {
    final angle = (ref.read(robotControlProvider).baseAngle + delta).clamp(0.0, 180.0);
    if (_gate.servo('base', angle.toInt())) _robotNotifier.setBaseAngle(angle);
  }
}

class _LandscapeCameraPanel extends StatelessWidget {
  const _LandscapeCameraPanel({
    required this.currentFrame,
    required this.link,
    required this.streamFps,
    required this.frameCount,
    required this.lastFrameAt,
    required this.lastFrameBytes,
    required this.detections,
    required this.detectionImageSize,
    required this.retry,
    required this.onReconnect,
    this.onWifiSettings,
  });

  final Uint8List? currentFrame;
  final ControlLink link;
  final double streamFps;
  final int frameCount;
  final DateTime? lastFrameAt;
  final int lastFrameBytes;
  final List<Detection> detections;
  final Size detectionImageSize;
  final RetryInfo retry;
  final VoidCallback onReconnect;
  final VoidCallback? onWifiSettings;

  @override
  Widget build(BuildContext context) {
    return ControlCameraHud(
      key: const ValueKey('control_camera'),
      frame: currentFrame,
      imageSize: detectionImageSize,
      detections: detections,
      link: link,
      fps: streamFps,
      retry: retry,
      onReconnect: onReconnect,
      onWifiSettings: onWifiSettings,
      debugBoxes: _showAppDetectionBoxes &&
              detections.isNotEmpty &&
              detectionImageSize.width > 0 &&
              detectionImageSize.height > 0
          ? CustomPaint(
              painter: SegmentationOverlayPainter(
                detections: detections,
                imageSize: detectionImageSize,
              ),
            )
          : null,
      diagnostics: _CameraDiagnosticsBadge(
        streamFps: streamFps,
        frameCount: frameCount,
        lastFrameAt: lastFrameAt,
        lastFrameBytes: lastFrameBytes,
      ),
      quizButton: const QuizReopenButton(),
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
    // Config → Settings → Show FPS overlay (decision 0145).
    final show = ref.watch(espConfigProvider.select((c) => c.valueOrNull?.showFpsOverlay ?? false));
    if (!show) return const SizedBox.shrink();
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
