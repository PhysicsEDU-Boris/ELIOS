// Bottom navigation (Figma page "N3 Bottom nav", component set 270:5746, spec
// 270:8626): Home, Learn, Control (raised round button), Config, Profile.
// Tab indices are the app's provider indices (Home 0, Learn 1, Config 2); only
// the on-screen order differs. Control is an action, never selected; Profile
// opens the sidebar, it is not a tab.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

const _barHeight = 64.0;
const _ringGap = 4.0; // surface-coloured ring round the Control button
const _controlSize = 56.0;
const _raise = 16.0 + _ringGap; // space above the top rule, taken by the circle

class ElioBottomNav extends StatelessWidget {
  const ElioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onControl,
    required this.onProfile,
    required this.user,
    this.profileOpen = false,
  });

  /// Active tab: Home 0, Learn 1, Config 2.
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onControl;
  final VoidCallback onProfile;
  final User? user;
  final bool profileOpen;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    Widget tab(
      int i,
      String label,
      IconData off,
      IconData on, {
      bool d = true,
    }) => _Cell(
      label: label,
      semantics: label,
      selected: currentIndex == i,
      divider: d,
      onTap: () => onSelectTab(i),
      icon: Icon(currentIndex == i ? on : off, size: 24),
    );
    return Semantics(
      container: true,
      label: 'Main',
      child: Material(
        color: p.surface,
        child: Container(
          constraints: const BoxConstraints(minHeight: _barHeight),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.borderMedium)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: tab(
                  0,
                  'Home',
                  Icons.home_outlined,
                  Icons.home,
                  d: false,
                ),
              ),
              Expanded(
                child: tab(
                  1,
                  'Learn',
                  Icons.menu_book_outlined,
                  Icons.menu_book,
                ),
              ),
              Expanded(
                child: _Cell(
                  label: 'Control',
                  semantics: 'Control, opens robot control',
                  selected: false,
                  divider: true,
                  onTap: onControl,
                  icon: const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: tab(2, 'Config', Icons.wifi_outlined, Icons.wifi),
              ),
              Expanded(
                child: _Cell(
                  label: 'Profile',
                  semantics: 'Profile and menu',
                  selected: profileOpen,
                  divider: true,
                  onTap: onProfile,
                  icon: _Avatar(user: user, ring: profileOpen),
                ),
              ),
            ],
          ),
        ),
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
    required this.divider,
    required this.onTap,
    required this.icon,
  });

  final String label, semantics;
  final bool selected, divider;
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
          decoration: BoxDecoration(
            border: widget.divider
                ? Border(left: BorderSide(color: p.borderSubtle))
                : null,
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (widget.selected)
                Container(
                  width: 24,
                  height: 3,
                  decoration: ShapeDecoration(
                    color: p.primaryText,
                    shape: const StadiumBorder(),
                  ),
                ),
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
                      child: IconTheme(
                        data: IconThemeData(color: color),
                        child: widget.icon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: ElioTokens.caption.copyWith(
                          color: color,
                          height: 16 / 12,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
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

/// The raised Control circle. Put it in `Scaffold.floatingActionButton` with
/// [ElioControlFabLocation]: it then overlaps the page, not the bar's layout
/// box, and the page above the bar is not shortened. The Control cell in the bar
/// carries the semantics.
class ElioControlButton extends StatefulWidget {
  const ElioControlButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<ElioControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ElioControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: InkResponse(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        highlightShape: BoxShape.circle,
        radius: _controlSize / 2 + _ringGap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
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
              color: p.primary,
              shape: BoxShape.circle,
              // 1.5 px stroke keeps the circle at 3:1 on white.
              border: Border.all(color: p.primaryText, width: 1.5),
              boxShadow: dark ? ElioGlow.control : ElioLightEffects.card,
            ),
            child: Icon(Icons.smart_toy, size: 28, color: p.onPrimary),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.ring});
  final User? user;
  final bool ring;

  String? get _initials {
    if (user == null || user!.isAnonymous) return null;
    var words = (user!.displayName ?? '').trim().split(RegExp(r'\s+'));
    if (words.first.isEmpty) words = (user!.email ?? '').trim().split(' ');
    final s = words.take(2).where((w) => w.isNotEmpty).map((w) => w[0]).join();
    return s.isEmpty ? null : s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final initials = _initials;
    final photo = user?.photoURL;
    final fallback = initials == null
        ? const Icon(Icons.person_outline_rounded, size: 20)
        : Text(
            initials,
            style: ElioTokens.caption.copyWith(
              color: p.primaryText,
              fontWeight: FontWeight.w600,
            ),
          );
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surface,
        border: Border.all(
          color: ring ? p.primaryText : p.formBorder,
          width: ring ? 2 : 1.5,
        ),
      ),
      // The initials show while the photo loads and when it fails (offline).
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Center(child: fallback),
            if (photo != null && photo.isNotEmpty)
              Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                frameBuilder: (_, child, frame, _) =>
                    frame == null ? const SizedBox.shrink() : child,
              ),
          ],
        ),
      ),
    );
  }
}
