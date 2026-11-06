import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/scan_record.dart';
import '../services/quiz_pdf_service.dart';
import '../theme/elio_tokens.dart';
import '../widgets/history_ui.dart';

/// Full-screen scan photo (Figma frame 11): near-black in both modes, pinch
/// 1x-4x, double-tap 1x/2.5x, swipe down to close, Hero from the detail.
/// Only opened when the saved crop exists ([historyHasPhoto]).
class HistoryPhotoViewer extends StatefulWidget {
  const HistoryPhotoViewer({super.key, required this.record});
  final ScanRecord record;

  static Future<void> open(BuildContext context, ScanRecord record) =>
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, a, b) => HistoryPhotoViewer(record: record),
          transitionsBuilder: (_, a, b, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );

  @override
  State<HistoryPhotoViewer> createState() => _HistoryPhotoViewerState();
}

class _HistoryPhotoViewerState extends State<HistoryPhotoViewer> {
  // Fixed viewer background (#05080F), allowed by the spec; text uses the
  // dark palette so it reads the same in light mode.
  static const _bg = Color(0xFF05080F);
  static const _on = ElioTokens.dark;
  final _zoom = TransformationController();
  Offset _tap = Offset.zero;
  double _drag = 0;
  bool _hint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _zoom.dispose();
    super.dispose();
  }

  bool get _zoomed => _zoom.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom() {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
      return;
    }
    const s = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-_tap.dx * (s - 1), -_tap.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Future<void> _share() async {
    try {
      await QuizPdfService.sharePhoto(widget.record);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.h3PdfFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n, r = widget.record;
    final day = historyDay(t, r.time);
    final at = DateFormat.Hm(dateLocaleOf(t)).format(r.time);
    final when = day == t.h3Today || day == t.h3Yesterday
        ? '${day.toLowerCase()} $at'
        : '$day $at';
    final fade = (1 - _drag / 300).clamp(0.3, 1.0);
    return Scaffold(
      backgroundColor: _bg.withValues(alpha: fade),
      body: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: GestureDetector(
                onDoubleTapDown: (d) => _tap = d.localPosition,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: _zoom,
                  minScale: 1,
                  maxScale: 4,
                  // Swipe down at 1x closes; zoomed, the drag pans instead.
                  onInteractionUpdate: (d) {
                    if (d.pointerCount == 1 && !_zoomed) {
                      setState(
                        () => _drag = (_drag + d.focalPointDelta.dy).clamp(
                          0.0,
                          double.infinity,
                        ),
                      );
                    }
                  },
                  onInteractionEnd: (_) {
                    if (_drag > 120) {
                      Navigator.of(context).maybePop();
                    } else if (_drag != 0) {
                      setState(() => _drag = 0);
                    }
                  },
                  child: Center(
                    child: Hero(
                      tag: 'history-photo-${r.id}',
                      child: Image.file(
                        File(r.cropPhotoPath!),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        semanticLabel: t.h3ScanPhoto(r.itemName),
                        errorBuilder: (_, error, stack) => Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: _on.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: SafeArea(
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: t.h3Close,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, size: 22, color: _on.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ElioTokens.subhead.copyWith(
                              color: _on.textPrimary,
                            ),
                          ),
                          Text(
                            t.h3ViewerMeta(
                              when,
                              historyCategory(t, r.category),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ElioTokens.caption.copyWith(
                              color: _on.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.h3SharePhoto,
                      onPressed: _share,
                      icon: Icon(
                        Icons.share_outlined,
                        size: 22,
                        color: _on.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hint ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: _on.surfaceRaised,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 14,
                          color: _on.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.h3PinchHint,
                            style: ElioTokens.caption.copyWith(
                              color: _on.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
