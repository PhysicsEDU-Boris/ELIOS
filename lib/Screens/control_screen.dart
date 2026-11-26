// Copyright (c) Boris Agung, Irham Fajar

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey, MethodChannel, SystemChrome, SystemUiMode;

import '../models/config_model.dart';
import '../models/control_session.dart';
import '../models/scanned_waste.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/config_link_provider.dart';
import '../providers/esp_config_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/ai_quiz_service.dart';
import '../services/live_scan_controller.dart';
import '../services/lock_tracking.dart';
import '../services/live_scan_state_machine.dart' show LiveScanState;
import '../services/quiz_tts_service.dart';
import '../services/robot/fader_throttle.dart';
import '../services/robot/joystick_controller.dart';
import '../services/robot/robot_settings.dart';
import 'advanced_settings_screen.dart';
import '../services/robot/motion_gate.dart';
import '../services/robot/r1_orchestrator.dart';
import '../services/robot/robot_controller.dart';
import '../services/scan_record_store.dart';
import '../services/websocket_service.dart';
import '../theme/elio_theme.dart';
import '../widgets/control/control_panels.dart';
import '../widgets/control/phone/phone_control.dart';
import '../widgets/control/phone/phone_guide.dart';
import '../widgets/control/r2_controls.dart';
import '../widgets/control/sort_bubble.dart';
import 'scan_history_screen.dart';
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
import '../services/robot/arm_kinematics.dart' show ArmRefusal;
import '../services/robot/arm_pose.dart';
import '../services/robot/arm_tag_switch.dart';
import '../services/robot/bin_run.dart';
import 'login_screen.dart';
import 'package:elio/l10n/l10n.dart';

/// The MaixCAM2 already draws its box, mask and label into the video, so the
/// app's own box is a debug aid, shown with the live-scan debug overlay only.
const _showAppDetectionBoxes = kDebugMode && liveScanEnabled;

/// `--dart-define=R1=true` (with LIVE_SCAN): R1 probes the MaixCAM2 command
/// link (decision 0023) and shows the result in the debug overlay. The
/// student flow (bin question, "Ambil") is not on screen yet (M4).
const _r1Enabled = liveScanEnabled && bool.fromEnvironment('R1');
const _pickUpQuizFlow = liveScanEnabled && bool.fromEnvironment('G1_PICKUP_QUIZ_FLOW');

/// A floating SnackBar's margins that put it in the top [band] of [screen] instead of the bottom.
EdgeInsets snackBarFromTop(Size screen, {double band = 96}) =>
    EdgeInsets.fromLTRB(16, 8, 16, (screen.height - band).clamp(8.0, double.infinity));

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> with WidgetsBindingObserver {
  final MaixCamSource _source = MaixCamSource();
  CapturedFrame? _latestFrame;
  /// The newest frame with an unannotated image, for LOCK (0181).
  CapturedFrame? _lastCleanFrame;

  /// LOCK (0181): the AI's answer shown on the video until UNLOCK or the next LOCK.
  LockedItem? _locked;

  /// The camera tracker's box for [_locked] (0182), as fractions; null until the first one.
  Rect? _trackBox;
  DateTime? _trackSeenAt;

  /// AprilTags (0182, 0183): on while R1 grips or a bin run plays; never for PICK UP or HOME.
  final _tagSwitch = ArmTagSwitch();
  bool _locking = false;
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
  late final JoystickController _joystick;

  /// The commanded arm pose and its planner (0234): every manual arm key goes through it.
  final _arm = ArmPose();
  DateTime? _armRefusedAt;

  /// When the last bin run ended (done or failed): its bubble shows for 5 s (0243).
  DateTime? _binRunEndedAt;

  /// The arm's ESP32 as the MaixCAM2 hears it (STATUS `esp32_age_s`, 0240): the ARM card's chip, and
  /// arm keys warn while it is false. Null: offline or older firmware. Polled every 2 s while connected.
  bool? _esp32Linked;
  Timer? _esp32Poll;
  final _fader = FaderThrottle(); // gripper, height, reach drags (0236)

  /// Set only with R1 (see [_r1Enabled]).
  R1Orchestrator? _r1;
  StreamSubscription<Map<String, dynamic>>? _robotReplies;
  Timer? _statusDebounceTimer;
  Timer? _r1Ticker;

  /// After the bin check (Got it): the arm carries the held item to the right bin (0240 "bin run").
  /// Not in R1 builds, which sort with their own orchestrator.
  BinRun? _binRun;
  Timer? _binRunTicker;
  late final StateController<BinRunCue> _binCue;
  String? _r1Status;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _drawerKey = GlobalKey<ElioDrawerHostState>();

  /// The R2 "Scan quiz" toggle: session-only (decision 0173).
  bool _scanQuizOn = true;

  /// "This drive" counts records saved from here on.
  final DateTime _openedAt = DateTime.now();

  /// The joystick's current direction, for the drive card's status chip.
  DriveDir? _driveDir;

  // R3 (phone): the Guide's targets, the loading skeleton and the Guide itself (0174).
  final _driveKey = GlobalKey(), _stopKey = GlobalKey(), _actionKey = GlobalKey(), _quizKey = GlobalKey();
  bool _skeleton = true;
  bool _guideOpen = false;
  Timer? _skeletonTimer;

  /// The last detector frame's boxes: preview-only frames (every other one)
  /// carry none, and the HUD tag must not blink (R2).
  List<Detection> _hudDetections = const [];

  @override
  void initState() {
    super.initState();
    _enterLandscapeFullscreen();
    _robotNotifier = ref.read(robotControlProvider.notifier);
    _quizNotifier = ref.read(wasteQuizProvider.notifier);
    ref.read(appPreferencesProvider); // loads Sound effects before the first click
    _dropPending = ref.read(r1DropPendingProvider.notifier);
    _binCue = ref.read(binRunCueProvider.notifier);

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
        firstTokenMs: () => AiQuizService.instance.lastReplyMs.value,
        ttsCount: () => QuizTtsService.instance.startedCount,
        nextWaitMs: () => ref.read(wasteQuizProvider.notifier).lastNextWaitMs,
      )..onQuizPhase(ref.read(wasteQuizProvider).phase); // a quiz may already be open (minimized)
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
      onStop: (reason) {
        _fader.cancel();
        _arm.markUnknown(); // the arm holds wherever the STOP caught it
        _r1?.emergencyStop(reason);
        _binRun?.cancel('stopped');
        _gate.status(); // the MaixCAM2 answers with the pose it froze at (0235)
      },
      onArmCommand: (motion) => _liveScan?.onArmCommand(motion),
      onHomeTimeout: () {
        if (mounted) {
          ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
        }
      },
      armBusy: () => (_r1?.ignoresLiveScanLocks ?? false) || (_binRun?.busy ?? false),
      handPaused: () => _r1?.handInView ?? false,
    )..addListener(() {
        if (_gate.stopped && mounted) {
          ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
        }
        if (mounted) setState(() {});
      });
    _joystick = JoystickController(
      // The speed fader is the top speed: a full push drives at its PWM.
      sendDrive: (l, r) {
        final s = ref.read(robotControlProvider).pwmSpeed;
        _gate.motor((l * s).round(), (r * s).round());
      },
      // ponytail: a refused step is not fed back to the stick's integrator; the next accepted step
      // is planned from the arm's real goal, so nothing jumps, but the knob's angle may run ahead.
      sendArmBase: (servo) => _armMove(_arm.base(servo.toDouble())),
      driveLocked: () => _gate.stopped || !_gate.linkUp || _gate.robot.driveLocked,
      armLocked: () =>
          _gate.stopped || !_gate.linkUp || (_gate.armBusy?.call() ?? false) || (_gate.handPaused?.call() ?? false),
      baseServo: () => ref.read(robotControlProvider).baseAngle,
      config: ref.read(robotSettingsProvider).joystick,
    )..start();
    _arm
      ..gripClosedOffset = ref.read(robotSettingsProvider).gripClosedOffset
      ..profile = ref.read(robotSettingsProvider).profile;
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);

    _robotReplies = ws.robotReplies.listen((msg) {
      robot.handleMessage(msg);
      final servo = ArmPose.servoFrom(msg['servo']);
      final reply = RobotReply.fromJson(msg);
      if (reply?.kind == ReplyKind.error && reply!.seq == _arm.movingSeq) {
        _arm.movingSeq = null; // the board refused the move: its next STATUS says where the arm is
        _gate.status();
      }
      if (ArmPose.poseUnknownFrom(msg)) _arm.markUnknown(); // ESP32 reset: arm keys ask for HOME first (0241)
      if (servo != null && msg['event'] != 'error') {
        if (_arm.onServo(servo, seq: reply?.seq, done: reply?.kind == ReplyKind.motionDone)) _syncArmState();
      }
      if (reply != null) {
        _binRun?.onReply(reply);
        if (_gate.pendingHomeSeq != null && reply.seq == _gate.pendingHomeSeq) {
          if (reply.kind == ReplyKind.motionDone) {
            final homeSuccess = _gate.onHomeReply(reply);
            if (homeSuccess) {
              ref.read(robotControlProvider.notifier).resetToHome();
              _arm.markHome();
              _syncArmState();
            }
          } else if (reply.kind == ReplyKind.error) {
            _gate.onHomeReply(reply);
            ref.read(robotControlProvider.notifier).updateStatus(atHome: false);
            // The planned way home was refused because the robot lost the pose (ESP32 reset): its own HOME.
            if (reply.reason == 'pose_unknown') _gate.home();
          } else if (reply.kind == ReplyKind.ack) {
            _gate.onHomeReply(reply);
            // Ack alone means accepted; do not mark successful or reset slider cache.
          }
        }
        if (reply.seq == robot.lastStatusSeq) {
          final silent = ArmPose.esp32SilentFrom(msg);
          if (silent != null && _esp32Linked != !silent && mounted) setState(() => _esp32Linked = !silent);
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
        // Wrong or unseen bin tag twice (0233): no DROP, the arm goes HOME by the usual gated path.
        if (reason == 'bin_check_failed') _gate.home();
        _gate.status(); // the arm's pose after the sort (0235)
      });
      _r1Ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final r1 = _r1!..tick();
        final text = r1.robotConnected ? 'robot terhubung' : r1.message ?? 'memeriksa robot...';
        if (mounted && text != _r1Status) setState(() => _r1Status = text);
        _syncArmTags(DateTime.now());
        final dropPending = r1.state == R1State.sorting || r1.state == R1State.waitBoth;
        if (dropPending) _arm.markUnknown(); // R1's PICK / bin sequence moves the arm (0233)
        if (ref.read(r1DropPendingProvider) != dropPending) {
          ref.read(r1DropPendingProvider.notifier).state = dropPending;
        }
      });
    }

    if (!_r1Enabled) {
      _binRun = BinRun(
        moveToBin: (bin) => _gate.linkUp && !_gate.stopped ? _gate.robot.moveToBin(bin) : null,
        drop: () => _gate.linkUp && !_gate.stopped ? _gate.robot.drop() : null,
        // The run's own HOME (the gate's would wait: the arm still belongs to the run).
        home: () => _gate.linkUp && !_gate.stopped ? _gate.robot.home() : null,
        onChanged: _onBinRun,
      );
      _binRunTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        _binRun!.tick();
        if (_binRun!.wantsTags) _syncArmTags(DateTime.now());
        final cue = switch (_binRun!.state) {
          BinRunState.done => BinRunCue.done,
          BinRunState.failed => BinRunCue.failed,
          _ when !_gate.linkUp || _gate.stopped => BinRunCue.none,
          _ => BinRunCue.ready,
        };
        if (_binCue.state != cue) _binCue.state = cue;
        // The countdown and the 5 s result bubble change without a state change.
        final ended = _binRunEndedAt;
        if (mounted &&
            (_binRun!.state == BinRunState.countdown ||
                (ended != null && DateTime.now().difference(ended) < const Duration(seconds: 6)))) {
          setState(() {});
        }
      });
    }

    // The ARM card's ESP32 chip (0240): STATUS every 2 s carries `esp32_age_s`.
    _esp32Poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_gate.linkUp) _gate.status();
    });

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

      setState(() {
        _latestFrame = frame;
        if (frame.hasPairedCleanImage) _lastCleanFrame = frame;
        if (frame.detections != null) _hudDetections = frame.detections!;
        if (_locked != null && frame.detections != null) {
          final tracked = trackedBox(frame.detections!, frame.width.toDouble(), frame.height.toDouble());
          if (tracked != null) {
            _trackBox = tracked;
            _trackSeenAt = now;
          }
        }
      });

      // Every frame, not only the R1 tick: a build without R1 has no tick (0183).
      _syncArmTags(now);

      // Auto-generated waste quiz: only fed by the real MaixCAM2 stream, the
      // debug phone-camera path triggers it manually instead.
      if (frame.detections != null && ref.read(debugQuizSourceProvider) == WasteQuizSource.maixCam2) {
        final liveScan = _liveScan;
        if (liveScan != null) {
          liveScan.onDetections(
            untracked(frame.detections!),
            frameSize: Size(frame.width.toDouble(), frame.height.toDouble()),
            armMoving: WebSocketService().armMoving, // same message as the frame (0026)
            capturedFrame: frame,
          );
        } else if (!_gate.stopped && _scanQuizOn) {
          ref.read(wasteQuizProvider.notifier).onDetections(untracked(frame.detections!));
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
        _binRun?.cancel('link_lost');
        _gate.linkLost(); // STOPPED (link_lost) until "Lanjutkan" (0026)
        _esp32Linked = null; // unknown until the next STATUS
        _arm.movingSeq = null; // that move's reply will not come
        _streamStartedForCurrentConnection = false;
        ref.read(robotControlProvider.notifier).updateStatus(
              clearEeMm: true,
              clearAtHome: true,
            );
      }
    }, fireImmediately: true);

    // Connect to the robot when the control screen opens. The phone skeleton
    // shows until this settles (or 1.5 s); STOP is live all that time.
    _skeletonTimer = Timer(const Duration(milliseconds: 1500), _endSkeleton);
    unawaited(_connectAndStartStream().whenComplete(_endSkeleton));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoGuide());
    debugPrint('Robot controls enabled: true (awaiting WebSocket connection)');
  }

  void _endSkeleton() {
    _skeletonTimer?.cancel();
    if (mounted && _skeleton) setState(() => _skeleton = false);
  }

  /// First time on a phone: open the Guide once and remember it on this device.
  Future<void> _maybeAutoGuide() async {
    // Not isPhoneLandscape: the screen is still turning to landscape on this first frame.
    if (!mounted || MediaQuery.sizeOf(context).shortestSide >= 600) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(controlGuideShownKey) ?? false) return;
      await prefs.setBool(controlGuideShownKey, true);
    } catch (e) {
      debugPrint('[Control] guide flag: $e');
      return;
    }
    if (mounted) setState(() => _guideOpen = true);
  }

  /// The Scan quiz toggle off (0173): frames still stream, none starts a lock or a quiz. STOP no longer
  /// pauses it (owner, 26 Nov: Go/Stop is the robot only; the gate still blocks every motion).
  void _applyScanPause() => _liveScan?.setScanPaused(!_scanQuizOn);

  /// Debug overlay: the AI's item next to the detector class (decision 0025).
  static String? _scanLine(ScannedWaste? scan) =>
      scan == null ? null : 'AI "${scan.displayName}"   detektor ${scan.detectorLabel ?? '-'}';

  /// Once per (re)connection, from whichever path sees it first.
  void _onNewConnection() {
    _gate.linkRestored(userOffline: _userOffline); // first: STOP + motor 0,0 before anything else (0026)
    _userOffline = false;
    _liveScan?.onLinkRestored(); // 0020: a drop can't time absence; harmless on the first connect
    _r1?.linkUp(); // 0023: probe the command link (old firmware: "robot tidak terhubung")
    _gate.robot.status();
    _tagSwitch.linkUp(); // the camera starts with tags off: say again what we want
  }

  void _syncArmTags(DateTime now) => _tagSwitch.sync(now,
      connected: WebSocketService().isConnected,
      r1Grips: (_r1?.wantsArmTags ?? false) || (_binRun?.wantsTags ?? false),
      send: WebSocketService().sendRobotCommand);

  /// Debug builds: what the tag search sees while it is on (0183), over the video.
  String? _tagLine() {
    final grips = (_r1?.wantsArmTags ?? false) || (_binRun?.wantsTags ?? false);
    if (!kDebugMode || !_tagSwitch.wanted(DateTime.now(), r1Grips: grips)) return null;
    final tags = WebSocketService().armTags ?? const [];
    return tags.isEmpty ? 'Tags: searching...' : 'Tags: ${tags.map((t) => 'id ${t.id} · ${t.distMm.round()} mm').join('   ')}';
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

  /// Offline pressed: the camera link only; Online later needs no GO (owner, 26 Nov).
  bool _userOffline = false;
  void _goOffline() {
    _userOffline = true;
    unawaited(ref.read(configLinkProvider.notifier).disconnect());
  }

  /// "Lanjutkan": the deliberate second action after a stop.
  void _resumeAfterStop() {
    _gate.resume();
    _r1?.resumeAfterStop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _joystick.letGo();
    _gate.onAppLifecycle(state);
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
    _fader.cancel();
    _frameSubscription?.cancel();
    _statusSubscription?.close();
    _r1Ticker?.cancel();
    _binRunTicker?.cancel();
    _esp32Poll?.cancel();
    _robotReplies?.cancel();
    _statusDebounceTimer?.cancel();
    _skeletonTimer?.cancel();
    _joystick.stop(); // no more ticks; the gate below sends motor 0,0
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _gate.dispose(); // motor 0,0, heartbeat off

    // Leaving Control stops the stream (motors are already 0 via the gate)
    // but keeps a live link, so Home can offer "Resume robot control" (ELIOS 3,
    // decision 0197). ELIOS setup's Disconnect ends the session.
    debugPrint('[Control] Stopping MaixCAM2 stream');
    _robotNotifier.stopStream();
    if (WebSocketService().isConnected) {
      debugPrint('[Control] Leaving robot control, robot stays connected');
    } else {
      // Not connected: stop any reconnect loop, as before.
      debugPrint('[Control] Leaving robot control, disconnecting WebSocket');
      unawaited(_robotNotifier.disconnect());
    }
    unawaited(AiQuizService.instance.cancel());
    setDesktopLandscape(false);
    _liveScan?.dispose();

    // Riverpod refuses provider writes while the tree unmounts, and the throw
    // used to skip the rest of dispose: clear the drop flag and any open quiz
    // (so it doesn't block future scans) once the tree is unlocked.
    final quiz = _quizNotifier;
    final dropPending = _dropPending;
    final binCue = _binCue; // no "close the gripper" cue on the ticket outside Control (0240)
    Future.microtask(() {
      dropPending.state = false;
      binCue.state = BinRunCue.none;
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
      // 0243 (owner, 26 Nov): the arm sorts when the student taps Done on the result page (onDone), no
      // longer as soon as the last question is answered.
      // Owner, 26 Nov: the lock ends with its quiz (finished or closed), so the next scan starts unlocked.
      if (_locked != null && prev?.phase != next.phase && const {WasteQuizPhase.finished, WasteQuizPhase.idle}.contains(next.phase)) {
        _lockOrUnlock();
      }
      // A new quiz: last run's "sorted" / "could not" is not this item's.
      if (prev?.phase == WasteQuizPhase.idle && next.phase != WasteQuizPhase.idle && !(_binRun?.pending ?? true)) {
        _binRun!.reset();
      }
    });

    // Resend resolution to the device whenever the user changes it mid-session.
    // Advanced settings: new joystick constants from the next tick (0232).
    ref.listen<RobotSettings>(robotSettingsProvider, (_, s) {
      _joystick.config = s.joystick;
      _arm.profile = s.profile;
      if (_arm.setGripClosedOffset(s.gripClosedOffset)) _armMove(_arm.close()); // a closed gripper stays closed
    });
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
    final detections = _hudDetections;
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
        ControlLink.waiting => (l10n.ctlWaiting, p.secondaryText),
        ControlLink.disconnected => (l10n.ctlOffline, p.errorText),
        _ when _gate.stopped => (l10n.ctlStopped, p.errorText),
        _ => (switch (_driveDir) {
            DriveDir.forward => l10n.ctlForward,
            DriveDir.back => l10n.ctlBack,
            DriveDir.left => l10n.ctlLeft,
            DriveDir.right => l10n.ctlRight,
            null => l10n.ctlReady,
          }, p.primaryText),
      };
      final (armWord, armColor) = switch (link) {
        ControlLink.waiting => (l10n.ctlWaiting, p.secondaryText),
        ControlLink.disconnected => (l10n.ctlOffline, p.errorText),
        _ when _gate.stopped => (l10n.ctlStopped, p.errorText),
        _ => (_gate.isHoming ? l10n.ctlHoming : l10n.ctlReady, p.primaryText),
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

      // Owner, 26 Nov: notifications drop in from the top, clear of the drive and arm controls.
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.up,
            insetPadding: snackBarFromTop(MediaQuery.sizeOf(context)),
          ),
        ),
        child: ElioDrawerHost(
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
              builder: (context, _) => isPhoneLandscape(context)
                  ? _phoneLayout(
                      link: link,
                      robotState: robotState,
                      quizState: quizState,
                      missionDone: missionDone,
                      user: user,
                      stop: stop,
                      reconnect: reconnect,
                    )
                  : ControlLayout(
                stoppedBanner: _gate.stopped ? StoppedBanner(reason: _gate.stopReason, onResume: _resumeAfterStop) : null,
                stoppedPill: _gate.stopped ? StoppedPill(reason: _gate.stopReason) : null,
                exitButton: ControlPill(icon: Icons.arrow_back_rounded, label: l10n.ctlExit, onTap: () => Navigator.of(context).pop()),
                debugScanButton: ControlPill(
                  icon: Icons.bug_report_outlined,
                  label: l10n.ctlDebugScan,
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
                    onStick: (v) => _joystick.setDriveStick(v.dx, v.dy),
                    onDirection: (dir) => setState(() => _driveDir = dir),
                    onRelease: () => setState(() => _driveDir = null),
                  ),
                ),
                driveHint: hint('tyre_buddy', isOperational ? l10n.ctlPushToDrive : l10n.ctlUnlocksOnConnect),
                speed: controlEnabled(
                  isOperational,
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(child: ControlCaps(l10n.ctlSpeedPwm)),
                      Text('${speed.toInt()}%', style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    SizedBox(
                      height: 40,
                      child: ControlFader(value: speed, max: 100, semanticLabel: l10n.ctlSpeed, onChanged: isOperational ? notifier.setPwmSpeed : null),
                    ),
                    const SizedBox(height: 4),
                    GearChips(speed: speed, onSelect: isOperational ? notifier.setPwmSpeed : null),
                  ]),
                ),
                camera: Stack(fit: StackFit.expand, children: [
                  _LandscapeCameraPanel(
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
                  if (_sortBubble() case final bubble?)
                    Positioned(left: 8, right: 8, bottom: 10, child: Center(child: bubble)),
                ]),
                actions: controlEnabled(
                  isOperational,
                  LayoutBuilder(builder: (context, c) {
                    final key = (c.maxHeight - 26).clamp(36.0, 64.0);
                    return Row(children: [
                      HomeButton(
                          onConfirmed: _armHome,
                          enabled: isOperational,
                          size: key),
                      const SizedBox(width: 10),
                      TransportKey(
                        icon: Icons.back_hand_outlined,
                        label: l10n.ctlPickUp,
                        primary: true,
                        size: key,
                        onTap: isOperational
                            ? _pickUp
                            : null,
                      ),
                      const SizedBox(width: 10),
                      TransportKey(
                        icon: Icons.front_hand_outlined,
                        label: l10n.ctlRelease,
                        size: key,
                        onTap: isOperational ? _releaseGripper : null,
                      ),
                      VerticalDivider(width: 24, color: p.borderSubtle),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Row(children: [
                            Expanded(child: ControlCaps(l10n.ctlGripperCaps)),
                            Text('${robotState.gripperVal.round()}%',
                                style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                          SizedBox(
                            height: 36,
                            child: ControlFader(
                              value: robotState.gripperVal,
                              max: 100,
                              semanticLabel: l10n.ctlGripper,
                              onChanged: isOperational
                                  ? (value) => _fader(() => _armMove(_arm.gripper(value)))
                                  : null,
                            ),
                          ),
                          if (c.maxHeight >= 90)
                            Row(children: [
                              Text(context.l10n.controlGripOpen, style: TextStyle(color: p.textTertiary, fontSize: 11)),
                              const Spacer(),
                              Text(context.l10n.controlGripClosed, style: TextStyle(color: p.textTertiary, fontSize: 11)),
                            ]),
                        ]),
                      ),
                    ]);
                  }),
                ),
                armStatus: ControlStatusChip(label: armWord, color: armColor),
                armHeight: controlEnabled(
                  isOperational,
                  armFader(l10n.ctlHeight, l10n.ctlUpDown, (robotState.heightValue / 180).clamp(0.0, 1.0), (value) {
                    _fader(() { if (_armMove(_arm.height(value))) _scheduleStatusRequest(); });
                  }),
                ),
                armReach: controlEnabled(
                  isOperational,
                  armFader(l10n.ctlReach, l10n.ctlFwdBack, (robotState.reachValue / 180).clamp(0.0, 1.0), (value) {
                    _fader(() { if (_armMove(_arm.reach(value))) _scheduleStatusRequest(); });
                  }),
                ),
                power: PowerGlowButton(
                  link: link,
                  size: tall ? 64 : 52,
                  onTap: link == ControlLink.disconnected
                      ? reconnect
                      : _goOffline,
                ),
                stopButton: EmergencyStopButton(onStop: stop),
                armTip: hint(
                  'gear_buddy',
                  isOperational
                      ? l10n.ctlArmHint
                      : l10n.ctlArmLocked,
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
                // Full-screen scan pages (decision 0217).
                quiz: Positioned.fill(
                  child: ScanQuizPages(
                    robot: true,
                    onStop: stop,
                    onRescan: () {
                      _liveScan?.logEvent('rescan_tapped', {});
                      _liveScan?.rescan();
                    },
                    onDone: () => _startBinRun(ref.read(wasteQuizProvider)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }));
  }
  /// R3 phone layout (decision 0174). Same handlers as R2, but nothing is dimmed
  /// or absorbed: offline the controls press and the gate sends nothing.
  Widget _phoneLayout({
    required ControlLink link,
    required RobotState robotState,
    required WasteQuizUiState quizState,
    required int missionDone,
    required User? user,
    required VoidCallback stop,
    required VoidCallback reconnect,
  }) {
    final notifier = _robotNotifier;
    final quizOpen = quizState.phase != WasteQuizPhase.idle;
    return PhoneControlLayout(
      link: link,
      stopped: _gate.stopped,
      stopReason: _gate.stopReason,
      skeleton: _skeleton,
      speed: robotState.pwmSpeed,
      onSpeed: notifier.setPwmSpeed,
      onStick: (v) => _joystick.setDriveStick(v.dx, v.dy),
      onDirection: (dir) => setState(() => _driveDir = dir),
      onRelease: () => setState(() => _driveDir = null),
      frame: _latestFrame?.bytes,
      fps: _streamFps,
      scanQuizOn: _scanQuizOn,
      onScanQuiz: (on) => setState(() {
        _scanQuizOn = on;
        _applyScanPause();
      }),
      voiceOn: quizState.voiceOn,
      onVoice: (_) => ref.read(wasteQuizProvider.notifier).toggleVoice(),
      onHome: _armHome,
      onPickUp: _pickUp,
      onReleaseGripper: _releaseGripper,
      gripper: robotState.gripperVal,
      onGripper: (value) => _fader(() => _armMove(_arm.gripper(value))),
      height: robotState.heightValue,
      onHeight: (value) {
        _fader(() { if (_armMove(_arm.height(value))) _scheduleStatusRequest(); });
      },
      reach: robotState.reachValue,
      onReach: (value) {
        _fader(() { if (_armMove(_arm.reach(value))) _scheduleStatusRequest(); });
      },
      yaw: _arm.yawFraction,
      onYaw: (value) => _fader(() => _armMove(_arm.yaw(value))),
      pitch: _arm.pitchFraction,
      onPitch: (value) => _fader(() => _armMove(_arm.pitch(value))),
      onBaseStick: _joystick.setArmStick,
      onPower: link == ControlLink.disconnected
          ? reconnect
          : _goOffline,
      onConnect: reconnect,
      onStop: stop,
      onGo:
          _resumeAfterStop, // clears STOPPED only; never sends a motion command
      missionDone: missionDone,
      trophies: ScanRecordStore.instance.totalTrophies,
      quizBadge: quizOpen ? 1 : null,
      quizWaiting: quizState.phase == WasteQuizPhase.identifying || quizState.phase == WasteQuizPhase.loadingQuestion,
      onQuiz: () {
        final q = ref.read(wasteQuizProvider.notifier);
        quizState.minimized ? q.restore() : q.minimize();
      },
      onHistory: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScanHistoryScreen(store: ScanRecordStore.instance),
        ),
      ),
      onAvatar: () => _drawerKey.currentState?.open(),
      onBack: () => Navigator.of(context).pop(),
      onGuide: () => setState(() => _guideOpen = true),
      onAdvanced: _openAdvanced,
      esp32Linked: link == ControlLink.connected ? _esp32Linked : null,
      photoUrl: user?.photoURL,
      // The box stays locked from SCAN until the quiz is over and the arm has dropped the item (0240).
      onLock: _scanHeld(quizOpen)
          ? null
          : _locked != null || (link == ControlLink.connected && _latestFrame != null && !_locking) ? _lockOrUnlock : null,
      locked: _locked != null,
      locking: _locking,
      onScan: !_scanHeld(quizOpen) && !_locking && (_locked != null || (link == ControlLink.connected && _latestFrame != null)) ? _scan : null,
      lockBox: _locked == null
          ? null
          : lockOverlayBox(aiBox: _locked!.box, trackBox: _trackBox, trackSeenAt: _trackSeenAt, now: DateTime.now()),
      lockLabel: _locked == null ? null : ScannedWaste.fromLabel(_locked!.result.item!).displayName,
      tagText: _tagLine(),
      sortBubble: _sortBubble(),
      frameAspect: _latestFrame == null || _latestFrame!.height == 0 ? 4 / 3 : _latestFrame!.width / _latestFrame!.height,
      driveKey: _driveKey,
      stopKey: _stopKey,
      actionKey: _actionKey,
      quizKey: _quizKey,
      overlays: [
        Positioned.fill(
          child: ScanQuizPages(
            robot: true,
            onStop: stop,
            onRescan: () {
              _liveScan?.logEvent('rescan_tapped', {});
              _liveScan?.rescan();
            },
            onDone: () => _startBinRun(ref.read(wasteQuizProvider)),
          ),
        ),
        if (_guideOpen)
          Positioned.fill(
            child: PhoneGuide(
              driveKey: _driveKey,
              stopKey: _stopKey,
              actionKey: _actionKey,
              quizKey: _quizKey,
              onStop: stop,
              onClose: () => setState(() => _guideOpen = false),
            ),
          ),
      ],
    );
  }

  /// LOCK (0181): a clean frame from the last second, else the live preview (it may carry the
  /// firmware's own drawings until the firmware stops making them). UNLOCK clears the box.
  Future<LockedItem?> _lockOrUnlock() async {
    if (_locked != null) {
      WebSocketService().sendRobotCommand(trackStopCommand);
      setState(() {
        _locked = null;
        _trackBox = null;
        _trackSeenAt = null;
      });
      return null;
    }
    final clean = _lastCleanFrame;
    final fresh = clean != null && DateTime.now().difference(clean.timestamp) < const Duration(seconds: 1);
    final frame = fresh ? clean : _latestFrame;
    if (frame == null) return null;
    setState(() => _locking = true);
    final answer = await ref.read(wasteQuizProvider.notifier).lockItem(frame);
    if (!mounted) return null;
    final lock = answer.lock;
    // The camera follows the box from here (0182). It is the box of this frame, ~2 s old by now.
    if (lock?.box != null) {
      WebSocketService().sendRobotCommand(trackStartCommand(lock!.box!, frame.width, frame.height, lock.result.item!));
    }
    setState(() {
      _locking = false;
      _locked = lock;
      _trackBox = null;
      _trackSeenAt = null;
    });
    if (answer.lock == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(answer.failure == 'busy'
            ? l10n.ctlAiBusy
            : answer.failure ?? l10n.ctlNoItem)));
    }
    return answer.lock;
  }

  /// KUNCI and SCAN wait while the quiz is open and while the arm is taking the item to its bin.
  bool _scanHeld(bool quizOpen) => quizOpen || (_binRun?.pending ?? false);

  /// Got it on the bin check: the bin run starts, or waits for the gripper (0240).
  void _startBinRun(WasteQuizUiState s) {
    final bin = Bin.fromCategoryId(s.scan?.category?.id);
    if (_binRun == null || bin == null || !_gate.linkUp || _gate.stopped) return;
    _binRun!
      ..reset()
      ..start(bin, holding: true);
  }

  void _onBinRun(BinRunState state) {
    if (!mounted) return;
    final pending = _binRun!.pending;
    if (state == BinRunState.done || state == BinRunState.failed) _binRunEndedAt = DateTime.now();
    if (_dropPending.state != pending) _dropPending.state = pending;
    if (state == BinRunState.moving) _arm.markUnknown(); // the saved sequence moves the arm; motion_done says where to
    if (state == BinRunState.moving) _syncArmTags(DateTime.now());
    if (state == BinRunState.done) {
      ref.read(robotControlProvider.notifier).resetToHome(); // dropped and back home
      _arm.markHome();
      _syncArmState();
    }
    if (state == BinRunState.failed) {
      final why = _binRun!.failure ?? 'error';
      if (why != 'stopped' && why != 'link_lost') {
        // 0240: HOLD ends whatever the robot may still be playing (a lost reply, a timeout), then
        // HOME by the gated path, like R1's bin_check_failed. STOP and a lost link stay where they are.
        _gate.robot.hold();
        _gate.home();
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.binRunFailed(why))));
      }
    }
    setState(() {});
  }

  /// SCAN (0181): the quiz popup for the locked item; with nothing locked, LOCK first.
  Future<void> _scan() async {
    final lock = _locked ?? await _lockOrUnlock();
    if (lock != null && mounted) ref.read(wasteQuizProvider.notifier).scanLocked(lock);
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
              Text(context.l10n.controlBase, style: TextStyle(color: Colors.white)),
              IconButton(onPressed: () => _nudgeBase(-2), icon: const Icon(Icons.chevron_left, color: Colors.white), tooltip: l10n.ctlBaseLeft),
              IconButton(onPressed: () => _nudgeBase(2), icon: const Icon(Icons.chevron_right, color: Colors.white), tooltip: l10n.ctlBaseRight),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('debug_home_button'),
                onPressed: _armHome,
                icon: const Icon(Icons.home_outlined, size: 18),
                label: Text(context.l10n.controlHome),
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
              Text(context.l10n.controlR1Status(_r1Status ?? context.l10n.controlCheckingRobot),
                  style: const TextStyle(color: Colors.white, fontSize: 12, backgroundColor: Colors.black54)),
            ],
            const SizedBox(height: 6),
            const Align(alignment: Alignment.centerLeft, child: QuestionSourceSwitch()), // 0018: from the next scan
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                // The AI on a phone-camera photo, without the MaixCAM2.
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
                label: Text(context.l10n.controlPhoneScan),
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


  /// Advanced settings (0232): the page asks for the teacher PIN; CONFIG goes out through the gate.
  Future<void> _openAdvanced() async {
    final esp = ref.read(espConfigProvider).valueOrNull;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdvancedSettingsScreen(
        linkUp: _gate.linkUp,
        address: '${esp?.esp32IpAddress ?? '—'}:${EspConfig.maixCamPort}',
        onSend: _gate.config,
      ),
    ));
  }
  /// Debug sheet's base chevrons: one 2 deg step each tap.
  void _nudgeBase(double delta) => _armMove(_arm.base(_arm.baseServo + delta));

  // ── Manual arm (0234): planned like robotic_hand_sim, sent as ARM_POSE ─────

  /// Sends a planned move, or says why the arm can't go there. True when sent.
  bool _armMove(ArmMove m) {
    final refusal = m.refusal;
    if (refusal != null) {
      _showArmRefusal(refusal);
      return false;
    }
    if (!_gate.armPose(m.path!, m.duration)) return false;
    _arm.commit(m, _gate.robot.lastArmSeq);
    if (_esp32Linked == false) {
      _showArmNote(l10n.armEsp32Silent); // sent, but nothing on the cable is listening
      _scheduleStatusRequest(); // clears as soon as the ESP32 is heard
    }
    _syncArmState();
    return true;
  }

  /// The sliders, the gripper and the base show the commanded pose.
  void _syncArmState() => _robotNotifier
    ..setBaseAngle(_arm.baseServo)
    ..setHeightValue(_arm.heightFraction * 180)
    ..setReachValue(_arm.reachFraction * 180)
    ..setGripperVal(_arm.gripperWidth);

  /// PICK closes the gripper to its closed angle (75 + the Advanced settings offset).
  void _pickUp() {
    if (!_armMove(_arm.close())) return;
    if (_pickUpQuizFlow) _liveScan?.onPickUpPressed();
  }

  /// RELEASE opens the gripper; when a sort is waiting for the student (0243) this is its drop.
  void _releaseGripper() {
    if (_armMove(_arm.open())) _binRun?.released(_gate.robot.lastArmSeq);
  }

  /// The arm's sort over the camera (0243): countdown, in progress, check the hand, then 5 s of success
  /// (a failure keeps its top notification).
  Widget? _sortBubble() {
    final run = _binRun;
    final bin = run?.bin;
    if (run == null || bin == null) return null;
    final name = switch (bin) {
      Bin.organik => 'Organik',
      Bin.anorganik => 'Anorganik',
      Bin.b3 => 'B3',
    };
    final ended = _binRunEndedAt;
    final recent = ended != null && DateTime.now().difference(ended) < const Duration(seconds: 5);
    final (String, SortBubbleKind)? b = switch (run.state) {
      BinRunState.countdown => (
          l10n.sortCountdown(name, (run.countdownLeft!.inMilliseconds / 1000).ceil().clamp(0, 99)),
          SortBubbleKind.busy
        ),
      BinRunState.needsRelease => (l10n.sortCheckHand(name), SortBubbleKind.help),
      BinRunState.done when recent => (l10n.sortSuccess, SortBubbleKind.success),
      _ when run.busy => (l10n.sortInProgress(name), SortBubbleKind.busy),
      _ => null,
    };
    return b == null ? null : SortBubble(text: b.$1, kind: b.$2);
  }

  /// HOME by the planned safe path; the firmware's own HOME when the arm's pose is unknown.
  void _armHome() {
    if (!_arm.known) {
      _gate.home();
      return;
    }
    final m = _arm.home();
    if (m.refusal != null) return _showArmRefusal(m.refusal!);
    if (_gate.home(path: m.path, motion: m.duration)) _arm.commit(m, _gate.robot.lastArmSeq);
  }

  void _showArmRefusal(ArmRefusal r) => _showArmNote(switch (r) {
        ArmRefusal.tank => l10n.armRefusedTank,
        ArmRefusal.tankPath => l10n.armRefusedTankPath,
        ArmRefusal.outOfReach => l10n.armRefusedReach,
        ArmRefusal.jointLimits || ArmRefusal.baseLimit => l10n.armRefusedLimits,
        ArmRefusal.unknownPose => l10n.armRefusedUnknown,
      });

  /// One arm message at a time, at most every 2 s (a fader drag would repeat it).
  void _showArmNote(String text) {
    final now = DateTime.now();
    if (!mounted || (_armRefusedAt != null && now.difference(_armRefusedAt!) < const Duration(seconds: 2))) return;
    _armRefusedAt = now;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
