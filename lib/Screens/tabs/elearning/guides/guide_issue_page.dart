import 'package:flutter/material.dart';
import '../../../../widgets/tour/app_tour.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../providers/daily_guide_provider.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/guide_progress.dart';
import '../../../../services/elio_feedback.dart';
import '../../../../theme/elio_motion.dart';
import '../../../../widgets/learn/learn_l3.dart';
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

    // Rule 7 entrance, 40 ms apart; the quest map comes after the hero.
    Widget rise(int i, Widget child) => ElioPopIn(index: i, child: child);
    final tone = topicTone(g.theme);

    return TourTip(
      id: 'guide_issue',
      label: () => l10n.tourLblGuide,
      steps: (k) => [
        TourStep(k[0], l10n.tipGuide1T, l10n.tipGuide1B),
        TourStep(k[1], l10n.tipGuide2T, l10n.tipGuide2B),
        TourStep(k[2], l10n.tipGuide3T, l10n.tipGuide3B),
        TourStep(k[3], l10n.tipGuide4T, l10n.tipGuide4B),
      ],
      builder: (context, k) => Scaffold(
        backgroundColor: p.background,
        appBar: GuideTopBar(
          title: g.issue == null
              ? l10n.dailyGuidesTitle
              : l10n.g4IssueN(g.issue!),
          subtitle: [
            guideDate(g, pattern: 'EEE d MMM y'),
            ?t('cover.read_time'),
          ].join(' · '),
          action: L3Sticker(
            label: l10n.g4XpOf(progress.xp, g.xp.total),
            color: p.secondaryText,
            angle: 0,
          ),
        ),
        // Card 17 on this page: a stop finished (back from the PDF, quiz or
        // lab) chimes, a finished guide sparkles.
        body: RiseWatcher(
          value: progress.stopsDone,
          onRise: (_, to) => to >= 3
              ? elioFeedback(ElioSfx.sparkle, ElioHaptics.celebrate)
              : elioFeedback(ElioSfx.chime, ElioHaptics.success),
          builder: (context, bump) => LearnListView(
            children: [
              // Hero: the polaroid lands here from the ticket (hero flight),
              // then the news and place stickers pop on.
              Container(
                key: k[0],
                height: 330,
                decoration: ShapeDecoration(
                  color: toneBg(
                    p,
                    tone == LearnTone.neutral ? LearnTone.info : tone,
                  ),
                  shape: const RoundedRectangleBorder(borderRadius: leafL),
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
                          child: GuidePolaroidHero(
                            polaroid: GuidePolaroid(
                              guide: g,
                              width: 176,
                              angle: 4,
                              caption:
                                  t('cover.image_caption') ??
                                  g.photo?.caption[lang],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (t('cover.news_date') case final d?)
                            _Pop(
                              delay: 380,
                              child: L3Sticker(
                                label: d.toUpperCase(),
                                color: p.errorText,
                                angle: -5,
                              ),
                            ),
                          if (t('cover.place') case final place?)
                            _Pop(
                              delay: 460,
                              child: L3Sticker(
                                label: place.toUpperCase(),
                                color: p.tertiaryText,
                                angle: 4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              rise(
                1,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GuideChip(g.topic[lang] ?? topicName(g.theme), tone: tone),
                    if (t('cover.subject') case final s?)
                      GuideChip(s, tone: LearnTone.warning),
                    if (t('cover.level') case final l?) GuideChip(l),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              rise(
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        g.title[lang]!,
                        style: context.text.displaySmall,
                      ),
                    ),
                    const SquiggleDraw(width: 180),
                    if (t('cover.subtitle') case final sub?) ...[
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        style: context.text.bodyMedium?.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              rise(
                3,
                Row(
                  key: k[1],
                  children: [
                    for (final (i, (code, label)) in [
                      ('en', l10n.g4LangEn),
                      ('id', l10n.g4LangId),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      LearnTabPill(
                        label: label,
                        selected: lang == code,
                        onTap: () => ref
                            .read(guideProgressProvider.notifier)
                            .setGuideLang(code),
                      ),
                    ],
                  ],
                ),
              ),
              if (!g.hasLang(want)) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.g4LangMissing,
                  style: context.text.bodySmall?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              rise(
                4,
                _LeafRow(
                  onTap: () => openPdf(),
                  label: l10n.g4ReadFullGuide,
                  leading: SizedBox(
                    width: 44,
                    height: 56,
                    child: Transform.rotate(
                      angle: -0.07,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LearnThumbnail(
                          url: g.asset(g.cover[lang]!).toString(),
                          fallbackAsset: LearnArt.coverIntro,
                          cacheManager: guideImageCache,
                        ),
                      ),
                    ),
                  ),
                  title: l10n.g4ReadFullGuide,
                  subtitle: l10n.g4PdfMeta(
                    g.pages,
                    lang == 'id' ? l10n.g4LangId : l10n.g4LangEn,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              rise(
                5,
                L3SectionTitle(
                  title: l10n.g4QuestMap,
                  squiggle: 130,
                  action: l10n.g4XpOf(progress.xp, g.xp.total),
                ),
              ),
              const SizedBox(height: 14),
              rise(
                6,
                KeyedSubtree(
                  key: k[2],
                  child: _Stop(
                    n: 1,
                    page: 2,
                    xp: g.xp.story,
                    title: l10n.g4StopStory,
                    desc: t('quest.1.desc'),
                    done: progress.story,
                    current: !progress.story,
                    actionLabel: l10n.g4ReadPage(2),
                    onAction: () => openPdf(2),
                    bump: progress.stopsDone == 1 ? bump : 0,
                  ),
                ),
              ),
              rise(
                7,
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
                  bump: progress.stopsDone == 2 ? bump : 0,
                ),
              ),
              rise(
                8,
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
                  bump: progress.stopsDone == 3 ? bump : 0,
                  extra: progress.physics
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MissionButton(
                              label: progress.quizPassed
                                  ? l10n.g4QuizPassed
                                  : l10n.g4QuickQuiz,
                              art: LearnArt.quizPaper,
                              done: progress.quizPassed,
                              onTap: openQuiz,
                            ),
                            _MissionButton(
                              label: progress.labApproved
                                  ? l10n.g4LabApproved
                                  : l10n.g4MiniLab,
                              art: LearnArt.miniLab,
                              done: progress.labApproved,
                              onTap: openLab,
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              if (t('cover.fun_fact') case final fact?) ...[
                const SizedBox(height: 16),
                rise(
                  9,
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: ShapeDecoration(
                      color: toneBg(p, LearnTone.warning),
                      shape: const RoundedRectangleBorder(borderRadius: leafL),
                    ),
                    child: Row(
                      children: [
                        // ELIO talks you through the fun fact (gentle bob, 8 s).
                        ElioIdleLoop(
                          builder: (context, w, child) => Transform.translate(
                            offset: Offset(0, -3 * w),
                            child: child,
                          ),
                          child: Transform.rotate(
                            angle: -0.1,
                            child: const RobotBuddy(
                              mood: RobotMood.talking,
                              height: 60,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.g4DidYouKnow.toUpperCase(),
                                style: context.text.labelSmall?.copyWith(
                                  color: p.secondaryText,
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
                ),
              ],
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 12),
                rise(
                  10,
                  _LeafRow(
                    onTap: () => _showSources(context, content, g, lang),
                    label: l10n.g4SourcesCount(sources.length),
                    leading: Icon(
                      Icons.description_outlined,
                      color: p.textSecondary,
                    ),
                    title: l10n.g4SourcesCount(sources.length),
                    subtitle: [
                      ...{
                        for (final s
                            in (content!.data['_sources'] as List? ?? const []))
                          if (s is Map && s['publisher'] is String)
                            s['publisher'] as String,
                      },
                      ?g.photo?.credit,
                    ].join(', '),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        // The action bar slides up (base, emphasized).
        bottomNavigationBar: ElioPopIn(
          rise: 96,
          scale: 1,
          duration: ElioMotion.base,
          delay: const Duration(milliseconds: 200),
          child: Container(
            key: k[3],
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: l3Shadow,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: L3Button(
                        label: l10n.g4Pdf,
                        secondary: true,
                        chevron: false,
                        height: 52,
                        onPressed: () => openPdf(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: L3Button(
                        label: continueLabel,
                        height: 52,
                        onPressed: progress.mission ? () => openPdf() : next,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pops a sticker on after [delay] ms (spring/bounce, from 0.4).
class _Pop extends StatelessWidget {
  const _Pop({required this.delay, required this.child});
  final int delay;
  final Widget child;
  @override
  Widget build(BuildContext context) => ElioPopIn(
    delay: Duration(milliseconds: delay),
    curve: ElioMotion.bounce,
    scale: 0.4,
    rise: 6,
    child: child,
  );
}

/// A tappable leaf row: leading art, title, subtitle, chevron.
class _LeafRow extends StatelessWidget {
  const _LeafRow({
    required this.onTap,
    required this.label,
    required this.leading,
    required this.title,
    required this.subtitle,
  });
  final VoidCallback onTap;
  final String label, title, subtitle;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    const shape = RoundedRectangleBorder(borderRadius: leafS);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ElioPress(
        child: Material(
          color: p.surface,
          shape: shape.copyWith(side: BorderSide(color: p.borderSubtle)),
          child: InkWell(
            customBorder: shape,
            onTap: () {
              elioFeedback(ElioSfx.pop, ElioHaptics.light);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.labelLarge),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: captionStyle(context),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: p.textPrimary,
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

/// Mission pill (quiz / mini lab): art bubble, label, check when done.
class _MissionButton extends StatelessWidget {
  const _MissionButton({
    required this.label,
    required this.art,
    required this.done,
    required this.onTap,
  });
  final String label, art;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ElioPress(
        pressed: 0.94,
        child: Material(
          color: done ? toneBg(p, LearnTone.success) : p.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: done ? toneBorder(p, LearnTone.success) : p.borderMedium,
              width: 1.5,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              elioFeedback(ElioSfx.pop, ElioHaptics.light);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: p.background,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: LearnIllustration(art),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: context.text.labelLarge?.copyWith(
                      color: done ? p.primaryText : p.textPrimary,
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_rounded, size: 18, color: p.primaryText),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quest stop: marker on a timeline and a leaf card. On open the line draws
/// down and a done marker pops its check; the current marker breathes (8 s).
/// [bump] > 0 replays the pop when this stop has just been finished.
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
    this.bump = 0,
  });

  final int n, page, xp, bump;
  final String title;
  final String? desc, lockedText, actionLabel;
  final bool done, current, locked, last;
  final VoidCallback? onAction;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final Widget marker;
    if (done) {
      marker = Replay(
        trigger: bump,
        duration: ElioMotion.slow,
        curve: ElioMotion.pop,
        builder: (context, v, child) =>
            Transform.scale(scale: 0.4 + 0.6 * v, child: child),
        child: ElioPopIn(
          delay: Duration(milliseconds: 260 + 90 * n),
          curve: ElioMotion.pop,
          scale: 0.3,
          rise: 0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 20, color: p.onPrimary),
          ),
        ),
      );
    } else if (locked) {
      marker = Container(
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
      );
    } else {
      final ring = Container(
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
      marker = !current
          ? ring
          : ElioIdleLoop(
              builder: (context, w, child) => DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.45 * w),
                      blurRadius: 4 + 10 * w,
                      spreadRadius: 4 * w,
                    ),
                  ],
                ),
                child: child,
              ),
              child: ring,
            );
    }
    final cardShape = RoundedRectangleBorder(
      borderRadius: leafS,
      side: BorderSide(
        color: current ? p.primary : p.borderSubtle,
        width: current ? 2 : 1,
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
                      // The path draws down to the next stop (a scale, so
                      // the row's intrinsic height is untouched).
                      child: ElioAfterFirstFrame(
                        builder: (context, ready) =>
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: ready ? 1 : 0),
                              duration: context.reduceMotion
                                  ? Duration.zero
                                  : ElioMotion.expressive,
                              curve: ElioMotion.standard,
                              builder: (context, v, child) => Transform(
                                alignment: Alignment.topCenter,
                                transform: Matrix4.diagonal3Values(1, v, 1),
                                child: child,
                              ),
                              child: Container(
                                width: 3,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: done ? p.primary : p.borderMedium,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    color: locked
                        ? p.surfaceRaised
                        : done
                        ? toneBg(p, LearnTone.success)
                        : p.surface,
                    shape: cardShape,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.g4StopPage(n, page).toUpperCase(),
                              style: context.text.labelSmall?.copyWith(
                                color: locked ? p.textSecondary : p.primaryText,
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
                        style: context.text.titleLarge?.copyWith(
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
                          style: captionStyle(context, p.textTertiary),
                        ),
                      ],
                      if (current && extra == null && actionLabel != null)
                        TextButton(
                          onPressed: () {
                            elioFeedback(ElioSfx.pop, ElioHaptics.light);
                            onAction?.call();
                          },
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
