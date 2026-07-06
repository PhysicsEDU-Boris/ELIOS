import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/elearning_module.dart';
import '../../models/app_notification.dart';
import '../../models/learning_progress.dart';
import '../../models/waste_category.dart';
import '../../providers/app_notification_provider.dart';
import '../../providers/learning_progress_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/elearning_content_service.dart';
import '../../widgets/elio_learning_app_bar.dart';
import 'elearning/guides_page.dart';
import 'elearning/quiz_page.dart';
import 'elearning/video_lessons_page.dart';

const _background = Color(0xFFF8FAF9);
const _primary = Color(0xFF00694C);
const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF3D4943);
const _border = Color(0xFFE6E9E8);

enum LearningSection { allCategories, guides, videoLessons, quiz }

class ElearningTab extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onQuizActiveChanged;
  final int quizResetGeneration;

  const ElearningTab({
    super.key,
    this.onQuizActiveChanged,
    this.quizResetGeneration = 0,
  });

  @override
  ConsumerState<ElearningTab> createState() => _ElearningTabState();
}

class _ElearningTabState extends ConsumerState<ElearningTab> {
  final ElearningContentService _service = ElearningContentService();
  LearningSection _selectedSection = LearningSection.allCategories;
  String? _selectedModuleId;
  String? _pendingResumeVideoId;
  String? _pendingResumeGuideId;
  bool _quizInProgress = false;
  final Set<LearningSection> _visitedSections = <LearningSection>{
    LearningSection.allCategories,
  };

  void _selectSection(LearningSection section) {
    setState(() {
      _selectedSection = section;
      _visitedSections.add(section);
      if (section == LearningSection.allCategories && !_quizInProgress) {
        _selectedModuleId = null;
      }
    });
  }

  void _clearModuleFilter() {
    if (_selectedModuleId == null || _quizInProgress) return;
    setState(() => _selectedModuleId = null);
  }

  void _handleLearningResumeIntent(LearningResumeIntent intent) {
    if (!mounted) return;

    setState(() {
      switch (intent.type) {
        case LearningResumeType.video:
          _selectedSection = LearningSection.videoLessons;
          _visitedSections.add(LearningSection.videoLessons);
          _selectedModuleId = intent.moduleId;
          _pendingResumeVideoId = intent.id;
          _pendingResumeGuideId = null;
          break;
        case LearningResumeType.guide:
          _selectedSection = LearningSection.guides;
          _visitedSections.add(LearningSection.guides);
          _selectedModuleId = intent.moduleId;
          _pendingResumeVideoId = null;
          _pendingResumeGuideId = intent.id;
          break;
        case LearningResumeType.quiz:
          _selectedSection = LearningSection.quiz;
          _visitedSections.add(LearningSection.quiz);
          _selectedModuleId = intent.moduleId ?? intent.id;
          _pendingResumeVideoId = null;
          _pendingResumeGuideId = null;
          break;
      }
    });

    _clearLearningResumeIntentLater(intent);
  }

  void _clearLearningResumeIntentLater(LearningResumeIntent handledIntent) {
    Future<void>(() {
      if (!mounted) return;

      final current = ref.read(learningResumeIntentProvider);
      if (current == null) return;

      final isSameIntent =
          current.type == handledIntent.type &&
          current.id == handledIntent.id &&
          current.moduleId == handledIntent.moduleId;

      if (!isSameIntent) return;

      ref.read(learningResumeIntentProvider.notifier).state = null;
    });
  }

  void _clearPendingResumeVideo() {
    if (!mounted || _pendingResumeVideoId == null) return;
    setState(() => _pendingResumeVideoId = null);
  }

  void _clearPendingResumeGuide() {
    if (!mounted || _pendingResumeGuideId == null) return;
    setState(() => _pendingResumeGuideId = null);
  }

  Future<void> _showLearningPath(
    ElearningModule module,
    LearningProgress? progress,
  ) async {
    final moduleProgress =
        progress?.categories[module.id]?.progressPercentage ?? 0;

    setState(() => _selectedModuleId = module.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _LearningPathSheet(
        module: module,
        progress: moduleProgress,
        onSectionSelected: (section) {
          Navigator.pop(sheetContext);
          setState(() {
            _selectedModuleId = module.id;
            _selectedSection = section;
            _visitedSections.add(section);
          });
        },
      ),
    );
  }

  Widget _buildSection(LearningSection section, LearningProgress? progress) {
    return switch (section) {
      LearningSection.allCategories => _AllCategoriesContent(
        service: _service,
        progress: progress,
        onModuleSelected: (module) => _showLearningPath(module, progress),
      ),
      LearningSection.guides => GuidesContent(
        selectedModuleId: _selectedModuleId,
        onClearFilter: _clearModuleFilter,
        resumeGuideId: _pendingResumeGuideId,
        onResumeGuideHandled: _clearPendingResumeGuide,
      ),
      LearningSection.videoLessons => VideoLessonsContent(
        selectedModuleId: _selectedModuleId,
        onClearFilter: _clearModuleFilter,
        resumeVideoId: _pendingResumeVideoId,
        onResumeVideoHandled: _clearPendingResumeVideo,
      ),
      LearningSection.quiz => QuizContent(
        key: ValueKey(widget.quizResetGeneration),
        selectedModuleId: _selectedModuleId,
        onClearFilter: _clearModuleFilter,
        onQuizActiveChanged: (active) {
          if (_quizInProgress == active) return;
          setState(() => _quizInProgress = active);
          widget.onQuizActiveChanged?.call(active);
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LearningResumeIntent?>(learningResumeIntentProvider, (
      previous,
      next,
    ) {
      if (next == null) return;
      _handleLearningResumeIntent(next);
    });

    final pendingIntent = ref.read(learningResumeIntentProvider);
    if (pendingIntent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final intent = ref.read(learningResumeIntentProvider);
        if (intent != null) _handleLearningResumeIntent(intent);
      });
    }

    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: ElioLearningAppBar(
        title: 'ELIO',
        action: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => _showLearningNotificationsTopPanel(context),
              icon: const Icon(Icons.notifications_none_rounded),
              color: _primary,
              tooltip: 'Notifications',
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBA1A1A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                  child: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _LearningFilterChips(
                    selectedSection: _selectedSection,
                    onSectionSelected: _selectSection,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: IndexedStack(
                index: _selectedSection.index,
                children: LearningSection.values
                    .map((section) {
                      if (_visitedSections.contains(section) ||
                          section == _selectedSection) {
                        return _buildSection(section, progress);
                      }
                      return const SizedBox.shrink();
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showLearningNotificationsTopPanel(BuildContext context) {
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
                      final notifier = ref.read(
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
                                    style: GoogleFonts.inter(
                                      color: _ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: 'Close notifications',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Learning updates and robot alerts from ELIO.',
                              style: GoogleFonts.inter(
                                color: _muted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                child: items.isEmpty
                                    ? const _LearningNotificationsEmptyState()
                                    : Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < items.length;
                                            i++
                                          ) ...[
                                            _LearningNotificationTile(
                                              item: items[i],
                                              onTap: () {
                                                notifier.markRead(items[i].id);
                                              },
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
                                      onPressed: notifier.markAllRead,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _primary,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Mark all read',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: notifier.clearAll,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFBA1A1A,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        'Clear all',
                                        style: GoogleFonts.inter(
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
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  'Done',
                                  style: GoogleFonts.inter(
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

class _LearningNotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback? onTap;

  const _LearningNotificationTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(item.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
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
                    style: GoogleFonts.inter(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

class _LearningNotificationsEmptyState extends StatelessWidget {
  const _LearningNotificationsEmptyState();

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
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Learning updates and robot alerts will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
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
      return _primary;
    case AppNotificationType.warning:
      return const Color(0xFFBA7517);
    case AppNotificationType.error:
      return const Color(0xFFBA1A1A);
    case AppNotificationType.quiz:
      return const Color(0xFF00647C);
    case AppNotificationType.info:
      return _primary;
  }
}

class _AllCategoriesContent extends StatelessWidget {
  final ElearningContentService service;
  final LearningProgress? progress;
  final ValueChanged<ElearningModule> onModuleSelected;

  const _AllCategoriesContent({
    required this.service,
    required this.progress,
    required this.onModuleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LearningHeader(),
              const SizedBox(height: 28),
              _ProgressOverviewCard(progress: progress),
              const SizedBox(height: 32),
              _CourseModulesSection(
                service: service,
                progress: progress,
                onModuleSelected: onModuleSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningHeader extends StatelessWidget {
  const _LearningHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn Waste\nClassification',
          style: GoogleFonts.inter(
            color: _ink,
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Explore the environmental physics behind waste, master proper '
          'sorting, and discover how the ELIO robot classifies materials for '
          'a more sustainable future.',
          style: GoogleFonts.inter(
            color: _muted,
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _LearningFilterChips extends StatefulWidget {
  final LearningSection selectedSection;
  final ValueChanged<LearningSection> onSectionSelected;

  const _LearningFilterChips({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  @override
  State<_LearningFilterChips> createState() => _LearningFilterChipsState();
}

class _LearningFilterChipsState extends State<_LearningFilterChips> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _scrollController = ScrollController();
  late final List<LearningSection> _sections;
  bool _isReordering = false;

  static const _labels = {
    LearningSection.allCategories: 'All Categories',
    LearningSection.guides: 'Guides',
    LearningSection.videoLessons: 'Video Lessons',
    LearningSection.quiz: 'Quiz',
  };

  @override
  void initState() {
    super.initState();
    _sections = [
      widget.selectedSection,
      ...LearningSection.values.where(
        (section) => section != widget.selectedSection,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant _LearningFilterChips oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedSection == widget.selectedSection) return;

    final hasEverySection =
        _sections.length == LearningSection.values.length &&
        _sections.toSet().length == LearningSection.values.length;
    final currentIndex = _sections.indexOf(widget.selectedSection);

    if (!hasEverySection || currentIndex < 0) {
      _sections
        ..clear()
        ..addAll([
          widget.selectedSection,
          ...LearningSection.values.where(
            (section) => section != widget.selectedSection,
          ),
        ]);
      _scrollToStart();
      return;
    }

    if (currentIndex == 0) {
      _scrollToStart();
      return;
    }

    final movedSection = _sections.removeAt(currentIndex);
    _sections.insert(0, movedSection);
    _scrollToStart();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSection(LearningSection section) {
    if (section == widget.selectedSection) {
      _scrollToStart();
      return;
    }

    if (_isReordering) return;

    final oldIndex = _sections.indexOf(section);
    if (oldIndex <= 0) return;

    _isReordering = true;
    final removedSection = _sections.removeAt(oldIndex);
    _listKey.currentState?.removeItem(
      oldIndex,
      (context, animation) => _buildAnimatedChip(
        section: removedSection,
        animation: animation,
        selected: false,
      ),
      duration: const Duration(milliseconds: 320),
    );

    _sections.insert(0, removedSection);
    widget.onSectionSelected(section);

    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;

      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 380),
      );
      _isReordering = false;
    });

    _scrollToStart();
  }

  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: AnimatedList(
        key: _listKey,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        initialItemCount: _sections.length,
        itemBuilder: (context, index, animation) {
          final section = _sections[index];
          return _buildAnimatedChip(
            section: section,
            animation: animation,
            selected: section == widget.selectedSection,
          );
        },
      ),
    );
  }

  Widget _buildAnimatedChip({
    required LearningSection section,
    required Animation<double> animation,
    required bool selected,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubicEmphasized,
    );

    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        axis: Axis.horizontal,
        sizeFactor: curved,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: selected ? _primary : _border,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () => _selectSection(section),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      style: GoogleFonts.inter(
                        color: selected ? Colors.white : _muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(_labels[section]!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressOverviewCard extends StatelessWidget {
  final LearningProgress? progress;

  const _ProgressOverviewCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = _overallProgress(progress);
    final percent = (value * 100).round();
    final activeModules = wasteCategories.where((category) {
      return (progress?.categories[category.id]?.progressPercentage ?? 0) > 0;
    }).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123524).withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: _primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Learning Progress',
                          style: GoogleFonts.inter(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activeModules == 0
                              ? 'Start a module to track your journey'
                              : '$activeModules of ${wasteCategories.length} modules in progress',
                          style: GoogleFonts.inter(
                            color: _muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      color: _primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE8EFEB),
                  valueColor: const AlwaysStoppedAnimation(_primary),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$percent% Overall Completion',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseModulesSection extends StatelessWidget {
  final ElearningContentService service;
  final LearningProgress? progress;
  final ValueChanged<ElearningModule> onModuleSelected;

  const _CourseModulesSection({
    required this.service,
    required this.progress,
    required this.onModuleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Course Modules',
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () => debugPrint('View all learning modules'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<ElearningModule>>(
          stream: service.watchModules(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _ModulesMessage(
                message: 'Learning modules could not be loaded.',
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final modules = snapshot.data!;
            if (modules.isEmpty) {
              return const _ModulesMessage(
                message: 'No learning modules available yet.',
              );
            }

            return Column(
              children: [
                for (final module in modules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _CourseModuleCard(
                      module: module,
                      metadata: _metadataFor(module.id),
                      progress:
                          progress?.categories[module.id]?.progressPercentage ??
                          0,
                      onPressed: () => onModuleSelected(module),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModulesMessage extends StatelessWidget {
  final String message;

  const _ModulesMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: _muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CourseModuleCard extends StatelessWidget {
  final ElearningModule module;
  final _ModuleMetadata metadata;
  final double progress;
  final VoidCallback onPressed;

  const _CourseModuleCard({
    required this.module,
    required this.metadata,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = progress > 0;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isActive ? _primary : Colors.white,
          width: isActive ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModuleArtwork(moduleId: module.id, metadata: metadata),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LevelChip(
                      label: module.level,
                      color: metadata.accent,
                      background: metadata.softColor,
                    ),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: '${module.durationMinutes} min',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  module.title,
                  style: GoogleFonts.inter(
                    color: _ink,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  module.description,
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF64746C),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${module.lessonCount} lessons',
                      style: GoogleFonts.inter(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$percent%',
                      style: GoogleFonts.inter(
                        color: isActive ? _primary : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE6E9E8),
                    valueColor: const AlwaysStoppedAnimation(_primary),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(
                      isActive
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                    label: Text(isActive ? 'Continue' : 'Start Learning'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _LearningPathSheet extends StatelessWidget {
  final ElearningModule module;
  final double progress;
  final ValueChanged<LearningSection> onSectionSelected;

  const _LearningPathSheet({
    required this.module,
    required this.progress,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module.title,
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              module.description,
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.school_outlined, label: module.level),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${module.durationMinutes} min',
                ),
                _InfoChip(
                  icon: Icons.menu_book_rounded,
                  label: '${module.lessonCount} lessons',
                ),
                _InfoChip(
                  icon: Icons.insights_rounded,
                  label: '$percent% complete',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Recommended path: Guide → Video → Quiz',
              style: GoogleFonts.inter(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _LearningPathButton(
              label: 'Open Guides',
              icon: Icons.menu_book_outlined,
              onPressed: () => onSectionSelected(LearningSection.guides),
            ),
            const SizedBox(height: 10),
            _LearningPathButton(
              label: 'Watch Video Lessons',
              icon: Icons.play_circle_outline_rounded,
              onPressed: () => onSectionSelected(LearningSection.videoLessons),
            ),
            const SizedBox(height: 10),
            _LearningPathButton(
              label: 'Take Quiz',
              icon: Icons.quiz_outlined,
              onPressed: () => onSectionSelected(LearningSection.quiz),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningPathButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _LearningPathButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ModuleArtwork extends StatelessWidget {
  final String moduleId;
  final _ModuleMetadata metadata;

  const _ModuleArtwork({required this.moduleId, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    metadata.softColor,
                    Colors.white,
                    metadata.accent.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -24,
            top: -42,
            child: _BlurredCircle(
              size: 132,
              color: metadata.accent.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            right: -12,
            bottom: -52,
            child: _BlurredCircle(
              size: 154,
              color: metadata.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: 35,
            bottom: 22,
            child: Transform.rotate(
              angle: -0.16,
              child: Text(
                metadata.secondaryEmoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: metadata.accent.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _moduleEmoji(moduleId),
              style: const TextStyle(fontSize: 54),
            ),
          ),
          Positioned(
            right: 32,
            top: 24,
            child: Transform.rotate(
              angle: 0.14,
              child: Text(
                metadata.tertiaryEmoji,
                style: const TextStyle(fontSize: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurredCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _LevelChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleMetadata {
  final Color accent;
  final Color softColor;
  final String secondaryEmoji;
  final String tertiaryEmoji;

  const _ModuleMetadata({
    required this.accent,
    required this.softColor,
    required this.secondaryEmoji,
    required this.tertiaryEmoji,
  });
}

_ModuleMetadata _metadataFor(String categoryId) {
  switch (categoryId) {
    case 'organic':
      return const _ModuleMetadata(
        accent: Color(0xFF059669),
        softColor: Color(0xFFECFDF5),
        secondaryEmoji: '🍃',
        tertiaryEmoji: '🥕',
      );
    case 'inorganic':
      return const _ModuleMetadata(
        accent: Color(0xFF2563EB),
        softColor: Color(0xFFDBEAFE),
        secondaryEmoji: '🥫',
        tertiaryEmoji: '🧴',
      );
    case 'hazardous':
      return const _ModuleMetadata(
        accent: Color(0xFFDC2626),
        softColor: Color(0xFFFEE2E2),
        secondaryEmoji: '🔋',
        tertiaryEmoji: '🧪',
      );
    default:
      return const _ModuleMetadata(
        accent: _primary,
        softColor: Color(0xFFECFDF5),
        secondaryEmoji: '♻️',
        tertiaryEmoji: '🌍',
      );
  }
}

String _moduleEmoji(String moduleId) {
  switch (moduleId) {
    case 'organic':
      return '🍃';
    case 'inorganic':
      return '♻️';
    case 'hazardous':
      return '🔋';
    default:
      return '🌍';
  }
}

double _overallProgress(LearningProgress? progress) {
  if (progress == null || wasteCategories.isEmpty) return 0;

  final total = wasteCategories.fold<double>(
    0,
    (sum, category) =>
        sum + (progress.categories[category.id]?.progressPercentage ?? 0),
  );
  return (total / wasteCategories.length).clamp(0.0, 1.0);
}
