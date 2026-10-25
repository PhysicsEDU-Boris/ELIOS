import 'package:flutter/material.dart';

const _textPrimary = Color(0xFF1C2833);
const _textSecondary = Color(0xFF7F8C8D);
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
                  color: _textSecondary,
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
              ? _redAccent
              : _textPrimary,
          size: isStop ? 30 : 28,
        ),
      ),
    );
  }
}

