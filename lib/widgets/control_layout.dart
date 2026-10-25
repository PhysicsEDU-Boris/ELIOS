import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

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

/// Builds a control at full size or compact (the two-column layout).
typedef ControlBuilder = Widget Function(bool compact);

/// The Control screen (decisions 0026, U1).
///
/// - Wide (from [wideMinWidth]): one row, as in Figma 43:30.
/// - Two columns (from [twoColumnMinWidth]): camera + PICK UP / RELEASE on the
///   left, sized from the space the compact controls leave; the controls on
///   the right. At 770x553 everything fits on one screen.
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
  static const cameraMaxWidth = 524.0;
  static const cameraMinWidth = 240.0;

  /// Compact controls (90 + 176 + 74 + 90 + gaps) + the smallest camera + gaps.
  static const _controlsWidth = 90 + 8 + 176 + 8 + 74 + 8 + 90.0;
  static const twoColumnMinWidth = 2 * _pad + _controlsWidth + 16 + cameraMinWidth;

  /// Full-size controls (74 + 212 + 74 + 130 + gaps) fit beside the smallest camera.
  static const _fullControlsWidth = 74 + 8 + 212 + 8 + 74 + 8 + 130.0;

  static const _pad = 16.0;
  static const _topBar = 48.0; // a pill row
  static const _actionsHeight = 72.0;
  static const _launcherHeight = 8 + 102.0;

  /// The least height each layout needs without scrolling.
  static const _wideMinHeight = 2 * _pad + _topBar + 40 + 388 + _launcherHeight;
  static const _twoColumnMinHeight = 2 * _pad + _topBar + 16 + ArmSlider.compactHeight + _launcherHeight;
  static const _twoColumnFullMinHeight = 2 * _pad + _topBar + 16 + 388 + _launcherHeight;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 16, height: 16);
    const gap8 = SizedBox(width: 8, height: 8);
    final topBar = SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          exitButton,
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (debugBuild && debugScanButton != null) debugScanButton!,
            historyButton,
          ]),
        ],
      ),
    );
    final rightLauncher = Align(alignment: Alignment.centerRight, child: launcher);

    return Column(
      children: [
        ?stoppedBanner,
        Expanded(
          child: LayoutBuilder(builder: (context, viewport) {
            final width = viewport.maxWidth;
            final Widget body;
            final bool pinStop;
            if (width >= wideMinWidth || width >= twoColumnMinWidth) {
              final wide = width >= wideMinWidth;
              // Two columns: full-size controls when they fit (1024x768), compact otherwise (770x553).
              final compact = !wide &&
                  (width < 2 * _pad + _fullControlsWidth + 16 + cameraMinWidth ||
                      viewport.maxHeight < _twoColumnFullMinHeight);
              final minHeight = wide ? _wideMinHeight : compact ? _twoColumnMinHeight : _twoColumnFullMinHeight;
              pinStop = viewport.maxHeight < minHeight;
              final speedColumn = Column(mainAxisSize: MainAxisSize.min, children: [
                speed(compact),
                if (!pinStop) ...[compact ? const SizedBox(height: 12) : gap, stopButton],
              ]);
              final Widget main;
              if (wide) {
                main = Column(children: [
                  topBar,
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      armHeight(false), gap, drivePad(false), gap,
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: cameraMaxWidth),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            AspectRatio(aspectRatio: cameraMaxWidth / 300, child: camera),
                            gap,
                            actions,
                          ]),
                        ),
                      ),
                      gap, speedColumn, gap, armReach(false),
                    ],
                  ),
                  const Spacer(),
                  rightLauncher,
                ]);
              } else {
                main = Column(children: [
                  topBar,
                  gap,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The camera takes what the controls leave: 4:3, width- or height-bound.
                        Expanded(
                          child: LayoutBuilder(builder: (context, left) {
                            final byHeight = (left.maxHeight - 12 - _actionsHeight) * 4 / 3;
                            final w = [left.maxWidth, byHeight, cameraMaxWidth].reduce((a, b) => a < b ? a : b);
                            return Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: w < cameraMinWidth ? cameraMinWidth : w,
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  AspectRatio(aspectRatio: 4 / 3, child: camera),
                                  const SizedBox(height: 12),
                                  actions,
                                ]),
                              ),
                            );
                          }),
                        ),
                        gap,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [armHeight(compact), gap8, drivePad(compact), gap8, speedColumn, gap8, armReach(compact)],
                            ),
                            const Spacer(),
                            launcher,
                          ],
                        ),
                      ],
                    ),
                  ),
                ]);
              }
              body = SizedBox(
                height: (pinStop ? minHeight : viewport.maxHeight) - 2 * _pad,
                child: main,
              );
            } else {
              // Phones: the page scrolls, so STOP is always pinned.
              pinStop = true;
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar,
                  gap,
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: cameraMaxWidth),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AspectRatio(aspectRatio: 4 / 3, child: camera),
                        const SizedBox(height: 12),
                        actions,
                      ]),
                    ),
                  ),
                  gap,
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [armHeight(false), drivePad(false), speed(false), armReach(false)],
                  ),
                  gap,
                  rightLauncher,
                ],
              );
            }
            return Stack(
              children: [
                SingleChildScrollView(
                  // Room under the content for the pinned STOP.
                  padding: EdgeInsets.fromLTRB(_pad, _pad, _pad, pinStop ? _pad + EmergencyStopButton.size + 16 : _pad),
                  child: body,
                ),
                if (pinStop) Positioned(right: _pad, bottom: _pad, child: stopButton),
                quiz,
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// A grey pill (Exit, History, Debug Scan).
class ControlPill extends StatelessWidget {
  const ControlPill({super.key, required this.icon, required this.label, required this.onTap, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _pillFill,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const StadiumBorder(side: BorderSide(color: _pillBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, trailing == null ? 12 : 8, trailing == null ? 24 : 10, trailing == null ? 12 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: _ink),
              const SizedBox(width: 8),
              Text(label, maxLines: 1, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// History with the trophy count. ponytail: the count is a placeholder and
/// a tap does nothing until U5 brings the history screen and the points.
class HistoryPill extends StatelessWidget {
  const HistoryPill({super.key, this.trophies = 0});

  final int trophies;

  @override
  Widget build(BuildContext context) {
    return ControlPill(
      icon: Icons.history_rounded,
      label: 'History',
      onTap: () {},
      trailing: DecoratedBox(
        decoration: const ShapeDecoration(color: Color(0x33D89E00), shape: StadiumBorder()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFD89E00)),
              const SizedBox(width: 4),
              Text('$trophies', style: const TextStyle(color: Color(0xFF7A5900), fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _label, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.96);
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            SizedBox(
              width: 90,
              height: 32,
              // May break after "/" (zero-width space): "FORWARD/" over "BACKWARD".
              child: Center(child: Text(label.replaceAll('/', '/\u200B'), maxLines: 2, textAlign: TextAlign.center, style: style)),
            )
          else
            Text(label, maxLines: 1, style: style),
          SizedBox(height: compact ? 6 : 10),
          Text(sublabel, maxLines: 1, style: const TextStyle(color: _subLabel, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8)),
          SizedBox(height: compact ? 6 : 10),
          Container(
            width: 74,
            height: compact ? 220 : 340,
            decoration: BoxDecoration(
              color: _armGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 5, offset: Offset(0, 3))],
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
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 1),
                ),
                child: Slider(value: value, onChanged: enabled ? onChanged : null),
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
  const SpeedSlider({super.key, required this.speed, required this.enabled, required this.onChanged, this.compact = false});

  final double speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  /// 160 px tall instead of 222: the narrow layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: RotatedBox(
        quarterTurns: 3,
        child: Container(
          width: compact ? 160 : 222,
          height: 74,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Speed (PWM)', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _label, fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  Text('${speed.toInt()}%', style: const TextStyle(color: _armGreen, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    activeTrackColor: Color(0xFFC8C8C8),
                    inactiveTrackColor: Color(0xFFECECEC),
                    trackHeight: 6,
                    thumbColor: Colors.white,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 2),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(value: speed.clamp(0, 100), max: 100, onChanged: enabled ? onChanged : null),
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
  const GripperButtons({super.key, required this.enabled, required this.onPickUp, required this.onRelease});

  final bool enabled;
  final VoidCallback onPickUp;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.44);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const padding = EdgeInsets.symmetric(horizontal: 10);
    Widget label(IconData icon, String text) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 26),
            const SizedBox(width: 10),
            Text(text, maxLines: 1),
          ]),
        );
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 72,
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
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 72,
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
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Semantics(
      button: true,
      label: 'Berhenti darurat',
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: _stopRed,
          shape: shape,
          elevation: 4,
          child: InkWell(
            customBorder: shape,
            onTap: onStop,
            // Scaled down, never wrapped, in whatever font the device has.
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'STOP',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
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
  const StoppedBanner({super.key, required this.reason, required this.onResume});

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
    return Material(
      color: const Color(0xFFD32F2F),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.pan_tool_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ROBOT DIHENTIKAN ($why). Pemindaian berhenti; kuis yang terbuka tetap bisa dijawab.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onResume,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      ),
    );
  }
}
