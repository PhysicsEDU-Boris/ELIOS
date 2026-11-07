// C1 Settings sheet 349:4445 / 349:4681 (decision 0145). Theme stays in the
// sidebar; every value is saved where it was before (EspConfig in secure
// storage, AppPreferences in shared preferences).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config_model.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/esp_config_provider.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/learn/learn_ui.dart';
import 'config_parts.dart';
import 'package:elio/l10n/l10n.dart';

Future<void> showConfigSettingsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ElioTheme.wrap(const ConfigSettingsSheet()),
    );

/// Header button that opens the sheet (top bar trailing on the Config tab).
class ConfigSettingsButton extends StatelessWidget {
  const ConfigSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        tooltip: l10n.settingsTitle,
        onPressed: () => showConfigSettingsSheet(context),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          backgroundColor: p.surface,
          side: BorderSide(color: p.borderSubtle),
        ),
        icon: Icon(Icons.my_location_rounded, color: p.textPrimary),
      ),
    );
  }
}

class ConfigSettingsSheet extends ConsumerWidget {
  const ConfigSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final esp = ref.watch(espConfigProvider).valueOrNull ?? const EspConfig();
    final prefs = ref.watch(appPreferencesProvider);
    void patchEsp(EspConfig Function(EspConfig) f) => ref.read(espConfigProvider.notifier).patch(f);
    void patchPrefs(AppPreferences Function(AppPreferences) f) => ref.read(appPreferencesProvider.notifier).update(f);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(learnRadiusXl)),
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: ShapeDecoration(color: p.borderMedium, shape: const StadiumBorder()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
              child: Row(
                children: [
                  const ConfigIconChip(Icons.my_location_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(context.l10n.settingsTitle,
                              style: ElioTokens.bodyLarge.copyWith(
                                  fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, color: p.textPrimary)),
                        ),
                        Text(context.l10n.settingsSubtitle, style: configCaption(p)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: p.surface,
                      side: BorderSide(color: p.borderSubtle),
                    ),
                    icon: Icon(Icons.close_rounded, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _Overline(l10n.setConnection),
                  ConfigCard(
                    child: _SwitchRow(
                      icon: Icons.sync_rounded,
                      title: l10n.setAutoReconnect,
                      subtitle: l10n.setAutoReconnectSub,
                      value: esp.autoReconnect,
                      onChanged: (v) => patchEsp((c) => c.copyWith(autoReconnect: v)),
                    ),
                  ),
                  _Overline(l10n.setVideo),
                  ConfigCard(
                    child: Column(
                      children: [
                        _RowHeader(
                          icon: Icons.desktop_windows_outlined,
                          title: l10n.setResolution,
                          subtitle: l10n.setResolutionSub,
                        ),
                        const SizedBox(height: 12),
                        ConfigSegmented(
                          label: l10n.setResolution,
                          options: const ['480p', '720p'],
                          selected: esp.resolutionPreset,
                          onSelected: (v) => patchEsp((c) => c.copyWith(resolutionPreset: v)),
                        ),
                        const _Divider(),
                        _SwitchRow(
                          icon: Icons.speed_rounded,
                          title: l10n.setShowFps,
                          subtitle: l10n.setShowFpsSub,
                          value: esp.showFpsOverlay,
                          onChanged: (v) => patchEsp((c) => c.copyWith(showFpsOverlay: v)),
                        ),
                      ],
                    ),
                  ),
                  _Overline(l10n.setSound),
                  ConfigCard(
                    child: Column(
                      children: [
                        _SwitchRow(
                          icon: Icons.music_note_outlined,
                          title: l10n.setSoundEffects,
                          subtitle: l10n.setSoundEffectsSub,
                          value: prefs.soundEffects,
                          onChanged: (v) => patchPrefs((s) => s.copyWith(soundEffects: v)),
                        ),
                        const _Divider(),
                        _RowHeader(
                          icon: Icons.volume_up_outlined,
                          title: l10n.setMasterVolume,
                          trailing: Text('${(prefs.masterVolume * 100).round()}%',
                              style: configStrong(p, color: p.primaryText)),
                        ),
                        Row(
                          children: [
                            Icon(Icons.volume_mute_outlined, color: p.textSecondary),
                            Expanded(
                              child: Slider(
                                value: prefs.masterVolume,
                                activeColor: p.primary,
                                inactiveColor: p.surfaceRaised,
                                semanticFormatterCallback: (v) => l10n.setMasterVolumeValue((v * 100).round()),
                                onChanged: (v) => patchPrefs((s) => s.copyWith(masterVolume: v)),
                              ),
                            ),
                            Icon(Icons.volume_up_outlined, color: p.textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _Overline(l10n.setQuiz),
                  ConfigCard(
                    child: Column(
                      children: [
                        _RowHeader(icon: Icons.signal_cellular_alt_rounded, title: l10n.setDifficulty),
                        const SizedBox(height: 12),
                        ConfigSegmented(
                          label: l10n.setDifficulty,
                          // Saved in English: the quiz reads 'Easy'/'Medium'/'Hard' in any language.
                          options: const ['Easy', 'Medium', 'Hard'],
                          labels: [l10n.setEasy, l10n.setMedium, l10n.setHard],
                          selected: prefs.quizDifficulty,
                          onSelected: (v) => patchPrefs((s) => s.copyWith(quizDifficulty: v)),
                        ),
                        const _Divider(),
                        _RowHeader(icon: Icons.schedule_rounded, title: l10n.setTimer, subtitle: l10n.setTimerSub),
                        const SizedBox(height: 12),
                        ConfigSegmented(
                          label: l10n.setTimer,
                          options: const ['30s', '60s', '90s', '120s'],
                          selected: prefs.quizTimer,
                          onSelected: (v) => patchPrefs((s) => s.copyWith(quizTimer: v)),
                        ),
                        const _Divider(),
                        _SwitchRow(
                          icon: Icons.skip_next_outlined,
                          title: l10n.setAllowSkip,
                          subtitle: l10n.setAllowSkipSub,
                          value: prefs.skipAllowed,
                          onChanged: (v) => patchPrefs((s) => s.copyWith(skipAllowed: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.borderSubtle))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ConfigButton(
                    label: l10n.notifDone,
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segment 349:4444: green pill on the chosen value.
class ConfigSegmented extends StatelessWidget {
  const ConfigSegmented({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labels,
  });

  final String label;
  final List<String> options;

  /// What each option shows, when it differs from the saved value.
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: p.surfaceRaised, shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final (i, o) in options.indexed)
            Expanded(
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: o == selected,
                label: '$label ${labels?[i] ?? o}',
                excludeSemantics: true,
                onTap: () => onSelected(o),
                child: Material(
                  color: o == selected ? p.primary : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(o),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(labels?[i] ?? o,
                            style: configStrong(p, color: o == selected ? p.onPrimary : p.textSecondary)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(),
              style: ElioTokens.label.copyWith(color: context.elio.textSecondary, letterSpacing: 1.6)),
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: configDivider(context.elio)));
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({required this.icon, required this.title, this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      children: [
        ConfigIconChip(icon, color: p.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: configStrong(p)),
              if (subtitle != null) Text(subtitle!, style: configCaption(p)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Row(
          children: [
            Expanded(child: _RowHeader(icon: icon, title: title, subtitle: subtitle)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}
