// Sidebar (Figma page "N1 Sidebar" 244:2358): phone drawer light 244:2561, dark
// 244:2625; item states 244:2689. The Figma has no theme toggle: the row above
// Sign Out follows the shadcn sidebar footer pattern; it is shown in every
// build since decision 0146 (it was behind DARK_MODE_OPTION / TESTER_BUILD).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_locale_provider.dart';
import '../providers/elio_theme_mode_provider.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;
import 'splash/elio_leaf.dart' show ElioMark;
import 'package:elio/l10n/l10n.dart';

const _minTap = 48.0;

class ElioSidebar extends ConsumerWidget {
  const ElioSidebar({
    super.key,
    required this.user,
    required this.currentIndex,
    required this.onSelect,
    required this.onSignOut,
    required this.onClose,
    this.showThemeToggle = true,
    this.body,
    this.subtitle,
  });

  final User? user;

  /// Tab index of the active item (Home 0, Learn 1, Configure 2).
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback onClose;
  final bool showThemeToggle;

  /// Replaces the Navigate section (Learn tab: Learn shortcuts, decision 0195).
  final Widget? body;

  /// Shown under "ELIOS" when [body] is set.
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final isGuest = user == null || user!.isAnonymous;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : context.l10n.sidebarGuestUser;
    final detail = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : context.l10n.sidebarLocalSession;
    final photo = user?.photoURL;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final dark = ref.watch(elioThemeModeProvider) == ElioThemeMode.dark;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  Row(
                    children: [
                      ElioMark(size: 40, color: p.primaryText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ELIOS',
                              style: ElioTokens.subhead.copyWith(
                                color: p.textPrimary,
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
                      IconButton(
                        onPressed: onClose,
                        tooltip: context.l10n.sidebarClose,
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
                  if (body != null) ...[
                    const SizedBox(height: 8),
                    body!,
                  ] else ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      context.l10n.sidebarNavigate,
                      style: ElioTokens.overline.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Item(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    title: context.l10n.sidebarHome,
                    active: currentIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _Item(
                    icon: Icons.menu_book_outlined,
                    activeIcon: Icons.menu_book,
                    title: context.l10n.sidebarLearn,
                    subtitle: context.l10n.sidebarLearnSubtitle,
                    active: currentIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  _Item(
                    icon: Icons.wifi_outlined,
                    activeIcon: Icons.wifi,
                    title: context.l10n.sidebarConfigure,
                    subtitle: context.l10n.sidebarConfigureSubtitle,
                    active: currentIndex == 2,
                    onTap: () => onSelect(2),
                  ),
                  _Item(
                    icon: Icons.gamepad_outlined,
                    activeIcon: Icons.gamepad,
                    title: context.l10n.sidebarControl,
                    subtitle: context.l10n.sidebarControlSubtitle,
                    active: false,
                    onTap: () => onSelect(3),
                  ),
                  ],
                ],
              ),
            ),
            // On short screens (landscape phones) the footer scrolls instead of
            // squeezing the menu to nothing.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: p.borderMedium,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: p.surfaceRaised,
                            backgroundImage: hasPhoto
                                ? NetworkImage(photo)
                                : null,
                            child: !hasPhoto
                                ? Icon(
                                    Icons.person_outline_rounded,
                                    color: p.primaryText,
                                  )
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
                                context.l10n.sidebarGuestBadge,
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
                                .setMode(
                                  v ? ElioThemeMode.dark : ElioThemeMode.light,
                                ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            secondary: Icon(
                              dark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              color: p.textSecondary,
                            ),
                            title: Text(
                              context.l10n.sidebarDarkMode,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Icon(
                          Icons.translate_rounded,
                          color: p.textSecondary,
                          semanticLabel: context.l10n.sidebarLanguage,
                        ),
                        // The dropdown is the title so a long name fits a narrow drawer.
                        title: DropdownButton<Locale>(
                          key: const Key('sidebar-language'),
                          isExpanded: true,
                          // Match by language so a regional device locale (en_US) still selects "en".
                          value: AppLocalizations.supportedLocales.firstWhere(
                            (l) =>
                                l.languageCode ==
                                Localizations.localeOf(context).languageCode,
                            orElse: () =>
                                AppLocalizations.supportedLocales.first,
                          ),
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final l in AppLocalizations.supportedLocales)
                              DropdownMenuItem(
                                value: l,
                                child: Text(
                                  lookupAppLocalizations(l).languageName,
                                  overflow: TextOverflow.ellipsis,
                                  style: ElioTokens.bodySmall.copyWith(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (l) {
                            if (l != null) {
                              ref.read(appLocaleProvider.notifier).setLocale(l);
                            }
                          },
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
                        label: Text(context.l10n.signOut),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
