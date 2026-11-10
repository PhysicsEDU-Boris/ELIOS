// Home H1 v4, gamified (decision 0144). Figma file J2jSbARJSyJCStNFeWkWDj,
// page "H1 v2 Home (reference style)" 321:2358:
//   333:4383 Home   334:4584 Guest / no scans   334:5265 Loading
//   334:5353 / 334:5681 / 334:5993 the same in dark (ElioTokens.dark via the theme)
//   329:3722 Search results   329:3836 Calendar month
// Every number comes from the local scan records (HomeStats) or learning
// progress (medals). ELIOS 3 (L4 Home 629:80734, decision 0197): leaf logo +
// greeting + bell, resume-control card while a robot is connected, level dial
// hero with the trophy sticker, stat pebbles and pop quest cards.
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../providers/robot_provider.dart';
import '../services/elearning_content_service.dart';
import '../services/scan_record_store.dart';
import '../theme/elio_motion.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/elio_celebration.dart';
import '../widgets/home_notifications_sheet.dart';
import '../widgets/splash/elio_leaf.dart' show ElioMark;
import 'home/home_activity.dart';
import 'home/home_parts.dart';
import 'home/home_search.dart';
import 'login_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'tabs/elearning/simulations/simulations_page.dart' show openSimulation;
import '../services/elio_feedback.dart';

const _scanTab = 2;
const _controlTab = 3;
const _historyTab = 4;
const _maxContentWidth = 720.0;
const _trackedLearningModuleIds = ['organic', 'inorganic', 'hazardous'];

/// What to celebrate now, given what was last seen. A null last value is a
/// first run on this phone/account: nothing is celebrated, only recorded.
({bool levelUp, List<int> newMedals}) celebrationsDue({
  required int? lastLevel,
  required int level,
  required Set<int>? lastMedals,
  required Set<int>? medals,
}) => (
  levelUp: lastLevel != null && level > lastLevel,
  newMedals: lastMedals == null || medals == null
      ? const []
      : ([...medals.difference(lastMedals)]..sort()),
);

/// Rotated by day. The first one is the Figma sample.
List<String> get homeFacts => [
  l10n.fact1,
  l10n.fact2,
  l10n.fact3,
  l10n.fact4,
  l10n.fact5,
];

ElearningContentService? _contentServiceOverride;
ElearningContentService get _contentService =>
    _contentServiceOverride ??= ElearningContentService();

/// Test seam: Firestore cannot run in widget tests.
@visibleForTesting
set homeContentServiceForTest(ElearningContentService? service) =>
    _contentServiceOverride = service;

/// Home's entrance (dial sweep, count-up, pop-ins) plays once per app
/// session, not on every tab switch (Figma 13 · 11-13).
bool _homeEntrancePlayed = false;

/// Latched when a HomeScreen is created, so the flag above flipping during
/// the first visit never cuts that visit's entrance short.
bool _playEntrance = true;

@visibleForTesting
void resetHomeEntrance() => _homeEntrancePlayed = false;

/// Test seam for a fixed "now".
@visibleForTesting
DateTime Function() homeClock = DateTime.now;

String homeDisplayName(User? user) {
  final name = user?.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) return email.split('@').first;
  return l10n.homeGuest;
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.name, required this.onOpenLearning});
  final String name;
  final VoidCallback onOpenLearning;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Row(
      children: [
        ElioMark(size: 40, color: p.primaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.homeHello(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ElioTokens.body.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.28,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                l10n.homeReady,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        HomeHeaderActions(onOpenLearning: onOpenLearning),
      ],
    );
  }
}

/// The bell beside the Home greeting (the trophy total sits on the hero).
class HomeHeaderActions extends ConsumerWidget {
  const HomeHeaderActions({super.key, required this.onOpenLearning});

  final VoidCallback onOpenLearning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: l10n.homeOpenNotifications,
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
    );
  }
}

/// "ELIOS robot · Still connected · Continue" (629:81091): only while a robot
/// session is still connected; Continue reopens Control.
class HomeResumeControl extends ConsumerWidget {
  const HomeResumeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(robotStatusProvider).valueOrNull ?? '';
    if (status.trim().toLowerCase() != 'connected') {
      return const SizedBox.shrink();
    }
    final p = authPalette(context);
    // Appears whenever a robot connects, so not session-gated.
    return ElioPopIn(
      rise: -16,
      curve: ElioMotion.soft,
      child: _resume(context, ref, p),
    );
  }

  Widget _resume(BuildContext context, WidgetRef ref, ElioPalette p) {
    void open() {
      elioFeedback(ElioSfx.blip, ElioHaptics.medium); // Figma 13 · 15
      ref.read(navigationIndexProvider.notifier).state = _controlTab;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        label:
            '${l10n.homeRobotOverline}, ${l10n.homeStillConnected}. '
            '${l10n.homeResumeControl}',
        excludeSemantics: true,
        onTap: open,
        child: Material(
          color: p.primary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: _leaf),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: p.isDark ? p.background : p.surface,
                      shape: BoxShape.circle,
                    ),
                    // The robot breathes 1 → 1.04 (2 s, pauses after 8 s).
                    child: ElioIdleLoop(
                      builder: (context, w, child) =>
                          Transform.scale(scale: 1 + 0.04 * w, child: child),
                      child: SvgPicture.asset(
                        'assets/illustrations/scan/elios_robot.svg',
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeRobotOverline.toUpperCase(),
                          style: _overline11(p.onPrimary),
                        ),
                        Text(
                          l10n.homeStillConnected,
                          style: ElioTokens.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.onPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: ShapeDecoration(
                      color: p.isDark ? p.background : p.surface,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.commonContinue,
                          style: ElioTokens.button.copyWith(
                            color: p.primaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: p.primaryText,
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

/// Organic leaf corners (30 on one diagonal, 10 on the other).
const _leaf = BorderRadius.only(
  topLeft: Radius.circular(30),
  topRight: Radius.circular(10),
  bottomRight: Radius.circular(30),
  bottomLeft: Radius.circular(10),
);
const _leafFlip = BorderRadius.only(
  topLeft: Radius.circular(10),
  topRight: Radius.circular(30),
  bottomRight: Radius.circular(10),
  bottomLeft: Radius.circular(30),
);

TextStyle _overline11(Color c) => ElioTokens.label.copyWith(
  fontSize: 11,
  letterSpacing: 1.1,
  height: 1.4,
  color: c,
);

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
    _playEntrance = !_homeEntrancePlayed;
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
              l10n.homeVideo,
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
              l10n.homeGuide,
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
            subtitle: l10n.homeScanSubtitle(
              shortDate(r.time.toLocal()),
              r.trophies,
            ),
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
        l10n.medalExplorer,
        l10n.medalExplorerDesc,
        l10n.medalExplorerHint,
        completed >= 3,
      ),
      _Medal(
        l10n.medalRobotics,
        l10n.medalRoboticsDesc,
        l10n.medalRoboticsHint,
        active.any(
          (e) => ['elio', 'robot', 'introduction'].any(text(e).contains),
        ),
      ),
      _Medal(
        l10n.medalAdvocate,
        l10n.medalAdvocateDesc,
        l10n.medalAdvocateHint,
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8 + MediaQuery.paddingOf(context).top,
                    16,
                    32,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ELIOS 3: the greeting scrolls with Home; no top bar.
                            _HomeGreeting(
                              name: homeDisplayName(user),
                              onOpenLearning: widget.onOpenLearning,
                            ),
                            const SizedBox(height: 16),
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

  String? _celebrationChecked;

  /// Level up / medal unlocked (Figma 13 · 38), compared with what this
  /// account last saw; the first check only records the current state.
  void _scheduleCelebrations(
    int level,
    String levelTitle,
    Set<int>? medalIds,
    List<_Medal> medals,
  ) {
    final uid = (ref.read(currentUserProvider) ?? widget.auth.currentUser)?.uid;
    if (uid == null) return;
    final key = '$uid|$level|${medalIds?.toList()?..sort()}';
    if (key == _celebrationChecked) return;
    _celebrationChecked = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final levelKey = 'elio_seen_level_$uid',
          medalKey = 'elio_seen_medals_$uid';
      final due = celebrationsDue(
        lastLevel: prefs.getInt(levelKey),
        level: level,
        lastMedals: prefs.getStringList(medalKey)?.map(int.parse).toSet(),
        medals: medalIds,
      );
      await prefs.setInt(levelKey, level);
      if (medalIds != null) {
        await prefs.setStringList(medalKey, [for (final m in medalIds) '$m']);
      }
      if (!mounted) return;
      if (due.levelUp) {
        ElioCelebration.show(
          context,
          art: homeArt(level >= 3 ? 'tree_lv3' : 'sprout_lv1'),
          title: l10n.celebrateLevelUp(level),
          subtitle: levelTitle,
        );
      }
      for (final i in due.newMedals) {
        ElioCelebration.show(
          context,
          art: homeArt('medal_gold'),
          title: l10n.celebrateMedal,
          subtitle: medals[i].name,
        );
      }
    });
  }

  List<Widget> _sections(
    BuildContext context,
    ElioPalette p,
    HomeStats stats,
    bool isGuest,
    List<_Medal> medals,
  ) {
    const gap = SizedBox(height: 16);
    final progress = ref.read(learningProgressProvider).valueOrNull;
    _scheduleCelebrations(
      stats.level.levelNumber,
      stats.level.title,
      // Medals are only known once learning progress has loaded.
      progress == null
          ? null
          : {
              for (final (i, m) in medals.indexed)
                if (m.unlocked) i,
            },
      medals,
    );
    if (!_homeEntrancePlayed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _homeEntrancePlayed = true,
      );
    }
    final day = DateTime.utc(
      stats.today.year,
      stats.today.month,
      stats.today.day,
    ).difference(DateTime.utc(stats.today.year)).inDays;
    return [
      const HomeResumeControl(),
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
        Text(l10n.homeTapSquare, style: homeSmall(p)),
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
        ? l10n.scansInMonth(
            l10n.scanCount(inMonth),
            monthNames[month.month - 1],
          )
        : inGrid == 0
        ? l10n.noScans17Weeks
        : l10n.scansIn17Weeks(l10n.scanCount(inGrid));
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
                      child: Text(
                        context.l10n.homeScanActivity,
                        style: homeTitle(p),
                      ),
                    ),
                    Text(subtitle, style: homeSmall(p)),
                  ],
                ),
              ),
              _Segmented(
                labels: [l10n.homeYear, l10n.homeMonth],
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
                        l10n.homeStreakLine(
                          l10n.dayCount(stats.currentStreak),
                          stats.longestStreak,
                        ),
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
                onPressed: () => _goTab(_scanTab),
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
                l10n.homeGuestProgress,
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
    final next = level.levelNumber + 1;
    final sticker = Transform.rotate(
      angle: 0.14,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.primary,
          shape: const StadiumBorder(),
          shadows: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 14, color: p.onPrimary),
              const SizedBox(width: 4),
              Text(
                context.l10n.homeTrophies(stats.totalTrophies),
                style: ElioTokens.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final lv = ElioTokens.caption.copyWith(color: p.textSecondary);
    return Semantics(
      container: true,
      label:
          l10n.levelSemantics(
            level.levelNumber,
            level.title,
            stats.totalTrophies,
          ) +
          (toNext == null
              ? l10n.levelSemanticsTop
              : l10n.levelSemanticsNext(toNext, next)),
      excludeSemantics: true,
      child: SizedBox(
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Soft hill and sun dots (629:80753-55).
            Positioned(
              top: 40,
              left: -106,
              right: -106,
              height: 430,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: p.isDark ? 0.10 : 0.08),
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(285, 215),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 34,
              child: _dot(p.primary.withValues(alpha: 0.45), 40),
            ),
            Positioned(
              top: 70,
              left: 2,
              child: _dot(p.primary.withValues(alpha: 0.45), 18),
            ),
            Positioned(
              top: 40,
              child: SizedBox(
                width: 300,
                height: 150,
                // Arc sweeps 0 → progress, the knob rides it (900, delay 200).
                child: ElioAfterFirstFrame(
                  builder: (context, ready) => TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end:
                          !ready &&
                              _playEntrance &&
                              !ElioMotion.reduced(context)
                          ? 0
                          : toNext == null
                          ? 1
                          : stats.levelProgress,
                    ),
                    duration: ElioMotion.reduced(context)
                        ? Duration.zero
                        : ElioMotion.celebrate +
                              const Duration(milliseconds: 200),
                    curve: const Interval(
                      0.18,
                      1,
                      curve: ElioMotion.emphasized,
                    ),
                    builder: (context, v, _) => CustomPaint(
                      painter: _DialPainter(
                        value: v,
                        track: p.borderSubtle,
                        fill: p.primary,
                        knob: p.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 52,
              child: ElioPopIn(
                play: _playEntrance,
                rise: 0,
                curve: ElioMotion.soft,
                child: homeArt(
                  level.levelNumber >= 3 ? 'tree_lv3' : 'sprout_lv1',
                  width: 156,
                  height: 161,
                ),
              ),
            ),
            Positioned(
              top: 196,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      Text(l10n.homeLvShort(level.levelNumber), style: lv),
                      const Spacer(),
                      if (toNext != null)
                        Text(l10n.homeLvShort(next), style: lv),
                    ],
                  ),
                ),
              ),
            ),
            // Sticker drops in rotating (spring/pop, delay 600).
            Positioned(
              top: 44,
              right: 4,
              child: ElioMotion.reduced(context) || !_playEntrance
                  ? sticker
                  : ElioAfterFirstFrame(
                      builder: (context, ready) =>
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: ready ? 1 : 0),
                            duration: const Duration(milliseconds: 1100),
                            curve: const Interval(
                              0.55,
                              1,
                              curve: ElioMotion.pop,
                            ),
                            child: sticker,
                            builder: (context, v, child) => Opacity(
                              opacity: v.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -16 * (1 - v)),
                                child: Transform.rotate(
                                  angle: 0.1 * (1 - v),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                    ),
            ),
            Positioned(
              top: 220,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    l10n.homeLevel(level.levelNumber).toUpperCase(),
                    style: _overline11(p.primaryText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.title,
                    textAlign: TextAlign.center,
                    style: homeNumber(
                      p,
                      36,
                    ).copyWith(height: 1.2, letterSpacing: -0.72),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats.totalTrophies == 0
                        ? l10n.homePlantFirst
                        : toNext == null
                        ? l10n.homeTopLevel
                        : l10n.homeToNextLong(toNext, next),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: homeSmall(p),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// Top half-circle dial: track, progress to the next level and a knob.
class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.knob,
  });

  final double value;
  final Color track, fill, knob;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.width - stroke,
    );
    Paint line(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, line(track));
    final v = value.clamp(0.0, 1.0);
    if (v > 0) canvas.drawArc(rect, math.pi, math.pi * v, false, line(fill));
    final a = math.pi + math.pi * v;
    final c = rect.center + Offset(math.cos(a), math.sin(a)) * rect.width / 2;
    canvas
      ..drawCircle(c, 9, Paint()..color = knob)
      ..drawCircle(
        c,
        9,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.knob != knob;
}

/// Three stat pebbles (629:80775-91), staggered like stones.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final acc = stats.quizAccuracy;
    final streak = stats.currentStreak;
    final pebbles = [
      (
        homeArt('scan_line_art', width: 22, height: 22),
        '${stats.totalScans}',
        l10n.homeScans,
        p.surface,
        6.0,
      ),
      (
        Icon(Icons.track_changes_rounded, size: 20, color: p.primaryText),
        acc == null ? '—' : '$acc%',
        l10n.homeQuizAccuracy,
        p.tertiaryText.withValues(alpha: p.isDark ? 0.14 : 0.06),
        32.0,
      ),
      (
        homeArt('streak_flame', width: 24, height: 28),
        '$streak',
        l10n.homeDayStreak,
        p.secondaryText.withValues(alpha: p.isDark ? 0.14 : 0.05),
        0.0,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, s) in pebbles.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: s.$5),
              child: ElioPopIn(
                play: _playEntrance,
                index: i,
                stagger: const Duration(milliseconds: 60),
                rise: 8,
                child: Semantics(
                  label: l10n.a11yLabelValue(
                    s.$3,
                    s.$2 == '—' ? l10n.noData : s.$2,
                  ),
                  container: true,
                  excludeSemantics: true,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: s.$4,
                        shape: CircleBorder(
                          side: BorderSide(color: p.borderSubtle),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              s.$1,
                              _CountText(s.$2, style: homeNumber(p, 28)),
                              Text(
                                s.$3,
                                style: ElioTokens.caption.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Numbers count up the first time they show (600 ms); "47%" keeps its %.
class _CountText extends StatelessWidget {
  const _CountText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^(\d+)(%?)$').firstMatch(text);
    if (m == null) return Text(text, style: style);
    return ElioCountUp(
      play: _playEntrance,
      value: int.parse(m.group(1)!),
      builder: (context, v) => Text('$v${m.group(2)}', style: style),
    );
  }
}

/// Daily quests: heading with squiggle and ring, then three pop cards
/// (629:81029) with an art bubble, reward and a progress ring check.
class _Quests extends StatelessWidget {
  const _Quests({required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final quests = stats.quests;
    final done = quests.where((q) => q.done).length;
    // Quest order is fixed: scan 3, finish a quiz, sort a B3 item.
    final art = [
      (homeArt('scan_line_art', width: 38, height: 38), p.primaryText),
      (homeArt('quest_target', width: 38, height: 38), p.tertiaryText),
      (homeArt('bin_b3', width: 30, height: 38), p.errorText),
    ];
    const tilt = [0.035, 0.0, -0.035];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.homeDailyQuests,
                      style: homeTitle(
                        p,
                      ).copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/illustrations/scan/squiggle.svg',
                    width: 72,
                    height: 10,
                    excludeFromSemantics: true,
                    colorFilter: ColorFilter.mode(p.primary, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.questsDoneLine(done), style: homeSmall(p)),
                ],
              ),
            ),
            Semantics(
              label: l10n.questsDoneSemantics(done),
              container: true,
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: 48,
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
                      style: homeSmall(
                        p,
                        color: p.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, q) in quests.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: ElioPopIn(
                    play: _playEntrance,
                    index: i,
                    stagger: const Duration(milliseconds: 60),
                    child: Transform.rotate(
                      angle: tilt[i % 3],
                      child: _QuestCard(
                        quest: q,
                        art: art[i % 3].$1,
                        tone: art[i % 3].$2,
                        radius: i.isOdd ? _leafFlip : _leaf,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.art,
    required this.tone,
    required this.radius,
  });

  final DailyQuest quest;
  final Widget art;
  final Color tone;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final q = quest;
    return Semantics(
      label: l10n.questSemantics(
        q.title,
        q.done ? l10n.questDone : l10n.percentValue((q.progress * 100).round()),
        q.reward,
      ),
      container: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 0),
            padding: const EdgeInsets.fromLTRB(8, 40, 8, 12),
            decoration: BoxDecoration(
              color: q.done ? p.primary.withValues(alpha: 0.12) : p.surface,
              borderRadius: radius,
              border: Border.all(color: p.borderSubtle),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  q.title,
                  textAlign: TextAlign.center,
                  style: ElioTokens.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: q.done ? p.textSecondary : p.textPrimary,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 8),
                TrophyAmount('+${q.reward}', chip: true),
                const SizedBox(height: 8),
                // Done check that fills up with the quest's progress.
                SizedBox.square(
                  dimension: 24,
                  child: q.done
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 24,
                          color: p.primaryText,
                        )
                      : CircularProgressIndicator(
                          value: q.progress,
                          strokeWidth: 2.5,
                          color: p.primary,
                          backgroundColor: p.borderMedium,
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -29,
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  tone.withValues(alpha: p.isDark ? 0.18 : 0.08),
                  p.surface,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: p.surface, width: 3),
              ),
              child: art,
            ),
          ),
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
            total == 0 ? l10n.binsHungry : l10n.binsFed(l10n.scanCount(total)),
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
                        '${l10n.a11yBinStat(b.label, stats.binCounts[b]!, pct(stats.binCounts[b]!))}${b == top ? l10n.a11yTopBin : ''}',
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
                                        l10n.binTop,
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
                ? l10n.residuNote
                : l10n.residuIncluded(
                    stats.residuCount,
                    l10n.scanWord(stats.residuCount),
                  ),
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
                TextSpan(text: l10n.homeScansUnit, style: homeSmall(p)),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.weekSemantics(
              stats.weekTotal,
              [
                for (var i = 0; i < 7; i++) '${weekdayNames[i]} ${perDay[i]}',
              ].join(', '),
            ),
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
          ? l10n.quizAccNoData
          : l10n.quizAccSemantics(acc, points.length) +
                (delta == null
                    ? ''
                    : l10n.quizAccDelta(
                        delta >= 0 ? l10n.deltaUp : l10n.deltaDown,
                        delta.abs(),
                      )),
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
                            ? l10n.noData
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
                l10n.homeMedalsOf(unlocked, medals.length),
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
        m.unlocked ? l10n.medalUnlocked : m.hint,
        textAlign: align,
        style: homeSmall(
          p,
          color: m.unlocked ? p.secondaryText : p.textSecondary,
        ).copyWith(fontSize: 12),
      ),
    ];
    return Semantics(
      container: true,
      label: l10n.a11yMedal(
        m.name,
        m.unlocked ? l10n.a11yUnlocked : l10n.a11yLocked,
        m.description,
      ),
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
                  Text(
                    context.l10n.homeDidYouKnow,
                    style: homeOverline(p.secondaryText),
                  ),
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

/// Home skeleton (Figma 12 · Home 635:23782): the same geometry as the L4
/// Home (dial, three pebbles, quest cards) under the section 12 shimmer;
/// static under reduced motion.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    Widget block(double h, {double r = homeRadiusL}) => Container(
      height: h,
      decoration: ShapeDecoration(color: p.borderSubtle, shape: homeShape(r)),
    );
    Widget circle() => AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.borderSubtle,
          shape: BoxShape.circle,
        ),
      ),
    );
    return Semantics(
      label: l10n.homeLoading,
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeGrowing,
            textAlign: TextAlign.center,
            style: homeSmall(p),
          ),
          const SizedBox(height: 16),
          ElioShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                block(300, r: 150),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: circle()),
                    const SizedBox(width: 8),
                    Expanded(child: circle()),
                    const SizedBox(width: 8),
                    Expanded(child: circle()),
                  ],
                ),
                const SizedBox(height: 24),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: block(24, r: 12),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: block(150)),
                    const SizedBox(width: 10),
                    Expanded(child: block(150)),
                    const SizedBox(width: 10),
                    Expanded(child: block(150)),
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
