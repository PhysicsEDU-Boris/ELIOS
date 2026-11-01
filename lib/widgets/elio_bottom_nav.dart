// Bottom navigation (Figma page "N3 Bottom nav"): Home, Learn, Control (raised
// round button), Config, Profile. Tab indices are the app's provider indices
// (Home 0, Learn 1, Config 2); only the on-screen order differs. Control is an
// action, never selected; Profile opens the sidebar, it is not a tab.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

const _barHeight = 64.0;
const _raise = 16.0;
const _controlSize = 56.0;

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
    Widget tab(int i, String label, IconData off, IconData on) => _Cell(
      label: label,
      semantics: label,
      selected: currentIndex == i,
      onTap: () => onSelectTab(i),
      icon: Icon(currentIndex == i ? on : off, size: 24),
    );
    return Semantics(
      container: true,
      label: 'Main',
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _raise),
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
                      child: tab(0, 'Home', Icons.home_outlined, Icons.home),
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
                        onTap: onControl,
                        icon: const SizedBox(height: _controlSize - _raise),
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
                        onTap: onProfile,
                        icon: _Avatar(user: user, ring: profileOpen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sits in the bar's own layout box, so the whole circle takes taps.
          Positioned(top: 0, child: _ControlButton(onTap: onControl)),
        ],
      ),
    );
  }
}

/// One 48 dp+ target: icon above label, selected stroke on the top rule.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String label, semantics;
  final bool selected;
  final VoidCallback onTap;
  final Widget icon;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _focused = false;

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
        splashFactory: plain ? NoSplash.splashFactory : null,
        focusColor: Colors.transparent,
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
            Container(
              constraints: const BoxConstraints(minHeight: _barHeight - 1),
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              decoration: _ring(p, _focused, BoxShape.rectangle),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme(
                    data: IconThemeData(color: color),
                    child: widget.icon,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: ElioTokens.caption.copyWith(
                        color: color,
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
    );
  }
}

/// 2 px ring plus 4 px halo, both from the palette.
Decoration? _ring(ElioPalette p, bool on, BoxShape shape) => !on
    ? null
    : BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(8),
        border: Border.all(color: p.primaryText, width: 2),
        boxShadow: [
          BoxShadow(color: p.primary.withValues(alpha: 0.25), spreadRadius: 4),
        ],
      );

class _ControlButton extends StatefulWidget {
  const _ControlButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ExcludeSemantics(
      child: InkResponse(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        splashFactory: MediaQuery.disableAnimationsOf(context)
            ? NoSplash.splashFactory
            : null,
        child: Container(
          width: _controlSize,
          height: _controlSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primary,
            shape: BoxShape.circle,
            border: _focused
                ? Border.all(color: p.primaryText, width: 2)
                : null,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.25),
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.smart_toy, size: 28, color: p.onPrimary),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.ring});
  final User? user;
  final bool ring;

  String? get _initials {
    if (user == null || user!.isAnonymous) return null;
    final words = (user!.displayName ?? '').trim().split(RegExp(r'\s+'));
    final src = words.first.isEmpty
        ? (user!.email ?? '').trim().split(RegExp(r'\s+'))
        : words.take(2).toList();
    final s = src.where((w) => w.isNotEmpty).map((w) => w[0]).join();
    return s.isEmpty ? null : s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final initials = _initials;
    final photo = user?.photoURL;
    final fallback = initials == null
        ? const Icon(Icons.person_outline_rounded, size: 18)
        : Text(
            initials,
            style: ElioTokens.caption.copyWith(
              color: p.primaryText,
              fontWeight: FontWeight.w600,
            ),
          );
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceRaised,
        border: Border.all(
          color: ring ? p.primaryText : Colors.transparent,
          width: 2,
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
