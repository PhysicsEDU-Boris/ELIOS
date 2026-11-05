import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../models/guide_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'learn_content.dart';
import 'package:elio/l10n/l10n.dart';


Future<void> openGuideLesson({
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
    learnRoute<void>(
      _GuidePdfPage(
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
    SnackBar(content: Text(context.l10n.guidePdfUnavailable)),
  );
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
      final file = await DefaultCacheManager().getSingleFile(widget.pdfUrl);
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

    final p = context.elio;
    final ready = !_isDownloading && !_loadFailed && _cachedFile != null;
    final Widget body;
    if (_isDownloading) {
      body = Center(child: LearnSpinner(label: l10n.lnLoadingGuide));
    } else if (!ready) {
      body = SingleChildScrollView(
        child: LearnStateView(
          asset: LearnArt.stateOffline,
          title: l10n.guidePdfUnavailable,
          message: l10n.lnCheckOpenAgain,
        ),
      );
    } else {
      body = SfPdfViewer.file(
        _cachedFile!,
        controller: _controller,
        initialPageNumber: _initialPageNumber(),
        onDocumentLoaded: (details) {
          _handleDocumentLoaded(details);
          if (mounted) setState(() {});
        },
        onPageChanged: (details) {
          _handlePageChanged(details);
          if (mounted) setState(() {});
        },
        onDocumentLoadFailed: (_) {
          if (mounted) {
            setState(() => _loadFailed = true);
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: body,
      bottomNavigationBar: !ready
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.lnPrevPage,
                        onPressed: _latestPageReached > 1 ? _controller.previousPage : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _effectivePageCount > 0
                              ? l10n.lnPageOf(_latestPageReached, _effectivePageCount)
                              : l10n.lnPage(_latestPageReached),
                          textAlign: TextAlign.center,
                          style: context.text.labelLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.lnNextPage,
                        onPressed: _effectivePageCount == 0 || _latestPageReached < _effectivePageCount
                            ? _controller.nextPage
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
