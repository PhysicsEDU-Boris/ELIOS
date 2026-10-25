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

/// The Control screen (decisions 0026, U1). Wide (from [wideMinWidth]): one
/// row, as in Figma 43:30. Narrower: the camera on top, the controls below,
/// wrapping on a phone. Everything scrolls, so nothing is ever cut off, and the
/// leaf button sits in the flow at the bottom right, so it covers nothing. The
/// quiz lays over the whole area below the STOPPED strip; its header has its
/// own STOP, because it hides the one under the speed slider.
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
  final Widget armHeight;
  final Widget drivePad;
  final Widget camera;
  final Widget actions;
  final Widget speed;
  final Widget stopButton;
  final Widget armReach;
  final Widget launcher;
  final Widget quiz;
  final Widget? stoppedBanner;

  static const wideMinWidth = 1100.0;
  static const cameraMaxWidth = 524.0;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 16, height: 16);
    final cameraColumn = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: cameraMaxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [AspectRatio(aspectRatio: cameraMaxWidth / 300, child: camera), gap, actions],
      ),
    );
    final speedColumn = Column(mainAxisSize: MainAxisSize.min, children: [speed, gap, stopButton]);
    return Column(
      children: [
        ?stoppedBanner,
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= wideMinWidth;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
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
                            SizedBox(height: wide ? 40 : 24),
                            if (wide)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  armHeight, gap, drivePad, gap,
                                  Flexible(child: cameraColumn), gap,
                                  speedColumn, gap, armReach,
                                ],
                              )
                            else ...[
                              Center(child: cameraColumn),
                              gap,
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 16,
                                children: [armHeight, drivePad, speedColumn, armReach],
                              ),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Align(alignment: Alignment.centerRight, child: launcher),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              quiz,
            ],
          ),
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
  });

  final String label;
  final String sublabel;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, style: const TextStyle(color: _label, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.96)),
          const SizedBox(height: 10),
          Text(sublabel, maxLines: 1, style: const TextStyle(color: _subLabel, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Container(
            width: 74,
            height: 340,
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
  const SpeedSlider({super.key, required this.speed, required this.enabled, required this.onChanged});

  final double speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.70,
      child: RotatedBox(
        quarterTurns: 3,
        child: Container(
          width: 222,
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

/// PICK UP and RELEASE, under the camera.
class GripperButtons extends StatelessWidget {
  const GripperButtons({super.key, required this.enabled, required this.onPickUp, required this.onRelease});

  final bool enabled;
  final VoidCallback onPickUp;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.44);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: enabled ? onPickUp : null,
                icon: const Icon(Icons.pan_tool_alt_outlined, size: 26),
                label: const Text('PICK UP', maxLines: 1),
                style: FilledButton.styleFrom(
                  backgroundColor: _pickUpGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _pickUpGreen,
                  disabledForegroundColor: Colors.white,
                  shape: shape,
                  textStyle: text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 72,
              child: OutlinedButton.icon(
                onPressed: enabled ? onRelease : null,
                icon: const Icon(Icons.back_hand_outlined, size: 26),
                label: const Text('RELEASE', maxLines: 1),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _label,
                  disabledForegroundColor: _label,
                  side: const BorderSide(color: Color(0xFFD9D9D9)),
                  shape: shape,
                  textStyle: text,
                ),
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
