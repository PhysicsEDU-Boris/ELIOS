import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/segmentation_provider.dart';
import '../providers/robot_provider.dart';

enum ControlMode { robotConnected, localCameraTest }

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key, this.mode = ControlMode.robotConnected});

  final ControlMode mode;

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  Uint8List? _currentFrame;
  ProviderSubscription<AsyncValue<Uint8List>>? _frameSubscription;
  CameraController? _cameraController;
  late final RobotControlNotifier _robotNotifier;
  String? _localCameraError;
  bool _isInitializingLocalCamera = false;
  bool? _lastLoggedRobotControlsEnabled;

  bool get _isLocalCameraMode => widget.mode == ControlMode.localCameraTest;

  static const Color textPrimary = Color(0xFF1C2833);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color primaryColor = Color(0xFF1D9E75);
  static const Color blueAccent = Color(0xFF3498DB);
  static const Color orangeAccent = Color(0xFFE67E22);
  static const Color redAccent = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _robotNotifier = ref.read(robotControlProvider.notifier);
    debugPrint('Selected control mode: ${widget.mode}');

    if (_isLocalCameraMode) {
      unawaited(_initializeLocalCamera());
    } else {
      // Subscribe to robot frames outside of build to avoid re-registering
      // the listener on every rebuild.
      _frameSubscription = ref.listenManual(robotFrameProvider, (_, next) {
        if (next.hasValue && mounted) {
          setState(() => _currentFrame = next.value);
        }
      });
      // Connect to the robot when the control screen opens.
      _robotNotifier.connect();
      debugPrint(
        'Robot controls enabled: true (awaiting WebSocket connection)',
      );
    }
  }

  Future<void> _initializeLocalCamera() async {
    if (!mounted) return;

    setState(() {
      _isInitializingLocalCamera = true;
      _localCameraError = null;
    });

    try {
      final cameras = await availableCameras();
      debugPrint(
        'Detected local cameras: ${cameras.map((camera) => '${camera.name} (${camera.lensDirection.name})').join(', ')}',
      );

      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        setState(() {
          _isInitializingLocalCamera = false;
          _localCameraError = 'No local camera was detected.';
        });
        debugPrint('Selected camera source: none available');
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      debugPrint(
        'Selected camera source: ${selectedCamera.name} (${selectedCamera.lensDirection.name})',
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _cameraController;
      setState(() {
        _cameraController = controller;
        _isInitializingLocalCamera = false;
        _localCameraError = null;
      });
      await previousController?.dispose();
      debugPrint('Robot controls enabled: false');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializingLocalCamera = false;
        _localCameraError = 'Unable to open local camera test mode.';
      });
      debugPrint('Local camera initialization failed: $error');
    }
  }

  @override
  void dispose() {
    _frameSubscription?.close();
    _cameraController?.dispose();
    if (!_isLocalCameraMode) {
      // Disconnect when leaving the control screen.
      _robotNotifier.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robotState = ref.watch(robotControlProvider);
    final status = _isLocalCameraMode
        ? 'Camera test mode'
        : ref.watch(robotStatusProvider).value ?? 'Disconnected';
    final segmentationState = _isLocalCameraMode
        ? const SegmentationState()
        : ref.watch(segmentationProvider);

    final isConnected = !_isLocalCameraMode && status == 'Connected';
    final isReconnecting = !_isLocalCameraMode && status == 'Reconnecting...';
    final isOperational = !_isLocalCameraMode && isConnected;

    if (_lastLoggedRobotControlsEnabled != isOperational) {
      _lastLoggedRobotControlsEnabled = isOperational;
      debugPrint('Robot controls ${isOperational ? 'enabled' : 'disabled'}');
    }

    final notifier = _robotNotifier;
    final speed = robotState.pwmSpeed;
    final statusLabel = _isLocalCameraMode
        ? 'LOCAL'
        : isConnected
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
                                    isLocal: _isLocalCameraMode,
                                    cameraController: _cameraController,
                                    currentFrame: _currentFrame,
                                    isInitializingLocalCamera:
                                        _isInitializingLocalCamera,
                                    localCameraError: _localCameraError,
                                    isProcessing:
                                        segmentationState.isProcessing,
                                    statusLabel: statusLabel,
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
        ],
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
    required this.isLocal,
    required this.cameraController,
    required this.currentFrame,
    required this.isInitializingLocalCamera,
    required this.localCameraError,
    required this.isProcessing,
    required this.statusLabel,
  });

  final bool isLocal;
  final CameraController? cameraController;
  final Uint8List? currentFrame;
  final bool isInitializingLocalCamera;
  final String? localCameraError;
  final bool isProcessing;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final hasCameraPreview =
        cameraController != null && cameraController!.value.isInitialized;
    final statusColor = isLocal
        ? _ControlScreenState.blueAccent
        : statusLabel == 'LIVE'
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
            if (isLocal && hasCameraPreview)
              CameraPreview(cameraController!)
            else if (isLocal)
              _CameraFallback(
                isLoading: isInitializingLocalCamera,
                message: localCameraError ?? 'Opening local camera...',
              )
            else if (currentFrame != null)
              Image.memory(
                currentFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              const _CameraFallback(
                isLoading: true,
                message: 'Waiting for ESP32-CAM stream...',
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
            if (isProcessing && !isLocal)
              const Center(child: CircularProgressIndicator(color: Colors.red)),
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
