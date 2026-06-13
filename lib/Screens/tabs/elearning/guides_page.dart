import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../models/guide_lesson.dart';
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

class GuidesContent extends StatefulWidget {
  final String? selectedModuleId;
  final VoidCallback? onClearFilter;

  const GuidesContent({super.key, this.selectedModuleId, this.onClearFilter});

  @override
  State<GuidesContent> createState() => _GuidesContentState();
}

class _GuidesContentState extends State<GuidesContent> {
  final ElearningContentService _service = ElearningContentService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: StreamBuilder<List<GuideLesson>>(
        stream: _service.watchGuideLessons(moduleId: widget.selectedModuleId),
        builder: (context, snapshot) {
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
                    else if (snapshot.data!.isEmpty)
                      _GuideMessage(
                        icon: Icons.menu_book_outlined,
                        title: 'No guides available.',
                        message: widget.selectedModuleId == null
                            ? 'Published guides will appear here.'
                            : 'This module does not have a published guide yet.',
                      )
                    else
                      ..._groupLessons(snapshot.data!).entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: _GuideModuleCard(
                            title: entry.key,
                            lessons: entry.value,
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

class _GuideModuleCard extends StatelessWidget {
  final String title;
  final List<GuideLesson> lessons;

  const _GuideModuleCard({required this.title, required this.lessons});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
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
            _GuideLessonTile(lesson: lessons[index]),
            if (index != lessons.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _GuideLessonTile extends StatelessWidget {
  final GuideLesson lesson;

  const _GuideLessonTile({required this.lesson});

  Future<void> _openGuide(BuildContext context) async {
    final pdfAsset = lesson.pdfAsset.trim();
    if (pdfAsset.isEmpty) {
      _showUnavailableMessage(context);
      return;
    }

    try {
      await rootBundle.load(pdfAsset);
    } on FlutterError {
      if (context.mounted) {
        _showUnavailableMessage(context);
      }
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _GuidePdfPage(title: lesson.title, pdfAsset: pdfAsset),
      ),
    );
  }

  void _showUnavailableMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guide PDF is not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _GuideCover(coverAsset: lesson.coverAsset),
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
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openGuide(context),
    );
  }
}

class _GuideCover extends StatelessWidget {
  final String coverAsset;

  const _GuideCover({required this.coverAsset});

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

    if (coverAsset.trim().isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        coverAsset,
        width: 52,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _GuidePdfPage extends StatefulWidget {
  final String title;
  final String pdfAsset;

  const _GuidePdfPage({required this.title, required this.pdfAsset});

  @override
  State<_GuidePdfPage> createState() => _GuidePdfPageState();
}

class _GuidePdfPageState extends State<_GuidePdfPage> {
  var _loadFailed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _primary,
        title: Text(widget.title),
      ),
      body: _loadFailed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Guide PDF is not available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SfPdfViewer.asset(
              widget.pdfAsset,
              onDocumentLoadFailed: (_) {
                if (mounted) {
                  setState(() => _loadFailed = true);
                }
              },
            ),
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
