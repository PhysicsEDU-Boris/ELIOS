import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../providers/daily_guide_provider.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/guide_progress.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../guides_page.dart';
import '../learn_content.dart';
import 'guide_lab_page.dart';
import 'guide_quiz_page.dart';
import 'guide_widgets.dart';

/// Guide issue 541:2781: hero polaroid, language switch, full PDF, quest map, sources.
class GuideIssuePage extends ConsumerWidget {
  const GuideIssuePage({super.key, required this.guide});
  final DailyGuide guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A republished issue (new revision) replaces the text while the page is open.
    final g =
        ref
            .watch(dailyGuideFeedProvider)
            .valueOrNull
            ?.guides
            .where((x) => x.date == guide.date)
            .firstOrNull ??
        guide;
    final want = guideLangOf(ref);
    final lang = g.lang(want);
    final content = ref.watch(guideContentProvider((g, lang))).valueOrNull;
    final progress = ref.watch(
      guideProgressProvider.select((s) => s.of(g.date)),
    );
    final page = ref.watch(
      guideProgressProvider.select((s) => s.pages[g.date] ?? 0),
    );
    final p = context.elio;
    String? t(String key) => content?.text(key);

    Future<void> openPdf([int? atLeast]) => openGuideLesson(
      context: context,
      ref: ref,
      lesson: g.lesson(lang),
      dailyInitialPage: atLeast != null && page < atLeast ? atLeast : page,
      onDailyPage: (n) => ref
          .read(guideProgressProvider.notifier)
          .pageReached(g.date, n, storyXp: g.xp.story, physicsXp: g.xp.physics),
    );
    void openQuiz() =>
        Navigator.of(context).push(learnRoute<void>(GuideQuizPage(guide: g)));
    void openLab() =>
        Navigator.of(context).push(learnRoute<void>(GuideLabPage(guide: g)));
    void next() => !progress.story
        ? openPdf(2)
        : !progress.physics
        ? openPdf(3)
        : !progress.quizPassed
        ? openQuiz()
        : openLab();

    final sources = content?.sources ?? const <String>[];
    final continueLabel = progress.mission
        ? l10n.g4ReadAgain
        : l10n.g4ContinueStop(
            !progress.story
                ? 1
                : !progress.physics
                ? 2
                : 3,
          );

    return Scaffold(
      backgroundColor: p.background,
      appBar: GuideTopBar(
        title: g.issue == null
            ? l10n.dailyGuidesTitle
            : l10n.g4IssueN(g.issue!),
        subtitle: [
          guideDate(g, pattern: 'EEE d MMM y'),
          ?t('cover.read_time'),
        ].join(' · '),
      ),
      body: LearnListView(
        children: [
          // Hero
          Container(
            height: 330,
            decoration: ShapeDecoration(
              color: Color.alphaBlend(
                toneText(context, topicTone(g.theme)).withValues(alpha: 0.08),
                p.surfaceRaised,
              ),
              shape: learnShape(learnRadiusXl),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Semantics(
                    image: true,
                    label:
                        t('cover.image_caption') ??
                        g.photo?.caption[lang] ??
                        g.title[lang],
                    child: ExcludeSemantics(
                      child: GuidePolaroid(
                        guide: g,
                        width: 176,
                        angle: 4,
                        caption:
                            t('cover.image_caption') ?? g.photo?.caption[lang],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (t('cover.news_date') case final d?)
                        GuideChip(
                          d.toUpperCase(),
                          tone: LearnTone.error,
                          fill: p.surface,
                        ),
                      if (t('cover.place') case final place?)
                        GuideChip(
                          place.toUpperCase(),
                          fill: p.tooltipBg,
                          color: p.tooltipText,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GuideChip(
                g.topic[lang] ?? topicName(g.theme),
                tone: topicTone(g.theme),
              ),
              if (t('cover.subject') case final s?)
                GuideChip(s, tone: LearnTone.warning),
              if (t('cover.level') case final l?) GuideChip(l),
            ],
          ),
          const SizedBox(height: 12),
          Text(g.title[lang]!, style: context.text.headlineSmall),
          if (t('cover.subtitle') case final sub?) ...[
            const SizedBox(height: 8),
            Text(
              sub,
              style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          LearnSegmented(
            labels: [l10n.g4LangEn, l10n.g4LangId],
            selected: lang == 'id' ? 1 : 0,
            onSelected: (i) => ref
                .read(guideProgressProvider.notifier)
                .setGuideLang(i == 1 ? 'id' : 'en'),
          ),
          if (!g.hasLang(want)) ...[
            const SizedBox(height: 8),
            Text(
              l10n.g4LangMissing,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          LearnCard(
            onTap: openPdf,
            semanticLabel: l10n.g4ReadFullGuide,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LearnThumbnail(
                      url: g.asset(g.cover[lang]!).toString(),
                      fallbackAsset: LearnArt.coverIntro,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.g4ReadFullGuide,
                        style: context.text.titleSmall,
                      ),
                      Text(
                        l10n.g4PdfMeta(
                          g.pages,
                          lang == 'id' ? l10n.g4LangId : l10n.g4LangEn,
                        ),
                        style: context.text.labelMedium?.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textSecondary),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: LearnSectionHeader(title: l10n.g4QuestMap)),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  l10n.g4XpOf(progress.xp, g.xp.total),
                  style: context.text.labelLarge?.copyWith(
                    color: p.primaryText,
                  ),
                ),
              ),
            ],
          ),
          _Stop(
            n: 1,
            page: 2,
            xp: g.xp.story,
            title: l10n.g4StopStory,
            desc: t('quest.1.desc'),
            done: progress.story,
            current: !progress.story,
            actionLabel: l10n.g4ReadPage(2),
            onAction: () => openPdf(2),
          ),
          _Stop(
            n: 2,
            page: 3,
            xp: g.xp.physics,
            title: l10n.g4StopPhysics,
            desc: t('quest.2.desc'),
            done: progress.physics,
            current: progress.story && !progress.physics,
            actionLabel: l10n.g4ReadPage(3),
            onAction: () => openPdf(3),
          ),
          _Stop(
            n: 3,
            page: g.pages,
            xp: g.xp.quiz + g.xp.lab,
            title: l10n.g4StopMission,
            desc: t('quest.3.desc'),
            done: progress.mission,
            current: progress.physics && !progress.mission,
            locked: !progress.physics,
            lockedText: l10n.g4FinishStop2,
            last: true,
            extra: progress.physics
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MissionButton(
                        label: progress.quizPassed
                            ? l10n.g4QuizPassed
                            : l10n.g4QuickQuiz,
                        done: progress.quizPassed,
                        onTap: openQuiz,
                      ),
                      _MissionButton(
                        label: progress.labApproved
                            ? l10n.g4LabApproved
                            : l10n.g4MiniLab,
                        done: progress.labApproved,
                        onTap: openLab,
                      ),
                    ],
                  )
                : null,
          ),
          if (t('cover.fun_fact') case final fact?) ...[
            const SizedBox(height: 16),
            LearnCard(
              color: p.surfaceRaised,
              child: Row(
                children: [
                  const SizedBox(
                    width: 56,
                    child: LearnIllustration(LearnArt.mascot, height: 52),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.g4DidYouKnow,
                          style: context.text.labelMedium?.copyWith(
                            color: p.secondaryText,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(fact, style: context.text.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            LearnCard(
              onTap: () => _showSources(context, content!, g, lang),
              semanticLabel: l10n.g4SourcesCount(sources.length),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: p.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.g4SourcesCount(sources.length),
                          style: context.text.titleSmall,
                        ),
                        if (t('label.sources') != null ||
                            g.photo?.credit != null)
                          Text(
                            [
                              ...{
                                for (final s
                                    in (content!.data['_sources'] as List? ??
                                        const []))
                                  if (s is Map && s['publisher'] is String)
                                    s['publisher'] as String,
                              },
                              ?g.photo?.credit,
                            ].join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.textSecondary),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: openPdf,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.g4Pdf),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 52),
                    shape: const StadiumBorder(),
                    foregroundColor: p.textPrimary,
                    side: BorderSide(color: p.borderMedium),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: progress.mission ? openPdf : next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            continueLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showSources(
  BuildContext context,
  GuideContent content,
  DailyGuide g,
  String lang,
) {
  final links = content.sourceLinks;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.elio.surface,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            content.text('label.sources') ?? l10n.g4Sources,
            style: sheet.text.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final (i, s) in content.sources.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s, style: sheet.text.bodyMedium),
              subtitle: links[i + 1] == null
                  ? null
                  : SelectableText(
                      links[i + 1].toString(),
                      style: sheet.text.labelMedium?.copyWith(
                        color: sheet.elio.tertiaryText,
                      ),
                    ),
              // ponytail: copy instead of open; the app has no URL-launcher plugin yet.
              trailing: links[i + 1] == null
                  ? null
                  : IconButton(
                      tooltip: l10n.g4CopyLink,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: links[i + 1].toString()),
                      ),
                    ),
            ),
          if (content.text('credit.images') ?? g.photo?.credit
              case final credit?) ...[
            const SizedBox(height: 8),
            Text(l10n.g4PhotoCredit, style: sheet.text.titleSmall),
            const SizedBox(height: 4),
            Text(
              [credit, ?g.photo?.license].join(' · '),
              style: sheet.text.bodySmall?.copyWith(
                color: sheet.elio.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MissionButton extends StatelessWidget {
  const _MissionButton({
    required this.label,
    required this.done,
    required this.onTap,
  });
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(
      done ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
      size: 18,
    ),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 44),
      shape: const StadiumBorder(),
      foregroundColor: context.elio.primaryText,
      side: BorderSide(color: context.elio.primaryText.withValues(alpha: 0.5)),
    ),
  );
}

/// Quest stop 537:2454 with its timeline marker.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.n,
    required this.page,
    required this.xp,
    required this.title,
    required this.desc,
    required this.done,
    required this.current,
    this.locked = false,
    this.lockedText,
    this.actionLabel,
    this.onAction,
    this.extra,
    this.last = false,
  });

  final int n, page, xp;
  final String title;
  final String? desc, lockedText, actionLabel;
  final bool done, current, locked, last;
  final VoidCallback? onAction;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final marker = done
        ? Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 20, color: p.onPrimary),
          )
        : locked
        ? Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: p.textSecondary,
            ),
          )
        : Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.primaryText, width: 2),
            ),
            child: Text(
              '$n',
              style: context.text.titleSmall?.copyWith(color: p.primaryText),
            ),
          );
    return Semantics(
      container: true,
      label:
          '${l10n.g4StopN(n)}: $title, ${done
              ? l10n.g4StopDone
              : locked
              ? l10n.g4StopLocked
              : l10n.g4StopOpen}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  ExcludeSemantics(child: marker),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: done ? p.primary : p.borderMedium,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LearnCard(
                  color: locked ? p.surfaceRaised : null,
                  borderColor: current ? p.primary : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.g4StopPage(n, page),
                              style: context.text.labelMedium?.copyWith(
                                color: locked ? p.textSecondary : p.primaryText,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GuideChip(
                            done ? l10n.g4XpDone(xp) : l10n.g4PlusXp(xp),
                            tone: done ? LearnTone.success : LearnTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: context.text.titleMedium?.copyWith(
                          color: locked ? p.textSecondary : null,
                        ),
                      ),
                      if (desc != null)
                        Text(
                          desc!,
                          style: context.text.bodySmall?.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      if (locked && lockedText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          lockedText!,
                          style: context.text.labelMedium?.copyWith(
                            color: p.textTertiary,
                          ),
                        ),
                      ],
                      if (current && extra == null && actionLabel != null)
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 40),
                            foregroundColor: p.primaryText,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(actionLabel!),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                        ),
                      if (extra != null) ...[
                        const SizedBox(height: 10),
                        extra!,
                      ],
                    ],
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
