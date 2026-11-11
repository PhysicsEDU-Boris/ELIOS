// Top bar (Figma page "N4 Profile top bar" 278:2358, component 278:2388, spec
// 279:2399): profile avatar, then the page title with an optional subtitle. Only
// the avatar is interactive; it opens the drawer.
import 'package:flutter/material.dart';

import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;
import 'package:elio/l10n/l10n.dart';

const _barHeight = 56.0;
const _tapTarget = 48.0;
const _avatarSize = 40.0;

class ElioTopBar extends StatelessWidget {
  const ElioTopBar({
    super.key,
    required this.title,
    required this.onOpenProfile,
    this.subtitle,
    this.photoUrl,
    this.avatarFocusNode,
    this.trailing,
    this.foreground,
  });

  final String title;
  final String? subtitle;
  final String? photoUrl;
  final VoidCallback onOpenProfile;

  /// Focus returns here when the drawer closes.
  final FocusNode? avatarFocusNode;

  /// Optional actions after the title (Home: trophy pill and bell).
  final Widget? trailing;

  /// Title and subtitle colour on a coloured bar (Learn: on the green header).
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _barHeight),
      child: Row(
        children: [
          // 12 dp + the 4 dp inside the target put the circle on the 16 dp margin.
          const SizedBox(width: 12),
          ElioAvatar(
            photoUrl: photoUrl,
            onTap: onOpenProfile,
            focusNode: avatarFocusNode,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: trailing == null ? 16 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ElioTokens.body.copyWith(
                      color: foreground ?? p.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ElioTokens.bodySmall.copyWith(
                        color: foreground?.withValues(alpha: 0.8) ?? p.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
        ],
      ),
    );
  }
}

/// The profile avatar; also on the Control screen (R2).
class ElioAvatar extends StatefulWidget {
  const ElioAvatar({super.key, required this.photoUrl, required this.onTap, this.focusNode});

  final String? photoUrl;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<ElioAvatar> createState() => _AvatarState();
}

class _AvatarState extends State<ElioAvatar> {
  bool _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final photo = widget.photoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    return Semantics(
      button: true,
      label: l10n.openProfileMenu,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkResponse(
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        // Ring for keyboard focus only; after a touch close it would look stuck.
        onFocusChange: (f) => setState(
          () => _focused =
              f &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional,
        ),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        highlightShape: BoxShape.circle,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: SizedBox.square(
          dimension: _tapTarget,
          child: Center(
            child: Container(
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // Pressed: filled halo. Focus: 2 px ring + 4 px halo.
                  if (_focused) ...[
                    BoxShadow(color: p.primaryText, spreadRadius: 2),
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.25),
                      spreadRadius: 6,
                    ),
                  ] else if (_pressed)
                    BoxShadow(color: p.surfaceRaised, spreadRadius: 4),
                ],
              ),
              child: CircleAvatar(
                radius: _avatarSize / 2,
                backgroundColor: p.surfaceRaised,
                backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                child: hasPhoto
                    ? null
                    : Icon(Icons.person_outline_rounded, color: p.primaryText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
