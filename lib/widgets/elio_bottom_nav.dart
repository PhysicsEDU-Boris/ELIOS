// Bottom navigation, ELIOS 3 (Figma "ELIOS BottomNav" 270:5746): Home, Learn,
// Scan (raised orb), History, Profile picture. Tab indices are the app's
// provider indices (Home 0, Learn 1, Scan 2, History 4, Profile 5); 3 stays
// the "open robot control" action used by Home and notifications.
import 'package:flutter/material.dart';

import '../theme/elio_motion.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;
import 'package:elio/l10n/l10n.dart';
import '../services/elio_feedback.dart';

const _barHeight = 64.0;
const _ringGap = 4.0; // surface-coloured ring round the Control button
const _controlSize = 56.0;
const _raise = 16.0 + _ringGap; // space above the top rule, taken by the circle

class ElioBottomNav extends StatelessWidget {
  const ElioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    this.photoUrl,
    this.initials,
  });

  /// Active tab: Home 0, Learn 1, Scan 2, History 4, Profile 5.
  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  /// Profile avatar (Figma "Nav / Profile avatar" 582:3957): the photo, else
  /// the initials, else the guest icon.
  final String? photoUrl;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    // S1 + H-select on a new tab only (silent on re-tap), Figma 13 · 1.
    void select(int i) {
      if (i != currentIndex) elioFeedback(ElioSfx.tick, ElioHaptics.select);
      onSelectTab(i);
    }

    Widget tab(int i, String label, IconData off, IconData on) => _Cell(
      label: label,
      semantics: label,
      selected: currentIndex == i,
      onTap: () => select(i),
      icon: Icon(currentIndex == i ? on : off, size: 24),
    );
    return Semantics(
      container: true,
      label: l10n.navMain,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: p.borderMedium),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(minHeight: _barHeight),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: tab(
                      0,
                      l10n.navHome,
                      Icons.home_outlined,
                      Icons.home,
                    ),
                  ),
                  Expanded(
                    child: tab(
                      1,
                      l10n.navLearn,
                      Icons.menu_book_outlined,
                      Icons.menu_book,
                    ),
                  ),
                  Expanded(
                    child: _Cell(
                      label: l10n.navScan,
                      semantics: l10n.navScanHint,
                      selected: currentIndex == 2,
                      // The orb above the bar is the active mark.
                      showStroke: false,
                      onTap: () => select(2),
                      icon: const SizedBox.shrink(),
                    ),
                  ),
                  Expanded(
                    child: tab(
                      4,
                      l10n.navHistory,
                      Icons.history_rounded,
                      Icons.history_rounded,
                    ),
                  ),
                  Expanded(
                    child: _Cell(
                      label: l10n.navProfile,
                      semantics: l10n.navProfile,
                      selected: currentIndex == 5,
                      onTap: () => select(5),
                      icon: NavProfileAvatar(
                        photoUrl: photoUrl,
                        initials: initials,
                        active: currentIndex == 5,
                      ),
                    ),
                  ),
                ],
              ),
              // One active stroke that slides to the new tab (spring/soft,
              // Figma 13 · 1); the Scan orb is its own mark.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    alignment: Alignment(_strokeX(currentIndex), -1),
                    duration: ElioMotion.reduced(context)
                        ? Duration.zero
                        : ElioMotion.slow,
                    curve: ElioMotion.soft,
                    child: FractionallySizedBox(
                      widthFactor: 0.2,
                      child: AnimatedOpacity(
                        opacity: currentIndex == 2 ? 0 : 1,
                        duration: ElioMotion.fast,
                        child: Center(
                          heightFactor: 1,
                          child: Container(
                            width: 24,
                            height: 3,
                            decoration: ShapeDecoration(
                              color: p.primaryText,
                              shape: const StadiumBorder(),
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
      ),
    );
  }

  /// Column of a tab index (Home 0, Learn 1, Scan 2, History 4, Profile 5)
  /// as an Alignment x over 5 equal columns.
  static double _strokeX(int index) {
    final col = switch (index) {
      0 => 0,
      1 => 1,
      4 => 3,
      5 => 4,
      _ => 2,
    };
    return -1 + col * 0.5;
  }
}

/// 28 dp avatar in a 32 dp slot; Active adds a 2 dp primary ring.
class NavProfileAvatar extends StatelessWidget {
  const NavProfileAvatar({
    super.key,
    this.photoUrl,
    this.initials,
    this.active = false,
  });

  final String? photoUrl;
  final String? initials;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final url = photoUrl;
    final letters = initials?.trim() ?? '';
    final Widget fallback = letters.isNotEmpty
        ? Center(
            child: Text(
              letters,
              style: ElioTokens.caption.copyWith(
                color: p.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : Icon(Icons.person_outline_rounded, size: 18, color: p.textSecondary);
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: active
          ? ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.primary, width: 2),
              ),
            )
          : null,
      child: Container(
        decoration: ShapeDecoration(
          color: p.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: p.borderMedium),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

/// One 48 dp+ target: 32 dp icon slot above the label, 24x3 stroke on the rule.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.onTap,
    required this.icon,
    this.showStroke = true,
  });

  final String label, semantics;
  final bool selected, showStroke;
  final VoidCallback onTap;
  final Widget icon;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final color = widget.selected ? p.primaryText : p.textSecondary;
    final plain = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semantics,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: _barHeight - 1),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (_focused)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.primaryText, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.25),
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 32,
                      alignment: Alignment.center,
                      // Pressed: Surface Raised pill behind the icon.
                      decoration: ShapeDecoration(
                        color: _pressed && !plain ? p.surfaceRaised : null,
                        shape: const StadiumBorder(),
                      ),
                      // Outline → filled cross-fade with a 0.9 → 1 pop (Figma 13 · 1).
                      child: AnimatedSwitcher(
                        duration: plain ? Duration.zero : ElioMotion.fast,
                        switchInCurve: ElioMotion.standard,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.9, end: 1.0).animate(
                              CurvedAnimation(parent: a, curve: ElioMotion.pop),
                            ),
                            child: child,
                          ),
                        ),
                        child: IconTheme(
                          key: ValueKey(widget.selected),
                          data: IconThemeData(color: color),
                          child: widget.icon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: ElioMotion.fast,
                        style: ElioTokens.caption.copyWith(
                          color: color,
                          height: 16 / 12,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        child: Text(widget.label, maxLines: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised Scan orb. Put it in `Scaffold.floatingActionButton` with
/// [ElioControlFabLocation]: it then overlaps the page, not the bar's layout
/// box. The Scan cell in the bar carries the semantics.
class ElioScanOrb extends StatefulWidget {
  const ElioScanOrb({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<ElioScanOrb> createState() => _ScanOrbState();
}

class _ScanOrbState extends State<ElioScanOrb> {
  bool _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final plain = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: InkResponse(
        onTap: () {
          elioFeedback(ElioSfx.pop, ElioHaptics.medium); // Figma 13 · 2
          widget.onTap();
        },
        onFocusChange: (f) => setState(() => _focused = f),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        highlightShape: BoxShape.circle,
        radius: _controlSize / 2 + _ringGap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: AnimatedScale(
          // Press 0.92 (90 ms), release spring/pop (Figma 13 · 2).
          scale: _pressed && !plain ? 0.92 : 1,
          duration: _pressed ? ElioMotion.instant : ElioMotion.slow,
          curve: _pressed ? ElioMotion.standard : ElioMotion.pop,
          child: Container(
            width: _controlSize + 2 * _ringGap,
            height: _controlSize + 2 * _ringGap,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              boxShadow: _focused
                  ? [
                      BoxShadow(color: p.primaryText, spreadRadius: 2),
                      BoxShadow(
                        color: p.primary.withValues(alpha: 0.25),
                        spreadRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Container(
              width: _controlSize,
              height: _controlSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed ? p.primaryHover : p.primary,
                shape: BoxShape.circle,
                // 1.5 px stroke keeps the circle at 3:1 on white.
                border: Border.all(color: p.primaryText, width: 1.5),
                boxShadow: dark ? ElioGlow.control : ElioLightEffects.card,
              ),
              child: Icon(
                Icons.crop_free_rounded,
                size: 28,
                color: p.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres the circle horizontally, its ring [_raise] above the bar's top rule.
class ElioControlFabLocation extends FloatingActionButtonLocation {
  const ElioControlFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) => Offset(
    (g.scaffoldSize.width - g.floatingActionButtonSize.width) / 2,
    g.contentBottom - _raise,
  );
}
