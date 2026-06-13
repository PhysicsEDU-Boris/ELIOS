import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../models/video_lesson.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/elio_learning_app_bar.dart';

const _background = Color(0xFFF7FAF6);
const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _surface = Color(0xFFEBEFEA);

class VideoLessonsPage extends StatelessWidget {
  const VideoLessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const ElioLearningAppBar(
        title: 'Video Lessons',
        showBack: true,
        backgroundColor: _background,
      ),
      body: const VideoLessonsContent(),
    );
  }
}

class VideoLessonsContent extends StatefulWidget {
  final String? selectedModuleId;
  final VoidCallback? onClearFilter;

  const VideoLessonsContent({
    super.key,
    this.selectedModuleId,
    this.onClearFilter,
  });

  @override
  State<VideoLessonsContent> createState() => _VideoLessonsContentState();
}

class _VideoLessonsContentState extends State<VideoLessonsContent> {
  final ElearningContentService _service = ElearningContentService();

  void _openVideo(VideoLesson lesson) {
    final youtubeId = lesson.youtubeId.trim();
    if (youtubeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is not available yet.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _YoutubeVideoPage(title: lesson.title, youtubeId: youtubeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: StreamBuilder<List<VideoLesson>>(
        stream: _service.watchVideoLessons(moduleId: widget.selectedModuleId),
        builder: (context, snapshot) {
          final lessons = snapshot.data ?? const <VideoLesson>[];
          final featured = lessons
              .where((lesson) => lesson.isFeatured)
              .firstOrNull;
          final sections = _groupVideos(
            lessons.where((lesson) => !lesson.isFeatured),
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watch and Learn',
                            style: GoogleFonts.inter(
                              color: _ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Explore waste management concepts through '
                            'educational videos and ELIO demonstrations.',
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.selectedModuleId != null) ...[
                            const SizedBox(height: 18),
                            _FilterBanner(
                              moduleId: widget.selectedModuleId!,
                              onClear: widget.onClearFilter,
                            ),
                          ],
                          const SizedBox(height: 22),
                          if (snapshot.hasError)
                            const _VideoMessage(
                              text: 'Video lessons could not be loaded.',
                            )
                          else if (!snapshot.hasData)
                            const Center(child: CircularProgressIndicator())
                          else if (lessons.isEmpty)
                            const _VideoMessage(
                              text: 'No published video lessons are available.',
                            )
                          else ...[
                            if (featured != null) ...[
                              _FeaturedVideoCard(
                                lesson: featured,
                                onTap: () => _openVideo(featured),
                              ),
                              const SizedBox(height: 28),
                            ],
                            for (final entry in sections.entries) ...[
                              Text(
                                entry.key,
                                style: GoogleFonts.inter(
                                  color: _ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 198,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: entry.value.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final lesson = entry.value[index];
                                    return _VideoLessonCard(
                                      lesson: lesson,
                                      onTap: () => _openVideo(lesson),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final String moduleId;
  final VoidCallback? onClear;

  const _FilterBanner({required this.moduleId, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: ${_moduleTitle(moduleId)}',
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedVideoCard extends StatelessWidget {
  final VideoLesson lesson;
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203D36), Color(0xFF0A1713)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (lesson.thumbnailAsset.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    lesson.thumbnailAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _VideoBadge(label: 'FEATURED'),
                    const Spacer(),
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const Spacer(),
                    Text(
                      lesson.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${lesson.durationLabel}  •  ${lesson.moduleLabel}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
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

class _VideoLessonCard extends StatelessWidget {
  final VideoLesson lesson;
  final VoidCallback onTap;

  const _VideoLessonCard({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 112,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withValues(alpha: 0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (lesson.thumbnailAsset.trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        lesson.thumbnailAsset,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 42,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: _VideoBadge(label: lesson.durationLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              lesson.moduleLabel,
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
    );
  }
}

class _YoutubeVideoPage extends StatefulWidget {
  final String title;
  final String youtubeId;

  const _YoutubeVideoPage({required this.title, required this.youtubeId});

  @override
  State<_YoutubeVideoPage> createState() => _YoutubeVideoPageState();
}

class _YoutubeVideoPageState extends State<_YoutubeVideoPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(mute: false, strictRelatedVideos: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(child: YoutubePlayer(controller: _controller)),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final String label;

  const _VideoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VideoMessage extends StatelessWidget {
  final String text;

  const _VideoMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: _muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Map<String, List<VideoLesson>> _groupVideos(Iterable<VideoLesson> lessons) {
  final groups = <String, List<VideoLesson>>{};
  for (final lesson in lessons) {
    final title = lesson.sectionTitle.trim().isEmpty
        ? _moduleTitle(lesson.moduleId)
        : lesson.sectionTitle;
    groups.putIfAbsent(title, () => <VideoLesson>[]).add(lesson);
  }
  return groups;
}

String _moduleTitle(String moduleId) {
  switch (moduleId) {
    case 'organic':
      return 'Organic Waste Management';
    case 'inorganic':
      return 'Inorganic / Recyclable Waste Management';
    case 'hazardous':
      return 'Hazardous Waste (B3) Management';
    default:
      return moduleId;
  }
}
