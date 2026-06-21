import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_notification.dart';
import '../models/guide_lesson.dart';
import '../models/learning_progress.dart';
import '../models/video_lesson.dart';
import '../models/waste_category.dart';
import '../providers/app_notification_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/elearning_content_service.dart';
import '../widgets/elio_colors.dart';
import 'tabs/elearning/quiz_review_page.dart';

const _background = Color(0xFFF8FAF9);
const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF6D7A73);
const _border = Color(0xFFE4EAE6);
const _cyan = Color(0xFF00647C);
const _amber = Color(0xFFBA7517);
const _trackedLearningModuleIds = ['organic', 'inorganic', 'hazardous'];

final _elearningContentService = ElearningContentService();

class HomeScreen extends ConsumerWidget {
  final FirebaseAuth auth;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenLearning;

  const HomeScreen({
    super.key,
    required this.auth,
    required this.onOpenDrawer,
    required this.onOpenLearning,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? auth.currentUser;
    final progress = ref.watch(learningProgressProvider);
    final hasSyncWarning = ref.watch(progressSyncWarningProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final isLoading = progress.isLoading;
    final hasError = progress.hasError || hasSyncWarning;

    return StreamBuilder<List<VideoLesson>>(
      stream: _elearningContentService.watchVideoLessons(),
      builder: (context, videoSnapshot) {
        return StreamBuilder<List<GuideLesson>>(
          stream: _elearningContentService.watchGuideLessons(),
          builder: (context, guideSnapshot) {
            final inventory = _LearningContentInventory(
              videos: videoSnapshot.data ?? const <VideoLesson>[],
              guides: guideSnapshot.data ?? const <GuideLesson>[],
              totalQuizModules: LearningProgress.fallbackTotalQuizModules,
              videosLoaded: videoSnapshot.hasData,
              guidesLoaded: guideSnapshot.hasData,
            );
            final dashboard = progress.when(
              loading: _DashboardData.empty,
              error: (error, stackTrace) {
                debugPrint('Learning progress error: $error');
                return _DashboardData.empty();
              },
              data: (progress) =>
                  _DashboardData.from(progress, inventory: inventory),
            );

            void openResumeItem(_ContinueLearningItem item) {
              final type = switch (item.type) {
                _LearningActivityType.video => LearningResumeType.video,
                _LearningActivityType.guide => LearningResumeType.guide,
                _LearningActivityType.quiz => LearningResumeType.quiz,
                _LearningActivityType.module => null,
              };

              if (type == null) {
                onOpenLearning();
                return;
              }

              ref
                  .read(learningResumeIntentProvider.notifier)
                  .state = LearningResumeIntent(
                type: type,
                id: item.id,
                moduleId: item.moduleId,
              );

              onOpenLearning();
            }

            return Scaffold(
              backgroundColor: _background,
              body: SafeArea(
                child: RefreshIndicator(
                  color: elioGreen,
                  onRefresh: () => ref.refresh(learningProgressProvider.future),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                        sliver: SliverList.list(
                          children: [
                            _TopBar(
                              name: _displayNameFor(user),
                              photoUrl: user?.photoURL,
                              onMenuPressed: onOpenDrawer,
                              unreadNotificationCount: unreadNotifications,
                              onNotificationsPressed: () =>
                                  _showNotificationsSheet(
                                    context: context,
                                    onOpenLearning: onOpenLearning,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            _Dashboard(
                              data: dashboard,
                              isGuest: user?.isAnonymous ?? true,
                              isLoading: isLoading,
                              hasProgressError: hasError,
                              onRetry: () =>
                                  ref.invalidate(learningProgressProvider),
                              onOpenLearning: onOpenLearning,
                              onResumeLearningItem: openResumeItem,
                              onSelectTab: (index) {
                                ref
                                        .read(navigationIndexProvider.notifier)
                                        .state =
                                    index;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _displayNameFor(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Guest';
  }
}

class _Dashboard extends StatelessWidget {
  final _DashboardData data;
  final bool isGuest;
  final bool isLoading;
  final bool hasProgressError;
  final VoidCallback onRetry;
  final VoidCallback onOpenLearning;
  final ValueChanged<_ContinueLearningItem> onResumeLearningItem;
  final ValueChanged<int> onSelectTab;

  const _Dashboard({
    required this.data,
    required this.isGuest,
    required this.isLoading,
    required this.hasProgressError,
    required this.onRetry,
    required this.onOpenLearning,
    required this.onResumeLearningItem,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasProgressError) ...[
          _ProgressWarning(onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        _HeroCard(data: data),
        if (isLoading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Color(0xFFE6E9E8),
            valueColor: AlwaysStoppedAnimation(elioGreen),
          ),
        ],
        const SizedBox(height: 22),
        const _SectionHeader(title: 'Continue Learning'),
        const SizedBox(height: 10),
        _ContinueLearningCard(
          data: data,
          onTap: onOpenLearning,
          onResumeLearningItem: onResumeLearningItem,
        ),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'Your Progress',
          actionLabel: 'View learning',
          onActionTap: onOpenLearning,
        ),
        const SizedBox(height: 10),
        _ProgressGrid(data: data, onOpenLearning: onOpenLearning),
        const SizedBox(height: 22),
        const _InsightCard(),
        const SizedBox(height: 22),
        const _SectionHeader(title: 'Achievements'),
        const SizedBox(height: 10),
        _AchievementList(data: data),
        const SizedBox(height: 22),
        const _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 6),
        _RecentActivityList(activities: data.activities),
        const SizedBox(height: 22),
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 10),
        _QuickActions(onOpenLearning: onOpenLearning, onSelectTab: onSelectTab),
        if (isGuest) ...[const SizedBox(height: 20), const _GuestBanner()],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final int unreadNotificationCount;

  const _TopBar({
    required this.name,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    required this.unreadNotificationCount,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuPressed,
          tooltip: 'Open navigation menu',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            side: const BorderSide(color: _border),
          ),
          icon: const Icon(Icons.menu_rounded, size: 21),
        ),
        const SizedBox(width: 9),
        CircleAvatar(
          radius: 20,
          backgroundColor: elioGreen.withValues(alpha: 0.1),
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
          child: photoUrl == null
              ? const Icon(Icons.person_rounded, color: elioGreen)
              : null,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                'Ready to learn with ELIO?',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationsPressed,
              tooltip: 'Open notifications',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                side: const BorderSide(color: _border),
              ),
              icon: const Icon(Icons.notifications_none_rounded, size: 21),
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBA1A1A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadNotificationCount > 9
                        ? '9+'
                        : '$unreadNotificationCount',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final _DashboardData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 10, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 330;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Welcome\nto '),
                                TextSpan(
                                  text: 'ELIO',
                                  style: GoogleFonts.sora(color: elioGreen),
                                ),
                              ],
                            ),
                            style: GoogleFonts.sora(
                              fontSize: compact ? 20 : 22,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Learn Environmental Physics through Robotics, AI & Smart Waste Sorting.',
                            style: GoogleFonts.manrope(
                              fontSize: compact ? 10 : 11,
                              height: 1.55,
                              color: const Color(0xFF3D4943),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: data.overallProgress,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFFE6E9E8),
                                    valueColor: const AlwaysStoppedAnimation(
                                      elioGreen,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${data.progressPercent}%',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: elioGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: compact ? 6 : 12),
                    _ElioRobot3DViewer(size: compact ? 126 : 144),
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                _HeroStat(label: 'Learning', value: data.learningItemsValue),
                _HeroStat(label: 'Quiz Avg', value: data.quizValue),
                _HeroStat(label: 'Current', value: data.currentShortLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElioRobot3DViewer extends StatefulWidget {
  final double size;

  const _ElioRobot3DViewer({required this.size});

  @override
  State<_ElioRobot3DViewer> createState() => _ElioRobot3DViewerState();
}

class _ElioRobot3DViewerState extends State<_ElioRobot3DViewer> {
  final Flutter3DController _controller = Flutter3DController();
  bool _hasError = false;
  bool _isLoaded = false;

  void _handleLoad(String modelAddress) {
    if (!mounted) return;
    debugPrint('ELIO 3D model loaded: $modelAddress');
    setState(() => _isLoaded = true);
  }

  void _handleError(String error) {
    debugPrint('ELIO 3D model failed to load: $error');
    if (!mounted) return;
    setState(() => _hasError = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _RotatingRobotStage(size: widget.size);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size + 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF4F0),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Flutter3DViewer(
              controller: _controller,
              src: 'assets/models/robot-elio.glb',
              enableTouch: true,
              activeGestureInterceptor: true,
              progressBarColor: elioGreen,
              onLoad: _handleLoad,
              onError: _handleError,
            ),
          ),
          if (!_isLoaded)
            IgnorePointer(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  color: Color(0x99EDF4F0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: elioGreen,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Row(
              children: [
                const Icon(
                  Icons.swipe_rounded,
                  size: 11,
                  color: Color(0x7300684C),
                ),
                const SizedBox(width: 4),
                Text(
                  'DRAG TO ROTATE',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0x7300684C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingRobotStage extends StatefulWidget {
  final double size;

  const _RotatingRobotStage({required this.size});

  @override
  State<_RotatingRobotStage> createState() => _RotatingRobotStageState();
}

class _RotatingRobotStageState extends State<_RotatingRobotStage> {
  double _angle = 0.18;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() => _angle += details.delta.dx * 0.018);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size + 18,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                color: Color(0xFFEDF4F0),
                shape: BoxShape.circle,
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(_angle)
                ..rotateZ(math.sin(_angle) * 0.04),
              child: Container(
                width: widget.size * 0.58,
                height: widget.size * 0.64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: elioGreen.withValues(alpha: 0.13)),
                  boxShadow: [
                    BoxShadow(
                      color: elioGreen.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: widget.size * 0.36,
                      height: widget.size * 0.25,
                      decoration: BoxDecoration(
                        color: elioGreen,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [_RobotEye(), _RobotEye()],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: widget.size * 0.32,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF86F8C9),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Row(
                children: [
                  const Icon(
                    Icons.swipe_rounded,
                    size: 11,
                    color: Color(0x7300684C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'DRAG TO ROTATE',
                    style: GoogleFonts.manrope(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0x7300684C),
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

class _RobotEye extends StatelessWidget {
  const _RobotEye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: Color(0xFF86F8C9),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _border)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressWarning extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProgressWarning({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _amber, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Progress could not be loaded. Showing local empty state.',
              style: GoogleFonts.manrope(
                fontSize: 10,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7A511C),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: _amber,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  final _DashboardData data;
  final VoidCallback onTap;
  final ValueChanged<_ContinueLearningItem> onResumeLearningItem;

  const _ContinueLearningCard({
    required this.data,
    required this.onTap,
    required this.onResumeLearningItem,
  });

  @override
  Widget build(BuildContext context) {
    final item = data.continueItem;
    final hasResumeItem = item != null;
    final resumeItem = item;
    final hasStarted = data.overallProgress > 0;
    final label = hasResumeItem || hasStarted
        ? 'CONTINUE LEARNING'
        : 'START LEARNING';
    final title = hasResumeItem
        ? resumeItem!.title
        : hasStarted
        ? data.currentModule
        : 'Module 1 · Introduction to ELIO';
    final subtitle = hasResumeItem
        ? '${_activityTypeLabel(resumeItem!.type)} · ${resumeItem.subtitle}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: elioGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: elioGreen.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              if (data.unfinishedItems.isEmpty) {
                onTap();
                return;
              }

              _showUnfinishedLearningSheet(
                context: context,
                items: data.unfinishedItems,
                onOpenLearning: onTap,
                onSelectItem: onResumeLearningItem,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: elioGreen,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              minimumSize: Size.zero,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: Text(
              hasResumeItem
                  ? 'Continue'
                  : hasStarted
                  ? 'Continue Module'
                  : 'Start Module 1',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressGrid extends StatelessWidget {
  final _DashboardData data;
  final VoidCallback onOpenLearning;

  const _ProgressGrid({required this.data, required this.onOpenLearning});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ProgressCard(
                icon: Icons.menu_book_rounded,
                iconColor: elioGreen,
                iconBackground: elioGreen.withValues(alpha: 0.08),
                label: 'Learning',
                value: data.learningItemsValue,
                subtitle: data.completedLearningItems == 0
                    ? 'No learning completed yet'
                    : '${data.completedLearningItems} learning items completed',
                onTap: () => _showLearningProgressSheet(
                  context: context,
                  data: data,
                  onOpenLearning: onOpenLearning,
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ProgressCard(
                icon: Icons.quiz_rounded,
                iconColor: _cyan,
                iconBackground: _cyan.withValues(alpha: 0.08),
                label: 'Quiz Avg',
                value: data.quizValue,
                subtitle: data.quizAttemptCount == 0
                    ? 'No quiz attempts yet'
                    : '${data.quizAttemptCount} quiz attempts',
                onTap: () => _showQuizProgressSheet(
                  context: context,
                  data: data,
                  onOpenLearning: onOpenLearning,
                ),
              ),
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: _ProgressCard(
                icon: Icons.play_lesson_rounded,
                iconColor: _amber,
                iconBackground: _amber.withValues(alpha: 0.1),
                label: 'Current Module',
                value: data.currentModule,
                subtitle: data.currentModule == 'Not started'
                    ? 'Start your first learning module'
                    : data.currentTimestamp == null
                    ? 'Continue this learning module'
                    : 'Last opened ${_relativeTime(data.currentTimestamp!)}',
                horizontal: true,
                onTap: () => _showCurrentModuleSheet(
                  context: context,
                  data: data,
                  onOpenLearning: onOpenLearning,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String subtitle;
  final bool horizontal;
  final VoidCallback? onTap;

  const _ProgressCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.subtitle,
    this.horizontal = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 17, color: iconColor),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: _muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: horizontal ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
            fontSize: horizontal ? 17 : 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(fontSize: 10, color: _muted),
        ),
      ],
    );

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: horizontal
          ? Row(
              children: [
                iconWidget,
                const SizedBox(width: 13),
                Expanded(child: content),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [iconWidget, const SizedBox(height: 9), content],
            ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 18, 17),
      decoration: BoxDecoration(
        color: elioGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: elioGreen.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [elioGreen, _cyan],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DID YOU KNOW?',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: elioGreen,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Smart sorting starts with recognizing the material.',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Explore each waste category to see how AI helps ELIO classify it.',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    height: 1.5,
                    color: const Color(0xFF3D4943),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 4),
              foregroundColor: elioGreen,
            ),
            child: Text(
              actionLabel!,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementList extends StatelessWidget {
  final _DashboardData data;

  const _AchievementList({required this.data});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      _Achievement(
        name: 'Environmental Explorer',
        description: 'Complete at least 3 learning items',
        icon: Icons.explore_rounded,
        color: _amber,
        unlocked: data.completedLearningItems >= 3,
      ),
      _Achievement(
        name: 'Robotics Beginner',
        description: 'Start the Introduction to ELIO module',
        icon: Icons.smart_toy_rounded,
        color: elioGreen,
        unlocked: data.roboticsStarted,
      ),
      _Achievement(
        name: 'Sustainability Advocate',
        description: 'Complete all environmental empathy reflections',
        icon: Icons.volunteer_activism_rounded,
        color: _cyan,
        unlocked: data.reflectionsCompleted,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < achievements.length; i++) ...[
          _AchievementCard(achievement: achievements[i]),
          if (i != achievements.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return AnimatedOpacity(
      opacity: unlocked ? 1 : 0.56,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: unlocked
                    ? achievement.color.withValues(alpha: 0.1)
                    : const Color(0xFFECEFED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                achievement.icon,
                color: unlocked ? achievement.color : _muted,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    unlocked
                        ? achievement.description
                        : 'Start learning to unlock achievements',
                    style: GoogleFonts.manrope(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: unlocked
                    ? elioGreen.withValues(alpha: 0.1)
                    : const Color(0xFFE8EBE9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 13,
                color: unlocked ? elioGreen : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<_HomeActivity> activities;

  const _RecentActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            const Icon(Icons.history_rounded, color: _muted, size: 28),
            const SizedBox(height: 9),
            Text(
              'Your lessons, videos, quizzes, and reflections will appear here once you begin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.5,
                color: _muted,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: i == activities.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activities[i].color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activities[i].title,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        if (activities[i].subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            activities[i].subtitle,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _relativeTime(activities[i].timestamp),
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UnfinishedLearningTile extends StatelessWidget {
  final _ContinueLearningItem item;
  final VoidCallback onTap;

  const _UnfinishedLearningTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      _LearningActivityType.video => Icons.play_circle_fill_rounded,
      _LearningActivityType.guide => Icons.picture_as_pdf_rounded,
      _LearningActivityType.quiz => Icons.quiz_rounded,
      _LearningActivityType.module => Icons.menu_book_rounded,
    };

    final color = switch (item.type) {
      _LearningActivityType.video => _amber,
      _LearningActivityType.guide => _cyan,
      _LearningActivityType.quiz => elioGreen,
      _LearningActivityType.module => elioGreen,
    };

    final subtitleParts = <String>[
      _activityTypeLabel(item.type),
      item.subtitle,
      if (item.timestamp != null) _relativeTime(item.timestamp!),
    ];
    final hasThumbnail =
        item.type == _LearningActivityType.video &&
        item.thumbnailAsset != null &&
        item.thumbnailAsset!.trim().isNotEmpty;
    final progress = item.progress?.clamp(0.0, 1.0);
    final showProgress =
        progress != null &&
        (item.type == _LearningActivityType.video ||
            item.type == _LearningActivityType.guide);

    Widget iconBox() {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              if (hasThumbnail)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.thumbnailAsset!,
                    width: 74,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => iconBox(),
                  ),
                )
              else
                iconBox(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE6E9E8),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedLearningTile extends StatelessWidget {
  final _CompletedLearningItem item;

  const _CompletedLearningTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == _LearningActivityType.video;
    final isGuide = item.type == _LearningActivityType.guide;
    final color = isVideo
        ? _amber
        : isGuide
        ? _cyan
        : elioGreen;
    final icon = isVideo
        ? Icons.play_circle_fill_rounded
        : isGuide
        ? Icons.picture_as_pdf_rounded
        : Icons.quiz_rounded;
    final hasPreview =
        item.previewAsset != null && item.previewAsset!.trim().isNotEmpty;
    final previewWidth = isVideo
        ? 74.0
        : isGuide
        ? 52.0
        : 48.0;
    final previewHeight = isVideo
        ? 48.0
        : isGuide
        ? 64.0
        : 48.0;
    final subtitle = item.timestamp == null
        ? item.subtitle
        : '${item.subtitle} · ${_relativeTime(item.timestamp!)}';

    Widget fallbackPreview() {
      return Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      );
    }

    final preview = hasPreview
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              item.previewAsset!,
              width: previewWidth,
              height: previewHeight,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallbackPreview(),
            ),
          )
        : fallbackPreview();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          preview,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: elioGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: elioGreen, size: 15),
          ),
        ],
      ),
    );
  }
}

class _QuizHistoryTile extends StatelessWidget {
  final _HomeActivity activity;
  final VoidCallback? onReview;

  const _QuizHistoryTile({required this.activity, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final hasReview = activity.quizReview != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasReview
                  ? Icons.fact_check_outlined
                  : Icons.history_edu_outlined,
              color: activity.color,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: GoogleFonts.manrope(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    activity.subtitle,
                    _relativeTime(activity.timestamp),
                  ].join(' • '),
                  style: GoogleFonts.manrope(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasReview)
                  OutlinedButton.icon(
                    onPressed: onReview,
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Review Answers'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: elioGreen,
                      visualDensity: VisualDensity.compact,
                      textStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    'Past Attempt • Review available for new attempts only',
                    style: GoogleFonts.manrope(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback? onAction;

  const _NotificationTile({required this.item, this.onAction});

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(item.type);
    final actionLabel = item.actionLabel ?? _notificationActionLabel(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_notificationIcon(item.type), color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.manrope(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.message} • ${_relativeTime(item.createdAt)}',
                  style: GoogleFonts.manrope(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: elioGreen,
                      visualDensity: VisualDensity.compact,
                      textStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_none_rounded, color: _muted, size: 30),
          const SizedBox(height: 10),
          Text(
            'No notifications right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Learning reminders, quiz review updates, and progress alerts will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _muted,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSheetEmptyMessage extends StatelessWidget {
  final String message;

  const _ProgressSheetEmptyMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenLearning;
  final ValueChanged<int> onSelectTab;

  const _QuickActions({
    required this.onOpenLearning,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Learn',
                subtitle: 'Lessons and quizzes',
                onTap: onOpenLearning,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.settings_input_component_rounded,
                title: 'Config',
                subtitle: 'Connect ELIO',
                onTap: () => onSelectTab(2),
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.tune_rounded,
                title: 'Control',
                subtitle: 'Drive the robot',
                onTap: () => onSelectTab(3),
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.videocam_rounded,
                title: 'Camera',
                subtitle: 'View camera tools',
                onTap: () => onSelectTab(3),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: elioGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: elioGreen, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Guest progress is stored on this device. Sign in to sync it across devices.',
              style: GoogleFonts.manrope(
                fontSize: 11,
                height: 1.45,
                color: const Color(0xFF7A511C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningContentInventory {
  final List<VideoLesson> videos;
  final List<GuideLesson> guides;
  final int totalQuizModules;
  final bool videosLoaded;
  final bool guidesLoaded;

  const _LearningContentInventory({
    required this.videos,
    required this.guides,
    required this.totalQuizModules,
    required this.videosLoaded,
    required this.guidesLoaded,
  });

  const _LearningContentInventory.empty()
    : videos = const [],
      guides = const [],
      totalQuizModules = LearningProgress.fallbackTotalQuizModules,
      videosLoaded = false,
      guidesLoaded = false;
}

class _DashboardData {
  final int completedModules;
  final int completedLearningItems;
  final int totalLearningItems;
  final int completedVideos;
  final int totalVideos;
  final int completedGuides;
  final int totalGuides;
  final int completedQuizModules;
  final int totalQuizModules;
  final int quizAttemptCount;
  final int? quizAverage;
  final double overallProgress;
  final String currentModule;
  final DateTime? currentTimestamp;
  final bool roboticsStarted;
  final bool reflectionsCompleted;
  final List<_HomeActivity> activities;
  final _ContinueLearningItem? continueItem;
  final List<_ContinueLearningItem> unfinishedItems;
  final List<_CompletedLearningItem> completedLearningItemsList;

  const _DashboardData({
    required this.completedModules,
    required this.completedLearningItems,
    required this.totalLearningItems,
    required this.completedVideos,
    required this.totalVideos,
    required this.completedGuides,
    required this.totalGuides,
    required this.completedQuizModules,
    required this.totalQuizModules,
    required this.quizAttemptCount,
    required this.quizAverage,
    required this.overallProgress,
    required this.currentModule,
    required this.currentTimestamp,
    required this.roboticsStarted,
    required this.reflectionsCompleted,
    required this.activities,
    required this.continueItem,
    required this.unfinishedItems,
    required this.completedLearningItemsList,
  });

  String get learningItemsValue =>
      '$completedLearningItems/$totalLearningItems';
  String get quizValue => quizAverage == null ? '--' : '$quizAverage%';
  int get progressPercent => (overallProgress * 100).round();

  factory _DashboardData.empty() {
    const inventory = _LearningContentInventory.empty();
    final totalVideos = inventory.videosLoaded
        ? inventory.videos.length
        : LearningProgress.fallbackTotalVideoLessons;
    final totalGuides = inventory.guidesLoaded
        ? inventory.guides.length
        : LearningProgress.fallbackTotalGuideLessons;
    final totalLearningItems =
        totalVideos + totalGuides + inventory.totalQuizModules;

    return _DashboardData(
      completedModules: 0,
      completedLearningItems: 0,
      totalLearningItems: totalLearningItems,
      completedVideos: 0,
      totalVideos: totalVideos,
      completedGuides: 0,
      totalGuides: totalGuides,
      completedQuizModules: 0,
      totalQuizModules: inventory.totalQuizModules,
      quizAttemptCount: 0,
      quizAverage: null,
      overallProgress: 0.0,
      currentModule: 'Not started',
      currentTimestamp: null,
      roboticsStarted: false,
      reflectionsCompleted: false,
      activities: [],
      continueItem: null,
      unfinishedItems: const [],
      completedLearningItemsList: const [],
    );
  }

  String get currentShortLabel {
    if (currentModule == 'Not started') return currentModule;
    final match = RegExp(
      r'(Module\s+\d+)',
      caseSensitive: false,
    ).firstMatch(currentModule);
    return match?.group(1) ?? currentModule;
  }

  factory _DashboardData.from(
    LearningProgress progress, {
    required _LearningContentInventory inventory,
  }) {
    final totalVideos = inventory.videosLoaded
        ? inventory.videos.length
        : LearningProgress.fallbackTotalVideoLessons;
    final totalGuides = inventory.guidesLoaded
        ? inventory.guides.length
        : LearningProgress.fallbackTotalGuideLessons;
    final totalQuizModules = inventory.totalQuizModules;
    final videoProgress = inventory.videosLoaded
        ? _averageVideoProgress(progress, inventory.videos)
        : progress.videoProgress;
    final guideProgress = inventory.guidesLoaded
        ? _averageGuideProgress(progress, inventory.guides)
        : progress.guideProgress;
    final quizProgress = totalQuizModules <= 0
        ? 0.0
        : (progress.completedQuizModules.length / totalQuizModules).clamp(
            0.0,
            1.0,
          );
    final overallProgress = _weightedOverallProgress(
      videoProgress: videoProgress,
      totalVideos: totalVideos,
      guideProgress: guideProgress,
      totalGuides: totalGuides,
      quizProgress: quizProgress,
      totalQuizModules: totalQuizModules,
    );
    final completedVideos = totalVideos <= 0
        ? 0
        : math.min(progress.completedVideoIds.length, totalVideos);
    final completedGuides = totalGuides <= 0
        ? 0
        : math.min(progress.completedGuideIds.length, totalGuides);
    final completedQuizModules = totalQuizModules <= 0
        ? 0
        : math.min(progress.completedQuizModules.length, totalQuizModules);
    final completedLearningItems =
        completedVideos + completedGuides + completedQuizModules;
    final totalLearningItems = totalVideos + totalGuides + totalQuizModules;

    final activeEntries = progress.categories.entries
        .where(
          (entry) =>
              _trackedLearningModuleIds.contains(entry.key) &&
              entry.value.progressPercentage > 0,
        )
        .toList();

    final quizEntries = activeEntries
        .where(
          (entry) =>
              entry.value.quizAttempts > 0 && entry.value.totalQuestions > 0,
        )
        .toList();
    final quizAttemptCount = quizEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.value.quizAttempts,
    );
    final quizAverage = quizEntries.isEmpty
        ? null
        : (quizEntries.fold<double>(
                    0,
                    (sum, entry) =>
                        sum +
                        (entry.value.quizBestScore /
                            entry.value.totalQuestions),
                  ) /
                  quizEntries.length *
                  100)
              .round();

    activeEntries.sort(
      (a, b) => (b.value.lastAccessed ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
            a.value.lastAccessed ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );

    final currentEntry = activeEntries.isEmpty ? null : activeEntries.first;
    final currentModule = currentEntry == null
        ? 'Not started'
        : _moduleTitle(currentEntry.key);
    final currentTimestamp = currentEntry?.value.lastAccessed;
    final unfinishedItems = _buildContinueItems(
      progress: progress,
      videos: inventory.videos,
      guides: inventory.guides,
    );
    final continueItem = unfinishedItems.isEmpty ? null : unfinishedItems.first;
    final completedLearningItemsList = _buildCompletedLearningItems(
      progress: progress,
      videos: inventory.videos,
      guides: inventory.guides,
    );

    final roboticsStarted = activeEntries.any((entry) {
      final searchable = '${entry.key} ${_moduleTitle(entry.key)}'
          .toLowerCase();
      return searchable.contains('elio') ||
          searchable.contains('robot') ||
          searchable.contains('introduction');
    });

    final reflectionEntries = activeEntries.where((entry) {
      final searchable = '${entry.key} ${_moduleTitle(entry.key)}'
          .toLowerCase();
      return searchable.contains('reflection') ||
          searchable.contains('empathy');
    }).toList();
    final reflectionsCompleted =
        reflectionEntries.isNotEmpty &&
        reflectionEntries.every((entry) => entry.value.lessonViewed);

    final itemActivities = <_HomeActivity>[
      ..._buildVideoActivities(progress, inventory.videos),
      ..._buildGuideActivities(progress, inventory.guides),
      ..._buildQuizActivities(progress),
    ];

    itemActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final fallbackCategoryActivities = activeEntries
        .where((entry) => entry.value.lastAccessed != null)
        .map((entry) {
          final attemptedQuiz = entry.value.quizAttempts > 0;
          return _HomeActivity(
            type: attemptedQuiz
                ? _LearningActivityType.quiz
                : _LearningActivityType.module,
            id: entry.key,
            title: attemptedQuiz
                ? 'Completed quiz: ${_moduleTitle(entry.key)}'
                : 'Opened module: ${_moduleTitle(entry.key)}',
            subtitle: attemptedQuiz
                ? 'Quiz attempted'
                : 'Learning module opened',
            timestamp: entry.value.lastAccessed!,
            color: attemptedQuiz ? _cyan : elioGreen,
            isCompleted: attemptedQuiz,
            quizReview: attemptedQuiz ? progress.quizReviews[entry.key] : null,
          );
        })
        .toList();
    final activities = itemActivities.isNotEmpty
        ? itemActivities.take(5).toList()
        : fallbackCategoryActivities.take(5).toList();

    return _DashboardData(
      completedModules: completedLearningItems,
      completedLearningItems: completedLearningItems,
      totalLearningItems: totalLearningItems,
      completedVideos: completedVideos,
      totalVideos: totalVideos,
      completedGuides: completedGuides,
      totalGuides: totalGuides,
      completedQuizModules: completedQuizModules,
      totalQuizModules: totalQuizModules,
      quizAttemptCount: quizAttemptCount,
      quizAverage: quizAverage,
      overallProgress: overallProgress,
      currentModule: currentModule,
      currentTimestamp: currentTimestamp,
      roboticsStarted: roboticsStarted,
      reflectionsCompleted: reflectionsCompleted,
      activities: activities,
      continueItem: continueItem,
      unfinishedItems: unfinishedItems,
      completedLearningItemsList: completedLearningItemsList,
    );
  }

  static double _averageVideoProgress(
    LearningProgress progress,
    List<VideoLesson> videos,
  ) {
    if (videos.isEmpty) return 0.0;

    final total = videos.fold<double>(0.0, (sum, lesson) {
      if (progress.completedVideoIds.contains(lesson.id)) return sum + 1.0;

      final duration = lesson.durationSeconds > 0 ? lesson.durationSeconds : 1;
      final watched = progress.videoWatchProgress[lesson.id] ?? 0;
      return sum + (watched / duration).clamp(0.0, 1.0);
    });

    return (total / videos.length).clamp(0.0, 1.0);
  }

  static double _averageGuideProgress(
    LearningProgress progress,
    List<GuideLesson> guides,
  ) {
    if (guides.isEmpty) return 0.0;

    final total = guides.fold<double>(0.0, (sum, guide) {
      if (progress.completedGuideIds.contains(guide.id)) return sum + 1.0;

      final pageCount = guide.pageCount > 0 ? guide.pageCount : 1;
      final readPages = progress.guideReadProgress[guide.id] ?? 0;
      return sum + (readPages / pageCount).clamp(0.0, 1.0);
    });

    return (total / guides.length).clamp(0.0, 1.0);
  }

  static List<_HomeActivity> _buildVideoActivities(
    LearningProgress progress,
    List<VideoLesson> videos,
  ) {
    final byId = {for (final video in videos) video.id: video};
    final activities = <_HomeActivity>[];

    for (final entry in progress.videoLastAccessed.entries) {
      final video = byId[entry.key];
      if (video == null) continue;

      final duration = video.durationSeconds > 0 ? video.durationSeconds : 1;
      final watched = progress.videoWatchProgress[video.id] ?? 0;
      final completed =
          progress.completedVideoIds.contains(video.id) || watched >= duration;
      final percent = (watched / duration).clamp(0.0, 1.0);
      final percentText = (percent * 100).round();

      activities.add(
        _HomeActivity(
          type: _LearningActivityType.video,
          id: video.id,
          title: completed
              ? 'Completed video: ${video.title}'
              : 'Watched video: ${video.title}',
          subtitle: completed ? 'Video completed' : '$percentText% watched',
          timestamp: entry.value,
          color: completed ? elioGreen : _amber,
          isCompleted: completed,
        ),
      );
    }

    return activities;
  }

  static List<_HomeActivity> _buildGuideActivities(
    LearningProgress progress,
    List<GuideLesson> guides,
  ) {
    final byId = {for (final guide in guides) guide.id: guide};
    final activities = <_HomeActivity>[];

    for (final entry in progress.guideLastAccessed.entries) {
      final guide = byId[entry.key];
      if (guide == null) continue;

      final pageCount = guide.pageCount > 0 ? guide.pageCount : 1;
      final readPages = progress.guideReadProgress[guide.id] ?? 0;
      final completed =
          progress.completedGuideIds.contains(guide.id) ||
          readPages >= pageCount;

      activities.add(
        _HomeActivity(
          type: _LearningActivityType.guide,
          id: guide.id,
          title: completed
              ? 'Completed guide: ${guide.title}'
              : 'Read guide: ${guide.title}',
          subtitle: completed
              ? 'Guide completed'
              : 'Page $readPages of $pageCount',
          timestamp: entry.value,
          color: completed ? elioGreen : _cyan,
          isCompleted: completed,
        ),
      );
    }

    return activities;
  }

  static List<_HomeActivity> _buildQuizActivities(LearningProgress progress) {
    final activities = <_HomeActivity>[];

    for (final entry in progress.quizLastAccessed.entries) {
      final quizId = entry.key;
      final completed = progress.completedQuizModules.contains(quizId);
      final score = progress.quizScores[quizId];

      activities.add(
        _HomeActivity(
          type: _LearningActivityType.quiz,
          id: quizId,
          title: completed
              ? 'Completed quiz: ${_moduleTitle(quizId)}'
              : 'Attempted quiz: ${_moduleTitle(quizId)}',
          subtitle: score == null ? 'Quiz attempted' : 'Best score $score%',
          timestamp: entry.value,
          color: completed ? elioGreen : _cyan,
          isCompleted: completed,
          quizReview: progress.quizReviews[quizId],
        ),
      );
    }

    return activities;
  }

  static List<_CompletedLearningItem> _buildCompletedLearningItems({
    required LearningProgress progress,
    required List<VideoLesson> videos,
    required List<GuideLesson> guides,
  }) {
    final items = <_CompletedLearningItem>[];

    for (final video in videos) {
      if (!progress.completedVideoIds.contains(video.id)) continue;

      final timestamp = progress.videoLastAccessed[video.id];

      items.add(
        _CompletedLearningItem(
          type: _LearningActivityType.video,
          id: video.id,
          title: video.title,
          subtitle: 'Video completed',
          timestamp: timestamp,
          previewAsset: video.thumbnailAsset,
        ),
      );
    }

    for (final guide in guides) {
      if (!progress.completedGuideIds.contains(guide.id)) continue;

      final timestamp = progress.guideLastAccessed[guide.id];

      items.add(
        _CompletedLearningItem(
          type: _LearningActivityType.guide,
          id: guide.id,
          title: guide.title,
          subtitle: 'Guide completed',
          timestamp: timestamp,
          previewAsset: guide.coverAsset,
        ),
      );
    }

    for (final quizId in progress.completedQuizModules) {
      final timestamp = progress.quizLastAccessed[quizId];
      final score = progress.quizScores[quizId];

      items.add(
        _CompletedLearningItem(
          type: _LearningActivityType.quiz,
          id: quizId,
          title: _moduleTitle(quizId),
          subtitle: score == null
              ? 'Quiz completed'
              : 'Quiz completed • Best score $score%',
          timestamp: timestamp,
          previewAsset: null,
        ),
      );
    }

    items.sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return items;
  }

  static List<_ContinueLearningItem> _buildContinueItems({
    required LearningProgress progress,
    required List<VideoLesson> videos,
    required List<GuideLesson> guides,
  }) {
    final candidates = <_ContinueLearningItem>[];

    final videosById = {for (final video in videos) video.id: video};
    for (final entry in progress.videoLastAccessed.entries) {
      final video = videosById[entry.key];
      if (video == null) continue;

      final duration = video.durationSeconds > 0 ? video.durationSeconds : 1;
      final watched = progress.videoWatchProgress[video.id] ?? 0;
      final completed =
          progress.completedVideoIds.contains(video.id) || watched >= duration;
      if (watched <= 0 || completed) continue;

      final percent = (watched / duration).clamp(0.0, 1.0);
      candidates.add(
        _ContinueLearningItem(
          type: _LearningActivityType.video,
          id: video.id,
          title: video.title,
          subtitle: '${(percent * 100).round()}% watched',
          progress: percent,
          timestamp: entry.value,
          isCompleted: false,
          moduleId: video.moduleId,
          thumbnailAsset: video.thumbnailAsset,
        ),
      );
    }

    final guidesById = {for (final guide in guides) guide.id: guide};
    for (final entry in progress.guideLastAccessed.entries) {
      final guide = guidesById[entry.key];
      if (guide == null) continue;

      final pageCount = guide.pageCount > 0 ? guide.pageCount : 1;
      final readPages = progress.guideReadProgress[guide.id] ?? 0;
      final completed =
          progress.completedGuideIds.contains(guide.id) ||
          readPages >= pageCount;
      if (readPages <= 0 || completed) continue;

      final percent = (readPages / pageCount).clamp(0.0, 1.0);
      candidates.add(
        _ContinueLearningItem(
          type: _LearningActivityType.guide,
          id: guide.id,
          title: guide.title,
          subtitle: 'Page $readPages of $pageCount',
          progress: percent,
          timestamp: entry.value,
          isCompleted: false,
          moduleId: guide.moduleId,
        ),
      );
    }

    candidates.sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return candidates;
  }

  static double _weightedOverallProgress({
    required double videoProgress,
    required int totalVideos,
    required double guideProgress,
    required int totalGuides,
    required double quizProgress,
    required int totalQuizModules,
  }) {
    var weightedSum = 0.0;
    var totalWeight = 0.0;

    if (totalVideos > 0) {
      weightedSum += videoProgress * 0.4;
      totalWeight += 0.4;
    }

    if (totalGuides > 0) {
      weightedSum += guideProgress * 0.2;
      totalWeight += 0.2;
    }

    if (totalQuizModules > 0) {
      weightedSum += quizProgress * 0.4;
      totalWeight += 0.4;
    }

    if (totalWeight == 0) return 0.0;
    return (weightedSum / totalWeight).clamp(0.0, 1.0);
  }
}

class _Achievement {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _Achievement({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });
}

enum _LearningActivityType { video, guide, quiz, module }

class _ContinueLearningItem {
  final _LearningActivityType type;
  final String id;
  final String title;
  final String subtitle;
  final double? progress;
  final DateTime? timestamp;
  final bool isCompleted;
  final String? moduleId;
  final String? thumbnailAsset;

  const _ContinueLearningItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.timestamp,
    required this.isCompleted,
    this.moduleId,
    this.thumbnailAsset,
  });
}

class _CompletedLearningItem {
  final _LearningActivityType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final String? previewAsset;

  const _CompletedLearningItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.previewAsset,
  });
}

class _HomeActivity {
  final _LearningActivityType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Color color;
  final bool isCompleted;
  final QuizReview? quizReview;

  const _HomeActivity({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
    required this.isCompleted,
    this.quizReview,
  });
}

String _activityTypeLabel(_LearningActivityType type) {
  switch (type) {
    case _LearningActivityType.video:
      return 'Video';
    case _LearningActivityType.guide:
      return 'Guide';
    case _LearningActivityType.quiz:
      return 'Quiz';
    case _LearningActivityType.module:
      return 'Module';
  }
}

void _showNotificationsSheet({
  required BuildContext context,
  required VoidCallback onOpenLearning,
}) {
  final rootContext = context;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss notifications',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final items = ref.watch(appNotificationProvider);
                      final notificationNotifier = ref.read(
                        appNotificationProvider.notifier,
                      );

                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: 720,
                          maxHeight:
                              MediaQuery.of(dialogContext).size.height * 0.78,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD8DEDB),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Notifications',
                                    style: GoogleFonts.sora(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Close notifications',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Learning updates and reminders from ELIO.',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                height: 1.4,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                child: items.isEmpty
                                    ? const _NotificationsEmptyState()
                                    : Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < items.length;
                                            i++
                                          ) ...[
                                            _NotificationTile(
                                              item: items[i],
                                              onAction:
                                                  _notificationActionLabel(
                                                        items[i],
                                                      ) ==
                                                      null
                                                  ? null
                                                  : () =>
                                                        _openNotificationAction(
                                                          rootContext:
                                                              rootContext,
                                                          sheetContext:
                                                              dialogContext,
                                                          ref: ref,
                                                          notification:
                                                              items[i],
                                                          onOpenLearning:
                                                              onOpenLearning,
                                                        ),
                                            ),
                                            if (i != items.length - 1)
                                              const Divider(
                                                height: 1,
                                                color: _border,
                                              ),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (items.isNotEmpty) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          notificationNotifier.markAllRead,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: elioGreen,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Mark all read',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: notificationNotifier.clearAll,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFBA1A1A,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Clear all',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: elioGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  'Done',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _openNotificationAction({
  required BuildContext rootContext,
  required BuildContext sheetContext,
  required WidgetRef ref,
  required AppNotification notification,
  required VoidCallback onOpenLearning,
}) {
  ref.read(appNotificationProvider.notifier).markRead(notification.id);
  Navigator.of(sheetContext).pop();

  Future<void>(() {
    if (!rootContext.mounted) return;

    switch (notification.routeHint) {
      case 'learning':
      case 'quiz':
      case 'quizReview':
        onOpenLearning();
        return;
      case 'robot':
        ref.read(navigationIndexProvider.notifier).state = 2;
        return;
      default:
        return;
    }
  });
}

String? _notificationActionLabel(AppNotification notification) {
  if (notification.actionLabel != null) return notification.actionLabel;

  switch (notification.routeHint) {
    case 'learning':
    case 'quiz':
    case 'quizReview':
      return 'Open Learning';
    case 'robot':
      return 'Open Config';
    default:
      return null;
  }
}

IconData _notificationIcon(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.success:
      return Icons.check_circle_outline_rounded;
    case AppNotificationType.warning:
      return Icons.warning_amber_rounded;
    case AppNotificationType.error:
      return Icons.error_outline_rounded;
    case AppNotificationType.robot:
      return Icons.smart_toy_outlined;
    case AppNotificationType.learning:
      return Icons.menu_book_outlined;
    case AppNotificationType.quiz:
      return Icons.fact_check_outlined;
    case AppNotificationType.info:
      return Icons.info_outline_rounded;
  }
}

Color _notificationColor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.success:
    case AppNotificationType.robot:
    case AppNotificationType.learning:
      return elioGreen;
    case AppNotificationType.warning:
      return _amber;
    case AppNotificationType.error:
      return const Color(0xFFBA1A1A);
    case AppNotificationType.quiz:
      return _cyan;
    case AppNotificationType.info:
      return elioGreen;
  }
}

void _showLearningProgressSheet({
  required BuildContext context,
  required _DashboardData data,
  required VoidCallback onOpenLearning,
}) {
  final visibleItems = data.completedLearningItemsList;

  _showProgressSummarySheet(
    context: context,
    title: 'Completed Learning',
    subtitle: 'Videos, guides, and quizzes you have completed.',
    actionLabel: 'Open Learning',
    onAction: onOpenLearning,
    child: visibleItems.isEmpty
        ? const _ProgressSheetEmptyMessage(
            message: 'Completed videos and guides will appear here.',
          )
        : Column(
            children: [
              for (var i = 0; i < visibleItems.length; i++) ...[
                _CompletedLearningTile(item: visibleItems[i]),
                if (i != visibleItems.length - 1)
                  const Divider(height: 1, color: _border),
              ],
            ],
          ),
  );
}

void _showQuizProgressSheet({
  required BuildContext context,
  required _DashboardData data,
  required VoidCallback onOpenLearning,
}) {
  final rootContext = context;
  final quizActivities = data.activities
      .where((activity) => activity.type == _LearningActivityType.quiz)
      .toList();

  _showProgressSummarySheet(
    context: context,
    title: 'Quiz History',
    subtitle: 'Recent quiz attempts and scores.',
    actionLabel: 'Open Quiz',
    onAction: onOpenLearning,
    child: quizActivities.isEmpty
        ? const _ProgressSheetEmptyMessage(
            message:
                'Quiz attempts will appear here after you complete a quiz.',
          )
        : Column(
            children: [
              for (var i = 0; i < quizActivities.length; i++) ...[
                _QuizHistoryTile(
                  activity: quizActivities[i],
                  onReview: quizActivities[i].quizReview == null
                      ? null
                      : () => _openQuizReviewFromSheet(
                          rootContext,
                          quizActivities[i].quizReview!,
                        ),
                ),
                if (i != quizActivities.length - 1)
                  const Divider(height: 1, color: _border),
              ],
            ],
          ),
  );
}

void _openQuizReviewFromSheet(BuildContext rootContext, QuizReview review) {
  Navigator.of(rootContext).pop();

  Future<void>(() {
    if (!rootContext.mounted) return;

    Navigator.of(rootContext).push(
      MaterialPageRoute<void>(
        builder: (context) => QuizReviewPage(review: review),
      ),
    );
  });
}

void _showCurrentModuleSheet({
  required BuildContext context,
  required _DashboardData data,
  required VoidCallback onOpenLearning,
}) {
  final subtitle = data.currentTimestamp == null
      ? 'Start your first learning module.'
      : 'Last opened ${_relativeTime(data.currentTimestamp!)}';

  _showProgressSummarySheet(
    context: context,
    title: 'Current Module',
    subtitle: 'Your latest learning module.',
    actionLabel: 'Open Learning',
    onAction: onOpenLearning,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_lesson_rounded,
              color: _amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.currentModule,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
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

void _showProgressSummarySheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String actionLabel,
  required VoidCallback onAction,
  required Widget child,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final maxHeight = MediaQuery.of(context).size.height * 0.82;

      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEDB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  height: 1.4,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAction();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: elioGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(
                    actionLabel,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showUnfinishedLearningSheet({
  required BuildContext context,
  required List<_ContinueLearningItem> items,
  required VoidCallback onOpenLearning,
  required ValueChanged<_ContinueLearningItem> onSelectItem,
}) {
  if (items.isEmpty) {
    onOpenLearning();
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final visibleItems = items.take(8).toList();

      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEDB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Unfinished Learning',
                style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an unfinished video or guide to continue learning.',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  height: 1.4,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < visibleItems.length; i++) ...[
                _UnfinishedLearningTile(
                  item: visibleItems[i],
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelectItem(visibleItems[i]);
                  },
                ),
                if (i != visibleItems.length - 1)
                  const Divider(height: 1, color: _border),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenLearning();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: elioGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(
                    'Open Learning',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _moduleTitle(String categoryId) {
  for (final category in wasteCategories) {
    if (category.id == categoryId) return category.title;
  }

  final lessonMatch = RegExp(
    r'^m(\d+)l(\d+)$',
    caseSensitive: false,
  ).firstMatch(categoryId);
  if (lessonMatch != null) {
    return 'Module ${lessonMatch.group(1)}, Lesson ${lessonMatch.group(2)}';
  }

  final words = categoryId
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  return words.isEmpty ? 'Learning module' : words;
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 30) return '${difference.inDays ~/ 7}w ago';
  if (difference.inDays < 365) return '${difference.inDays ~/ 30}mo ago';
  return '${difference.inDays ~/ 365}y ago';
}
