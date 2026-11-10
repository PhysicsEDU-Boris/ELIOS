// ELIOS 3 Select vehicle (Figma 629:90849): ELIOS is ready; the drone is
// shown in colour but locked ("Coming soon"). Use ELIOS opens ELIOS setup.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../services/elio_feedback.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/elio_page_title.dart';
import '../../widgets/learn/learn_ui.dart';
import '../config_screen.dart';
import 'scan_hub_screen.dart' show scanArt;

class SelectVehicleScreen extends StatelessWidget {
  const SelectVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          void useElios() {
            elioFeedback(ElioSfx.blip, ElioHaptics.medium);
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EliosSetupScreen()),
            );
          }

          return Scaffold(
            backgroundColor: p.background,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  ElioPageTitle(
                    title: l10n.scanSelectVehicle,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 16),
                  ExcludeSemantics(
                    child: Center(
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            '$scanArt/elios_robot.svg',
                            width: 200,
                            height: 170,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ELIOS',
                    textAlign: TextAlign.center,
                    style: ElioTokens.body.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    l10n.vehicleEliosDesc,
                    textAlign: TextAlign.center,
                    style: ElioTokens.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VehicleTile(
                        name: l10n.vehicleDrone,
                        art: '$scanArt/drone.svg',
                        locked: true,
                        onTap: null,
                      ),
                      const SizedBox(width: 16),
                      _VehicleTile(
                        name: 'ELIOS',
                        art: '$scanArt/elios_robot.svg',
                        locked: false,
                        onTap: useElios,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: useElios,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        shape: const StadiumBorder(),
                        textStyle: ElioTokens.button,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.vehicleUse('ELIOS')),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: p.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.vehicleMaixNote,
                          style: ElioTokens.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ],
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

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.name,
    required this.art,
    required this.locked,
    required this.onTap,
  });

  final String name, art;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: locked ? p.surface : p.primary,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.check_rounded,
            size: 14,
            color: locked ? p.textPrimary : p.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            locked ? l10n.vehicleComingSoon : l10n.vehicleReady,
            style: ElioTokens.label.copyWith(
              color: locked ? p.textPrimary : p.onPrimary,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: !locked,
      selected: !locked,
      label: '$name, ${locked ? l10n.vehicleComingSoon : l10n.vehicleReady}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: locked
            ? p.surfaceRaised
            : p.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: locked
              ? BorderSide.none
              : BorderSide(color: p.primary, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 150,
            height: 140,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: locked ? 0.85 : 1,
                          child: SvgPicture.asset(art, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: ElioTokens.button.copyWith(
                          fontSize: 16,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      chip,
                    ],
                  ),
                ),
                if (locked)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: p.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: p.background,
                      ),
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

/// ELIOS setup (Figma 629:90894): the old Config tab content as a pushed page.
/// A successful connect opens Control, as before.
class EliosSetupScreen extends StatelessWidget {
  const EliosSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          return Scaffold(
            backgroundColor: p.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: ElioPageTitle(
                      title: l10n.setupTitle,
                      subtitle: l10n.vehicleEliosDesc,
                      onBack: () => Navigator.of(context).maybePop(),
                      // Back to Select vehicle (Figma "Change").
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: p.primaryText,
                          backgroundColor: p.primary.withValues(alpha: 0.12),
                          shape: const StadiumBorder(),
                          minimumSize: const Size(48, 40),
                        ),
                        child: Text(l10n.vehicleChange),
                      ),
                    ),
                  ),
                  const Expanded(child: ConfigScreen()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
