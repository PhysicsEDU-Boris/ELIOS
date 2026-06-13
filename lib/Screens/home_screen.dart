import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/learning_progress.dart';
import '../models/waste_category.dart';
import '../providers/auth_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/elio_colors.dart';
import 'tabs/elearning_tab.dart';

const _background = Color(0xFFF8FAF9);
const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF6D7A73);
const _border = Color(0xFFE4EAE6);
const _cyan = Color(0xFF00647C);
const _amber = Color(0xFFBA7517);
const _trackedLearningModuleIds = ['organic', 'inorganic', 'hazardous'];
const _moduleCount = 3;

class HomeScreen extends ConsumerWidget {
  final FirebaseAuth auth;
  final VoidCallback onOpenDrawer;

  const HomeScreen({super.key, required this.auth, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? auth.currentUser;
    final progress = ref.watch(learningProgressProvider);
    final hasSyncWarning = ref.watch(progressSyncWarningProvider);
    final dashboard = progress.when(
      loading: _DashboardData.empty,
      error: (error, stackTrace) {
        debugPrint('Learning progress error: $error');
        return _DashboardData.empty();
      },
      data: _DashboardData.from,
    );
    final isLoading = progress.isLoading;
    final hasError = progress.hasError || hasSyncWarning;

    void openLearning() {
      ref.read(navigationIndexProvider.notifier).state = 1;
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ElearningTab()));
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
                    ),
                    const SizedBox(height: 14),
                    _Dashboard(
                      data: dashboard,
                      isGuest: user?.isAnonymous ?? true,
                      isLoading: isLoading,
                      hasProgressError: hasError,
                      onRetry: () => ref.invalidate(learningProgressProvider),
                      onOpenLearning: openLearning,
                      onSelectTab: (index) {
                        ref.read(navigationIndexProvider.notifier).state =
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
  final ValueChanged<int> onSelectTab;

  const _Dashboard({
    required this.data,
    required this.isGuest,
    required this.isLoading,
    required this.hasProgressError,
    required this.onRetry,
    required this.onOpenLearning,
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
        _ContinueLearningCard(data: data, onTap: onOpenLearning),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'Your Progress',
          actionLabel: 'View learning',
          onActionTap: onOpenLearning,
        ),
        const SizedBox(height: 10),
        _ProgressGrid(data: data),
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

  const _TopBar({
    required this.name,
    required this.onMenuPressed,
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _border),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: _ink,
            size: 21,
          ),
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
                _HeroStat(label: 'Modules', value: data.modulesValue),
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

  const _ContinueLearningCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasStarted = data.overallProgress > 0;
    final module = hasStarted
        ? data.currentModule
        : 'Module 1 · Introduction to ELIO';

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
            hasStarted ? 'CONTINUE LEARNING' : 'START LEARNING',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            module,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: data.overallProgress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF86F8C9)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${data.progressPercent}%',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF86F8C9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: elioGreen,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              minimumSize: Size.zero,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: Text(
              hasStarted ? 'Continue Module' : 'Start Module 1',
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

  const _ProgressGrid({required this.data});

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
                label: 'Modules',
                value: data.modulesValue,
                subtitle: data.completedModules == 0
                    ? 'No modules completed yet'
                    : '${data.completedModules} modules explored',
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

  const _ProgressCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.subtitle,
    this.horizontal = false,
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

    return Container(
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
        description: 'Complete at least 3 learning modules',
        icon: Icons.explore_rounded,
        color: _amber,
        unlocked: data.completedModules >= 3,
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
                    child: Text(
                      activities[i].title,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
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

class _DashboardData {
  final int completedModules;
  final int quizAttemptCount;
  final int? quizAverage;
  final double overallProgress;
  final String currentModule;
  final DateTime? currentTimestamp;
  final bool roboticsStarted;
  final bool reflectionsCompleted;
  final List<_HomeActivity> activities;

  const _DashboardData({
    required this.completedModules,
    required this.quizAttemptCount,
    required this.quizAverage,
    required this.overallProgress,
    required this.currentModule,
    required this.currentTimestamp,
    required this.roboticsStarted,
    required this.reflectionsCompleted,
    required this.activities,
  });

  String get modulesValue => '$completedModules/$_moduleCount';
  String get quizValue => quizAverage == null ? '--' : '$quizAverage%';
  int get progressPercent => (overallProgress * 100).round();

  factory _DashboardData.empty() {
    return const _DashboardData(
      completedModules: 0,
      quizAttemptCount: 0,
      quizAverage: null,
      overallProgress: 0.0,
      currentModule: 'Not started',
      currentTimestamp: null,
      roboticsStarted: false,
      reflectionsCompleted: false,
      activities: [],
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

  factory _DashboardData.from(LearningProgress progress) {
    final activeEntries = progress.categories.entries
        .where(
          (entry) =>
              _trackedLearningModuleIds.contains(entry.key) &&
              entry.value.progressPercentage > 0,
        )
        .toList();

    final completedModules = activeEntries.length;
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

    final totalProgress = activeEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value.progressPercentage,
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

    final activities = activeEntries
        .where((entry) => entry.value.lastAccessed != null)
        .map((entry) {
          final attemptedQuiz = entry.value.quizAttempts > 0;
          return _HomeActivity(
            title: attemptedQuiz
                ? 'Completed quiz: ${_moduleTitle(entry.key)}'
                : 'Opened module: ${_moduleTitle(entry.key)}',
            timestamp: entry.value.lastAccessed!,
            color: attemptedQuiz ? _cyan : elioGreen,
          );
        })
        .take(5)
        .toList();

    return _DashboardData(
      completedModules: math.min(completedModules, _moduleCount),
      quizAttemptCount: quizAttemptCount,
      quizAverage: quizAverage,
      overallProgress: (totalProgress / _moduleCount).clamp(0.0, 1.0),
      currentModule: currentModule,
      currentTimestamp: currentTimestamp,
      roboticsStarted: roboticsStarted,
      reflectionsCompleted: reflectionsCompleted,
      activities: activities,
    );
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

class _HomeActivity {
  final String title;
  final DateTime timestamp;
  final Color color;

  const _HomeActivity({
    required this.title,
    required this.timestamp,
    required this.color,
  });
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
