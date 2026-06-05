import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/learning_progress.dart';
import '../../models/waste_category.dart';
import '../../providers/learning_progress_provider.dart';
import 'elearning/guides_page.dart';

const _background = Color(0xFFF8FAF9);
const _primary = Color(0xFF00694C);
const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF3D4943);
const _border = Color(0xFFE6E9E8);

class ElearningTab extends ConsumerWidget {
  const ElearningTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 34, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LearningHeader(),
                  const SizedBox(height: 30),
                  _LearningFilterChips(
                    onAllCategoriesTap: () =>
                        debugPrint('All learning categories selected'),
                    onGuidesTap: () => _openGuides(context),
                    onVideoLessonsTap: () =>
                        debugPrint('Video lessons selected'),
                    onQuizTap: () => debugPrint('Quiz selected'),
                  ),
                  const SizedBox(height: 28),
                  _ProgressOverviewCard(progress: progress),
                  const SizedBox(height: 32),
                  _CourseModulesSection(progress: progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openGuides(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const GuidesPage()));
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
            fontSize: 40,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
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

class _LearningFilterChips extends StatelessWidget {
  final VoidCallback? onAllCategoriesTap;
  final VoidCallback? onGuidesTap;
  final VoidCallback? onVideoLessonsTap;
  final VoidCallback? onQuizTap;

  const _LearningFilterChips({
    this.onAllCategoriesTap,
    this.onGuidesTap,
    this.onVideoLessonsTap,
    this.onQuizTap,
  });

  static const _labels = ['All Categories', 'Guides', 'Video Lessons', 'Quiz'];

  @override
  Widget build(BuildContext context) {
    final callbacks = [
      onAllCategoriesTap,
      onGuidesTap,
      onVideoLessonsTap,
      onQuizTap,
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == 0;
          return Material(
            color: selected ? _primary : _border,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: callbacks[index],
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Text(
                    _labels[index],
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
  final LearningProgress? progress;

  const _CourseModulesSection({required this.progress});

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
        ...wasteCategories.map((category) {
          final metadata = _metadataFor(category.id);
          final categoryProgress =
              progress?.categories[category.id]?.progressPercentage ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _CourseModuleCard(
              category: category,
              metadata: metadata,
              progress: categoryProgress,
              onPressed: () => debugPrint(
                '${categoryProgress > 0 ? 'Continue' : 'Start'} '
                '${category.id} learning module',
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CourseModuleCard extends StatelessWidget {
  final WasteCategory category;
  final _ModuleMetadata metadata;
  final double progress;
  final VoidCallback onPressed;

  const _CourseModuleCard({
    required this.category,
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
          _ModuleArtwork(category: category, metadata: metadata),
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
                      label: metadata.level,
                      color: metadata.accent,
                      background: metadata.softColor,
                    ),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: metadata.duration,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  metadata.title,
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
                  metadata.description,
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
                      '${metadata.lessonCount} lessons',
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

class _ModuleArtwork extends StatelessWidget {
  final WasteCategory category;
  final _ModuleMetadata metadata;

  const _ModuleArtwork({required this.category, required this.metadata});

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
            child: Text(category.emoji, style: const TextStyle(fontSize: 54)),
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
  final String title;
  final String description;
  final String level;
  final String duration;
  final int lessonCount;
  final Color accent;
  final Color softColor;
  final String secondaryEmoji;
  final String tertiaryEmoji;

  const _ModuleMetadata({
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
    required this.lessonCount,
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
        title: 'Organic Waste Management',
        description:
            'Learn how food scraps and natural materials decompose, then see '
            'how ELIO identifies them for composting.',
        level: 'Beginner Friendly',
        duration: '20–25 min',
        lessonCount: 6,
        accent: Color(0xFF059669),
        softColor: Color(0xFFECFDF5),
        secondaryEmoji: '🍃',
        tertiaryEmoji: '🥕',
      );
    case 'inorganic':
      return const _ModuleMetadata(
        title: 'Inorganic / Recyclable Waste Management',
        description:
            'Understand plastics, glass, paper, and metals while exploring '
            'the physical signals ELIO uses to sort recyclables.',
        level: 'Intermediate',
        duration: '20–25 min',
        lessonCount: 7,
        accent: Color(0xFF2563EB),
        softColor: Color(0xFFDBEAFE),
        secondaryEmoji: '🥫',
        tertiaryEmoji: '🧴',
      );
    case 'hazardous':
      return const _ModuleMetadata(
        title: 'Hazardous Waste (B3) Management',
        description:
            'Recognize batteries, electronics, and toxic materials, and learn '
            'the safe handling rules used by ELIO.',
        level: 'Advanced Level',
        duration: '25–30 min',
        lessonCount: 8,
        accent: Color(0xFFDC2626),
        softColor: Color(0xFFFEE2E2),
        secondaryEmoji: '🔋',
        tertiaryEmoji: '🧪',
      );
    default:
      return const _ModuleMetadata(
        title: 'Waste Management',
        description: 'Learn how ELIO identifies and sorts this waste category.',
        level: 'Beginner Friendly',
        duration: '20–25 min',
        lessonCount: 6,
        accent: _primary,
        softColor: Color(0xFFECFDF5),
        secondaryEmoji: '♻️',
        tertiaryEmoji: '🌍',
      );
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
