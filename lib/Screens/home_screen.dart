// Home H1 v4, gamified (decision 0144). Figma file J2jSbARJSyJCStNFeWkWDj,
// page "H1 v2 Home (reference style)" 321:2358:
//   333:4383 Home   334:4584 Guest / no scans   334:5265 Loading
//   334:5353 / 334:5681 / 334:5993 the same in dark (ElioTokens.dark via the theme)
//   329:3722 Search results   329:3836 Calendar month
// Every number comes from the local scan records (HomeStats) or learning
// progress (medals). ELIOS 3 L3 Home (629:80377 light, 629:81350 dark,
// decision 0209): leaf logo + greeting + bell, resume-control card while a
// robot is connected, level dial hero with the trophy sticker, stat pebbles,
// pop quest cards, Scan activity leaf panel, Recent scans polaroid fan, Bin
// shelf, This week / Quiz accuracy leaves and the Medal ribbon. Opening Home
// plays one entrance timeline; lower sections play as they scroll into view.
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
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
import '../widgets/history_ui.dart'
    show
        HistoryScanCard,
        HistoryTone,
        historyDay,
        historyPhotoImage,
        historyTint;
import '../widgets/learn/learn_ui.dart' show LearnIllustration, LearnThumbnail;
import 'tabs/elearning/learn_content.dart' show LearnArt;
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
/// [seenLevel] never goes down: learning XP arrives after the first frame, and
/// a brief lower level must not make the real one celebrate again (0212).
({bool levelUp, List<int> newMedals, int seenLevel}) celebrationsDue({
  required int? lastLevel,
  required int level,
  required Set<int>? lastMedals,
  required Set<int>? medals,
}) => (
  levelUp: lastLevel != null && level > lastLevel,
  seenLevel: math.max(level, lastLevel ?? level),
  newMedals: lastMedals == null || medals == null
      ? const []
      : ([...medals.difference(lastMedals)]..sort()),
);

ElearningContentService? _contentServiceOverride;
ElearningContentService get _contentService =>
    _contentServiceOverride ??= ElearningContentService();

/// Test seam: Firestore cannot run in widget tests.
@visibleForTesting
set homeContentServiceForTest(ElearningContentService? service) =>
    _contentServiceOverride = service;

/// The Home entrance timeline (plays on every open, like Learn's).
const _introMs = 1500;
double _ms(int ms) => ms / _introMs;

final _groundPath = Path()
  ..moveTo(0, 12)
  ..cubicTo(60, 2, 120, 22, 195, 12)
  ..cubicTo(270, 2, 330, 2, 390, 12);
final _ribbonPath = Path()
  ..moveTo(0, 6)
  ..cubicTo(130, 32.6667, 260, 32.6667, 390, 6);

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
  const _HomeGreeting({
    required this.a,
    required this.name,
    required this.onOpenLearning,
  });
  final Animation<double> a;
  final String name;
  final VoidCallback onOpenLearning;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Row(
      children: [
        // The leaf spins in, the greeting rises, the bell pops.
        HomeRise(
          a,
          0,
          _ms(420),
          rise: 0,
          scale: 0.3,
          turn: -0.8,
          curve: ElioMotion.pop,
          child: ElioMark(size: 40, color: p.primaryText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeRise(
                a,
                _ms(60),
                _ms(380),
                rise: 10,
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.homeHello(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ElioTokens.headline.copyWith(
                      height: 1.25,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
              HomeRise(
                a,
                _ms(140),
                _ms(460),
                rise: 8,
                child: Text(
                  l10n.homeReady,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
        HomeRise(
          a,
          _ms(220),
          _ms(620),
          rise: 0,
          scale: 0.4,
          curve: ElioMotion.pop,
          child: HomeHeaderActions(onOpenLearning: onOpenLearning),
        ),
      ],
    );
  }
}

/// The bell beside the Home greeting (629:80382): a 44 dp surface circle in
/// a 48 dp tap target. The trophy total sits on the hero.
class HomeHeaderActions extends ConsumerWidget {
  const HomeHeaderActions({super.key, required this.onOpenLearning});

  final VoidCallback onOpenLearning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: l10n.homeOpenNotifications,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        padding: EdgeInsets.zero,
      ),
      onPressed: () {
        elioFeedback(ElioSfx.tick, ElioHaptics.select);
        showNotificationsSheet(
          context: context,
          onOpenLearning: onOpenLearning,
        );
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: p.error,
        textColor: p.onError,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: p.surface,
            shape: CircleBorder(side: BorderSide(color: p.borderSubtle)),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: 22,
            color: p.textPrimary,
          ),
        ),
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

const _leaf = homeLeaf;
const _leafFlip = homeLeafFlip;

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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  )..addListener(_beat);

  /// Sections whose reveal already played in this visit.
  final _seen = <Object>{};
  bool _introQueued = false;
  int _nextBeat = 0;

  // S2 as the tree lands, S4 (+ a light tap) as the dial closes, S9-short as
  // the trophy sticker lands; quiet, like the Learn entrance.
  static const _beats = [
    (540, ElioSfx.pop, 0.6),
    (1040, ElioSfx.chime, 0.7),
    (1240, ElioSfx.sparkleShort, 0.5),
  ];

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: everything at rest, no entrance sounds.
    if (!_introQueued && ElioMotion.reduced(context)) {
      _introQueued = true;
      _nextBeat = _beats.length;
      _intro.value = 1;
    }
  }

  /// Starts the entrance once the scans are loaded and on screen.
  void _queueIntro() {
    if (_introQueued) return;
    _introQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  void _beat() {
    final ms = _intro.value * _introMs;
    while (_nextBeat < _beats.length && ms >= _beats[_nextBeat].$1) {
      final (_, sfx, gain) = _beats[_nextBeat++];
      if (sfx == ElioSfx.chime) ElioHaptics.light();
      unawaited(ElioSound.instance.play(sfx, gain: gain));
    }
  }

  /// A quiet sound with its haptic, for a section landing.
  void _cue(ElioSfx sfx, void Function() haptic) {
    haptic();
    unawaited(ElioSound.instance.play(sfx, gain: 0.5));
  }

  @override
  void dispose() {
    _intro.dispose();
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
            thumb: LearnThumbnail(
              url: v.thumbnailUrl,
              fallbackAsset: LearnArt.cover(v.moduleId),
            ),
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
            thumb: LearnThumbnail(
              url: g.coverUrl,
              fallbackAsset: LearnArt.guideThumb(g.moduleId),
            ),
            onTap: () => _resume(LearningResumeType.guide, g.id, g.moduleId),
          ),
      for (final s in physicsModules)
        if (m(s.title) || m(s.description))
          SearchItem(
            scope: SearchScope.simulasi,
            title: s.title,
            subtitle: s.tag,
            icon: s.icon,
            thumb: LearnIllustration(
              LearnArt.simulation(s.id),
              fit: BoxFit.cover,
            ),
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
            thumb: const LearnIllustration(
              LearnArt.quizThumb,
              fit: BoxFit.cover,
            ),
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
            thumb: historyPhotoImage(r),
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
                if (loaded) _queueIntro();
                final stats = HomeStats.from(
                  loaded ? _store.records : const [],
                  homeClock(),
                  learnXp: _store.learnXp,
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
                              a: _intro,
                              name: homeDisplayName(user),
                              onOpenLearning: widget.onOpenLearning,
                            ),
                            const SizedBox(height: 8),
                            HomeRise(
                              _intro,
                              _ms(160),
                              _ms(520),
                              rise: 12,
                              child: HomeSearchField(
                                controller: _search,
                                focusNode: _searchFocus,
                                scope: _scope,
                                onScope: (s) => setState(() => _scope = s),
                                resultCount: _search.text.isEmpty
                                    ? null
                                    : results.length,
                              ),
                            ),
                            const SizedBox(height: 12),
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
      await prefs.setInt(levelKey, due.seenLevel);
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

  Widget _reveal(
    Object id,
    Widget Function(Animation<double> a) builder, {
    int ms = 900,
    List<(double, VoidCallback)> cues = const [],
  }) => HomeReveal(
    id: id,
    seen: _seen,
    duration: Duration(milliseconds: ms),
    cues: cues,
    builder: (context, a) => builder(a),
  );

  List<Widget> _sections(
    BuildContext context,
    ElioPalette p,
    HomeStats stats,
    bool isGuest,
    List<_Medal> medals,
  ) {
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
    final anyMedal = medals.any((m) => m.unlocked);
    return [
      const HomeResumeControl(),
      if (isGuest) ...[
        _GuestBanner(
          onSignIn: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
          ),
        ),
        const SizedBox(height: 16),
      ],
      _Hero(stats: stats, a: _intro),
      _StatsRow(stats: stats, a: _intro),
      const SizedBox(height: 34),
      _Quests(stats: stats, seen: _seen),
      const SizedBox(height: 38),
      _reveal(
        'activity',
        (a) => _activityCard(p, stats, a),
        cues: [(0.15, ElioHaptics.select)],
      ),
      if (_monthMode && _selectedDay != null) ...[
        const SizedBox(height: 16),
        DayScans(
          stats: stats,
          day: _selectedDay!,
          onOpenHistory: () => _goTab(_historyTab),
        ),
        const SizedBox(height: 12),
        Text(l10n.homeTapSquare, style: homeSmall(p)),
        const SizedBox(height: 22),
      ],
      if (!stats.isEmpty) ...[
        const SizedBox(height: 14),
        _reveal(
          'recent',
          (a) => _RecentScans(
            stats: stats,
            a: a,
            onOpen: () {
              elioFeedback(ElioSfx.pop, ElioHaptics.light);
              _goTab(_historyTab);
            },
          ),
          ms: 1000,
          // The last polaroid lands.
          cues: [(0.8, () => _cue(ElioSfx.tick, ElioHaptics.light))],
        ),
      ],
      const SizedBox(height: 34),
      _reveal(
        'bins',
        (a) => _BinBuddies(stats: stats, a: a),
        ms: 1200,
        // The bins hit the shelf.
        cues: [(0.42, () => _cue(ElioSfx.pop, ElioHaptics.light))],
      ),
      const SizedBox(height: 8),
      _reveal(
        'week',
        (a) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HomeRise(
                  a,
                  0,
                  0.4,
                  rise: 20,
                  dx: -24,
                  child: _ThisWeek(stats: stats, a: a),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: HomeRise(
                  a,
                  0.1,
                  0.5,
                  rise: 20,
                  dx: 24,
                  child: _QuizAccuracy(stats: stats, a: a),
                ),
              ),
            ],
          ),
        ),
        ms: 1100,
        cues: [(0.15, ElioHaptics.select)],
      ),
      const SizedBox(height: 28),
      _reveal(
        'medals',
        (a) => _Medals(medals: medals, a: a),
        ms: 1300,
        // The first medal settles: a sparkle only when one is unlocked.
        cues: [
          (
            0.6,
            anyMedal
                ? () => _cue(ElioSfx.sparkleShort, ElioHaptics.light)
                : ElioHaptics.select,
          ),
        ],
      ),
    ];
  }

  /// Scan activity leaf panel (629:80445).
  Widget _activityCard(ElioPalette p, HomeStats stats, Animation<double> a) {
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
    return HomeRise(
      a,
      0,
      0.4,
      rise: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.borderSubtle),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(32),
            bottomLeft: Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 17, 8, 21),
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
                        HomeRise(
                          a,
                          0.1,
                          0.4,
                          rise: 10,
                          child: Semantics(
                            header: true,
                            child: Text(
                              context.l10n.homeScanActivity,
                              style: homeTitle(p),
                            ),
                          ),
                        ),
                        HomeRise(
                          a,
                          0.18,
                          0.48,
                          rise: 8,
                          child: Text(subtitle, style: homeCaption(p)),
                        ),
                      ],
                    ),
                  ),
                  HomeRise(
                    a,
                    0.2,
                    0.55,
                    rise: 0,
                    dx: 20,
                    child: _Segmented(
                      labels: [l10n.homeYear, l10n.homeMonth],
                      selected: _monthMode ? 1 : 0,
                      onSelect: (i) {
                        elioFeedback(ElioSfx.tick, ElioHaptics.select);
                        setState(() => _monthMode = i == 1);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_monthMode)
                Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: MonthView(
                    stats: stats,
                    month: month,
                    selected: _selectedDay,
                    onMonth: (m) => setState(() => _shownMonth = m),
                    onSelect: (d) {
                      ElioHaptics.select();
                      setState(() => _selectedDay = d);
                    },
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 15),
                  child: YearGrid(
                    stats: stats,
                    reveal: a,
                    onSelectDay: (d) {
                      elioFeedback(ElioSfx.tick, ElioHaptics.select);
                      setState(() {
                        _monthMode = true;
                        _selectedDay = d;
                        _shownMonth = DateTime(d.year, d.month);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  spacing: 12,
                  children: [
                    HomeRise(
                      a,
                      0.45,
                      0.8,
                      rise: 0,
                      dx: -12,
                      child: stats.isEmpty
                          ? Text(
                              context.l10n.homeFirstScanToday,
                              style: homeCaption(p),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_outlined,
                                  size: 16,
                                  color: p.secondaryText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.homeStreakLine(
                                    l10n.dayCount(stats.currentStreak),
                                    stats.longestStreak,
                                  ),
                                  style: homeCaption(p),
                                ),
                              ],
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ActivityLegend(reveal: a),
                    ),
                  ],
                ),
                if (stats.isEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(right: 11),
                    child: FilledButton(
                      onPressed: () {
                        elioFeedback(ElioSfx.pop, ElioHaptics.light);
                        _goTab(_scanTab);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: homeShape(999),
                      ),
                      child: Text(context.l10n.homeScanItem),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Medal {
  const _Medal(this.name, this.description, this.hint, this.unlocked);
  final String name, description, hint;
  final bool unlocked;
}

/// Year | Month (629:80448): raised pill, the selected side fills green.
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
        shape: const StadiumBorder(),
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
                  onTap: i == selected ? null : () => onSelect(i),
                  customBorder: const StadiumBorder(),
                  child: AnimatedContainer(
                    duration: ElioMotion.reduced(context)
                        ? Duration.zero
                        : ElioMotion.base,
                    curve: ElioMotion.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: i == selected
                          ? p.primary
                          : p.primary.withValues(alpha: 0),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      labels[i],
                      style: ElioTokens.button.copyWith(
                        height: 1.4,
                        color: i == selected ? p.onPrimary : p.textSecondary,
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

/// Level dial hero (629:80395): soft hill, sun dots, dial, eco tree, level
/// text and the trophy sticker, all on the Home entrance timeline [a].
class _Hero extends StatelessWidget {
  const _Hero({required this.stats, required this.a});
  final HomeStats stats;
  final Animation<double> a;

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
              // The total counts up as the sticker lands.
              AnimatedBuilder(
                animation: a,
                builder: (context, _) => Text(
                  context.l10n.homeTrophies(
                    (stats.totalTrophies *
                            homeSlice(
                              a,
                              _ms(900),
                              _ms(1500),
                              ElioMotion.standard,
                            ))
                        .round(),
                  ),
                  style: homeCaption(p, color: p.onPrimary, weight: 700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final lv = homeCaption(p);
    Widget dot(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
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
        height: 320,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // The hill swells up from below.
            Positioned(
              top: 40,
              left: -106,
              right: -106,
              height: 430,
              child: HomeRise(
                a,
                _ms(60),
                _ms(600),
                rise: 60,
                scale: 0.86,
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: p.isDark ? 0.10 : 0.08),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(285, 215),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 34,
              child: HomeRise(
                a,
                _ms(380),
                _ms(760),
                rise: 0,
                scale: 0,
                curve: ElioMotion.pop,
                child: dot(40),
              ),
            ),
            Positioned(
              top: 70,
              left: 2,
              child: HomeRise(
                a,
                _ms(460),
                _ms(840),
                rise: 0,
                scale: 0,
                curve: ElioMotion.pop,
                child: dot(18),
              ),
            ),
            // The arc sweeps 0 → progress and the knob rides it.
            Positioned(
              top: 40,
              child: HomeRise(
                a,
                _ms(120),
                _ms(480),
                rise: 0,
                child: AnimatedBuilder(
                  animation: a,
                  builder: (context, _) => CustomPaint(
                    size: const Size(300, 150),
                    painter: _DialPainter(
                      value:
                          (toNext == null ? 1 : stats.levelProgress) *
                          homeSlice(a, _ms(320), _ms(1040)),
                      track: p.borderSubtle,
                      fill: p.primary,
                      knob: p.surface,
                    ),
                  ),
                ),
              ),
            ),
            // The tree grows out of its pot, then sways for a moment.
            Positioned(
              top: 52,
              child: HomeRise(
                a,
                _ms(200),
                _ms(820),
                rise: 0,
                scale: 0.2,
                curve: ElioMotion.pop,
                alignment: Alignment.bottomCenter,
                child: ElioIdleLoop(
                  period: const Duration(seconds: 3),
                  length: const Duration(seconds: 9),
                  builder: (context, wave, child) => Transform.rotate(
                    angle: 0.035 * wave,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  // Tap: the tree springs and rustles.
                  child: HomeBoing(
                    amp: 0.12,
                    turn: 0.07,
                    alignment: Alignment.bottomCenter,
                    child: homeArt(
                      level.levelNumber >= 3 ? 'tree_lv3' : 'sprout_lv1',
                      width: 156,
                      height: 161,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 196,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 304,
                  child: HomeRise(
                    a,
                    _ms(380),
                    _ms(700),
                    rise: 0,
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
            ),
            // The sticker drops in rotating (spring/pop).
            Positioned(
              top: 52,
              right: -10,
              child: HomeRise(
                a,
                _ms(820),
                _ms(1300),
                rise: -24,
                turn: 0.35,
                scale: 0.7,
                curve: ElioMotion.pop,
                // Tap: the sticker wobbles with a trophy sparkle.
                child: HomeBoing(
                  amp: 0.14,
                  turn: 0.18,
                  sfx: ElioSfx.sparkleShort,
                  child: sticker,
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: 0,
              right: 0,
              child: HomeRise(
                a,
                _ms(460),
                _ms(840),
                rise: 14,
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
                      style: ElioTokens.display.copyWith(color: p.textPrimary),
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
                    ).constrained300(),
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

extension on Widget {
  Widget constrained300() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: this,
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
      // Flat ends on the baseline (629:80399); the knob caps the progress.
      ..strokeCap = StrokeCap.butt;
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

/// Three stat pebbles (629:80418-37), staggered like stones: 108, 122 and
/// 106 wide, each popping in and counting up on the entrance timeline.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.a});
  final HomeStats stats;
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final acc = stats.quizAccuracy;
    Widget icon(String name) => SvgPicture.asset(
      'assets/illustrations/home/$name.svg',
      width: 20,
      height: 20,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(p.primaryText, BlendMode.srcIn),
    );
    final pebbles = [
      (
        icon('icon_scan'),
        '${stats.totalScans}',
        l10n.homeScans,
        p.surface,
        6.0,
        108,
      ),
      (
        icon('icon_target'),
        acc == null ? '—' : '$acc%',
        l10n.homeQuizAccuracy,
        historyTint(p, HistoryTone.info).bg,
        32.0,
        122,
      ),
      (
        // The flame flickers for a moment.
        ElioIdleLoop(
          period: const Duration(milliseconds: 900),
          builder: (context, wave, child) => Transform.scale(
            scale: 1 + 0.1 * wave,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: homeArt('streak_flame', width: 24, height: 28),
        ),
        '${stats.currentStreak}',
        l10n.homeDayStreak,
        historyTint(p, HistoryTone.warning).bg,
        0.0,
        106,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, s) in pebbles.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              flex: s.$6,
              child: Padding(
                padding: EdgeInsets.only(top: s.$5),
                child: HomeRise(
                  a,
                  _ms(780 + i * 110),
                  _ms(1240 + i * 110),
                  rise: 28,
                  scale: 0.4,
                  curve: ElioMotion.pop,
                  // Tap: the pebble bounces.
                  child: HomeBoing(
                    amp: 0.1,
                    sfx: ElioSfx.tick,
                    haptic: ElioHaptics.select,
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
                                  _Count(
                                    a,
                                    _ms(860 + i * 110),
                                    1,
                                    s.$2,
                                    style: homeNumber(p, 28),
                                  ),
                                  Text(s.$3, style: homeCaption(p)),
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
            ),
          ],
        ],
      ),
    );
  }
}

/// A number that counts up over [from]..[to] of [a]; "47%" keeps its %.
class _Count extends StatelessWidget {
  const _Count(this.a, this.from, this.to, this.text, {required this.style});
  final Animation<double> a;
  final double from, to;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^(\d+)(%?)$').firstMatch(text);
    if (m == null) return Text(text, style: style);
    final n = int.parse(m.group(1)!);
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) => Text(
        '${(n * homeSlice(a, from, to, ElioMotion.standard)).round()}'
        '${m.group(2)}',
        style: style,
      ),
    );
  }
}

/// Daily quests (629:80438-44, cards 629:80672): heading with squiggle and
/// ring, then three pop cards dealt in, the middle one raised.
class _Quests extends StatelessWidget {
  const _Quests({required this.stats, required this.seen});
  final HomeStats stats;
  final Set<Object> seen;

  @override
  Widget build(BuildContext context) => HomeReveal(
    id: 'quests',
    seen: seen,
    // Visible as Home opens: waits for the hero to finish.
    delay: const Duration(milliseconds: 950),
    duration: const Duration(milliseconds: 1200),
    builder: _body,
  );

  Widget _body(BuildContext context, Animation<double> a) {
    final p = authPalette(context);
    final quests = stats.quests;
    final done = quests.where((q) => q.done).length;
    // Quest order is fixed: scan 3, finish a quiz, sort a B3 item.
    final art = [
      (homeArt('scan_line_art', width: 40, height: 40), HistoryTone.success),
      (homeArt('quest_target', width: 38, height: 38), HistoryTone.info),
      (homeArt('bin_b3', width: 32, height: 38), HistoryTone.error),
    ];
    const tilt = [0.035, 0.0, -0.035];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHead(
          a: a,
          title: context.l10n.homeDailyQuests,
          squiggle: 96,
          subtitle: l10n.questsDoneLine(done),
          trailing: Semantics(
            label: l10n.questsDoneSemantics(done),
            container: true,
            excludeSemantics: true,
            child: HomeRise(
              a,
              0.1,
              0.45,
              rise: 0,
              scale: 0.5,
              curve: ElioMotion.pop,
              child: SizedBox.square(
                dimension: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The ring sweeps up to the quests done.
                    AnimatedBuilder(
                      animation: a,
                      builder: (context, _) => SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: done / 3 * homeSlice(a, 0.3, 0.85),
                          strokeWidth: 4,
                          color: p.primary,
                          backgroundColor: p.borderSubtle,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    Text(
                      '$done/3',
                      style: homeCaption(p, color: p.textPrimary, weight: 700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 50),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, q) in quests.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  // Dealt from above, left to right; the side cards sit 16
                  // lower than the middle one.
                  child: HomeRise(
                    a,
                    0.2 + 0.12 * i,
                    0.62 + 0.12 * i,
                    rise: -56,
                    turn: i == 1 ? 0.12 : (1 - i) * 0.2,
                    scale: 0.85,
                    curve: ElioMotion.soft,
                    child: Transform.translate(
                      offset: Offset(0, i % 3 == 1 ? 0 : 16),
                      child: Transform.rotate(
                        angle: tilt[i % 3],
                        // Tap: the card wobbles; a finished quest chimes.
                        child: HomeBoing(
                          amp: 0.06,
                          turn: 0.05,
                          sfx: q.done ? ElioSfx.chime : ElioSfx.pop,
                          child: _QuestCard(
                            quest: q,
                            art: art[i % 3].$1,
                            tone: art[i % 3].$2,
                            radius: i.isOdd ? _leafFlip : _leaf,
                            a: a,
                            at: 0.34 + 0.12 * i,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    required this.a,
    required this.at,
  });

  final DailyQuest quest;
  final Widget art;
  final HistoryTone tone;
  final BorderRadius radius;

  /// The art bubble pops at [at] of [a], the reward and check follow.
  final Animation<double> a;
  final double at;

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
            constraints: const BoxConstraints(minHeight: 160),
            padding: const EdgeInsets.fromLTRB(7, 40, 7, 10),
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
                  style: homeSmall(
                    p,
                    color: q.done ? p.textSecondary : p.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 8),
                HomeRise(
                  a,
                  at + 0.08,
                  at + 0.34,
                  rise: 6,
                  scale: 0.6,
                  curve: ElioMotion.pop,
                  child: TrophyAmount('+${q.reward}', chip: true),
                ),
                const SizedBox(height: 4),
                // Done check: an empty ring that fills with the quest's
                // progress, a bouncing tick once done.
                HomeRise(
                  a,
                  at + 0.2,
                  at + 0.5,
                  rise: 0,
                  scale: 0,
                  curve: q.done ? ElioMotion.bounce : ElioMotion.pop,
                  child: SizedBox.square(
                    dimension: 24,
                    child: q.done
                        ? Icon(
                            Icons.check_circle_rounded,
                            size: 24,
                            color: p.primaryText,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(1),
                            child: CircularProgressIndicator(
                              value: q.progress,
                              strokeWidth: 2,
                              color: p.primary,
                              backgroundColor: p.borderMedium,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -29,
            child: HomeRise(
              a,
              at,
              at + 0.3,
              rise: 10,
              scale: 0,
              curve: ElioMotion.pop,
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(historyTint(p, tone).bg, p.surface),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 3),
                ),
                child: art,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent scans → History (629:80715): a fan of the three latest scan cards
/// beside the total, the latest scan and "Open History".
class _RecentScans extends StatelessWidget {
  const _RecentScans({
    required this.stats,
    required this.a,
    required this.onOpen,
  });
  final HomeStats stats;
  final Animation<double> a;
  final VoidCallback onOpen;

  // Centre and angle of each mini card in the 150 × 130 fan; latest first.
  static const _slots = [
    (21.1, 78.6, 10.0),
    (72.8, 58.0, 0.0),
    (122.5, 66.6, -9.0),
  ];

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final tint = historyTint(p, HistoryTone.success);
    final latest = ([
      ...stats.records,
    ]..sort((x, y) => y.time.compareTo(x.time))).take(3).toList();
    final day = historyDay(t, latest.first.time.toLocal(), now: homeClock());
    final line = t.homeLatestScan(
      latest.first.itemName,
      RegExp(r'\d').hasMatch(day) ? day : day.toLowerCase(),
    );
    final count = t.scanCount(stats.totalScans);
    return Semantics(
      button: true,
      label: '$count. $line. ${t.homeOpenHistory}',
      excludeSemantics: true,
      onTap: onOpen,
      child: ElioPress(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: HomeRise(
            a,
            0,
            0.35,
            rise: 28,
            child: Container(
              constraints: const BoxConstraints(minHeight: 148),
              decoration: BoxDecoration(
                color: tint.bg,
                border: Border.all(color: tint.border!),
                borderRadius: homeLeaf,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (i, r) in latest.indexed)
                    Positioned(
                      left: 7 + _slots[i].$1 - 30.78,
                      top: -23 + _slots[i].$2 - 52,
                      // Dealt onto the card one by one.
                      child: HomeRise(
                        a,
                        0.22 + 0.16 * i,
                        0.62 + 0.16 * i,
                        rise: 36,
                        dx: 90,
                        turn: 0.6,
                        scale: 0.6,
                        curve: ElioMotion.soft,
                        child: Transform.rotate(
                          angle: _slots[i].$3 * math.pi / 180,
                          child: SizedBox(
                            width: 61.56,
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              child: SizedBox(
                                width: 171,
                                child: IgnorePointer(
                                  // The card stretches to its row in History.
                                  child: IntrinsicHeight(
                                    child: HistoryScanCard(r, onTap: () {}),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(169, 17, 16, 0),
                    child: HomeRise(
                      a,
                      0.3,
                      0.65,
                      rise: 0,
                      dx: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.searchScansHeader,
                            style: _overline11(p.primaryText),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _Count(
                                a,
                                0.3,
                                0.9,
                                '${stats.totalScans}',
                                style: homeNumber(p, 28),
                              ),
                              const SizedBox(width: 6),
                              Text(t.homeScansUnit.trim(), style: homeSmall(p)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(line, style: homeCaption(p)),
                          const SizedBox(height: 4),
                          // The button hangs a little over the card's edge.
                          Transform.translate(
                            offset: const Offset(0, 6),
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: p.primary,
                                shape: const StadiumBorder(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 16,
                                      color: p.onPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        t.homeOpenHistory,
                                        style: ElioTokens.button.copyWith(
                                          height: 1.4,
                                          color: p.onPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // The chevron nudges right for a moment.
                                    ElioIdleLoop(
                                      period: const Duration(
                                        milliseconds: 1200,
                                      ),
                                      length: const Duration(seconds: 6),
                                      builder: (context, wave, child) =>
                                          Transform.translate(
                                            offset: Offset(3 * wave, 0),
                                            child: child,
                                          ),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: p.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// Bin buddies (629:80584-614): heading, then the three bins on a wavy shelf,
/// sized by rank, with count, share bar and a "Top" sticker. Tap a bin and it
/// jumps.
class _BinBuddies extends StatefulWidget {
  const _BinBuddies({required this.stats, required this.a});
  final HomeStats stats;
  final Animation<double> a;

  @override
  State<_BinBuddies> createState() => _BinBuddiesState();
}

class _BinBuddiesState extends State<_BinBuddies> {
  final _taps = {for (final b in HomeBin.values) b: 0};

  static const _art = {
    HomeBin.organik: 'bin_organik',
    HomeBin.anorganik: 'bin_anorganik',
    HomeBin.b3: 'bin_b3',
  };

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final stats = widget.stats, a = widget.a;
    final total = stats.totalScans;
    final top = stats.topBin;
    String pct(int n) => total == 0 ? '0%' : '${(n * 100 / total).round()}%';
    // Biggest bin 1.3×, then 1.05× and 0.95× (Figma); all 1× with no scans.
    final ranked = [...HomeBin.values]
      ..sort((x, y) => stats.binCounts[y]!.compareTo(stats.binCounts[x]!));
    double size(HomeBin b) =>
        total == 0 ? 1 : const [1.3, 1.05, 0.95][ranked.indexOf(b)];

    // Count (grows with the text size) + gap + the tallest bin.
    final shelf = 104 + MediaQuery.textScalerOf(context).scale(36);

    Widget column(int i, HomeBin b) {
      final n = stats.binCounts[b]!;
      final s = size(b);
      return Semantics(
        label:
            '${l10n.a11yBinStat(b.label, n, pct(n))}${b == top ? l10n.a11yTopBin : ''}',
        container: true,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            elioFeedback(ElioSfx.pop, ElioHaptics.light);
            setState(() => _taps[b] = _taps[b]! + 1);
          },
          child: Column(
            children: [
              SizedBox(
                height: shelf,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    HomeRise(
                      a,
                      0.4 + 0.08 * i,
                      0.7 + 0.08 * i,
                      rise: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _Count(
                            a,
                            0.4 + 0.08 * i,
                            0.95,
                            '$n',
                            style: homeNumber(p, 28),
                          ),
                          const SizedBox(width: 4),
                          Text(pct(n), style: homeCaption(p)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Dropped onto the shelf; bounces as it lands.
                        HomeRise(
                          a,
                          0.08 + 0.1 * i,
                          0.5 + 0.1 * i,
                          rise: -90,
                          curve: Curves.bounceOut,
                          child: ElioJump(
                            trigger: _taps[b],
                            height: 14,
                            child: homeArt(
                              _art[b]!,
                              width: 64 * s,
                              height: 76 * s,
                            ),
                          ),
                        ),
                        if (b == top)
                          Positioned(
                            right: -34,
                            top: -6,
                            child: HomeRise(
                              a,
                              0.66,
                              0.96,
                              rise: -10,
                              scale: 0,
                              turn: 0.8,
                              curve: ElioMotion.pop,
                              child: Transform.rotate(
                                angle: -12 * math.pi / 180,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: p.secondaryText,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      l10n.binTop,
                                      style: homeCaption(
                                        p,
                                        color: p.onPrimary,
                                        weight: 700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              HomeRise(
                a,
                0.45 + 0.08 * i,
                0.75 + 0.08 * i,
                rise: 8,
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  style: homeSmall(
                    p,
                    color: p.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 90,
                // The share bar fills after the bin has landed.
                child: AnimatedBuilder(
                  animation: a,
                  builder: (context, _) => HomeBar(
                    value:
                        (total == 0 ? 0 : n / total) *
                        homeSlice(a, 0.5 + 0.08 * i, 1),
                    color: p.primary,
                    track: p.surfaceRaised,
                    height: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHead(
          a: a,
          title: context.l10n.homeBinBuddies,
          squiggle: 90,
          subtitle: total == 0
              ? l10n.binsHungry
              : l10n.binsFed(l10n.scanCount(total)),
        ),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Wavy ground across the whole screen, drawn left → right.
            Positioned(
              left: -16,
              right: -16,
              top: shelf - 12,
              height: 24,
              child: AnimatedBuilder(
                animation: a,
                builder: (context, _) => CustomPaint(
                  painter: HomeStrokePainter(
                    _groundPath,
                    p.borderMedium,
                    t: homeSlice(a, 0, 0.4),
                  ),
                ),
              ),
            ),
            // Columns centred at 72 / 195 / 318 of 390.
            LayoutBuilder(
              builder: (context, c) => OverflowBox(
                fit: OverflowBoxFit.deferToChild,
                minWidth: c.maxWidth * 369 / 358,
                maxWidth: c.maxWidth * 369 / 358,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, b) in HomeBin.values.indexed)
                      Expanded(child: column(i, b)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        HomeRise(
          a,
          0.6,
          0.9,
          rise: 8,
          child: Text(
            stats.residuCount == 0
                ? l10n.residuNote
                : l10n.residuIncluded(
                    stats.residuCount,
                    l10n.scanWord(stats.residuCount),
                  ),
            style: homeCaption(p),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _leafCard(Color color, Color border, BorderRadius radius) =>
    BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: radius,
    );

/// This week (leaf, 629:80615): scans this week and a bar per day.
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.stats, required this.a});
  final HomeStats stats;
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final week = stats.weekBins;
    final perDay = [for (final d in week) d.values.fold(0, (x, y) => x + y)];
    final label = homeCaption(p, color: p.textTertiary);
    return Container(
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      decoration: _leafCard(p.surface, p.borderSubtle, homeLeaf),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.homeThisWeek, style: homeCaption(p)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _Count(
                a,
                0.2,
                0.8,
                '${stats.weekTotal}',
                style: homeNumber(p, 28),
              ),
              const SizedBox(width: 4),
              Text(l10n.homeScansUnit.trim(), style: homeCaption(p)),
            ],
          ),
          const Spacer(),
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
                // Bars grow from the baseline, Monday first.
                AnimatedBuilder(
                  animation: a,
                  builder: (context, _) => CustomPaint(
                    size: const Size(double.infinity, 60),
                    painter: WeekBarsPainter(
                      week,
                      {for (final b in HomeBin.values) b: binColor(p, b)},
                      stub: p.borderMedium,
                      t: homeSlice(a, 0.3, 1, Curves.linear),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final d in weekdayNames)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 12,
                            child: Text(
                              d.characters.first.toUpperCase(),
                              textAlign: TextAlign.center,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: label,
                            ),
                          ),
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

/// Quiz accuracy (mirrored leaf, 629:80634): accuracy, trend and the line.
class _QuizAccuracy extends StatelessWidget {
  const _QuizAccuracy({required this.stats, required this.a});
  final HomeStats stats;
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final tint = historyTint(p, HistoryTone.info);
    final acc = stats.quizAccuracy;
    final delta = stats.quizDelta;
    final points = stats.quizPercents;
    final down = (delta ?? 0) < 0;
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 172),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 17),
        decoration: _leafCard(tint.bg, tint.border!, homeLeafFlip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.homeQuizAccuracy, style: homeCaption(p)),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                _Count(
                  a,
                  0.25,
                  0.85,
                  acc == null ? '—' : '$acc%',
                  style: homeNumber(p, 28),
                ),
                HomeRise(
                  a,
                  0.6,
                  0.9,
                  rise: 6,
                  scale: 0.6,
                  curve: ElioMotion.pop,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        down
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 14,
                        color: down ? p.errorText : p.primaryText,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        acc == null
                            ? l10n.noData
                            : delta == null
                            ? '±0'
                            : '${delta >= 0 ? '+' : ''}$delta',
                        style: homeCaption(
                          p,
                          color: down ? p.errorText : p.primaryText,
                          weight: 700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 8),
            // The line draws itself left → right.
            AnimatedBuilder(
              animation: a,
              builder: (context, _) => CustomPaint(
                size: const Size(double.infinity, 60),
                painter: SparklinePainter(
                  points,
                  p.tertiaryText,
                  t: homeSlice(a, 0.3, 0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Medals (629:80645-66): heading with "1 of 3 ›", then the medals hanging
/// from a ribbon across the screen. They swing in on their strings; a tap
/// makes an unlocked medal jump and a locked one shake.
class _Medals extends StatefulWidget {
  const _Medals({required this.medals, required this.a});
  final List<_Medal> medals;
  final Animation<double> a;

  @override
  State<_Medals> createState() => _MedalsState();
}

class _MedalsState extends State<_Medals> {
  late final _taps = [for (final _ in widget.medals) 0];

  void _tap(int i) {
    if (widget.medals[i].unlocked) {
      elioFeedback(ElioSfx.sparkleShort, ElioHaptics.light);
    } else {
      elioFeedback(ElioSfx.knock, ElioHaptics.warning);
    }
    setState(() => _taps[i]++);
  }

  void _seeAll() {
    elioFeedback(ElioSfx.tick, ElioHaptics.select);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: authPalette(context).surface,
      builder: (_) => ElioTheme.wrap(_MedalSheet(medals: widget.medals)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final medals = widget.medals, a = widget.a;
    final unlocked = medals.where((m) => m.unlocked).length;

    Widget column(int i, _Medal m) {
      // The middle medal hangs lower (Figma: strings 14 / 34 / 14).
      final mid = i % 3 == 1;
      final from = 0.25 + 0.13 * i;
      final art = homeArt(
        m.unlocked ? 'medal_gold' : 'medal_locked',
        width: 56,
        height: 66,
      );
      return Semantics(
        container: true,
        button: true,
        label: l10n.a11yMedal(
          m.name,
          m.unlocked ? l10n.a11yUnlocked : l10n.a11yLocked,
          m.description,
        ),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7.5),
            child: Column(
              children: [
                SizedBox(height: mid ? 26 : 22),
                // String and medal swing in like a pendulum from the ribbon.
                AnimatedBuilder(
                  animation: a,
                  builder: (context, child) {
                    final x = homeSlice(a, from, from + 0.55, Curves.linear);
                    return Opacity(
                      opacity: (x * 4).clamp(0.0, 1.0),
                      alwaysIncludeSemantics: true,
                      child: Transform.rotate(
                        angle:
                            (i.isEven ? 0.9 : -0.9) *
                            (1 - Curves.elasticOut.transform(x)),
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: mid ? 34 : 14,
                        color: p.borderStrong,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: m.unlocked
                            ? ElioJump(
                                trigger: _taps[i],
                                height: 12,
                                child: art,
                              )
                            : ElioShake(
                                trigger: _taps[i] == 0 ? null : _taps[i],
                                child: art,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                HomeRise(
                  a,
                  from + 0.2,
                  from + 0.45,
                  rise: 8,
                  child: Text(
                    m.name,
                    textAlign: TextAlign.center,
                    style: homeSmall(
                      p,
                      color: p.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                HomeRise(
                  a,
                  from + 0.3,
                  from + 0.55,
                  rise: 0,
                  scale: m.unlocked ? 0.4 : 1,
                  curve: m.unlocked ? ElioMotion.bounce : ElioMotion.emphasized,
                  child: Text(
                    m.unlocked ? l10n.medalUnlocked : m.hint,
                    textAlign: TextAlign.center,
                    style: homeCaption(
                      p,
                      color: m.unlocked ? p.primaryText : p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHead(
          a: a,
          title: context.l10n.homeMedals,
          squiggle: 72,
          trailing: HomeRise(
            a,
            0.1,
            0.4,
            rise: 0,
            dx: 12,
            child: InkWell(
              onTap: _seeAll,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.homeMedalsOf(unlocked, medals.length),
                      style: ElioTokens.button.copyWith(
                        height: 1.4,
                        color: p.primaryText,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: p.primaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // The ribbon is strung across the whole screen, left → right.
            Positioned(
              left: -16,
              right: -16,
              top: 0,
              height: 40,
              child: AnimatedBuilder(
                animation: a,
                builder: (context, _) => CustomPaint(
                  painter: HomeStrokePainter(
                    _ribbonPath,
                    p.borderStrong,
                    t: homeSlice(a, 0, 0.4),
                  ),
                ),
              ),
            ),
            // Columns centred at 70 / 195 / 320 of 390.
            LayoutBuilder(
              builder: (context, c) => OverflowBox(
                fit: OverflowBoxFit.deferToChild,
                minWidth: c.maxWidth * 375 / 358,
                maxWidth: c.maxWidth * 375 / 358,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, m) in medals.indexed)
                      Expanded(child: column(i, m)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "See all": every medal with how to earn it.
class _MedalSheet extends StatelessWidget {
  const _MedalSheet({required this.medals});
  final List<_Medal> medals;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(context.l10n.homeMedals, style: homeTitle(p)),
            ),
            for (final (i, m) in medals.indexed) ...[
              const SizedBox(height: 16),
              ElioPopIn(
                index: i,
                stagger: const Duration(milliseconds: 60),
                child: Row(
                  children: [
                    homeArt(
                      m.unlocked ? 'medal_gold' : 'medal_locked',
                      width: 44,
                      height: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: homeSmall(
                              p,
                              color: p.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(m.description, style: homeCaption(p)),
                          Text(
                            m.unlocked ? l10n.medalUnlocked : m.hint,
                            style: homeCaption(
                              p,
                              color: m.unlocked
                                  ? p.primaryText
                                  : p.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
