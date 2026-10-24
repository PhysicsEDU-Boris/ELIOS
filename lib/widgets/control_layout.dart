import 'package:flutter/material.dart';

/// The Control screen's layout (decision 0026, E1b): STOP, the D-pad and the
/// debug panel get their own rail (right in landscape, bottom in portrait),
/// and the STOPPED banner its own full-width strip on top. The quiz popup and
/// everything else lay out in [content] only, so nothing covers STOP and STOP
/// covers nothing (24 Oct: it hid the quiz's close and minimise buttons).
class ControlLayout extends StatelessWidget {
  const ControlLayout({
    super.key,
    required this.content,
    required this.stopButton,
    required this.drivePad,
    this.debugPanel,
    this.stoppedBanner,
  });

  final Widget content;
  final Widget stopButton;
  final Widget drivePad;
  final Widget? debugPanel;
  final Widget? stoppedBanner;

  static const railWidth = 220.0;
  static const portraitDebugHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?stoppedBanner,
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final landscape = constraints.maxWidth >= constraints.maxHeight;
            final panel = debugPanel == null ? null : SingleChildScrollView(child: debugPanel);
            if (landscape) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: content),
                  SizedBox(
                    width: railWidth,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        stopButton,
                        const SizedBox(height: 8),
                        drivePad,
                        if (panel != null) Expanded(child: panel),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: content),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [stopButton, const SizedBox(width: 16), drivePad],
                ),
                if (panel != null) SizedBox(height: portraitDebugHeight, child: panel),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// The emergency stop: large, red, one tap. A fixed size, so "STOP" never wraps.
class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({super.key, required this.onStop});

  final VoidCallback onStop;

  static const size = 96.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Berhenti darurat',
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: const Color(0xFFD32F2F),
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            // Scaled down, never wrapped, in whatever font the device has.
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'STOP',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
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
