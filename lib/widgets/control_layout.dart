import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../Screens/scan_history_screen.dart';
import '../services/scan_record_store.dart';

// Figma 43:30 (Control Screen · Chat Minimized).
const _ink = Color(0xFF333333);
const _label = Color(0xFF6B6B6B);
const _subLabel = Color(0xFF9A9A9A);
const _pillFill = Color(0xFFEEEEEE);
const _pillBorder = Color(0xFFC9C9C9);
const _cardBorder = Color(0xFFDCDCDC);
const _armGreen = Color(0xFF5DB89C);
const _pickUpGreen = Color(0xFF6CC1A6);
const _stopRed = Color(0xFFD32F2F);

/// Builds a control at full size or compact.
typedef ControlBuilder = Widget Function(bool compact);

/// The Control screen (decisions 0026, U1).
///
/// - Desktop (from [desktopMinWidth]): one row, as in Figma 43:30. Arm height
///   and D-pad on the left, camera and gripper in the center, speed + STOP and
///   arm reach on the right. Down to 770x553 everything fits on one screen
///   without scrolling using compact controls.
/// - Stacked (phones): camera on top, the controls wrap below, the page scrolls.
///
/// Scrolling is the last fallback. Whenever the page can scroll, STOP is
/// pinned bottom right instead of under the speed slider, so it never scrolls
/// away. The quiz lays over everything below the STOPPED strip and has its
/// own STOP in its header.
class ControlLayout extends StatelessWidget {
  const ControlLayout({
    super.key,
    required this.exitButton,
    required this.historyButton,
    this.homeButton,
    this.debugScanButton,
    this.debugBuild = kDebugMode,
    required this.armHeight,
    required this.drivePad,
    required this.camera,
    required this.actions,
    required this.speed,
    required this.stopButton,
    required this.armReach,
    required this.launcher,
    required this.quiz,
    this.stoppedBanner,
  });

  final Widget exitButton;
  final Widget historyButton;
  final Widget? homeButton;

  /// Shown only in debug builds ([debugBuild]).
  final Widget? debugScanButton;
  final bool debugBuild;
  final ControlBuilder armHeight;
  final ControlBuilder drivePad;
  final Widget camera;
  final Widget actions;
  final ControlBuilder speed;
  final Widget stopButton;
  final ControlBuilder armReach;
  final Widget launcher;
  final Widget quiz;
  final Widget? stoppedBanner;

  static const wideMinWidth = 1100.0;
  static const desktopMinWidth = 600.0;
  static const cameraMaxWidth = 524.0;
  static const cameraMinWidth = 240.0;

  static const _pad = 16.0;
  static const _padCompact = 8.0;
  static const _topBar = 48.0; // a pill row

  /// The least height each layout needs without scrolling.
  static const _wideMinHeight = 2 * _pad + _topBar + 40 + 388 + 64.0;
  static const _desktopMinHeight =
      2 * _pad + _topBar + 16 + ArmSlider.compactHeight;
  static const _landscapeShortMinHeight =
      2 * _padCompact + 32.0 + 6.0 + ArmSlider.compactShortHeight;

  @override
  Widget build(BuildContext context) {
    final topBar = SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          exitButton,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ?homeButton,
              if (debugBuild && debugScanButton != null) debugScanButton!,
              historyButton,
            ],
          ),
        ],
      ),
    );

    return Column(
      children: [
        ?stoppedBanner,
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final width = viewport.maxWidth;
              final totalHeight =
                  MediaQuery.maybeSizeOf(context)?.height ??
                  (viewport.maxHeight + (stoppedBanner != null ? 44.0 : 0.0));
              final isShort = totalHeight < 500;
              final compactDesktop =
                  width >= desktopMinWidth && width < wideMinWidth;
              final pad = isShort || compactDesktop ? _padCompact : _pad;
              final Widget body;
              final bool pinStop;
              if (width >= desktopMinWidth) {
                final wide = width >= wideMinWidth;
                final compact = !wide;
                final minHeight = wide
                    ? _wideMinHeight
                    : isShort
                    ? _landscapeShortMinHeight
                    : _desktopMinHeight;
                pinStop = viewport.maxHeight < minHeight;
                final gap = SizedBox(
                  width: isShort ? 6 : (compact ? 2 : 16),
                  height: isShort ? 6 : (compact ? 8 : 16),
                );
                final speedColumn = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    speed(compact),
                    if (!pinStop) ...[gap, stopButton],
                  ],
                );
                final main = Column(
                  children: [
                    topBar,
                    SizedBox(height: wide ? 40 : (isShort ? 6 : 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        armHeight(compact),
                        gap,
                        drivePad(compact),
                        gap,
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: cameraMinWidth,
                              maxWidth: isShort
                                  ? cameraMinWidth
                                  : cameraMaxWidth,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AspectRatio(
                                  aspectRatio: isShort
                                      ? 16 / 9
                                      : (cameraMaxWidth / 300),
                                  child: camera,
                                ),
                                gap,
                                actions,
                              ],
                            ),
                          ),
                        ),
                        gap,
                        speedColumn,
                        gap,
                        armReach(compact),
                      ],
                    ),
                  ],
                );
                body = SizedBox(
                  height: (pinStop ? minHeight : viewport.maxHeight) - 2 * pad,
                  child: main,
                );
              } else {
                // Narrow portrait: stacked fallback with pinned STOP.
                pinStop = true;
                const gap = SizedBox(width: 12, height: 12);
                body = SizedBox(
                  height:
                      viewport.maxHeight -
                      2 * pad -
                      EmergencyStopButton.size -
                      16,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width - 2 * pad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          topBar,
                          gap,
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: cameraMaxWidth,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: camera,
                                  ),
                                  const SizedBox(height: 10),
                                  actions,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Motion controls row: Arm Height, DrivePad, Arm Reach, scaled to never overflow
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                armHeight(true),
                                const SizedBox(width: 8),
                                drivePad(true),
                                const SizedBox(width: 8),
                                armReach(true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(child: speed(true)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      pad,
                      pad,
                      pinStop ? pad + EmergencyStopButton.size + 16 : pad,
                    ),
                    child: body,
                  ),
                  if (pinStop)
                    Positioned(right: pad, bottom: pad, child: stopButton),
                  Positioned(
                    right: pad,
                    bottom: pinStop ? pad + EmergencyStopButton.size + 8 : pad,
                    child: launcher,
                  ),
                  quiz,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A grey pill (Exit, History, Debug Scan).
class ControlPill extends StatelessWidget {
  const ControlPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final fontSize = isShort ? 13.0 : 16.0;
    final iconSize = isShort ? 16.0 : 20.0;
    final padVert = isShort ? 6.0 : (trailing == null ? 12.0 : 8.0);
    final padLeft = isShort ? 14.0 : 20.0;
    final padRight = isShort ? 14.0 : (trailing == null ? 24.0 : 10.0);
    return Material(
      color: _pillFill,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const StadiumBorder(side: BorderSide(color: _pillBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(padLeft, padVert, padRight, padVert),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: _ink),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: _ink,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// HOME button with 1-second hold-to-confirm (decision 0027).
class HomeButton extends StatefulWidget {
  const HomeButton({
    super.key,
    required this.onConfirmed,
    this.enabled = true,
    this.holdDuration = const Duration(seconds: 1),
  });

  final VoidCallback onConfirmed;
  final bool enabled;
  final Duration holdDuration;

  @override
  State<HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<HomeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDown() {
    if (!widget.enabled) return;
    _holdTimer?.cancel();
    _controller.forward(from: 0.0);
    _holdTimer = Timer(widget.holdDuration, () {
      widget.onConfirmed();
    });
  }

  void _onUpOrCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!widget.enabled) return;
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final fontSize = isShort ? 13.0 : 16.0;
    final iconSize = isShort ? 16.0 : 20.0;
    final padVert = isShort ? 6.0 : 12.0;
    final padLeft = isShort ? 14.0 : 20.0;
    final padRight = isShort ? 14.0 : 24.0;

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onDown(),
        onPointerUp: (_) => _onUpOrCancel(),
        onPointerCancel: (_) => _onUpOrCancel(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Material(
              color: _pillFill,
              elevation: 2,
              shadowColor: Colors.black26,
              shape: const StadiumBorder(side: BorderSide(color: _pillBorder)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (_controller.value > 0)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _controller.value,
                        child: Container(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(padLeft, padVert, padRight, padVert),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_outlined, size: iconSize, color: _ink),
                        const SizedBox(width: 6),
                        Text(
                          'HOME',
                          maxLines: 1,
                          style: TextStyle(
                            color: _ink,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// History with the trophy count. Opens the scan history screen.
class HistoryPill extends StatelessWidget {
  const HistoryPill({super.key, this.trophies, this.store, this.onTap});

  final int? trophies;
  final ScanRecordStore? store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveStore = store ?? ScanRecordStore.instance;
    return AnimatedBuilder(
      animation: effectiveStore,
      builder: (context, _) {
        final total = trophies ?? effectiveStore.totalTrophies;
        return ControlPill(
          icon: Icons.history_rounded,
          label: 'History',
          onTap:
              onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        ScanHistoryScreen(store: effectiveStore),
                  ),
                );
              },
          trailing: DecoratedBox(
            decoration: const ShapeDecoration(
              color: Color(0x33D89E00),
              shape: StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 14,
                    color: Color(0xFFD89E00),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: Color(0xFF7A5900),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// UP/DOWN (arm height) or FORWARD/BACKWARD (arm reach): a 74 x 340 green
/// slider under its two labels.
class ArmSlider extends StatelessWidget {
  const ArmSlider({
    super.key,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final String sublabel;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  /// 90 px wide (the label on two lines) and a 220 px slider: the narrow layout.
  final bool compact;

  static const compactHeight = 32 + 6 + 12 + 6 + 220.0;
  static const compactShortHeight = 26 + 3 + 10 + 3 + 180.0;

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final trackHeight = isShort ? 180.0 : (compact ? 220.0 : 340.0);
    final sliderWidth = isShort ? 66.0 : 74.0;
    final gap = isShort ? 3.0 : (compact ? 6.0 : 10.0);
    final style = TextStyle(
      color: _label,
      fontSize: isShort ? 10.5 : 12,
      fontWeight: FontWeight.w700,
      letterSpacing: isShort ? 0.7 : 0.96,
    );
    final subStyle = TextStyle(
      color: _subLabel,
      fontSize: isShort ? 9.0 : 10.0,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact || isShort)
            SizedBox(
              width: isShort ? 80 : 90,
              height: isShort ? 26 : 32,
              // May break after "/" (zero-width space): "FORWARD/" over "BACKWARD".
              child: Center(
                child: Text(
                  label.replaceAll('/', '/\u200B'),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            )
          else
            Text(label, maxLines: 1, style: style),
          SizedBox(height: gap),
          Text(sublabel, maxLines: 1, style: subStyle),
          SizedBox(height: gap),
          Container(
            width: sliderWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              color: _armGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.black.withValues(alpha: 0.18),
                  inactiveTrackColor: Colors.black.withValues(alpha: 0.18),
                  trackHeight: 4,
                  thumbColor: const Color(0xFFD9D9D9),
                  overlayColor: Colors.white.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    elevation: 1,
                  ),
                ),
                child: Slider(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Speed (PWM): Figma's card turned upright, 74 wide, so STOP fits under it.
class SpeedSlider extends StatelessWidget {
  const SpeedSlider({
    super.key,
    required this.speed,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final double speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  /// 160 px tall instead of 222: the narrow layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final cardWidth = isShort ? 140.0 : (compact ? 160.0 : 222.0);
    final cardHeight = isShort ? 66.0 : 74.0;
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: RotatedBox(
        quarterTurns: 3,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          padding: EdgeInsets.fromLTRB(
            isShort ? 10 : 16,
            isShort ? 6 : 10,
            isShort ? 10 : 16,
            isShort ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Speed (PWM)',
                        maxLines: 1,
                        style: TextStyle(
                          color: _label,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${speed.toInt()}%',
                    style: TextStyle(
                      color: _armGreen,
                      fontSize: isShort ? 12 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFC8C8C8),
                    inactiveTrackColor: const Color(0xFFECECEC),
                    trackHeight: isShort ? 4 : 6,
                    thumbColor: Colors.white,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isShort ? 10 : 12,
                      elevation: 2,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: isShort ? 14 : 16,
                    ),
                  ),
                  child: Slider(
                    value: speed.clamp(0, 100),
                    max: 100,
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PICK UP and RELEASE, under the camera. The label scales down in a narrow
/// column instead of being clipped.
class GripperButtons extends StatelessWidget {
  const GripperButtons({
    super.key,
    required this.enabled,
    required this.onPickUp,
    required this.onRelease,
    this.width = 0,
    this.onWidthChanged,
  });

  final bool enabled;
  final VoidCallback onPickUp;
  final VoidCallback onRelease;
  final double width;
  final ValueChanged<double>? onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final btnHeight = isShort ? 48.0 : 72.0;
    final text = TextStyle(
      fontSize: isShort ? 14 : 18,
      fontWeight: FontWeight.w700,
      letterSpacing: isShort ? 1.0 : 1.44,
    );
    final iconSize = isShort ? 20.0 : 26.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final padding = EdgeInsets.symmetric(horizontal: isShort ? 6 : 10);
    Widget label(IconData icon, String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize),
          SizedBox(width: isShort ? 6 : 10),
          Text(text, maxLines: 1),
        ],
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: btnHeight,
                  child: FilledButton(
                    onPressed: enabled ? onPickUp : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _pickUpGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _pickUpGreen,
                      disabledForegroundColor: Colors.white,
                      shape: shape,
                      padding: padding,
                      textStyle: text,
                    ),
                    child: label(Icons.pan_tool_alt_outlined, 'PICK UP'),
                  ),
                ),
              ),
              SizedBox(width: isShort ? 8 : 16),
              Expanded(
                child: SizedBox(
                  height: btnHeight,
                  child: OutlinedButton(
                    onPressed: enabled ? onRelease : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _label,
                      disabledForegroundColor: _label,
                      side: const BorderSide(color: Color(0xFFD9D9D9)),
                      shape: shape,
                      padding: padding,
                      textStyle: text,
                    ),
                    child: label(Icons.back_hand_outlined, 'RELEASE'),
                  ),
                ),
              ),
            ],
          ),
          if (onWidthChanged != null) ...[
            SizedBox(height: isShort ? 2 : 4),
            Row(
              children: [
                const Text(
                  'GRIPPER WIDTH',
                  style: TextStyle(
                    color: _label,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: width.clamp(0, 100),
                    max: 100,
                    onChanged: enabled ? onWidthChanged : null,
                  ),
                ),
                Text(
                  '${width.round()}%',
                  style: const TextStyle(color: _label, fontSize: 9),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The emergency stop, in the square under the speed slider: red, one tap,
/// a fixed size, so "STOP" never wraps.
class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({super.key, required this.onStop});

  final VoidCallback onStop;

  static const size = 74.0;

  @override
  Widget build(BuildContext context) {
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    final btnSize = isShort ? 64.0 : size;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Semantics(
      button: true,
      label: 'Berhenti darurat',
      child: SizedBox.square(
        dimension: btnSize,
        child: Material(
          color: _stopRed,
          shape: shape,
          elevation: 4,
          child: InkWell(
            customBorder: shape,
            onTap: onStop,
            // Scaled down, never wrapped, in whatever font the device has.
            child: Padding(
              padding: EdgeInsets.all(isShort ? 8 : 10),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'STOP',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// STOPPED: why, and "Lanjutkan", the deliberate second action. A full-width
/// strip above everything else, so it hides nothing.
class StoppedBanner extends StatelessWidget {
  const StoppedBanner({
    super.key,
    required this.reason,
    required this.onResume,
  });

  final String? reason;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final why = switch (reason) {
      'link_lost' => 'koneksi terputus',
      'button' => 'tombol STOP',
      'error' => 'robot error',
      _ => reason ?? '-',
    };
    final isShort =
        MediaQuery.maybeSizeOf(context)?.height != null &&
        MediaQuery.sizeOf(context).height < 500;
    return Material(
      color: const Color(0xFFD32F2F),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isShort ? 4 : 6,
        ),
        child: Row(
          children: [
            Icon(
              Icons.pan_tool_rounded,
              color: Colors.white,
              size: isShort ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ROBOT DIHENTIKAN ($why). Pemindaian berhenti; kuis yang terbuka tetap bisa dijawab.',
                maxLines: isShort ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isShort ? 11.5 : 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onResume,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: EdgeInsets.symmetric(
                  horizontal: isShort ? 8 : 16,
                  vertical: isShort ? 4 : 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Lanjutkan',
                style: TextStyle(fontSize: isShort ? 12 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
