import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/daily_guide_provider.dart';
import '../../../services/daily_guide_service.dart';
import '../../../services/guide_progress.dart';
import '../../../widgets/history_ui.dart' show HistorySkeletonBlock;
import '../../../widgets/learn/learn_ui.dart';
import 'guides/guide_issue_page.dart';
import 'guides/guide_widgets.dart';
import 'learn_content.dart';

void openGuideIssue(BuildContext context, DailyGuide guide) =>
    Navigator.of(context).push(learnRoute<void>(GuideIssuePage(guide: guide)));

/// Learn hub: Today card above the knowledge challenge, then the "Guide archive" row (541:2389).
class GuidesHubSection extends ConsumerWidget {
  const GuidesHubSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(dailyGuideFeedProvider).valueOrNull;
    final guides = feed?.guides ?? const <DailyGuide>[];
    final streak = ref.watch(guideProgressProvider.select((s) => s.streak));
    void openFeed() =>
        Navigator.of(context).push(learnRoute<void>(const DailyGuidesPage()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (guides.isNotEmpty) ...[
          GuideTodayCard(
            guide: guides.first,
            onOpen: () => openGuideIssue(context, guides.first),
          ),
          const SizedBox(height: 12),
        ],
        LearnCard(
          onTap: openFeed,
          semanticLabel: l10n.g4GuideArchive,
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: Row(
            children: [
              if (guides.isNotEmpty)
                ExcludeSemantics(child: GuideMiniStack(guides: guides))
              else
                SizedBox(
                  width: 56,
                  child: Icon(
                    Icons.newspaper_rounded,
                    color: context.elio.primaryText,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.g4GuideArchive, style: context.text.titleMedium),
                    Text(
                      guides.isEmpty
                          ? l10n.dailyGuidesDescription
                          : l10n.g4IssuesStreak(guides.length, streak),
                      style: context.text.bodySmall?.copyWith(
                        color: context.elio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.elio.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Guides feed 541:2518.
class DailyGuidesPage extends ConsumerStatefulWidget {
  const DailyGuidesPage({super.key});

  @override
  ConsumerState<DailyGuidesPage> createState() => _DailyGuidesPageState();
}

class _DailyGuidesPageState extends ConsumerState<DailyGuidesPage> {
  String? _topic;

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(dailyGuideFeedProvider.notifier).refresh(),
      ref.read(guideProgressProvider.notifier).sync(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(dailyGuideFeedProvider);
    final lang = guideLangOf(ref);
    final p = context.elio;
    return Scaffold(
      backgroundColor: p.background,
      appBar: GuideTopBar(
        title: l10n.dailyGuidesTitle,
        subtitle: l10n.g4FeedSubtitle,
        action: Semantics(
          button: true,
          label: l10n.g4GuideLanguage,
          excludeSemantics: true,
          child: OutlinedButton(
            onPressed: () => showGuideLanguageSheet(context, ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              shape: const StadiumBorder(),
              side: BorderSide(color: p.borderSubtle),
              foregroundColor: p.textPrimary,
            ),
            child: Text(
              ref.watch(guideProgressProvider.select((s) => s.guideLang)) ==
                      null
                  ? l10n.g4LangPill
                  : lang.toUpperCase(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (feed) {
          AsyncValue(:final value?) => _list(value, lang),
          AsyncError() => LearnListView(
            onRefresh: _refresh,
            children: [
              LearnStateView(
                asset: LearnArt.stateOffline,
                title: l10n.g4FeedError,
                message: l10n.lnCheckOpenAgain,
                primaryLabel: l10n.dailyGuidesRefresh,
                onPrimary: _refresh,
              ),
            ],
          ),
          _ => const _FeedSkeleton(),
        },
      ),
    );
  }

  Widget _list(DailyGuideFeed feed, String lang) {
    final p = context.elio;
    final guides = feed.guides;
    final themes = [
      for (final t in guideThemes)
        if (guides.any((g) => g.theme == t)) t,
    ];
    final archive = [
      for (final g in guides)
        if (_topic == null || g.theme == _topic) g,
    ];
    final guest = ref.watch(guideProgressProvider.select((s) => s.guestImport));
    return LearnListView(
      onRefresh: _refresh,
      children: [
        if (feed.offline)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LearnCard(
              color: p.secondaryText.withValues(alpha: 0.06),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: p.secondaryText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.g4OfflineBanner,
                      style: context.text.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    style: TextButton.styleFrom(
                      foregroundColor: p.primaryText,
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(l10n.g4Retry),
                  ),
                ],
              ),
            ),
          ),
        if (guest != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GuestImportCard(xp: guest.xp),
          ),
        if (guides.isEmpty)
          LearnStateView(
            asset: LearnArt.stateEmpty,
            title: l10n.g4EmptyTitle,
            message: l10n.g4EmptyBody,
            primaryLabel: l10n.g4CheckAgain,
            onPrimary: _refresh,
          )
        else ...[
          const GuideStreakCard(),
          const SizedBox(height: 18),
          Text(
            l10n.g4TodayDate(
              DateFormat(
                'EEE d MMM',
                dateLocale,
              ).format(DateTime.now()).toUpperCase(),
            ),
            style: context.text.labelMedium?.copyWith(
              color: p.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GuideTodayCard(
            guide: guides.first,
            onOpen: () => openGuideIssue(context, guides.first),
          ),
          Row(
            children: [
              Expanded(child: LearnSectionHeader(title: l10n.g4Archive)),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  l10n.g4IssueCount(guides.length),
                  style: context.text.labelLarge?.copyWith(
                    color: p.primaryText,
                  ),
                ),
              ),
            ],
          ),
          if (themes.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in [null, ...themes])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t == null ? l10n.g4All : topicName(t)),
                        selected: _topic == t,
                        showCheckmark: false,
                        selectedColor: p.primary,
                        backgroundColor: p.surface,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: _topic == t ? p.primary : p.borderSubtle,
                          ),
                        ),
                        labelStyle: context.text.labelLarge?.copyWith(
                          color: _topic == t ? p.onPrimary : p.textPrimary,
                        ),
                        onSelected: (_) => setState(() => _topic = t),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth > 560 ? 3 : 2;
              final width = (box.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final (i, g) in archive.indexed)
                    SizedBox(
                      width: width,
                      child: GuideArchiveCard(
                        guide: g,
                        tiltLeft: i % columns == 0,
                        onTap: () => openGuideIssue(context, g),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Explicit offer to move a guest's guide progress on this phone into this account (0191 pattern).
class _GuestImportCard extends ConsumerWidget {
  const _GuestImportCard({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(guideProgressProvider.notifier);
    return LearnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.g4ImportTitle, style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.g4ImportBody(xp),
            style: context.text.bodySmall?.copyWith(
              color: context.elio.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: Text(l10n.g4ImportTitle),
                      content: Text(l10n.g4ImportConfirm(xp)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: Text(l10n.g4NotNow),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: Text(l10n.g4Import),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await notifier.importGuest();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.g4ImportFailed)),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.g4Import),
              ),
              TextButton(
                onPressed: notifier.declineGuest,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.g4NotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading 543:2961: the shared H3 shimmer, shaped like the feed.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: l10n.lnLoadingGuide,
    child: LearnListView(
      children: [
        LearnCard(
          child: Column(
            children: const [
              HistorySkeletonBlock(height: 16),
              SizedBox(height: 16),
              HistorySkeletonBlock(height: 34, radius: 17),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LearnCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              HistorySkeletonBlock(width: 112, height: 160),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    HistorySkeletonBlock(height: 18),
                    SizedBox(height: 10),
                    HistorySkeletonBlock(height: 18),
                    SizedBox(height: 10),
                    HistorySkeletonBlock(height: 12),
                    SizedBox(height: 10),
                    HistorySkeletonBlock(width: 90, height: 22, radius: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(
                child: LearnCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: const [
                      HistorySkeletonBlock(height: 112),
                      SizedBox(height: 10),
                      HistorySkeletonBlock(height: 12),
                      SizedBox(height: 8),
                      HistorySkeletonBlock(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
