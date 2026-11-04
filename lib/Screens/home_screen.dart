// Home H1 v4, gamified (decision 0144). Figma file J2jSbARJSyJCStNFeWkWDj,
// page "H1 v2 Home (reference style)" 321:2358:
//   333:4383 Home   334:4584 Guest / no scans   334:5265 Loading
//   334:5353 / 334:5681 / 334:5993 the same in dark (ElioTokens.dark via the theme)
//   329:3722 Search results   329:3836 Calendar month
// Every number comes from the local scan records (HomeStats) or learning
// progress (medals). The header pill and bell live in the shell's top bar.
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/guide_lesson.dart';
import '../models/home_stats.dart';
import '../models/learning_progress.dart';
import '../models/physics_module.dart';
import '../models/quiz_set.dart';
import '../models/video_lesson.dart';
import '../models/waste_category.dart';
import '../providers/app_notification_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/elearning_content_service.dart';
import '../services/scan_record_store.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/home_notifications_sheet.dart';
import 'home/home_activity.dart';
import 'home/home_parts.dart';
import 'home/home_search.dart';
import 'login_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'tabs/elearning/simulations/simulations_page.dart'
    show openSimulation;

const _controlTab = 3;
const _historyTab = 4;
const _maxContentWidth = 720.0;
const _trackedLearningModuleIds = ['organic', 'inorganic', 'hazardous'];

/// Rotated by day. The first one is the Figma sample.
const homeFacts = [
  'Plastics under 1,0 g/cm³ float in water. Recycling plants use that to separate them.',
  'Batteries are B3 waste: their metals can leak into soil and water, so they need a special drop-off.',
  'Fruit peels and food scraps can turn into compost in a few weeks.',
  'Rinsing a bottle before recycling keeps the rest of the bin clean.',
  'Aluminium cans can be recycled again and again without losing quality.',
];

ElearningContentService? _contentServiceOverride;
ElearningContentService get _contentService =>
    _contentServiceOverride ??= ElearningContentService();

/// Test seam: Firestore cannot run in widget tests.
@visibleForTesting
set homeContentServiceForTest(ElearningContentService? service) =>
    _contentServiceOverride = service;

/// Test seam for a fixed "now".
@visibleForTesting
DateTime Function() homeClock = DateTime.now;

String homeDisplayName(User? user) {
  final name = user?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) return email.split('@').first;
  return 'Guest';
}

/// Trophy pill and bell for the Home top bar.
class HomeHeaderActions extends ConsumerWidget {
  const HomeHeaderActions({
    super.key,
    required this.onOpenLearning,
    this.store,
  });

  final VoidCallback onOpenLearning;
  final ScanRecordStore? store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final s = store ?? ScanRecordStore.instance;
    final unread = ref.watch(unreadNotificationCountProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListenableBuilder(
          listenable: s,
          builder: (context, _) => Semantics(
            label: '${s.totalTrophies} trophies',
            container: true,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: p.surface,
                shape: homeShape(999, p.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: p.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.totalTrophies}',
                      style: ElioTokens.button.copyWith(
                        fontSize: 16,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Open notifications',
          style: IconButton.styleFrom(minimumSize: const Size.square(48)),
          onPressed: () => showNotificationsSheet(
            context: context,
            onOpenLearning: onOpenLearning,
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 9 ? '9+' : '$unread'),
            backgroundColor: p.error,
            textColor: p.onError,
            child: Icon(Icons.notifications_none_rounded, color: p.textPrimary),
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.onOpenLearning,
    this.store,
  });

  final FirebaseAuth auth;
  final VoidCallback onOpenLearning;
  final ScanRecordStore? store;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScanRecordStore _store = widget.store ?? ScanRecordStore.instance;
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'home search');
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _debounce;

  // Cached learning content; null until the stream first delivers.
  List<VideoLesson>? _videos;
  List<GuideLesson>? _guides;
  List<QuizSet> _quizSets = const [];

  String _query = '';
  SearchScope _scope = SearchScope.all;
  bool _expanded = false;

  bool _monthMode = false;
  DateTime? _selectedDay;
  DateTime? _shownMonth;

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
    void listen<T>(Stream<T> stream, void Function(T) onData) => _subs.add(
      stream.listen(
        (v) => mounted ? setState(() => onData(v)) : null,
        onError: (Object e) => debugPrint('[Home] content stream: $e'),
      ),
    );
    listen<List<VideoLesson>>(
      _contentService.watchVideoLessons(),
      (v) => _videos = v,
    );
    listen<List<GuideLesson>>(
      _contentService.watchGuideLessons(),
      (v) => _guides = v,
    );
    listen<List<QuizSet>>(
      _contentService.watchQuizSets(),
      (v) => _quizSets = v,
    );
    _search.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final text = _search.text;
    if (text.trim().isEmpty) {
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => (_query = text, _expanded = false));
    });
    setState(() {}); // field border and clear button follow the text at once
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _goTab(int index) =>
      ref.read(navigationIndexProvider.notifier).state = index;

  void _resume(LearningResumeType type, String id, String? moduleId) {
    ref.read(learningResumeIntentProvider.notifier).state =
        LearningResumeIntent(type: type, id: id, moduleId: moduleId);
    widget.onOpenLearning();
  }

  List<SearchItem> _results(HomeStats stats, LearningProgress? progress) {
    final q = _query;
    if (q.trim().isEmpty) return const [];
    bool m(String s) => searchMatches(s, q);
    return [
      for (final v in _videos ?? const <VideoLesson>[])
        if (m(v.title))
          SearchItem(
            scope: SearchScope.lessons,
            title: v.title,
            subtitle: [
              'Video',
              v.moduleLabel,
              v.durationLabel,
            ].where((s) => s.isNotEmpty).join(' · '),
            icon: Icons.play_circle_outline_rounded,
            onTap: () => _resume(LearningResumeType.video, v.id, v.moduleId),
          ),
      for (final g in _guides ?? const <GuideLesson>[])
        if (m(g.title))
          SearchItem(
            scope: SearchScope.lessons,
            title: g.title,
            subtitle: [
              'Guide',
              g.moduleTitle,
            ].where((s) => s.isNotEmpty).join(' · '),
            icon: Icons.description_outlined,
            onTap: () => _resume(LearningResumeType.guide, g.id, g.moduleId),
          ),
      for (final s in physicsModules)
        if (m(s.title) || m(s.description))
          SearchItem(
            scope: SearchScope.simulasi,
            title: s.title,
            subtitle: s.tag,
            icon: s.icon,
            onTap: () => openSimulation(context, ref, s),
          ),
      for (final s in _quizSets)
        if (m(s.title))
          SearchItem(
            scope: SearchScope.quiz,
            title: s.title,
            subtitle: [
              '${s.questionCount} questions',
              if (progress?.quizScores[s.moduleId] case final best?)
                'best $best%',
            ].join(' · '),
            icon: Icons.help_outline_rounded,
            onTap: () => _resume(LearningResumeType.quiz, s.id, s.moduleId),
          ),
      for (final r in [
        ...stats.records,
      ]..sort((a, b) => b.time.compareTo(a.time)))
        if (m(r.itemName))
          SearchItem(
            scope: SearchScope.scans,
            title: r.itemName,
            subtitle:
                '${shortDate(r.time.toLocal())} · +${r.trophies} trophies',
            bin: HomeBin.of(r.category),
            onTap: () => _goTab(_historyTab),
          ),
    ];
  }

  /// The achievement rules of the old Home (decision 0140), unchanged.
  List<_Medal> _medals(LearningProgress? progress) {
    int capped(int n, int total) => total <= 0 ? 0 : math.min(n, total);
    final videosTotal =
        _videos?.length ?? LearningProgress.fallbackTotalVideoLessons;
    final guidesTotal =
        _guides?.length ?? LearningProgress.fallbackTotalGuideLessons;
    final completed = progress == null
        ? 0
        : capped(progress.completedVideoIds.length, videosTotal) +
              capped(progress.completedGuideIds.length, guidesTotal) +
              capped(
                progress.completedQuizModules.length,
                LearningProgress.fallbackTotalQuizModules,
              );
    final active = [
      ...?progress?.categories.entries.where(
        (e) =>
            _trackedLearningModuleIds.contains(e.key) &&
            e.value.progressPercentage > 0,
      ),
    ];
    String text(MapEntry<String, CategoryProgress> e) {
      final title = wasteCategories
          .where((c) => c.id == e.key)
          .map((c) => c.title)
          .firstOrNull;
      return '${e.key} ${title ?? e.key}'.toLowerCase();
    }

    final reflections = active.where(
      (e) => text(e).contains('reflection') || text(e).contains('empathy'),
    );
    return [
      _Medal(
        'Environmental Explorer',
        'Complete at least 3 learning items',
        '3 learning items',
        completed >= 3,
      ),
      _Medal(
        'Robotics Beginner',
        'Start the Introduction to ELIO module',
        'Start Intro to ELIO',
        active.any(
          (e) => ['elio', 'robot', 'introduction'].any(text(e).contains),
        ),
      ),
      _Medal(
        'Sustainability Advocate',
        'Complete all environmental empathy reflections',
        'All reflections',
        reflections.isNotEmpty &&
            reflections.every((e) => e.value.lessonViewed),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? widget.auth.currentUser;
    final isGuest = user?.isAnonymous ?? true;
    final progress = ref.watch(learningProgressProvider).valueOrNull;

    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = authPalette(context);
          return Material(
            color: p.background,
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final loaded = _store.isLoaded;
                final stats = HomeStats.from(
                  loaded ? _store.records : const [],
                  homeClock(),
                );
                final results = _results(stats, progress);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HomeSearchField(
                              controller: _search,
                              focusNode: _searchFocus,
                              scope: _scope,
                              onScope: (s) => setState(() => _scope = s),
                              resultCount: _search.text.isEmpty
                                  ? null
                                  : results.length,
                            ),
                            const SizedBox(height: 16),
                            if (_query.trim().isNotEmpty)
                              HomeSearchResults(
                                query: _query,
                                items: results,
                                scope: _scope,
                                onScope: (s) => setState(() => _scope = s),
                                expanded: _expanded,
                                onExpand: () =>
                                    setState(() => _expanded = true),
                              )
                            else if (!loaded)
                              const _LoadingSkeleton()
                            else
                              ..._sections(
                                context,
                                p,
                                stats,
                                isGuest,
                                _medals(progress),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    ElioPalette p,
    HomeStats stats,
    bool isGuest,
    List<_Medal> medals,
  ) {
    const gap = SizedBox(height: 16);
    final day = DateTime.utc(
      stats.today.year,
      stats.today.month,
      stats.today.day,
    ).difference(DateTime.utc(stats.today.year)).inDays;
    return [
      if (isGuest) ...[
        _GuestBanner(
          onSignIn: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
          ),
        ),
        gap,
      ],
      _Hero(stats: stats),
      gap,
      _StatsRow(stats: stats),
      gap,
      _Quests(stats: stats),
      gap,
      _activityCard(p, stats),
      if (_monthMode && _selectedDay != null) ...[
        gap,
        DayScans(
          stats: stats,
          day: _selectedDay!,
          onOpenHistory: () => _goTab(_historyTab),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap any square in the Year view to open that day here.',
          style: homeSmall(p),
        ),
      ],
      gap,
      _BinBuddies(stats: stats),
      gap,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _ThisWeek(stats: stats)),
            const SizedBox(width: 12),
            Expanded(child: _QuizAccuracy(stats: stats)),
          ],
        ),
      ),
      gap,
      _Medals(medals: medals),
      gap,
      _DidYouKnow(fact: homeFacts[day % homeFacts.length]),
    ];
  }

  Widget _activityCard(ElioPalette p, HomeStats stats) {
    final month = _shownMonth ?? DateTime(stats.today.year, stats.today.month);
    final inGrid = stats.scansInGrid;
    final inMonth = stats.scansInMonth(month.year, month.month);
    final subtitle = _monthMode
        ? '$inMonth ${inMonth == 1 ? 'scan' : 'scans'} in ${monthNames[month.month - 1]}'
        : inGrid == 0
        ? 'No scans in the last 17 weeks'
        : '$inGrid ${inGrid == 1 ? 'scan' : 'scans'} in the last 17 weeks';
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(context.l10n.homeScanActivity, style: homeTitle(p)),
                    ),
                    Text(subtitle, style: homeSmall(p)),
                  ],
                ),
              ),
              _Segmented(
                labels: const ['Year', 'Month'],
                selected: _monthMode ? 1 : 0,
                onSelect: (i) => setState(() => _monthMode = i == 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_monthMode)
            MonthView(
              stats: stats,
              month: month,
              selected: _selectedDay,
              onMonth: (m) => setState(() => _shownMonth = m),
              onSelect: (d) => setState(() => _selectedDay = d),
            )
          else ...[
            YearGrid(
              stats: stats,
              onSelectDay: (d) => setState(() {
                _monthMode = true;
                _selectedDay = d;
                _shownMonth = DateTime(d.year, d.month);
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 12,
              children: [
                if (stats.isEmpty)
                  Text(context.l10n.homeFirstScanToday, style: homeSmall(p))
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      homeArt('streak_flame', width: 16, height: 19),
                      const SizedBox(width: 6),
                      Text(
                        'Streak ${stats.currentStreak} ${stats.currentStreak == 1 ? 'day' : 'days'} · longest ${stats.longestStreak}',
                        style: homeSmall(p),
                      ),
                    ],
                  ),
                const ActivityLegend(),
              ],
            ),
            if (stats.isEmpty) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _goTab(_controlTab),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: homeShape(999),
                ),
                child: Text(context.l10n.homeScanItem),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Medal {
  const _Medal(this.name, this.description, this.hint, this.unlocked);
  final String name, description, hint;
  final bool unlocked;
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: homeShape(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  onTap: () => onSelect(i),
                  customBorder: homeShape(999),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 42,
                      minWidth: 48,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: i == selected
                        ? ShapeDecoration(
                            color: p.field,
                            shape: homeShape(999, p.borderMedium),
                          )
                        : null,
                    child: Text(
                      labels[i],
                      style: ElioTokens.bodySmall.copyWith(
                        color: i == selected ? p.textPrimary : p.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
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

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: p.tertiaryText.withValues(alpha: 0.08),
        shape: homeShape(homeRadiusL, p.tertiaryText.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Guest progress is stored on this device. Sign in to sync it across devices.',
                style: ElioTokens.bodySmall.copyWith(
                  color: p.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onSignIn,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: p.field,
                foregroundColor: p.textPrimary,
                side: BorderSide(color: p.borderSubtle),
                shape: homeShape(999),
              ),
              child: Text(context.l10n.signIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final level = stats.level;
    final toNext = stats.trophiesToNext;
    final ink = p.onPrimary;
    final label = ElioTokens.bodySmall.copyWith(
      color: ink,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      container: true,
      label:
          'Level ${level.levelNumber}, ${level.title}. ${stats.totalTrophies} trophies'
          '${toNext == null ? ', top level' : ', $toNext to level ${level.levelNumber + 1}'}',
      excludeSemantics: true,
      child: HomeCard(
        color: p.primary,
        padding: 18,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: p.field,
                      shape: homeShape(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 16,
                            color: p.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Level ${level.levelNumber}',
                            style: ElioTokens.bodySmall.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.title,
                    style: homeNumber(p, 28).copyWith(color: ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats.totalTrophies == 0
                        ? 'Plant your first trophy: scan an item.'
                        : 'Your tree grows with every trophy.',
                    style: ElioTokens.body.copyWith(color: ink, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  HomeBar(
                    value: stats.levelProgress,
                    color: ink,
                    track: p.isDark ? ink.withValues(alpha: 0.25) : p.field,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        Text(context.l10n.homeTrophies(stats.totalTrophies), style: label),
                        Text(
                          toNext == null
                              ? 'Top level'
                              : '$toNext to Lv${level.levelNumber + 1}',
                          style: label,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Lv1-2 sprout, Lv3-5 tree until more art exists.
            homeArt(
              level.levelNumber >= 3 ? 'tree_lv3' : 'sprout_lv1',
              width: 96,
              height: 99,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final acc = stats.quizAccuracy;
    final streak = stats.currentStreak;
    final tiles = [
      (
        homeArt('scan_line_art', width: 28, height: 28),
        '${stats.totalScans}',
        'Scans',
      ),
      (
        Icon(Icons.help_outline_rounded, size: 28, color: p.tertiaryText),
        acc == null ? '—' : '$acc%',
        'Quiz accuracy',
      ),
      (homeArt('streak_flame', width: 26, height: 30), '$streak', 'Day streak'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label:
                  '${tiles[i].$3}: ${tiles[i].$2 == '—' ? 'no data' : tiles[i].$2}',
              container: true,
              excludeSemantics: true,
              child: HomeCard(
                padding: 12,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final text = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tiles[i].$2, style: homeNumber(p, 22)),
                        Text(tiles[i].$3, style: homeSmall(p)),
                      ],
                    );
                    // Narrow phones and large text: icon above the number.
                    if (c.maxWidth <
                        100 * MediaQuery.textScalerOf(context).scale(1)) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tiles[i].$1,
                          const SizedBox(height: 4),
                          text,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        tiles[i].$1,
                        const SizedBox(width: 8),
                        Expanded(child: text),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Quests extends StatelessWidget {
  const _Quests({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final quests = stats.quests;
    final done = quests.where((q) => q.done).length;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              homeArt('quest_target', width: 40, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(context.l10n.homeDailyQuests, style: homeTitle(p)),
                    ),
                    Text(
                      '$done of 3 done · resets at midnight',
                      style: homeSmall(p),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: '$done of 3 quests done',
                container: true,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: done / 3,
                          strokeWidth: 4,
                          color: p.primary,
                          backgroundColor: p.borderSubtle,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '$done/3',
                        style: homeSmall(p, color: p.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          for (final q in quests) ...[
            const SizedBox(height: 10),
            Semantics(
              label:
                  '${q.title}, ${q.done ? 'done' : '${(q.progress * 100).round()} percent'}. Reward ${q.reward} trophies',
              container: true,
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: q.done
                      ? p.primary.withValues(alpha: 0.12)
                      : p.surfaceRaised.withValues(alpha: p.isDark ? 0.4 : 0.6),
                  shape: homeShape(homeRadiusM),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      q.done
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: p.primary,
                              size: 26,
                            )
                          : Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: p.textSecondary,
                              size: 26,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.title,
                              style: ElioTokens.body.copyWith(
                                color: q.done ? p.textSecondary : p.textPrimary,
                                height: 1.35,
                              ),
                            ),
                            if (!q.done) ...[
                              const SizedBox(height: 6),
                              HomeBar(
                                value: q.progress,
                                color: p.primary,
                                track: p.borderSubtle,
                                height: 6,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      TrophyAmount('+${q.reward}', chip: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BinBuddies extends StatelessWidget {
  const _BinBuddies({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final total = stats.totalScans;
    final top = stats.topBin;
    String pct(int n) => total == 0 ? '0%' : '${(n * 100 / total).round()}%';
    const art = {
      HomeBin.organik: 'bin_organik',
      HomeBin.anorganik: 'bin_anorganik',
      HomeBin.b3: 'bin_b3',
    };
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(context.l10n.homeBinBuddies, style: homeTitle(p)),
          ),
          Text(
            total == 0
                ? 'Your bins are hungry: scan an item'
                : '$total ${total == 1 ? 'scan' : 'scans'} fed to your 3 bins',
            style: homeSmall(p),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final b in HomeBin.values) ...[
                if (b != HomeBin.organik) const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label:
                        '${b.label} ${stats.binCounts[b]} scans, ${pct(stats.binCounts[b]!)}${b == top ? ', top bin' : ''}',
                    container: true,
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 84,
                          height: 76,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              homeArt(art[b]!, width: 64, height: 76),
                              if (b == top)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: p.secondaryText,
                                      shape: homeShape(999),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      child: Text(
                                        'Top',
                                        style: ElioTokens.label.copyWith(
                                          color: p.field,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${stats.binCounts[b]}',
                                style: homeNumber(p, 22),
                              ),
                              TextSpan(
                                text: ' ${pct(stats.binCounts[b]!)}',
                                style: homeSmall(p),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          b.label,
                          style: ElioTokens.body.copyWith(
                            color: p.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        HomeBar(
                          value: total == 0 ? 0 : stats.binCounts[b]! / total,
                          color: binColor(p, b),
                          track: p.borderSubtle,
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.residuCount == 0
                ? 'Residu scans count toward Anorganik.'
                : 'Anorganik includes ${stats.residuCount} residu ${stats.residuCount == 1 ? 'scan' : 'scans'} (the robot sorts residu there).',
            style: homeSmall(p),
          ),
        ],
      ),
    );
  }
}

class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final week = stats.weekBins;
    final perDay = [for (final d in week) d.values.fold(0, (a, b) => a + b)];
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return HomeCard(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.homeThisWeek, style: homeSmall(p)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${stats.weekTotal}', style: homeNumber(p, 30)),
                TextSpan(text: ' scans', style: homeSmall(p)),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Semantics(
            label:
                '${stats.weekTotal} scans this week. '
                '${[for (var i = 0; i < 7; i++) '${weekdayNames[i]} ${perDay[i]}'].join(', ')}',
            container: true,
            excludeSemantics: true,
            child: Column(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: WeekBarsPainter(week, {
                    for (final b in HomeBin.values) b: binColor(p, b),
                  }),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: homeSmall(p).copyWith(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizAccuracy extends StatelessWidget {
  const _QuizAccuracy({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final acc = stats.quizAccuracy;
    final delta = stats.quizDelta;
    final points = stats.quizPercents;
    return Semantics(
      label: acc == null
          ? 'Quiz accuracy: no data'
          : 'Quiz accuracy $acc percent over the last ${points.length} scans with questions'
                '${delta == null ? '' : ', ${delta >= 0 ? 'up' : 'down'} ${delta.abs()} points'}',
      container: true,
      excludeSemantics: true,
      child: HomeCard(
        padding: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.homeQuizAccuracy, style: homeSmall(p)),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: [
                Text(acc == null ? '—' : '$acc%', style: homeNumber(p, 30)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (delta ?? 0) < 0
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 18,
                        color: (delta ?? 0) < 0 ? p.errorText : p.primaryText,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        acc == null
                            ? 'no data'
                            : delta == null
                            ? '±0'
                            : '${delta >= 0 ? '+' : ''}$delta',
                        style: homeSmall(
                          p,
                          color: (delta ?? 0) < 0 ? p.errorText : p.primaryText,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 8),
            CustomPaint(
              size: const Size(double.infinity, 64),
              painter: SparklinePainter(
                points,
                p.primaryText,
                p.primary.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Medals extends StatelessWidget {
  const _Medals({required this.medals});
  final List<_Medal> medals;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final unlocked = medals.where((m) => m.unlocked).length;
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(context.l10n.homeMedals, style: homeTitle(p)),
                ),
              ),
              Text(
                '$unlocked of ${medals.length}',
                style: homeSmall(
                  p,
                  color: p.primaryText,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              // "Environmental" must fit on one line; else one medal per row.
              final wide =
                  c.maxWidth / 3 >=
                  100 * MediaQuery.textScalerOf(context).scale(1);
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < medals.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8, height: 8),
                    wide
                        ? Expanded(child: _medal(p, medals[i], wide))
                        : _medal(p, medals[i], wide),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _medal(ElioPalette p, _Medal m, bool wide) {
    final art = homeArt(
      m.unlocked ? 'medal_gold' : 'medal_locked',
      width: 44,
      height: 52,
    );
    final align = wide ? TextAlign.center : TextAlign.start;
    final text = [
      Text(
        m.name,
        textAlign: align,
        style: ElioTokens.bodySmall.copyWith(
          fontSize: 13,
          color: p.textPrimary,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        m.unlocked ? 'Unlocked' : m.hint,
        textAlign: align,
        style: homeSmall(
          p,
          color: m.unlocked ? p.secondaryText : p.textSecondary,
        ).copyWith(fontSize: 12),
      ),
    ];
    return Semantics(
      container: true,
      label:
          '${m.name}, ${m.unlocked ? 'unlocked' : 'locked'}. ${m.description}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: m.unlocked
              ? p.secondaryText.withValues(alpha: 0.06)
              : p.surfaceRaised.withValues(alpha: p.isDark ? 0.4 : 0.6),
          shape: homeShape(homeRadiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: wide
              ? Column(children: [art, const SizedBox(height: 8), ...text])
              : Row(
                  children: [
                    art,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: text,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DidYouKnow extends StatelessWidget {
  const _DidYouKnow({required this.fact});
  final String fact;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Semantics(
      container: true,
      child: HomeCard(
        color: p.secondaryText.withValues(alpha: 0.07),
        child: Row(
          children: [
            homeArt('bulb_buddy', width: 48, height: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.homeDidYouKnow, style: homeOverline(p.secondaryText)),
                  const SizedBox(height: 4),
                  Text(
                    fact,
                    style: ElioTokens.body.copyWith(
                      color: p.textPrimary,
                      height: 1.45,
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

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Static under reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    Widget block(double h) => Container(
      height: h,
      decoration: ShapeDecoration(
        color: p.borderSubtle,
        shape: homeShape(homeRadiusL),
      ),
    );
    return Semantics(
      label: 'Loading your progress',
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Growing your tree…',
            textAlign: TextAlign.center,
            style: homeSmall(p),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                block(150),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: block(58)),
                    const SizedBox(width: 10),
                    Expanded(child: block(58)),
                    const SizedBox(width: 10),
                    Expanded(child: block(58)),
                  ],
                ),
                const SizedBox(height: 16),
                block(190),
                const SizedBox(height: 16),
                block(150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
