import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/learning_progress.dart';
import '../../../models/waste_category.dart';
import '../../../providers/learning_progress_provider.dart';

const _background = Color(0xFFF8FAF9);
const _primary = Color(0xFF00694C);
const _darkGreen = Color(0xFF001F11);
const _ink = Color(0xFF1B1C1D);
const _muted = Color(0xFF414843);
const _border = Color(0xFFC1C8C1);
const _blue = Color(0xFF3E6185);

class GuidesPage extends ConsumerWidget {
  const GuidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _darkGreen.withValues(alpha: 0.08),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: _primary,
          tooltip: 'Back to learning hub',
        ),
        title: Text(
          'Guides',
          style: GoogleFonts.inter(
            color: _darkGreen,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GuideFilterChips(),
                  const SizedBox(height: 42),
                  const _GuidesHeader(),
                  const SizedBox(height: 22),
                  _GuideProgressCard(progress: progress),
                  const SizedBox(height: 32),
                  _ClassificationModule(progress: progress),
                  const SizedBox(height: 32),
                  _AdvancedRecyclingModule(progress: progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideFilterChips extends StatelessWidget {
  const _GuideFilterChips();

  static const _labels = ['All Categories', 'Guides', 'Video Lessons', 'Quiz'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _primary : const Color(0xFFE6E9E8),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              _labels[index],
              style: GoogleFonts.inter(
                color: selected ? Colors.white : const Color(0xFF3D4943),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuidesHeader extends StatelessWidget {
  const _GuidesHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Physics\nEnvironmental\nLearning Module',
      style: GoogleFonts.inter(
        color: _ink,
        fontSize: 38,
        height: 1.26,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
    );
  }
}

class _GuideProgressCard extends StatelessWidget {
  final LearningProgress? progress;

  const _GuideProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final value = _overallProgress(progress);
    final percent = (value * 100).round();
    final completedLessons = _completedLessonCount(progress);
    final totalLessons = wasteCategories.fold<int>(
      0,
      (sum, category) => sum + category.examples.length + category.tips.length,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT PROGRESS',
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$percent%\nCompleted',
                  style: GoogleFonts.inter(
                    color: _darkGreen,
                    fontSize: 25,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$completedLessons of $totalLessons\nLessons',
                style: GoogleFonts.inter(
                  color: _blue,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: const Color(0xFFE3E2E3),
              valueColor: const AlwaysStoppedAnimation(_primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationModule extends StatelessWidget {
  final LearningProgress? progress;

  const _ClassificationModule({required this.progress});

  @override
  Widget build(BuildContext context) {
    final organic = _category('organic');
    final inorganic = _category('inorganic');
    final organicViewed =
        progress?.categories[organic.id]?.lessonViewed ?? false;
    final inorganicViewed =
        progress?.categories[inorganic.id]?.lessonViewed ?? false;

    final lessons = [
      _GuideLesson(
        'Introduction & Definitions of Waste',
        organicViewed || inorganicViewed,
      ),
      _GuideLesson('Categories of ${organic.title}', organicViewed),
      _GuideLesson('Categories of ${inorganic.title}', inorganicViewed),
      _GuideLesson(
        'Biodegradable vs. Non-Biodegradable Properties',
        organicViewed && inorganicViewed,
      ),
    ];

    return _GuideModuleCard(
      title: 'Module 1:',
      subtitle: 'Waste Classification &\nIdentification',
      description:
          'Foundational principles of physical waste streams and sorting logic.',
      child: Column(
        children: [
          for (var index = 0; index < lessons.length; index++) ...[
            _ChecklistTile(lesson: lessons[index]),
            if (index != lessons.length - 1) const SizedBox(height: 17),
          ],
        ],
      ),
    );
  }
}

class _AdvancedRecyclingModule extends StatelessWidget {
  final LearningProgress? progress;

  const _AdvancedRecyclingModule({required this.progress});

  @override
  Widget build(BuildContext context) {
    final organic = _category('organic');
    final inorganic = _category('inorganic');
    final hazardous = _category('hazardous');

    return _GuideModuleCard(
      title: 'Module 2:',
      subtitle: 'Advanced Recycling With ELIO',
      description:
          'Application of robotic systems in large-scale environmental reclamation.',
      child: Column(
        children: [
          _FeaturePanel(
            title: '${organic.title} Upcycling\n(Compost & Biogas)',
            actionLabel: 'Launch\nELIO\nSimulation',
            actionIcon: Icons.rocket_launch_outlined,
            filled: true,
            onPressed: () => debugPrint('Launch ELIO organic simulation'),
          ),
          const SizedBox(height: 18),
          _GuideActionRow(
            title: '${inorganic.title}\n(3R) Management',
            completed:
                progress?.categories[inorganic.id]?.lessonViewed ?? false,
            badge: 'Interactive\nFeature',
          ),
          const SizedBox(height: 18),
          _FeaturePanel(
            title: 'Industrial Recycling:\nPlastic, Paper, Metal',
            actionLabel: 'Watch\nAnimation',
            actionIcon: Icons.play_circle_outline_rounded,
            filled: false,
            onPressed: () => debugPrint('Watch industrial recycling animation'),
          ),
          const SizedBox(height: 18),
          _GuideActionRow(
            title: 'The Role of Robotics in\nEnvironmental Protection',
            completed:
                progress?.categories[hazardous.id]?.lessonViewed ?? false,
          ),
          const SizedBox(height: 22),
          const _EthicsCallout(),
        ],
      ),
    );
  }
}

class _GuideModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final Widget child;

  const _GuideModuleCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _darkGreen,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _darkGreen,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final _GuideLesson lesson;

  const _ChecklistTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            lesson.completed
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            color: _border,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            lesson.title,
            style: GoogleFonts.inter(color: _ink, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  final String title;
  final String actionLabel;
  final IconData actionIcon;
  final bool filled;
  final VoidCallback onPressed;

  const _FeaturePanel({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: _darkGreen,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: filled
                ? FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(actionIcon, size: 15),
                    label: Text(actionLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: _darkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: onPressed,
                    icon: Icon(actionIcon, size: 15),
                    label: Text(actionLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GuideActionRow extends StatelessWidget {
  final String title;
  final bool completed;
  final String? badge;

  const _GuideActionRow({
    required this.title,
    required this.completed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          completed
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          color: _border,
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(color: _ink, fontSize: 14, height: 1.45),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _blue.withValues(alpha: 0.2)),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.inter(
                color: const Color(0xFFA7CAF3),
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EthicsCallout extends StatelessWidget {
  const _EthicsCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined, color: _blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Environmental Empathy\n& Ethical Reflections',
              style: GoogleFonts.inter(
                color: _blue,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFFA7BBD3),
          ),
        ],
      ),
    );
  }
}

class _GuideLesson {
  final String title;
  final bool completed;

  const _GuideLesson(this.title, this.completed);
}

WasteCategory _category(String id) {
  return wasteCategories.firstWhere((category) => category.id == id);
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

int _completedLessonCount(LearningProgress? progress) {
  if (progress == null) return 0;

  return wasteCategories.fold<int>(0, (sum, category) {
    final categoryProgress = progress.categories[category.id];
    if (categoryProgress == null) return sum;

    final lessonPoints = categoryProgress.lessonViewed
        ? category.examples.length
        : 0;
    final quizPoints = categoryProgress.totalQuestions == 0
        ? 0
        : (category.tips.length *
                  categoryProgress.quizBestScore /
                  categoryProgress.totalQuestions)
              .round();
    return sum + lessonPoints + quizPoints;
  });
}
