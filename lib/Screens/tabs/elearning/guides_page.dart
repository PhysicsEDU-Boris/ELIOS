import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../models/guide_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/elio_learning_app_bar.dart';

const _background = Color(0xFFF8FAF9);
const _primary = Color(0xFF00694C);
const _ink = Color(0xFF1B1C1D);
const _muted = Color(0xFF414843);
const _border = Color(0xFFC1C8C1);

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const ElioLearningAppBar(title: 'Guides', showBack: true),
      body: const GuidesContent(),
    );
  }
}

class GuidesContent extends ConsumerStatefulWidget {
  final String? selectedModuleId;
  final VoidCallback? onClearFilter;
  final String? resumeGuideId;
  final VoidCallback? onResumeGuideHandled;

  const GuidesContent({
    super.key,
    this.selectedModuleId,
    this.onClearFilter,
    this.resumeGuideId,
    this.onResumeGuideHandled,
  });

  @override
  ConsumerState<GuidesContent> createState() => _GuidesContentState();
}

class _GuidesContentState extends ConsumerState<GuidesContent> {
  final ElearningContentService _service = ElearningContentService();
  String? _lastHandledResumeGuideId;

  @override
  void didUpdateWidget(covariant GuidesContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.resumeGuideId != widget.resumeGuideId) {
      _lastHandledResumeGuideId = null;
    }
  }

  void _maybeOpenResumeGuide(List<GuideLesson> guides) {
    final resumeGuideId = widget.resumeGuideId;
    if (resumeGuideId == null || resumeGuideId.trim().isEmpty) return;
    if (_lastHandledResumeGuideId == resumeGuideId) return;

    GuideLesson? target;
    for (final guide in guides) {
      if (guide.id == resumeGuideId) {
        target = guide;
        break;
      }
    }

    if (target == null) return;

    _lastHandledResumeGuideId = resumeGuideId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onResumeGuideHandled?.call();
      _openGuideLesson(context: context, ref: ref, lesson: target!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: StreamBuilder<List<GuideLesson>>(
        stream: _service.watchGuideLessons(moduleId: widget.selectedModuleId),
        builder: (context, snapshot) {
          final guides = snapshot.data ?? const <GuideLesson>[];
          if (snapshot.hasData) _maybeOpenResumeGuide(guides);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Physics\nEnvironmental\nLearning Module',
                      style: GoogleFonts.inter(
                        color: _ink,
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (widget.selectedModuleId != null) ...[
                      const SizedBox(height: 18),
                      _FilterBanner(
                        moduleId: widget.selectedModuleId!,
                        onClear: widget.onClearFilter,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (snapshot.hasError)
                      const _GuideMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Guides could not be loaded.',
                        message:
                            'Check the Firestore connection and try again.',
                      )
                    else if (!snapshot.hasData)
                      const Center(child: CircularProgressIndicator())
                    else if (guides.isEmpty)
                      _GuideMessage(
                        icon: Icons.menu_book_outlined,
                        title: 'No guides available.',
                        message: widget.selectedModuleId == null
                            ? 'Published guides will appear here.'
                            : 'This module does not have a published guide yet.',
                      )
                    else
                      ..._groupLessons(guides).entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: _GuideModuleCard(
                            title: entry.key,
                            lessons: entry.value,
                            onOpenGuide: (lesson) => _openGuideLesson(
                              context: context,
                              ref: ref,
                              lesson: lesson,
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

Future<void> _openGuideLesson({
  required BuildContext context,
  required WidgetRef ref,
  required GuideLesson lesson,
}) async {
  debugPrint('[StartupDiag] opening WebView/PDF only after user action');

  final pdfUrl = lesson.pdfUrl.trim();
  if (pdfUrl.isEmpty) {
    _showGuideUnavailableMessage(context);
    return;
  }

  if (!context.mounted) return;
  final progress = ref.read(learningProgressProvider).valueOrNull;
  final initialPage = progress?.guideReadProgress[lesson.id] ?? 0;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => _GuidePdfPage(
        title: lesson.title,
        pdfUrl: pdfUrl,
        guideId: lesson.id,
        moduleId: lesson.moduleId,
        pageCount: lesson.pageCount,
        readTimeMinutes: lesson.readTimeMinutes,
        initialPage: initialPage,
      ),
    ),
  );
}

void _showGuideUnavailableMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Guide PDF is not available yet.')),
  );
}

class _GuideModuleCard extends StatelessWidget {
  final String title;
  final List<GuideLesson> lessons;
  final ValueChanged<GuideLesson> onOpenGuide;

  const _GuideModuleCard({
    required this.title,
    required this.lessons,
    required this.onOpenGuide,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < lessons.length; index++) ...[
                _GuideLessonTile(
                  lesson: lessons[index],
                  onOpenGuide: onOpenGuide,
                ),
                if (index != lessons.length - 1) const Divider(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideLessonTile extends ConsumerWidget {
  final GuideLesson lesson;
  final ValueChanged<GuideLesson> onOpenGuide;

  const _GuideLessonTile({required this.lesson, required this.onOpenGuide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final readPages = progress?.guideReadProgress[lesson.id] ?? 0;
    final totalPages = lesson.pageCount > 0 ? lesson.pageCount : 1;
    final percent = (readPages / totalPages).clamp(0.0, 1.0);
    final completed = progress?.completedGuideIds.contains(lesson.id) ?? false;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _GuideCover(coverUrl: lesson.coverUrl),
          minLeadingWidth: 52,
          minVerticalPadding: 8,
          visualDensity: VisualDensity.comfortable,
          title: Text(
            lesson.title,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: lesson.description.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    lesson.description,
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
          trailing: completed
              ? const Icon(Icons.check_circle_rounded, color: _primary)
              : const Icon(Icons.chevron_right_rounded),
          onTap: () => onOpenGuide(lesson),
        ),
        if (percent > 0 || completed) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: completed ? 1 : percent,
            minHeight: 4,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: _border.withValues(alpha: 0.35),
            valueColor: const AlwaysStoppedAnimation<Color>(_primary),
          ),
        ],
      ],
    );
  }
}

class _GuideCover extends StatelessWidget {
  final String coverUrl;

  const _GuideCover({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 52,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EF),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_outlined, color: _primary),
    );

    if (coverUrl.trim().isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        width: 52,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

class _GuidePdfPage extends ConsumerStatefulWidget {
  final String title;
  final String pdfUrl;
  final String guideId;
  final String moduleId;
  final int pageCount;
  final int readTimeMinutes;
  final int initialPage;

  const _GuidePdfPage({
    required this.title,
    required this.pdfUrl,
    required this.guideId,
    required this.moduleId,
    required this.pageCount,
    required this.readTimeMinutes,
    required this.initialPage,
  });

  @override
  ConsumerState<_GuidePdfPage> createState() => _GuidePdfPageState();
}

class _GuidePdfPageState extends ConsumerState<_GuidePdfPage> {
  late final PdfViewerController _controller;
  late final LearningProgressNotifier _progressNotifier;
  File? _cachedFile;
  var _isDownloading = true;
  var _loadFailed = false;
  var _effectivePageCount = 0;
  var _latestPageReached = 0;
  var _loggedPdfBuild = false;

  @override
  void initState() {
    super.initState();
    _progressNotifier = ref.read(learningProgressProvider.notifier);
    _controller = PdfViewerController();
    _effectivePageCount = widget.pageCount < 0 ? 0 : widget.pageCount;
    _latestPageReached = _initialPageNumber();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(widget.pdfUrl);
      if (!mounted) return;
      setState(() {
        _cachedFile = file;
        _isDownloading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isDownloading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_latestPageReached > 0) {
      _saveProgressAfterDispose(
        _latestPageReached,
        pageCount: _effectivePageCount,
      );
    }
    super.dispose();
  }

  int _initialPageNumber() {
    final initial = widget.initialPage <= 0 ? 1 : widget.initialPage;
    if (_effectivePageCount <= 0) return initial;
    return initial.clamp(1, _effectivePageCount).toInt();
  }

  void _saveProgressAfterDispose(int pageReached, {required int pageCount}) {
    final notifier = _progressNotifier;
    final guideId = widget.guideId;
    final moduleId = widget.moduleId;
    final readTimeMinutes = widget.readTimeMinutes;

    Future<void>(() {
      unawaited(
        notifier.updateGuideReadProgress(
          guideId,
          moduleId: moduleId,
          pageReached: pageReached,
          pageCount: pageCount,
          readMinutes: readTimeMinutes,
        ),
      );
    });
  }

  void _saveProgress(int pageReached, {required int pageCount}) {
    unawaited(
      _progressNotifier.updateGuideReadProgress(
        widget.guideId,
        moduleId: widget.moduleId,
        pageReached: pageReached,
        pageCount: pageCount,
        readMinutes: widget.readTimeMinutes,
      ),
    );
  }

  void _handleDocumentLoaded(PdfDocumentLoadedDetails details) {
    _effectivePageCount = details.document.pages.count;
    _latestPageReached = _initialPageNumber();
    _saveProgress(_latestPageReached, pageCount: _effectivePageCount);
  }

  void _handlePageChanged(PdfPageChangedDetails details) {
    final pageCount = _effectivePageCount > 0
        ? _effectivePageCount
        : details.isLastPage
        ? details.newPageNumber
        : widget.pageCount;
    _effectivePageCount = pageCount;
    _latestPageReached = details.newPageNumber;
    _saveProgress(_latestPageReached, pageCount: pageCount);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedPdfBuild) {
      _loggedPdfBuild = true;
      debugPrint('[StartupDiag] building WebView/PDF screen');
    }

    final Widget body;
    if (_isDownloading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadFailed || _cachedFile == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Guide PDF is not available yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = SfPdfViewer.file(
        _cachedFile!,
        controller: _controller,
        initialPageNumber: _initialPageNumber(),
        onDocumentLoaded: _handleDocumentLoaded,
        onPageChanged: _handlePageChanged,
        onDocumentLoadFailed: (_) {
          if (mounted) {
            setState(() => _loadFailed = true);
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _primary,
        title: Text(widget.title),
      ),
      body: body,
    );
  }
}

class _GuideMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _GuideMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

Map<String, List<GuideLesson>> _groupLessons(List<GuideLesson> lessons) {
  final groups = <String, List<GuideLesson>>{};
  for (final lesson in lessons) {
    final title = lesson.moduleTitle.trim().isEmpty
        ? _moduleTitle(lesson.moduleId)
        : lesson.moduleTitle;
    groups.putIfAbsent(title, () => <GuideLesson>[]).add(lesson);
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
