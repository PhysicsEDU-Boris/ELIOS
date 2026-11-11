import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/elio_dark_theme.dart';
import '../../theme/elio_tokens.dart';
import '../splash/elio_leaf.dart';
import 'package:elio/l10n/l10n.dart';

// Design file 0091: radius/m for inputs and banners, Full (pill) for buttons and links.
const _radiusM = 12.0;
const _pill = StadiumBorder();

/// The palette of the [ElioTheme.wrap] ancestor (dark or light).
ElioPalette authPalette(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? ElioTokens.dark
    : ElioTokens.light;

/// Focus glow for buttons and links: the design-system focus ring in dark; null
/// lets [ElioGlowBox] use the light-mode ring.
List<BoxShadow>? _ring(ElioPalette p) => p.isDark ? ElioGlow.focusRing : null;

/// Label above a 48 dp field with a leading icon (Figma component 193:370).
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.onTapOutside,
    this.autofillHints,
    this.suffix,
    this.hasError = false,
    this.dimmed = false,
  });

  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted, onChanged;
  final TapRegionCallback? onTapOutside;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  /// Error border and glow (the field the banner is about).
  final bool hasError;

  /// Loading state: raised fill, 40 % opacity, not editable.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radiusM),
      borderSide: BorderSide(color: c, width: w),
    );
    final errorBorder = hasError ? border(p.errorText, 2) : null;
    final field = TextFormField(
      controller: controller,
      validator: validator,
      focusNode: focusNode,
      obscureText: obscure,
      readOnly: dimmed,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: !obscure && keyboardType != TextInputType.emailAddress,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      onTapOutside: onTapOutside,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: dimmed ? p.surfaceRaised : null,
        constraints: const BoxConstraints(minHeight: 48),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 7),
          child: Icon(icon, size: 20, color: p.textSecondary),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 20,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 48,
          height: 48,
        ),
        enabledBorder: errorBorder,
        focusedBorder: errorBorder,
      ),
    );
    return Opacity(
      opacity: dimmed ? ElioTokens.disabledInputOpacity : 1,
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ElioTokens.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radiusM),
                boxShadow: hasError
                    ? [
                        BoxShadow(
                          color: p.error.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: ElioGlowBox(
                radius: _radiusM,
                onFocusGlow: hasError ? const [] : null,
                child: field,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 48 dp show/hide control for a password [AuthField].
class AuthVisibilityToggle extends StatelessWidget {
  const AuthVisibilityToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: obscured ? l10n.qrShowPassword : l10n.qrHidePassword,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Icon(
      obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 20,
      color: authPalette(context).textSecondary,
    ),
  );
}

enum AuthBannerKind { error, success }

/// Error or "reset link sent" banner (Figma chip/error, chip/success).
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.kind, required this.message});

  final AuthBannerKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final isError = kind == AuthBannerKind.error;
    final tint = isError ? p.error : (p.isDark ? p.primary : p.primaryText);
    final fill = isError ? (p.isDark ? 0.12 : 0.08) : (p.isDark ? 0.12 : 0.06);
    final edge = p.isDark ? 0.25 : 0.35;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ElioTokens.space16,
          vertical: 12,
        ),
        decoration: ShapeDecoration(
          color: tint.withValues(alpha: fill),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(_radiusM),
            side: BorderSide(color: tint.withValues(alpha: edge)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: isError ? p.errorText : p.primaryText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: ElioTokens.bodySmall.copyWith(
                  color: isError ? p.errorText : p.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary action. [loading] keeps the fill and shows a spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ElioGlowBox(
      radius: 9999,
      glow: p.isDark ? ElioGlow.buttonHover : const [],
      onFocusGlow: _ring(p),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style:
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: _pill,
            ).copyWith(
              backgroundColor: loading
                  ? WidgetStatePropertyAll(p.primary)
                  : null,
              foregroundColor: loading
                  ? WidgetStatePropertyAll(p.onPrimary)
                  : null,
            ),
        child: loading
            ? Semantics(
                label: l10n.authPleaseWait,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: p.onPrimary,
                  ),
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Full-width secondary action (Google, Guest): surface fill, medium border.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.google = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool google;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ElioGlowBox(
      radius: 9999,
      onFocusGlow: _ring(p),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: _pill,
        ),
        child: google
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: onPressed == null ? ElioTokens.disabledOpacity : 1,
                    child: SvgPicture.asset(
                      'assets/icon/google_icon.svg',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(label)),
                ],
              )
            : Text(label),
      ),
    );
  }
}

/// Green text link, 48 dp tall (Figma component Link).
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.dimWhenDisabled = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// False where the design keeps the link at full strength while loading.
  final bool dimWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ElioGlowBox(
      radius: 9999,
      glow: const [],
      onFocusGlow: _ring(p),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: _pill,
          foregroundColor: p.primaryText,
          disabledForegroundColor: dimWhenDisabled
              ? p.primaryText.withValues(alpha: ElioTokens.disabledOpacity)
              : p.primaryText,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: ElioTokens.space8),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(label),
      ),
    );
  }
}

/// "Atau" divider.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(child: Divider(color: p.borderMedium)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElioMark(size: 14, color: p.primaryText),
                const SizedBox(width: 6),
                Text(
                  label ?? l10n.authOr,
                  style: ElioTokens.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: p.borderMedium)),
        ],
      ),
    );
  }
}

/// ELIOS wordmark: Display 36 on the desktop panel, Subhead 20 on phones.
TextStyle authBrandStyle(ElioPalette p, {required bool large}) =>
    (large
            ? ElioTokens.display
            : ElioTokens.subhead.copyWith(
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ))
        .copyWith(color: p.textPrimary);

/// Desktop left panel: surface fill, two decor rings, the mark and wordmark.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 520,
        child: ClipRect(
          child: CustomPaint(
            painter: _RingsPainter(
              p.borderMedium.withValues(alpha: 0.6),
              p.surface,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElioMark(size: 150, color: p.primaryText),
                  const SizedBox(height: ElioTokens.space24),
                  Text('ELIOS', style: authBrandStyle(p, large: true)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.stroke, this.fill);
  final Color stroke, fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke;
    canvas
      ..drawCircle(c, 309.5, ring)
      ..drawCircle(c, 429.5, ring);
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.stroke != stroke || old.fill != fill;
}

/// Hides the keyboard the way the old screen did.
void authDismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

/// ELIOS 3 login header (Figma L4 644:24854): green field with a curved
/// bottom, the leaf logo in a white circle, the wordmark, bin buddies and the
/// robot. Decorative only.
class AuthOrganicHeader extends StatelessWidget {
  const AuthOrganicHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final top = MediaQuery.paddingOf(context).top;
    Widget dot(double size, Color c) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    Widget bin(String name) => SvgPicture.asset(
      'assets/illustrations/home/$name.svg',
      height: 50,
      excludeFromSemantics: true,
    );
    return ExcludeSemantics(
      child: ClipPath(
        clipper: _WaveClipper(),
        child: ColoredBox(
          color: p.primary,
          child: SizedBox(
            height: 230 + top,
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -50,
                  child: dot(200, p.primaryHover),
                ),
                Positioned(
                  left: 20,
                  top: top + 110,
                  child: dot(32, p.primaryHover),
                ),
                for (final (l, t, s) in [
                  (60.0, 50.0, 10.0),
                  (300.0, 80.0, 12.0),
                  (280.0, 140.0, 8.0),
                ])
                  Positioned(
                    left: l,
                    top: top + t,
                    child: Icon(
                      Icons.auto_awesome,
                      size: s,
                      color: p.onPrimary,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: top + 20,
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.isDark ? p.background : p.surface,
                          shape: BoxShape.circle,
                        ),
                        child: ElioMark(size: 56, color: p.primaryText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ELIOS',
                        style: ElioTokens.display.copyWith(
                          color: p.onPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 22,
                  child: Row(
                    children: [
                      bin('bin_organik'),
                      const SizedBox(width: 4),
                      bin('bin_anorganik'),
                      const SizedBox(width: 4),
                      bin('bin_b3'),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 14,
                  child: SvgPicture.asset(
                    'assets/illustrations/scan/elios_robot.svg',
                    height: 64,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 24)
    ..quadraticBezierTo(
      s.width * .25,
      s.height - 40,
      s.width * .5,
      s.height - 20,
    )
    ..quadraticBezierTo(s.width * .78, s.height, s.width, s.height - 30)
    ..lineTo(s.width, 0)
    ..close();

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
