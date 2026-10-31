// Sidebar (Figma page "N1 Sidebar" 244:2358): phone drawer light 244:2561, dark
// 244:2625; item states 244:2689. The Figma has no theme toggle: the row above
// Sign Out follows the shadcn sidebar footer pattern and is shown only behind
// the same gate as the Config setting (decision 0130, [darkModeOption]).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/elio_theme_mode_provider.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

const _minTap = 48.0;

class ElioSidebar extends ConsumerWidget {
  const ElioSidebar({
    super.key,
    required this.user,
    required this.currentIndex,
    required this.onSelect,
    required this.onSignOut,
    required this.onClose,
    this.showThemeToggle = darkModeOption,
  });

  final User? user;

  /// Tab index of the active item (Home 0, Learn 1, Configure 2).
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback onClose;
  final bool showThemeToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final isGuest = user == null || user!.isAnonymous;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Guest User';
    final detail = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : 'Local session';
    final photo = user?.photoURL;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final dark = ref.watch(elioThemeModeProvider) == ElioThemeMode.dark;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.smart_toy_outlined, color: p.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ELIOS',
                        style: ElioTokens.subhead.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Close sidebar',
                      constraints: const BoxConstraints.tightFor(
                        width: _minTap,
                        height: _minTap,
                      ),
                      icon: Icon(
                        Icons.view_sidebar_outlined,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'NAVIGATE',
                    style: ElioTokens.overline.copyWith(color: p.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                _Item(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  title: 'Home',
                  active: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _Item(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  title: 'Learn',
                  subtitle: 'Waste types & quizzes',
                  active: currentIndex == 1,
                  onTap: () => onSelect(1),
                ),
                _Item(
                  icon: Icons.wifi_outlined,
                  activeIcon: Icons.wifi,
                  title: 'Configure',
                  subtitle: 'Setup ESP32 WebSocket',
                  active: currentIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _Item(
                  icon: Icons.gamepad_outlined,
                  activeIcon: Icons.gamepad,
                  title: 'Control',
                  subtitle: 'Drive robot & Camera',
                  active: false,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: p.borderMedium),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: p.surfaceRaised,
                  backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                  child: !hasPhoto
                      ? Icon(Icons.person_outline_rounded, color: p.primaryText)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ElioTokens.bodySmall.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ElioTokens.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isGuest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: p.secondaryText),
                      ),
                    ),
                    child: Text(
                      'GUEST',
                      style: ElioTokens.overline.copyWith(
                        color: p.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showThemeToggle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                container: true,
                child: SwitchListTile(
                  value: dark,
                  onChanged: (v) => ref
                      .read(elioThemeModeProvider.notifier)
                      .setMode(v ? ElioThemeMode.dark : ElioThemeMode.light),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  secondary: Icon(
                    dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: p.textSecondary,
                  ),
                  title: Text(
                    'Dark mode',
                    style: ElioTokens.bodySmall.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextButton.icon(
              onPressed: onSignOut,
              style: TextButton.styleFrom(
                foregroundColor: p.errorText,
                minimumSize: const Size.fromHeight(_minTap),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: ElioTokens.button,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 22),
              label: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.active,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon, activeIcon;
  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(12),
      side: active ? BorderSide(color: p.borderMedium) : BorderSide.none,
    );
    return Semantics(
      button: true,
      selected: active,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: active ? p.background : Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minTap),
              child: Stack(
                children: [
                  if (active)
                    Positioned(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(width: 3, color: p.primaryText),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          active ? activeIcon : icon,
                          size: 24,
                          color: active ? p.primaryText : p.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: ElioTokens.bodySmall.copyWith(
                                  color: p.textPrimary,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  style: ElioTokens.caption.copyWith(
                                    color: p.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
