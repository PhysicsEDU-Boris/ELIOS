import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _background = Color(0xFFF7FAF6);
const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _surface = Color(0xFFEBEFEA);

class VideoLessonsPage extends StatefulWidget {
  const VideoLessonsPage({super.key});

  @override
  State<VideoLessonsPage> createState() => _VideoLessonsPageState();
}

class _VideoLessonsPageState extends State<VideoLessonsPage> {
  void _openVideoPlaceholder(_VideoLesson lesson) {
    debugPrint('Video lesson selected: ${lesson.title}');
    showDialog<void>(
      context: context,
      builder: (context) => _VideoPlaceholderDialog(lesson: lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _VideoLessonsTopBar(),
                        const SizedBox(height: 26),
                        const _VideoLessonsHeader(),
                        const SizedBox(height: 16),
                        _FeaturedVideoCard(
                          lesson: _featuredVideo,
                          onTap: () => _openVideoPlaceholder(_featuredVideo),
                        ),
                        const SizedBox(height: 28),
                        for (final section in _videoSections) ...[
                          _VideoSection(
                            section: section,
                            onLessonTap: _openVideoPlaceholder,
                          ),
                          const SizedBox(height: 30),
                        ],
                      ],
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

class _VideoLessonsTopBar extends StatelessWidget {
  const _VideoLessonsTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            color: _primary,
            tooltip: 'Back to learning hub',
          ),
          const SizedBox(width: 4),
          const Icon(Icons.eco_outlined, color: _primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'ELIO',
            style: GoogleFonts.inter(
              color: _primary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _primary.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.school_outlined, color: _primary, size: 19),
          ),
        ],
      ),
    );
  }
}

class _VideoLessonsHeader extends StatelessWidget {
  const _VideoLessonsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Lessons',
          style: GoogleFonts.inter(
            color: _ink,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Explore waste management concepts through engaging educational '
          'videos and ELIO robot demonstrations.',
          style: GoogleFonts.inter(
            color: _muted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeaturedVideoCard extends StatelessWidget {
  final _VideoLesson lesson;
  final VoidCallback onTap;

  const _FeaturedVideoCard({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border.withValues(alpha: 0.3)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203D36), Color(0xFF0A1713)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: 18,
                top: 12,
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  color: Color(0xFF9FF4CE),
                  size: 112,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _VideoBadge(
                  label: '☆ FEATURED',
                  background: _primary.withValues(alpha: 0.92),
                  foreground: Colors.white,
                ),
              ),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _VideoBadge(
                          label: lesson.duration,
                          background: _ink.withValues(alpha: 0.72),
                          foreground: Colors.white,
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lesson.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      lesson.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _VideoSection extends StatelessWidget {
  final _VideoSectionData section;
  final ValueChanged<_VideoLesson> onLessonTap;

  const _VideoSection({required this.section, required this.onLessonTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 18, height: 18, color: _ink),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                section.title,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => debugPrint('View all ${section.title} videos'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('View All →'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (section.lessons.isEmpty)
          const _EmptyVideosState()
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.lessons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final lesson = section.lessons[index];
                return _VideoLessonCard(
                  lesson: lesson,
                  onTap: () => onLessonTap(lesson),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VideoLessonCard extends StatelessWidget {
  final _VideoLesson lesson;
  final VoidCallback onTap;

  const _VideoLessonCard({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VideoThumbnail(lesson: lesson),
              const SizedBox(height: 8),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lesson.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
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

class _VideoThumbnail extends StatelessWidget {
  final _VideoLesson lesson;

  const _VideoThumbnail({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lesson.accent.withValues(alpha: 0.28),
            lesson.accent.withValues(alpha: 0.08),
            _surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(child: Icon(lesson.icon, color: lesson.accent, size: 52)),
          Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.68),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: _VideoBadge(
              label: lesson.duration,
              background: _ink.withValues(alpha: 0.72),
              foreground: Colors.white,
            ),
          ),
          Positioned(
            left: 7,
            top: 7,
            child: _VideoBadge(
              label: lesson.status,
              background: Colors.white.withValues(alpha: 0.86),
              foreground: lesson.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _VideoBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlaceholderDialog extends StatelessWidget {
  final _VideoLesson lesson;

  const _VideoPlaceholderDialog({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(lesson.icon, color: lesson.accent, size: 34),
      title: Text(
        lesson.title,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Video player is not connected yet. This lesson will support local '
        'or Firebase-hosted videos later.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: _muted, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _EmptyVideosState extends StatelessWidget {
  const _EmptyVideosState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.3)),
      ),
      child: Text(
        'No video lessons available yet.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: _muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VideoLesson {
  final String title;
  final String subtitle;
  final String category;
  final String duration;
  final IconData icon;
  final Color accent;
  final String status;
  final String? futureAssetPath;

  const _VideoLesson({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.duration,
    required this.icon,
    required this.accent,
    required this.status,
    this.futureAssetPath,
  });
}

class _VideoSectionData {
  final String title;
  final List<_VideoLesson> lessons;

  const _VideoSectionData({required this.title, required this.lessons});
}

const _featuredVideo = _VideoLesson(
  title: 'Introduction to Waste Management',
  subtitle: 'Foundation module',
  category: 'Foundation Module',
  duration: '12:45',
  icon: Icons.precision_manufacturing_outlined,
  accent: Color(0xFF9FF4CE),
  status: 'Watch',
  futureAssetPath: 'assets/videos/elio_robot_demo.mp4',
);

const _videoSections = [
  _VideoSectionData(
    title: 'Organic Waste',
    lessons: [
      _VideoLesson(
        title: 'Introduction to Organic Waste',
        subtitle: 'Mod 1 • Basics',
        category: 'Organic',
        duration: '5:20',
        icon: Icons.eco_outlined,
        accent: Color(0xFF3B7C45),
        status: 'Watch',
        futureAssetPath: 'assets/videos/organic_composting.mp4',
      ),
      _VideoLesson(
        title: 'Composting Fundamentals',
        subtitle: 'Mod 1 • Science',
        category: 'Organic',
        duration: '8:15',
        icon: Icons.compost_outlined,
        accent: Color(0xFF6B512D),
        status: 'Watch',
        futureAssetPath: 'assets/videos/organic_composting.mp4',
      ),
      _VideoLesson(
        title: 'Composting Into Biogas',
        subtitle: 'Mod 1 • Practical',
        category: 'Organic',
        duration: '6:40',
        icon: Icons.energy_savings_leaf_outlined,
        accent: Color(0xFF20745B),
        status: 'Soon',
      ),
    ],
  ),
  _VideoSectionData(
    title: 'Recyclables & 3R',
    lessons: [
      _VideoLesson(
        title: 'Understanding Recyclable Waste',
        subtitle: 'Mod 2 • Basics',
        category: 'Inorganic',
        duration: '7:10',
        icon: Icons.recycling_rounded,
        accent: Color(0xFF356A7D),
        status: 'Watch',
        futureAssetPath: 'assets/videos/inorganic_3r.mp4',
      ),
      _VideoLesson(
        title: 'Reduce: Minimizing Impact',
        subtitle: 'Mod 2 • The 3Rs',
        category: 'Inorganic',
        duration: '4:45',
        icon: Icons.local_drink_outlined,
        accent: Color(0xFF89745A),
        status: 'Watch',
      ),
      _VideoLesson(
        title: 'Reuse: Creative Solutions',
        subtitle: 'Mod 2 • The 3Rs',
        category: 'Inorganic',
        duration: '6:05',
        icon: Icons.autorenew_rounded,
        accent: Color(0xFF506B52),
        status: 'Soon',
      ),
    ],
  ),
  _VideoSectionData(
    title: 'Hazardous Waste',
    lessons: [
      _VideoLesson(
        title: 'Introduction to B3 Waste',
        subtitle: 'Mod 3 • Basics',
        category: 'Hazardous',
        duration: '9:30',
        icon: Icons.warning_amber_rounded,
        accent: Color(0xFF176C7B),
        status: 'Watch',
        futureAssetPath: 'assets/videos/hazardous_b3.mp4',
      ),
      _VideoLesson(
        title: 'Characteristics of Hazmat',
        subtitle: 'Mod 3 • Analysis',
        category: 'Hazardous',
        duration: '11:15',
        icon: Icons.battery_alert_outlined,
        accent: Color(0xFF625B50),
        status: 'Watch',
      ),
      _VideoLesson(
        title: 'Safe Handling Procedures',
        subtitle: 'Mod 3 • Protocol',
        category: 'Hazardous',
        duration: '8:25',
        icon: Icons.health_and_safety_outlined,
        accent: Color(0xFF4B8583),
        status: 'Soon',
      ),
    ],
  ),
];
