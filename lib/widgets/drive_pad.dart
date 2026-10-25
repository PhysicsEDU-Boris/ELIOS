import 'package:flutter/material.dart';

const _textPrimary = Color(0xFF1C2833);
const _label = Color(0xFF6B6B6B);
const _textSecondary = Color(0xFF9A9A9A);
const _redAccent = Color(0xFFE74C3C);

/// The wheel D-pad: one `motor` command on touch-down, [onStop] (motor 0,0) on
/// release or cancel; nothing repeats while held (decision 0026).
class DrivePad extends StatelessWidget {
  const DrivePad({
    super.key,
    required this.speed,
    required this.enabled,
    required this.onForward,
    required this.onBack,
    required this.onLeft,
    required this.onRight,
    required this.onStop,
    this.compact = false,
  });

  final double speed;
  final bool enabled;
  final VoidCallback onForward;
  final VoidCallback onBack;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onStop;

  /// 56 px keys, no top inset: the narrow Control layout (U1).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback onPressed, {bool isStop = false}) =>
        _DpadButton(icon: icon, onPressed: onPressed, onReleased: onStop, isStop: isStop, size: compact ? 56 : 68);
    final rowGap = SizedBox(height: compact ? 4 : 12);
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: AbsorbPointer(
        absorbing: !enabled,
        // Figma 43:42: 68 px keys, 4 px apart in the middle row, 12 px above and below.
        child: Padding(
          padding: EdgeInsets.only(top: compact ? 0 : 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DRIVE CONTROLS',
                style: TextStyle(color: _label, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.68),
              ),
              SizedBox(height: compact ? 8 : 14),
              button(Icons.arrow_upward, onForward),
              rowGap,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  button(Icons.arrow_back, onLeft),
                  const SizedBox(width: 4),
                  button(Icons.hexagon_outlined, onStop, isStop: true),
                  const SizedBox(width: 4),
                  button(Icons.arrow_forward, onRight),
                ],
              ),
              rowGap,
              button(Icons.arrow_downward, onBack),
              SizedBox(height: compact ? 8 : 14),
              Text(
                '${speed.toInt()}% PWM',
                style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.48),
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
    this.size = 68,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final bool isStop;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isStop ? const Color(0xFFFDF1EF) : Colors.white,
          borderRadius: BorderRadius.circular(isStop ? size / 2 : 12),
          border: Border.all(
            color: isStop ? const Color(0xFFF3CFCA) : const Color(0xFFDCDCDC),
          ),
          boxShadow: isStop ? null : const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Icon(
          icon,
          color: isStop
              ? _redAccent
              : _textPrimary,
          size: size * (isStop ? 0.53 : 0.47),
        ),
      ),
    );
  }
}

