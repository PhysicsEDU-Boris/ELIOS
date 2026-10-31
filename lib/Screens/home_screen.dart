// Home screen restyle H1 (decision 0140). Figma file J2jSbARJSyJCStNFeWkWDj,
// page "H1 Home screen" 243:2358:
//   243:2359 Phone / Light / With activity     243:2556 Phone / Dark / With activity
//   243:2753 Phone / Light / First launch      245:2358 Desktop 1280 / Light
//   245:2446 spec frame
// Look and layout only: every action, route, provider and data flow is as
// before. The bottom sheets and dialogs below stay on the legacy look (they
// are re-themed with their own screens), see [_legacyTheme].
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
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
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart';
import '../widgets/elio_colors.dart';
import 'tabs/elearning/quiz_review_page.dart';

// Legacy colours: only the bottom sheets and dialogs below still use these.
const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF6D7A73);
const _border = Color(0xFFE4EAE6);
const _cyan = Color(0xFF00647C);
const _amber = Color(0xFFBA7517);
const _trackedLearningModuleIds = ['organic', 'inorganic', 'hazardous'];

// Design file 0091 shape scale.
const _radiusL = 16.0;
const _radiusM = 12.0;
const _minTap = 48.0;
const _wideBreakpoint = 840.0;
const _maxContentWidth = 1040.0;

ElearningContentService? _contentServiceOverride;
ElearningContentService get _elearningContentService =>
    _contentServiceOverride ??= ElearningContentService();

/// Test seams: Firestore and the WebView-based 3D viewer cannot run in widget tests.
@visibleForTesting
set homeContentServiceForTest(ElearningContentService? service) =>
    _contentServiceOverride = service;

@visibleForTesting
bool homeStaticRobotForTest = false;

/// The app theme (not the [ElioTheme.wrap] one) for sheets and dialogs that
/// still use the legacy look; they are launched from inside the wrapped screen.
Widget _legacyTheme(BuildContext context, Widget child) =>
    Theme(data: Theme.of(Navigator.of(context).context), child: child);

ShapeBorder _shape(ElioPalette p, double radius, {Color? side}) =>
    RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: side ?? p.borderMedium),
    );

TextStyle _title(ElioPalette p, double size) => ElioTokens.subhead.copyWith(
  fontSize: size,
  height: 1.3,
  color: p.textPrimary,
);

TextStyle _small(ElioPalette p, {Color? color, FontWeight? weight}) =>
    ElioTokens.bodySmall.copyWith(
      fontSize: 13,
      height: 1.4,
      color: color ?? p.textSecondary,
      fontWeight: weight,
    );

TextStyle _overline(ElioPalette p) =>
    ElioTokens.overline.copyWith(color: p.primaryText);

/// Surface card with the design-system border; tappable cards get an ink
/// ripple clipped to the same continuous shape.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = _radiusL,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final shape = _shape(p, radius);
    final body = Padding(padding: padding, child: child);
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? SizedBox(width: double.infinity, child: body)
            : InkWell(
                onTap: onTap,
                customBorder: shape,
                child: SizedBox(width: double.infinity, child: body),
              ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, {this.size = 40, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(_radiusM),
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? p.primaryText),
    );
  }
}

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

            return ElioTheme.wrap(
              Builder(
                builder: (context) {
                  final p = authPalette(context);
                  return Scaffold(
                    backgroundColor: p.background,
                    body: SafeArea(
                      child: RefreshIndicator(
                        color: p.primaryText,
                        onRefresh: () =>
                            ref.refresh(learningProgressProvider.future),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _maxContentWidth,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      32,
                                    ),
                                    child: Column(
                                      children: [
                                        _TopBar(
                                          name: _displayNameFor(user),
                                          photoUrl: user?.photoURL,
                                          onMenuPressed: onOpenDrawer,
                                          unreadNotificationCount:
                                              unreadNotifications,
                                          onNotificationsPressed: () =>
                                              _showNotificationsSheet(
                                                context: context,
                                                onOpenLearning: onOpenLearning,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        _Dashboard(
                                          data: dashboard,
                                          isGuest: user?.isAnonymous ?? true,
                                          isLoading: isLoading,
                                          hasProgressError: hasError,
                                          onRetry: () => ref.invalidate(
                                            learningProgressProvider,
                                          ),
                                          onOpenLearning: onOpenLearning,
                                          onResumeLearningItem: openResumeItem,
                                          onSelectTab: (index) {
                                            ref
                                                    .read(
                                                      navigationIndexProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                index;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
    final hero = _HeroCard(data: data);
    final loading = isLoading
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              label: 'Loading progress',
              child: const _Bar(value: null),
            ),
          )
        : const SizedBox.shrink();
    final continueCard = _ContinueLearningCard(
      data: data,
      onTap: onOpenLearning,
      onResumeLearningItem: onResumeLearningItem,
    );
    final progress = <Widget>[
      _SectionHeader(
        title: 'Your Progress',
        actionLabel: 'View learning',
        onActionTap: onOpenLearning,
      ),
      const SizedBox(height: 8),
      _ProgressGrid(data: data, onOpenLearning: onOpenLearning),
    ];
    final insight = const _InsightCard();
    final achievements = <Widget>[
      const _SectionHeader(title: 'Achievements'),
      const SizedBox(height: 8),
      _AchievementList(data: data),
    ];
    final recent = <Widget>[
      const _SectionHeader(title: 'Recent Activity'),
      const SizedBox(height: 8),
      _RecentActivityList(activities: data.activities),
    ];
    final quick = <Widget>[
      const _SectionHeader(title: 'Quick Actions'),
      const SizedBox(height: 8),
      _QuickActions(onOpenLearning: onOpenLearning, onSelectTab: onSelectTab),
    ];
    const gap = SizedBox(height: 24);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint - 32;
        final left = <Widget>[
          if (hasProgressError) ...[
            _ProgressWarning(onRetry: onRetry),
            const SizedBox(height: 12),
          ],
          hero,
          loading,
          const SizedBox(height: 16),
          continueCard,
          gap,
          ...progress,
          if (wide) ...[gap, ...recent],
        ];
        final right = <Widget>[
          if (!wide) gap,
          insight,
          gap,
          ...achievements,
          if (!wide) ...[gap, ...recent],
          gap,
          ...quick,
        ];
        final guest = isGuest
            ? const Padding(
                padding: EdgeInsets.only(top: 24),
                child: _GuestBanner(),
              )
            : const SizedBox.shrink();

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...left, ...right, guest],
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: left,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: right,
                  ),
                ),
              ],
            ),
            guest,
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  /// Null shows the indeterminate loading bar.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ElioTokens.radiusFull),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: p.surfaceRaised,
        valueColor: AlwaysStoppedAnimation(p.primary),
      ),
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
    final p = authPalette(context);
    final badgeLabel = unreadNotificationCount > 9
        ? '9+'
        : '$unreadNotificationCount';
    return Row(
      children: [
        IconButton(
          onPressed: onMenuPressed,
          tooltip: 'Open navigation menu',
          constraints: const BoxConstraints.tightFor(
            width: _minTap,
            height: _minTap,
          ),
          style: IconButton.styleFrom(foregroundColor: p.textPrimary),
          icon: const Icon(Icons.menu_rounded, size: 24),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 20,
          backgroundColor: p.surfaceRaised,
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
          child: photoUrl == null
              ? Icon(Icons.person_outline_rounded, color: p.primaryText)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _title(p, 18),
              ),
              Text(
                'Ready to learn with ELIO?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _small(p),
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
              constraints: const BoxConstraints.tightFor(
                width: _minTap,
                height: _minTap,
              ),
              style: IconButton.styleFrom(foregroundColor: p.textPrimary),
              icon: const Icon(Icons.notifications_none_rounded, size: 24),
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: p.isDark ? p.error : p.errorText,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: p.background, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeLabel,
                      style: ElioTokens.label.copyWith(
                        color: p.isDark ? p.onError : Colors.white,
                        fontSize: 10,
                        height: 1.2,
                      ),
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
    return _Card(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _ElioRobot3DViewer(height: 160),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroStat(label: 'Learning', value: data.learningItemsValue),
                const SizedBox(width: 8),
                _HeroStat(label: 'Quiz Avg', value: data.quizValue),
                const SizedBox(width: 8),
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
  final double height;

  const _ElioRobot3DViewer({required this.height});

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
    final p = authPalette(context);
    final useStage = _hasError || homeStaticRobotForTest;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'ELIO robot 3D viewer. Drag to rotate.',
      child: Container(
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: p.background,
          shape: _shape(p, _radiusL, side: p.borderSubtle),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (useStage)
              _RotatingRobotStage(height: widget.height)
            else ...[
              // Bottom inset keeps the real model clear of the "DRAG TO ROTATE" label.
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ExcludeSemantics(
                  child: Flutter3DViewer(
                    controller: _controller,
                    src: 'assets/models/robot-elio.glb',
                    enableTouch: true,
                    activeGestureInterceptor: true,
                    progressBarColor: p.primaryText,
                    onLoad: _handleLoad,
                    onError: _handleError,
                  ),
                ),
              ),
              if (!_isLoaded)
                IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: p.primaryText,
                      ),
                    ),
                  ),
                ),
            ],
            Positioned(
              bottom: 8,
              child: IgnorePointer(
                child: Text(
                  'DRAG TO ROTATE',
                  style: ElioTokens.overline.copyWith(
                    fontSize: 10,
                    color: p.textSecondary,
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

class _RotatingRobotStage extends StatefulWidget {
  final double height;

  const _RotatingRobotStage({required this.height});

  @override
  State<_RotatingRobotStage> createState() => _RotatingRobotStageState();
}

class _RotatingRobotStageState extends State<_RotatingRobotStage> {
  double _angle = 0.18;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final h = widget.height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() => _angle += details.delta.dx * 0.018);
      },
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(_angle)
            ..rotateZ(math.sin(_angle) * 0.04),
          child: Container(
            width: h * 0.62,
            height: h * 0.5,
            decoration: ShapeDecoration(
              color: p.surface,
              shape: _shape(p, _radiusL, side: p.borderStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RobotEye(color: p.primary),
                _RobotEye(color: p.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RobotEye extends StatelessWidget {
  const _RobotEye({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(
          color: p.surface,
          shape: _shape(p, _radiusM, side: p.borderSubtle),
        ),
        child: Semantics(
          container: true,
          label: '$label $value',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: _title(p, 16).copyWith(height: 1.25)),
              Text(label, style: _small(p).copyWith(fontSize: 12)),
            ],
          ),
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
    final p = authPalette(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: ShapeDecoration(
          color: p.secondaryText.withValues(alpha: p.isDark ? 0.12 : 0.04),
          shape: _shape(
            p,
            _radiusM,
            side: p.secondaryText.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: p.secondaryText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Progress could not be loaded. Showing local empty state.',
                style: _small(p, color: p.textPrimary),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: p.secondaryText,
                minimumSize: const Size(_minTap, _minTap),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
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
    final p = authPalette(context);
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

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _overline(p)),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _title(p, 20),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _small(p, color: p.textPrimary),
            ),
          ],
          const SizedBox(height: 12),
          Semantics(
            label: 'Overall progress ${data.progressPercent}%',
            child: _Bar(value: data.overallProgress),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: hasResumeItem
                ? 'Continue'
                : hasStarted
                ? 'Continue Module'
                : 'Start Module 1',
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
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ProgressCard(
                      icon: Icons.menu_book_outlined,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressCard(
                      icon: Icons.check_rounded,
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ProgressCard(
              icon: Icons.explore_outlined,
              label: 'Current Module',
              value: data.currentModule,
              subtitle: data.currentModule == 'Not started'
                  ? 'Start your first learning module'
                  : data.currentTimestamp == null
                  ? 'Continue this learning module'
                  : 'Last opened ${_relativeTime(data.currentTimestamp!)}',
              valueOnTop: false,
              onTap: () => _showCurrentModuleSheet(
                context: context,
                data: data,
                onOpenLearning: onOpenLearning,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Figma order: icon, value, label, subtitle. The Current Module card puts the
/// label below the value as well (name first), so [valueOnTop] only differs in size.
class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final bool valueOnTop;
  final VoidCallback? onTap;

  const _ProgressCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueOnTop = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return _Card(
      onTap: onTap,
      semanticsLabel: '$label, $value, $subtitle',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: p.primaryText),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _title(p, valueOnTop ? 22 : 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: _small(p, weight: FontWeight.w600)),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _small(p, color: p.textTertiary).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: p.primaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DID YOU KNOW?', style: _overline(p)),
                  const SizedBox(height: 8),
                  Text(
                    'Smart sorting starts with recognizing the material.',
                    style: _title(p, 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore each waste category to see how AI helps ELIO classify it.',
                    style: _small(p),
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
    final p = authPalette(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: _title(p, 20)),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(_minTap, _minTap),
                foregroundColor: p.primaryText,
                textStyle: ElioTokens.button,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
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
        icon: Icons.explore_outlined,
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
          if (i != achievements.length - 1) const SizedBox(height: 8),
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
    final p = authPalette(context);
    final unlocked = achievement.unlocked;
    return _Card(
      padding: const EdgeInsets.all(12),
      semanticsLabel:
          '${achievement.name}, ${unlocked ? 'unlocked' : 'locked'}. ${achievement.description}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            _IconTile(
              unlocked ? achievement.icon : Icons.lock_outline_rounded,
              color: unlocked ? null : authPalette(context).textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: _small(
                      p,
                      color: p.textPrimary,
                      weight: FontWeight.w600,
                    ).copyWith(fontSize: 14),
                  ),
                  Text(
                    achievement.description,
                    style: _small(p).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unlocked) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 20, color: p.primaryText),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<_HomeActivity> activities;

  const _RecentActivityList({required this.activities});

  static IconData _icon(_LearningActivityType type) => switch (type) {
    _LearningActivityType.video => Icons.play_circle_outline_rounded,
    _LearningActivityType.guide => Icons.menu_book_outlined,
    _LearningActivityType.quiz => Icons.check_rounded,
    _LearningActivityType.module => Icons.explore_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    if (activities.isEmpty) {
      return _Card(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: p.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              'Your lessons, videos, quizzes, and reflections will appear here once you begin.',
              textAlign: TextAlign.center,
              style: _small(p),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < activities.length; i++) ...[
          _Card(
            padding: const EdgeInsets.all(12),
            semanticsLabel:
                '${activities[i].title}. ${activities[i].subtitle}. ${_relativeTime(activities[i].timestamp)}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  _IconTile(_icon(activities[i].type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activities[i].title,
                          style: _small(
                            p,
                            color: p.textPrimary,
                            weight: FontWeight.w600,
                          ).copyWith(fontSize: 14),
                        ),
                        if (activities[i].subtitle.trim().isNotEmpty)
                          Text(
                            activities[i].subtitle,
                            style: _small(p).copyWith(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTime(activities[i].timestamp),
                    style: _small(
                      p,
                      color: p.textTertiary,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (i != activities.length - 1) const SizedBox(height: 8),
        ],
      ],
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
        item.thumbnailUrl != null &&
        item.thumbnailUrl!.trim().isNotEmpty;
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
                  child: CachedNetworkImage(
                    imageUrl: item.thumbnailUrl!,
                    width: 74,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => iconBox(),
                    errorWidget: (_, _, _) => iconBox(),
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
        item.previewUrl != null && item.previewUrl!.trim().isNotEmpty;
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
            child: CachedNetworkImage(
              imageUrl: item.previewUrl!,
              width: previewWidth,
              height: previewHeight,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallbackPreview(),
              errorWidget: (_, _, _) => fallbackPreview(),
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
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.menu_book_outlined,
                title: 'Learn',
                subtitle: 'Lessons and quizzes',
                onTap: onOpenLearning,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.wifi_rounded,
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
                icon: Icons.videocam_outlined,
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
    final p = authPalette(context);
    return _Card(
      onTap: onTap,
      semanticsLabel: '$title, $subtitle',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconTile(icon, size: 36),
            const SizedBox(height: 12),
            Text(title, style: _title(p, 16)),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _small(p).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: p.secondaryText.withValues(alpha: p.isDark ? 0.12 : 0.04),
          shape: _shape(
            p,
            _radiusM,
            side: p.secondaryText.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: p.secondaryText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Guest progress is stored on this device. Sign in to sync it across devices.',
                style: _small(p, color: p.textPrimary),
              ),
            ),
          ],
        ),
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
          previewUrl: video.thumbnailUrl,
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
          previewUrl: guide.coverUrl,
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
          previewUrl: null,
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
          thumbnailUrl: video.thumbnailUrl,
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
  final String? thumbnailUrl;

  const _ContinueLearningItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.timestamp,
    required this.isCompleted,
    this.moduleId,
    this.thumbnailUrl,
  });
}

class _CompletedLearningItem {
  final _LearningActivityType type;
  final String id;
  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final String? previewUrl;

  const _CompletedLearningItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.previewUrl,
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
    builder: (context) => _legacyTheme(
      context,
      Builder(
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
      ),
    ),
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
    builder: (context) => _legacyTheme(
      context,
      Builder(
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
      ),
    ),
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
