// ELIOS 3 Scan hub, the centre tab (Figma 629:90675): Scan & quiz with the
// phone, Robot scan (Select vehicle → ELIOS setup → Control), Scan to
// contribute.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/elio_page_title.dart';
import '../../widgets/learn/learn_ui.dart';
import 'contribute_screen.dart';
import 'phone_scan_screen.dart';
import 'select_vehicle_screen.dart';

const scanArt = 'assets/illustrations/scan';

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          return Material(
            color: p.background,
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                children: [
                  ElioPageTitle(
                    title: l10n.navScan,
                    subtitle: l10n.scanHubSubtitle,
                  ),
                  const SizedBox(height: 20),
                  _PhoneCard(
                    onOpen: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PhoneScanScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _RobotCard(
                    onOpen: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SelectVehicleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ContributeCard(
                    onOpen: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ContributeScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Organic leaf corners: 40 on one diagonal, 12 on the other.
BorderRadius leafRadius({bool flip = false}) => flip
    ? const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(40),
        bottomRight: Radius.circular(12),
        bottomLeft: Radius.circular(40),
      )
    : const BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(40),
        bottomLeft: Radius.circular(12),
      );

TextStyle _overline(Color c) => ElioTokens.label.copyWith(
  fontSize: 11,
  letterSpacing: 1.1,
  height: 1.4,
  color: c,
);

TextStyle _headline(Color c) => ElioTokens.body.copyWith(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  height: 1.3,
  letterSpacing: -0.28,
  color: c,
);

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.color,
    required this.radius,
    required this.overline,
    required this.overlineColor,
    required this.title,
    required this.body,
    required this.bodyColor,
    required this.titleColor,
    required this.art,
    required this.button,
    required this.onTap,
    this.border,
  });

  final Color color, overlineColor, bodyColor, titleColor;
  final Color? border;
  final BorderRadius radius;
  final String overline, title, body;
  final Widget art, button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 236,
            child: Stack(
              children: [
                Positioned.fill(child: art),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overline.toUpperCase(),
                        style: _overline(overlineColor),
                      ),
                      const SizedBox(height: 6),
                      // Clear of the art on the right, long titles shrink.
                      FractionallySizedBox(
                        widthFactor: 0.72,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, style: _headline(titleColor)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: 0.58,
                        child: Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ElioTokens.bodySmall.copyWith(
                            color: bodyColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      button,
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.lead,
  });

  final String label;
  final Color bg, fg;
  final IconData? lead;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[
          Icon(lead, size: 18, color: fg),
          const SizedBox(width: 6),
        ],
        Text(label, style: ElioTokens.button.copyWith(color: fg)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, size: 18, color: fg),
      ],
    ),
  );
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return _HubCard(
      color: p.primary,
      radius: leafRadius(),
      overline: l10n.scanPhoneOverline,
      overlineColor: p.onPrimary,
      title: l10n.scanPhoneTitle,
      titleColor: p.onPrimary,
      body: l10n.scanPhoneBody,
      bodyColor: p.onPrimary,
      onTap: onOpen,
      button: _Pill(
        label: l10n.scanOpenCamera,
        lead: Icons.photo_camera_outlined,
        bg: p.isDark ? p.background : p.surface,
        fg: p.primaryText,
      ),
      art: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -42,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: p.primaryHover,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 30,
              top: 46,
              child: Transform.rotate(
                angle: 0.14,
                child: Container(
                  width: 96,
                  height: 150,
                  padding: const EdgeInsets.fromLTRB(7, 11, 7, 0),
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.textPrimary, width: 3),
                  ),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: p.primaryText.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      '$scanArt/viewfinder.svg',
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 36,
              top: 118,
              child: SvgPicture.asset(
                '$scanArt/bin_buddy_scanned.svg',
                width: 40,
                height: 47,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotCard extends StatelessWidget {
  const _RobotCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return _HubCard(
      color: p.tertiaryText.withValues(alpha: p.isDark ? 0.12 : 0.06),
      border: p.tertiaryText.withValues(alpha: 0.35),
      radius: leafRadius(flip: true),
      overline: l10n.scanRobotOverline,
      overlineColor: p.tertiaryText,
      title: l10n.scanRobotTitle,
      titleColor: p.textPrimary,
      body: l10n.scanRobotBody,
      bodyColor: p.textSecondary,
      onTap: onOpen,
      button: _Pill(
        label: l10n.scanSelectVehicle,
        bg: p.textPrimary,
        fg: p.background,
      ),
      art: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              right: 4,
              top: 39,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 55,
              child: SvgPicture.asset(
                '$scanArt/elios_robot.svg',
                width: 160,
                height: 136,
              ),
            ),
            Positioned(
              right: 14,
              top: 9,
              child: SvgPicture.asset(
                '$scanArt/drone.svg',
                width: 58,
                height: 27,
              ),
            ),
            Positioned(
              right: 4,
              top: 3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: p.isDark ? p.surfaceRaised : const Color(0xFF0F1729),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributeCard extends StatelessWidget {
  const _ContributeCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return _HubCard(
      color: p.secondaryText.withValues(alpha: p.isDark ? 0.10 : 0.04),
      border: p.secondaryText.withValues(alpha: 0.35),
      radius: leafRadius(),
      overline: l10n.scanContributeOverline,
      overlineColor: p.secondaryText,
      title: l10n.contributeTitle,
      titleColor: p.textPrimary,
      body: l10n.scanContributeBody,
      bodyColor: p.textSecondary,
      onTap: onOpen,
      button: _Pill(
        label: l10n.contributeStart,
        lead: Icons.fiber_manual_record_rounded,
        bg: p.error,
        fg: p.onError,
      ),
      art: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              right: 28,
              top: 95,
              child: SvgPicture.asset(
                '$scanArt/bin_with_label.svg',
                width: 80,
                height: 95,
              ),
            ),
            Positioned(
              right: 8,
              top: 74,
              child: Transform.rotate(
                angle: 0.07,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p.textPrimary, width: 1.5),
                  ),
                  child: Text(
                    l10n.h3CatRecyclable.toUpperCase(),
                    style: ElioTokens.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 22,
              top: 23,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 4,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.circle, size: 22, color: p.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
