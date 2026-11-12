// ELIOS 3 Select vehicle (Figma 629:90849): ELIOS is ready; the drone is
// shown in colour but locked ("Coming soon"). Use ELIOS opens ELIOS setup.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../services/elio_feedback.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/elio_page_title.dart';
import '../../widgets/learn/learn_ui.dart';
import '../config_screen.dart';
import '../home/home_parts.dart' show homeWeight;
import 'scan_hub_screen.dart' show scanArt;

class SelectVehicleScreen extends StatefulWidget {
  const SelectVehicleScreen({super.key});

  @override
  State<SelectVehicleScreen> createState() => _SelectVehicleScreenState();
}

class _SelectVehicleScreenState extends State<SelectVehicleScreen> {
  /// Bumps on every ELIOS select: ring, art pop, robot hop, pedestal bounce.
  int _pick = 0;

  /// Bumps on every tap on the locked drone: shake, badge wiggle, toast.
  int _locked = 0;
  bool _toast = false;
  Timer? _toastTimer;

  /// Stage robot follows a horizontal drag, then springs back.
  double _tilt = 0;
  bool _dragging = false;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  // Figma 13 · 22.
  void _select() {
    elioFeedback(ElioSfx.tick, ElioHaptics.select);
    setState(() => _pick++);
  }

  void _lockedTap() {
    elioFeedback(ElioSfx.knock, ElioHaptics.warning);
    _toastTimer?.cancel();
    setState(() {
      _locked++;
      _toast = true;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = false);
    });
  }

  Future<void> _useElios() async {
    elioFeedback(ElioSfx.blip, ElioHaptics.medium);
    // The robot hops, then the page opens.
    if (!ElioMotion.reduced(context)) {
      setState(() => _pick++);
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(ElioPageRoute<void>(builder: (_) => const EliosSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          final pick = _pick == 0 ? null : _pick;
          // Stage (629:90856): glow, spotlight, pedestal, the lit vehicle.
          final stage = SizedBox(
            width: 390,
            height: 372,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 35,
                  top: 10,
                  // The spotlight breathes while the page is idle.
                  child: ElioIdleLoop(
                    period: const Duration(milliseconds: 2400),
                    builder: (context, w, child) =>
                        Transform.scale(scale: 1 + 0.03 * w, child: child),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: p.primary.withValues(
                          alpha: p.isDark ? 0.16 : 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 75,
                  top: 50,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: 95,
                  top: 272,
                  child: ElioJump(
                    trigger: pick,
                    height: 4,
                    delay: const Duration(milliseconds: 120),
                    child: Container(
                      width: 200,
                      height: 34,
                      decoration: ShapeDecoration(
                        color: p.primaryActive,
                        shape: const OvalBorder(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 80,
                  top: 82,
                  // ponytail: the stage shows the flat robot (it morphs from
                  // the hub); the real GLB with drag-to-rotate is on ELIOS
                  // setup. Swap in the 3D viewer here if the owner wants it.
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _dragging = true),
                    onHorizontalDragUpdate: (d) => setState(
                      () =>
                          _tilt = (_tilt + d.delta.dx / 900).clamp(-0.06, 0.06),
                    ),
                    onHorizontalDragEnd: (_) => setState(() {
                      _dragging = false;
                      _tilt = 0;
                    }),
                    child: AnimatedRotation(
                      turns: _tilt,
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: ElioMotion.bounce,
                      child: ElioJump(
                        trigger: pick,
                        height: 16,
                        child: Hero(
                          tag: 'elios-robot',
                          child: SvgPicture.asset(
                            '$scanArt/elios_robot.svg',
                            width: 230,
                            height: 195.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 316,
                  child: ElioPopIn(
                    rise: 8,
                    delay: const Duration(milliseconds: 120),
                    child: Column(
                      children: [
                        Text(
                          'ELIOS',
                          style: homeWeight(
                            ElioTokens.headline,
                            700,
                          ).copyWith(color: p.textPrimary),
                        ),
                        Text(
                          l10n.vehicleEliosDesc,
                          textAlign: TextAlign.center,
                          style: ElioTokens.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          return Scaffold(
            backgroundColor: p.background,
            body: SafeArea(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      ElioPageTitle(
                        title: l10n.scanSelectVehicle,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 8),
                      ExcludeSemantics(
                        child: Center(
                          child: FittedBox(fit: BoxFit.scaleDown, child: stage),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElioPopIn(
                              index: 0,
                              stagger: const Duration(milliseconds: 60),
                              delay: const Duration(milliseconds: 160),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _VehicleTile(
                                  name: l10n.vehicleDrone,
                                  art: '$scanArt/drone.svg',
                                  locked: true,
                                  trigger: _locked == 0 ? null : _locked,
                                  onTap: _lockedTap,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElioPopIn(
                              index: 1,
                              stagger: const Duration(milliseconds: 60),
                              delay: const Duration(milliseconds: 160),
                              child: _VehicleTile(
                                name: 'ELIOS',
                                art: '$scanArt/elios_robot.svg',
                                locked: false,
                                trigger: pick,
                                onTap: _select,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElioPopIn(
                        delay: const Duration(milliseconds: 280),
                        child: ElioPress(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _useElios,
                              style: FilledButton.styleFrom(
                                backgroundColor: p.primary,
                                foregroundColor: p.onPrimary,
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.vehicleUse('ELIOS'),
                                    style: homeWeight(
                                      ElioTokens.button,
                                      600,
                                    ).copyWith(color: p.onPrimary, height: 1.4),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
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
                  // Locked drone: "Coming soon" toast slides up.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedSlide(
                          offset: _toast ? Offset.zero : const Offset(0, 1.5),
                          duration: ElioMotion.base,
                          curve: ElioMotion.emphasized,
                          child: AnimatedOpacity(
                            opacity: _toast ? 1 : 0,
                            duration: ElioMotion.fast,
                            child: Semantics(
                              liveRegion: _toast,
                              child: Container(
                                key: const ValueKey('vehicle_locked_toast'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: ShapeDecoration(
                                  color: p.textPrimary,
                                  shape: const StadiumBorder(),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 16,
                                      color: p.background,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${l10n.vehicleDrone} · ${l10n.vehicleComingSoon}',
                                      style: homeWeight(
                                        ElioTokens.button,
                                        600,
                                      ).copyWith(color: p.background),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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

/// Vehicle slot (629:90865 drone, 629:90877 ELIOS): leaf corners, the art
/// pops out of the selected slot, status chip, lock badge.
class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.name,
    required this.art,
    required this.locked,
    required this.trigger,
    required this.onTap,
  });

  final String name, art;
  final bool locked;

  /// A new value replays the slot's reaction (select or locked).
  final Object? trigger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final reduced = ElioMotion.reduced(context);
    final r = locked ? 22.0 : 28.0;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(r),
      topRight: const Radius.circular(8),
      bottomRight: Radius.circular(r),
      bottomLeft: const Radius.circular(8),
    );
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
            size: 12,
            color: locked ? p.textSecondary : p.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            locked ? l10n.vehicleComingSoon : l10n.vehicleReady,
            maxLines: 1,
            softWrap: false,
            style: homeWeight(
              ElioTokens.caption,
              700,
            ).copyWith(color: locked ? p.textSecondary : p.onPrimary),
          ),
        ],
      ),
    );
    final h = locked ? 160.0 : 176.0;
    // Select: the 3 px ring draws around the slot (200 ms).
    final box = TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: locked || trigger == null || reduced ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, v, child) => Container(
        width: 110,
        height: h,
        decoration: BoxDecoration(
          color: locked
              ? p.surfaceRaised
              : p.primaryActive.withValues(alpha: p.isDark ? 0.16 : 0.06),
          borderRadius: radius,
          border: locked
              ? Border.all(color: p.borderSubtle)
              : Border.all(
                  color: p.primary.withValues(alpha: v),
                  width: 3 * v,
                ),
        ),
      ),
    );
    final tile = SizedBox(
      width: 110,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          box,
          Positioned(
            // Drone: Figma insets the art to 91 × 43 inside its 96 × 66 box.
            top: locked ? 28 : -21,
            // Selected: the art pops up out of the slot (y −18, spring).
            child: ElioJump(
              trigger: locked ? null : trigger,
              height: 18,
              child: SvgPicture.asset(
                art,
                width: locked ? 91 : 110,
                height: locked ? 43 : 93.5,
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            top: locked ? 97 : 111,
            child: Text(
              name,
              style: homeWeight(
                ElioTokens.body,
                700,
              ).copyWith(color: p.textPrimary),
            ),
          ),
          Positioned(
            top: locked ? 125 : 139,
            // "Coming soon" is wider than the slot (Figma: it overhangs).
            child: SizedBox(
              width: 110,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: 150,
                fit: OverflowBoxFit.deferToChild,
                child: chip,
              ),
            ),
          ),
          if (locked)
            Positioned(
              right: 3,
              top: -9,
              // Locked tap: the badge wiggles ±12°.
              child: TweenAnimationBuilder<double>(
                key: ValueKey(trigger),
                tween: Tween(begin: trigger == null || reduced ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 420),
                builder: (context, v, child) => Transform.rotate(
                  angle:
                      math.sin(v * math.pi * 4) * (1 - v) * 12 * math.pi / 180,
                  child: child,
                ),
                child: Container(
                  width: 28,
                  height: 28,
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
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: !locked,
      label: '$name, ${locked ? l10n.vehicleComingSoon : l10n.vehicleReady}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Locked: the slot shakes x ±6 × 3.
        child: ElioShake(
          trigger: locked ? trigger : null,
          child: ElioPress(pressed: 0.96, child: tile),
        ),
      ),
    );
  }
}

/// ELIOS setup (Figma 629:90894, redesign 629:91327): the old Config tab content as a pushed page.
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.vehicleChange),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
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
