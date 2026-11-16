// ELIOS 3 Profile tab (Figma 629:100963, account menu 629:101083, guest
// 629:101228): Appearance (dark mode, language), Sound (effects, master
// volume), Quiz (source, difficulty, timer, skipping). The avatar opens a
// compact account menu. Every value is saved where it was before
// (AppPreferences, theme mode and locale in shared preferences).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_locale_provider.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/elio_theme_mode_provider.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/elio_theme_reveal.dart';
import '../../widgets/learn/learn_ui.dart';
import '../../widgets/splash/elio_leaf.dart';
import '../config/config_settings_sheet.dart' show ConfigSegmented;
import '../../services/elio_feedback.dart';

/// "b•••@gmail.com": the first letter and the domain only.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return email;
  return '${email[0]}•••${email.substring(at)}';
}

/// Up to two initials from the display name, else the email.
String initialsOf(User? user) {
  final name = user?.displayName?.trim() ?? '';
  final source = name.isNotEmpty ? name : (user?.email ?? '');
  final words = source
      .split(RegExp(r'[\s@._-]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final letters = words.length == 1
      ? words.first.substring(0, 1)
      : words[0].substring(0, 1) + words[1].substring(0, 1);
  return letters.toUpperCase();
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.user, required this.onSignOut});

  final User? user;

  /// Signs out and returns to the login screen (also "Switch account").
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          final prefs = ref.watch(appPreferencesProvider);
          final dark = ref.watch(elioThemeModeProvider) == ElioThemeMode.dark;
          void patch(AppPreferences Function(AppPreferences) f) =>
              ref.read(appPreferencesProvider.notifier).update(f);
          final lang = Localizations.localeOf(context).languageCode;

          return Material(
            color: p.background,
            child: SafeArea(
              top: false, // the header's green curve sits behind the status bar
              bottom: false,
              child: _StatusBarScrim(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  children: _staggered([
                    _ProfileHeader(user: user, onSignOut: onSignOut),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.palette_outlined,
                      tone: p.primaryText,
                      title: l10n.profileAppearance,
                    ),
                    // The new theme grows out of the switch (Figma 13 · 36).
                    Builder(
                      builder: (row) => _SwitchRow(
                        title: l10n.sidebarDarkMode,
                        subtitle: l10n.profileDarkModeSub,
                        value: dark,
                        onChanged: (v) {
                          final box = row.findRenderObject() as RenderBox?;
                          final at = box == null
                              ? Offset.zero
                              : box.localToGlobal(
                                  Offset(
                                    box.size.width - 40,
                                    box.size.height / 2,
                                  ),
                                );
                          ThemeSwitchReveal.run(
                            at,
                            () => ref
                                .read(elioThemeModeProvider.notifier)
                                .setMode(
                                  v ? ElioThemeMode.dark : ElioThemeMode.light,
                                ),
                          );
                        },
                      ),
                    ),
                    const _Rule(),
                    _RowTitle(
                      title: l10n.sidebarLanguage,
                      subtitle: l10n.profileLanguageSub,
                    ),
                    const SizedBox(height: 10),
                    ConfigSegmented(
                      key: const Key('profile-language'),
                      label: l10n.sidebarLanguage,
                      options: [
                        for (final l in AppLocalizations.supportedLocales)
                          l.languageCode,
                      ],
                      labels: [
                        for (final l in AppLocalizations.supportedLocales)
                          lookupAppLocalizations(l).languageName,
                      ],
                      selected: lang,
                      onSelected: (code) => ref
                          .read(appLocaleProvider.notifier)
                          .setLocale(Locale(code)),
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      icon: Icons.music_note_outlined,
                      tone: p.secondaryText,
                      title: l10n.setSound,
                    ),
                    _SwitchRow(
                      title: l10n.setSoundEffects,
                      subtitle: l10n.setSoundEffectsSub,
                      value: prefs.soundEffects,
                      onChanged: (v) =>
                          patch((s) => s.copyWith(soundEffects: v)),
                    ),
                    const _Rule(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.setMasterVolume,
                            style: _rowTitle(p),
                          ),
                        ),
                        Text(
                          '${(prefs.masterVolume * 100).round()}%',
                          style: ElioTokens.button.copyWith(
                            color: p.primaryText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.volume_mute_outlined,
                          size: 20,
                          color: p.textSecondary,
                        ),
                        Expanded(
                          child: Slider(
                            value: prefs.masterVolume,
                            activeColor: p.primary,
                            inactiveColor: p.surfaceRaised,
                            semanticFormatterCallback: (v) =>
                                l10n.setMasterVolumeValue((v * 100).round()),
                            onChanged: (v) {
                              // H-select on each 10 % detent, no sound while dragging.
                              if ((v * 10).round() !=
                                  (prefs.masterVolume * 10).round()) {
                                ElioHaptics.select();
                              }
                              patch((s) => s.copyWith(masterVolume: v));
                            },
                            // Preview at the new volume on release (Figma 13 · 6).
                            onChangeEnd: (_) =>
                                ElioSound.instance.play(ElioSfx.pop),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_outlined,
                          size: 20,
                          color: p.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.help_outline_rounded,
                      tone: p.errorText,
                      title: l10n.setQuiz,
                    ),
                    _RowTitle(
                      title: l10n.profileQuestionSource,
                      subtitle: l10n.profileQuestionSourceSub,
                    ),
                    const SizedBox(height: 10),
                    ConfigSegmented(
                      label: l10n.profileQuestionSource,
                      options: [
                        QuestionSource.bank.name,
                        QuestionSource.ai.name,
                      ],
                      labels: [l10n.questionBank, 'ELIOS AI'],
                      selected: prefs.questionSource.name,
                      onSelected: (v) => patch(
                        (s) => s.copyWith(
                          questionSource: QuestionSource.values.byName(v),
                        ),
                      ),
                    ),
                    const _Rule(),
                    _RowTitle(title: l10n.setDifficulty),
                    const SizedBox(height: 10),
                    ConfigSegmented(
                      label: l10n.setDifficulty,
                      // Saved in English: the quiz reads 'Easy'/'Medium'/'Hard'.
                      options: const ['Easy', 'Medium', 'Hard'],
                      labels: [l10n.setEasy, l10n.setMedium, l10n.setHard],
                      selected: prefs.quizDifficulty,
                      onSelected: (v) =>
                          patch((s) => s.copyWith(quizDifficulty: v)),
                    ),
                    const _Rule(),
                    _RowTitle(title: l10n.setTimer, subtitle: l10n.setTimerSub),
                    const SizedBox(height: 10),
                    ConfigSegmented(
                      label: l10n.setTimer,
                      options: const ['30s', '60s', '90s', '120s'],
                      selected: prefs.quizTimer,
                      onSelected: (v) => patch((s) => s.copyWith(quizTimer: v)),
                    ),
                    const _Rule(),
                    _SwitchRow(
                      title: l10n.setAllowSkip,
                      subtitle: l10n.setAllowSkipSub,
                      value: prefs.skipAllowed,
                      onChanged: (v) =>
                          patch((s) => s.copyWith(skipAllowed: v)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The header's curve shows behind the status bar at rest; once the list
/// scrolls, a background strip covers the status bar so settings text never
/// runs under the clock (found on the phone, 16 Nov).
class _StatusBarScrim extends StatefulWidget {
  const _StatusBarScrim({required this.child});
  final Widget child;

  @override
  State<_StatusBarScrim> createState() => _StatusBarScrimState();
}

class _StatusBarScrimState extends State<_StatusBarScrim> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final scrolled =
            n.metrics.axis == Axis.vertical && n.metrics.pixels > 60;
        if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const Key('profile-status-scrim'),
                opacity: _scrolled ? 1 : 0,
                duration: ElioMotion.reduced(context)
                    ? Duration.zero
                    : ElioMotion.fast,
                child: ColoredBox(color: context.elio.background),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry: the header pops in by itself, then each section (title + its rows)
/// rises in after the one before. Reduce motion: a plain fade (ElioPopIn).
List<Widget> _staggered(List<Widget> children) {
  var section = 0;
  return [
    children.first,
    for (final w in children.skip(1))
      ElioPopIn(index: (w is _Section ? ++section : section) + 2, child: w),
  ];
}

TextStyle _rowTitle(ElioPalette p) => ElioTokens.body.copyWith(
  fontWeight: FontWeight.w600,
  height: 1.4,
  color: p.textPrimary,
);

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onSignOut});
  final User? user;
  final VoidCallback onSignOut;

  Future<void> _openMenu(BuildContext context) async {
    elioFeedback(ElioSfx.pop, ElioHaptics.light); // Figma 13 · 35
    final p = context.elio;
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final guest = user == null || user!.isAnonymous;
    final choice = await showMenu<String>(
      context: context,
      // Popover from the avatar: 200 ms emphasized, dismiss 150 (Figma 13 · 9).
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 200),
        reverseDuration: ElioMotion.fast,
        curve: ElioMotion.emphasized,
        reverseCurve: ElioMotion.exit,
      ),
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      position: RelativeRect.fromLTRB(
        origin.dx + box.size.width / 2,
        origin.dy + 40,
        16,
        0,
      ),
      items: [
        if (!guest)
          PopupMenuItem(
            value: 'switch',
            child: _MenuRow(
              icon: Icons.people_outline_rounded,
              label: l10n.profileSwitchAccount,
              color: p.textPrimary,
            ),
          ),
        PopupMenuItem(
          value: 'out',
          child: _MenuRow(
            icon: guest ? Icons.login_rounded : Icons.logout_rounded,
            label: guest ? l10n.signIn : l10n.signOut,
            color: guest ? p.primaryText : p.errorText,
          ),
        ),
      ],
    );
    // Switch account and Sign out both go back to the login screen, where
    // the Google account picker opens.
    if (choice != null) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final guest = user == null || user!.isAnonymous;
    final name = guest
        ? l10n.homeGuest
        : (user!.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : (user!.email?.split('@').first ?? l10n.homeGuest));
    final email = user?.email;
    final photo = user?.photoURL;
    final initials = guest ? '' : initialsOf(user);
    final chipColor = guest ? p.secondaryText : p.primaryText;

    // Avatar (629:100971): leaf shape, 5 dp surface ring outside, soft shadow.
    const leaf = BorderRadius.only(
      topLeft: Radius.circular(58),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(58),
      bottomLeft: Radius.circular(16),
    );
    final avatar = Container(
      width: 130,
      height: 130,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: leaf + const BorderRadius.all(Radius.circular(5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0F1729),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(color: p.surfaceRaised, borderRadius: leaf),
        clipBehavior: Clip.antiAlias,
        child: photo != null && photo.isNotEmpty && !guest
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(p, initials),
              )
            : _fallback(p, initials),
      ),
    );
    // Edit leaf (629:100976): 3 dp surface ring. Decorative; the avatar is the button.
    final badge = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.primary,
        shape: BoxShape.circle,
        border: Border.all(color: p.surface, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            offset: Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      // ponytail: Figma's dark frame draws the leaf in primary on primary
      // (invisible); the on-primary ink is used there instead.
      child: ElioMark(size: 24, color: p.isDark ? p.onPrimary : p.primaryText),
    );
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        SizedBox(height: top),
        SizedBox(
          height: 166,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Full-bleed: the list pads 16 dp each side.
              Positioned(
                left: -16,
                right: -16,
                top: 0,
                bottom: 0,
                child: const _HeaderDecor(key: Key('profile-header-decor')),
              ),
              Positioned(
                top: 31,
                // Entry: the avatar pops in first (spring), then the sections.
                child: ElioPopIn(
                  scale: 0.8,
                  rise: 0,
                  curve: ElioMotion.pop,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Semantics(
                        button: true,
                        label: l10n.profileAccountMenu,
                        excludeSemantics: true,
                        onTap: () => _openMenu(context),
                        child: Builder(
                          builder: (anchor) => InkWell(
                            key: const Key('profile-avatar'),
                            customBorder: const RoundedRectangleBorder(
                              borderRadius: leaf,
                            ),
                            onTap: () => _openMenu(anchor),
                            child: avatar,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 95,
                        top: 94,
                        child: IgnorePointer(
                          child: ExcludeSemantics(child: badge),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: ElioTokens.body.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: p.textPrimary,
          ),
        ),
        Text(
          guest || email == null ? l10n.profileNotSignedIn : maskEmail(email),
          style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: ShapeDecoration(
            color: chipColor.withValues(alpha: 0.08),
            shape: StadiumBorder(
              side: BorderSide(color: chipColor.withValues(alpha: 0.35)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                guest ? Icons.phone_android_rounded : Icons.cloud_done_outlined,
                size: 16,
                color: chipColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  guest ? l10n.profileGuestChip : l10n.profileSynced,
                  style: ElioTokens.label.copyWith(color: chipColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          guest ? l10n.profileGuestTap : l10n.profileTapPicture,
          textAlign: TextAlign.center,
          style: ElioTokens.caption.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }

  Widget _fallback(ElioPalette p, String initials) => Center(
    child: initials.isNotEmpty
        ? Text(
            initials,
            style: ElioTokens.body.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: p.primaryText,
            ),
          )
        : Icon(Icons.person_outline_rounded, size: 56, color: p.textSecondary),
  );
}

/// Header backdrop (851:28593-603): green curve reaching behind the status
/// bar, bubbles, confetti, mini leaf and sparkle. Drawn on a 390 dp frame and
/// spread to the real width. Purely visual.
class _HeaderDecor extends StatelessWidget {
  const _HeaderDecor({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final k = box.maxWidth / 390;
            Widget at(double x, double y, Widget child) =>
                Positioned(left: x * k, top: y, child: child);
            Widget dot(double d, Color c) => Container(
              width: d,
              height: d,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            );
            Widget bar(double h, double deg, Color c) => Transform.rotate(
              angle: deg * 3.1415926535 / 180,
              child: Container(
                width: 6,
                height: h,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
            const white = Color(0xD9FFFFFF);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -125 * k,
                  top: -178,
                  width: 640 * k,
                  height: 300,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: p.primary,
                      shape: const OvalBorder(),
                    ),
                  ),
                ),
                at(296, -92, dot(120, p.primaryHover)),
                at(-22, 40, dot(64, p.primaryHover)),
                // Confetti fades in after the avatar lands.
                Positioned.fill(
                  child: ElioPopIn(
                    rise: 0,
                    scale: 1,
                    delay: ElioMotion.fast,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        at(
                          318,
                          74,
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: p.surface, width: 3),
                            ),
                          ),
                        ),
                        at(60, 22, dot(10, ElioTokens.answerYellow)),
                        at(107, 67, bar(16, -30, ElioTokens.answerBlue)),
                        at(41, 112, bar(14, 25, ElioTokens.answerRed)),
                        at(348, 40, dot(8, white)),
                        at(281, 108, bar(14, 40, ElioTokens.answerYellow)),
                        at(86, 42, dot(6, white)),
                        at(
                          17.5,
                          13,
                          Transform.rotate(
                            angle: 20 * 3.1415926535 / 180,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(3),
                                  bottomRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          // Beside the avatar at any width.
                          left: box.maxWidth / 2 + 73,
                          top: 136,
                          child: SvgPicture.asset(
                            'assets/illustrations/home/icon_sparkle.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              p.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 12),
      Text(label, style: ElioTokens.button.copyWith(color: color)),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.tone, required this.title});
  final IconData icon;
  final Color tone;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Semantics(
            header: true,
            child: Text(
              title,
              style: ElioTokens.body.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTitle extends StatelessWidget {
  const _RowTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _rowTitle(p)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: ElioTokens.caption.copyWith(color: p.textSecondary),
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    void flip(bool v) {
      elioFeedback(
        v ? ElioSfx.toggleOn : ElioSfx.toggleOff,
        ElioHaptics.select,
      );
      onChanged(v);
    }

    // The whole row toggles, not only the switch.
    return MergeSemantics(
      child: InkWell(
        onTap: () => flip(!value),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: _RowTitle(title: title, subtitle: subtitle),
            ),
            Switch(value: value, onChanged: flip),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: context.elio.borderSubtle),
  );
}
