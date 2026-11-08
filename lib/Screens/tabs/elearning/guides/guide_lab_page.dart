import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/frame_source/phone_frame_source.dart';
import '../../../../services/frame_source/viewfinder_crop.dart';
import '../../../../services/guide_progress.dart';
import '../../../../services/history_cloud.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../learn_content.dart';
import 'guide_widgets.dart';

const labMinSeconds = 15;
const labMaxSeconds = 30;
const labFrames = 8;
const labMaxBytes = 1500000;

/// [n] items spread evenly from first to last (all of them when there are fewer).
List<T> pickEvenly<T>(List<T> items, int n) {
  if (items.length <= n) return List.of(items);
  return [
    for (var i = 0; i < n; i++)
      items[(i * (items.length - 1) / (n - 1)).round()],
  ];
}

enum _Step { brief, recording, photos, review, checking, result }

/// Mini lab 544:2891: brief -> record 15-30 s (or 3 photos) -> 8 frames shown -> Send -> verdict.
/// The phone keeps no video: one small frame per second is held in memory while recording, 8 are
/// picked, and they are dropped after the check. Nothing leaves the phone before Send.
class GuideLabPage extends ConsumerStatefulWidget {
  const GuideLabPage({super.key, required this.guide, this.camera});
  final DailyGuide guide;

  /// Tests pass a fake; the app opens the phone camera.
  final PhoneFrameSource? camera;

  @override
  ConsumerState<GuideLabPage> createState() => _GuideLabPageState();
}

class _GuideLabPageState extends ConsumerState<GuideLabPage> {
  _Step _step = _Step.brief;
  PhoneFrameSource? _camera;
  final _samples = <Uint8List>[];
  List<Uint8List> _frames = const [];
  Timer? _tick;
  int _seconds = 0;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _tick?.cancel();
    _camera?.dispose();
    _samples.clear();
    super.dispose();
  }

  Future<void> _openCamera(_Step step) async {
    _stopping = false;
    _samples.clear();
    _seconds = 0;
    final cam = widget.camera ?? PhoneFrameSource();
    _camera = cam;
    setState(() => _step = step);
    await cam.initialize();
    if (step == _Step.recording && mounted) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
        if (_seconds >= labMaxSeconds) {
          unawaited(_stop()); // longer clips: the first 30 s are used
        } else {
          unawaited(_sample());
        }
        if (mounted) setState(() {});
      });
    }
  }

  /// Frame conversions still running; [_stop] waits for them (a slow phone may lag a second or two).
  final _pending = <Future<void>>[];
  bool _stopping = false;

  Future<void> _sample() {
    final f = _sampleOnce();
    _pending.add(f);
    return f.whenComplete(() => _pending.remove(f));
  }

  Future<void> _sampleOnce() async {
    try {
      final shot = await _camera?.capture();
      if (shot != null) {
        _samples.add(
          await downscaleJpeg(shot.bytes, maxSide: 512, quality: 70),
        );
      }
    } catch (e) {
      debugPrint('[Lab] frame skipped: $e');
    }
  }

  Future<void> _stop() async {
    // One stop per clip: overlapping timer ticks used to stop again and replace the frames with none.
    if (_stopping) return;
    _stopping = true;
    _tick?.cancel();
    _tick = null;
    await Future.wait(List.of(_pending));
    await _closeCamera();
    var frames = pickEvenly(_samples, labFrames);
    _samples.clear();
    // ponytail: 512 px JPEG 70 frames are ~40 KB; shrink again only in the rare case they add up past 1.5 MB.
    if (frames.fold<int>(0, (s, f) => s + f.length) > labMaxBytes) {
      frames = [
        for (final f in frames)
          await downscaleJpeg(f, maxSide: 360, quality: 60),
      ];
    }
    if (mounted) {
      setState(() {
        _frames = frames;
        _step = _Step.review;
      });
    }
  }

  Future<void> _closeCamera() async {
    final cam = _camera;
    _camera = null;
    if (cam != null && widget.camera == null) cam.dispose();
  }

  Future<void> _photo() async {
    await _sample();
    if (_samples.length >= 3) {
      await _stop();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _discard() {
    _tick?.cancel();
    _closeCamera();
    _samples.clear();
    setState(() {
      _frames = const [];
      _step = _Step.brief;
    });
  }

  Future<void> _send(String lang) async {
    setState(() => _step = _Step.checking);
    final frames = [for (final f in _frames) base64Encode(f)];
    String? message;
    try {
      final reply = await ref
          .read(guideProgressProvider.notifier)
          .checkLab(widget.guide.date, lang, frames);
      if (mounted) {
        setState(() {
          _result = reply;
          _step = _Step.result;
        });
      }
    } on CloudHttpException catch (e) {
      message = e.status == 429 ? l10n.g4LabLimit : l10n.g4LabBusy;
    } catch (_) {
      message = l10n.g4LabOffline;
    } finally {
      _frames =
          const []; // checked (or not sent): the frames are gone either way
    }
    if (message != null && mounted) {
      setState(() => _step = _Step.brief);
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(message!),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(d),
              child: Text(l10n.g4Ok),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final lang = g.lang(guideLangOf(ref));
    final content = ref.watch(guideContentProvider((g, lang))).valueOrNull;
    final p = context.elio;
    final verdict = _result?['verdict'];
    return Scaffold(
      backgroundColor: p.background,
      appBar: GuideTopBar(
        title: _step == _Step.result ? l10n.g4LabResult : l10n.g4MiniLab,
        subtitle: _step == _Step.result
            ? content?.text('lab.title')
            : l10n.g4StopMissionSub,
      ),
      body: SafeArea(
        top: false,
        child: switch (_step) {
          _Step.brief => _brief(content),
          _Step.recording || _Step.photos => _capture(),
          _Step.review => _review(),
          _Step.checking => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LearnIllustration(LearnArt.mascot, height: 96),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.g4LabChecking,
                      style: context.text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: context.reduceMotion ? null : null,
                    color: p.primary,
                    backgroundColor: p.borderSubtle,
                  ),
                ],
              ),
            ),
          ),
          _Step.result =>
            verdict == 'approved'
                ? _approved(content)
                : _retry(content, verdict == 'teacher'),
        },
      ),
      bottomNavigationBar: switch (_step) {
        _Step.brief => _bottom([
          FilledButton.icon(
            onPressed: content == null || content.mustShow.isEmpty
                ? null
                : () => _openCamera(_Step.recording),
            icon: const Icon(Icons.videocam_outlined),
            label: Text(l10n.g4Record),
            style: _big(context, filled: true),
          ),
          OutlinedButton(
            onPressed: content == null || content.mustShow.isEmpty
                ? null
                : () => _openCamera(_Step.photos),
            style: _big(context),
            child: Text(l10n.g4ThreePhotos),
          ),
        ]),
        _Step.review => _bottom([
          FilledButton.icon(
            onPressed: _frames.isEmpty ? null : () => _send(lang),
            icon: const Icon(Icons.send_rounded),
            label: Text(l10n.g4Send),
            style: _big(context, filled: true),
          ),
          OutlinedButton(
            onPressed: _discard,
            style: _big(context),
            child: Text(l10n.g4Retake),
          ),
        ]),
        _Step.result => _bottom(
          verdict == 'approved'
              ? [
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: _big(context, filled: true),
                    child: Text(l10n.lnDone),
                  ),
                ]
              : [
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _result = null;
                      _step = _Step.brief;
                    }),
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(l10n.g4TryAgain),
                    style: _big(context, filled: true),
                  ),
                  if (verdict != 'teacher')
                    OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(guideProgressProvider.notifier)
                            .requestReview(g.date);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.g4ReviewSent)),
                          );
                        }
                      },
                      style: _big(context),
                      child: Text(l10n.g4AskTeacher),
                    ),
                ],
        ),
        _ => null,
      },
    );
  }

  ButtonStyle _big(BuildContext context, {bool filled = false}) =>
      (filled ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        foregroundColor: filled ? null : context.elio.textPrimary,
      );

  Widget _bottom(List<Widget> buttons) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.elio.surface,
      border: Border(top: BorderSide(color: context.elio.borderSubtle)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, b) in buttons.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: b),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _brief(GuideContent? c) {
    final p = context.elio;
    if (c == null) {
      return Center(child: LearnSpinner(label: l10n.lnLoadingGuide));
    }
    final xp = widget.guide.xp.lab;
    return LearnListView(
      children: [
        LearnCard(
          color: p.surfaceRaised,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: p.surface,
                  shape: learnShape(14),
                ),
                child: Icon(
                  Icons.science_outlined,
                  color: p.tertiaryText,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.text('lab.title') ?? l10n.g4MiniLab,
                      style: context.text.titleLarge,
                    ),
                    Text(
                      l10n.g4LabMeta(xp),
                      style: context.text.labelMedium?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LearnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(l10n.g4WhatToDo, p.textSecondary),
              const SizedBox(height: 8),
              for (final (i, s) in c.labSteps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: context.text.labelMedium?.copyWith(
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s, style: context.text.bodyLarge)),
                    ],
                  ),
                ),
              if (c.text('lab.question') case final q?)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: p.surfaceRaised,
                    shape: learnShape(learnRadiusM),
                  ),
                  child: Text(
                    l10n.g4YourQuestion(q),
                    style: context.text.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LearnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('✦ ${l10n.g4AiLooksFor}', p.primaryText),
              const SizedBox(height: 6),
              for (final m in c.mustShow) _check(m, null),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LearnCard(
          color: p.surfaceRaised,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.back_hand_outlined, color: p.secondaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.g4SafetyTitle, style: context.text.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      [
                        // Published safety items often have no full stop; keep them as sentences.
                        for (final x in c.safety)
                          RegExp(r'[.!?]$').hasMatch(x.trim())
                              ? x.trim()
                              : '${x.trim()}.',
                        l10n.g4PrivacyNote,
                      ].join(' '),
                      style: context.text.bodySmall?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String s, Color c) => Text(
    s.toUpperCase(),
    style: context.text.labelMedium?.copyWith(
      color: c,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
    ),
  );

  /// Checklist row 537:2521: empty (brief), pass or missing.
  Widget _check(String text, bool? pass) {
    final p = context.elio;
    return Semantics(
      label: pass == null
          ? text
          : '$text: ${pass ? l10n.g4Pass : l10n.g4Missing}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pass == null
                    ? null
                    : pass
                    ? p.primary
                    : p.errorText.withValues(alpha: 0.1),
                border: pass == null
                    ? Border.all(color: p.formBorder, width: 1.5)
                    : null,
              ),
              child: pass == null
                  ? null
                  : Icon(
                      pass ? Icons.check_rounded : Icons.close_rounded,
                      size: 16,
                      color: pass ? p.onPrimary : p.errorText,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }

  Widget _capture() {
    final p = context.elio;
    final cam = _camera;
    final recording = _step == _Step.recording;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(learnRadiusXl),
              child: ColoredBox(
                color: p.tooltipBg,
                child: cam == null
                    ? const SizedBox.expand()
                    : ListenableBuilder(
                        listenable: cam,
                        builder: (_, _) =>
                            SizedBox.expand(child: cam.buildPreview()),
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  recording
                      ? l10n.g4RecordingSeconds(_seconds, labMaxSeconds)
                      : l10n.g4PhotosTaken(_samples.length),
                  style: context.text.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recording ? l10n.g4RecordHint(labMinSeconds) : l10n.g4PhotoHint,
                style: context.text.bodySmall?.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: recording
                    ? FilledButton.icon(
                        onPressed: _seconds >= labMinSeconds ? _stop : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l10n.g4StopRecording),
                        style: _big(context, filled: true),
                      )
                    : FilledButton.icon(
                        onPressed: _photo,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.g4TakePhoto),
                        style: _big(context, filled: true),
                      ),
              ),
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.g4Cancel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _review() {
    final p = context.elio;
    return LearnListView(
      children: [
        Text(
          l10n.g4ReviewTitle(_frames.length),
          style: context.text.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.g4ReviewBody,
          style: context.text.bodySmall?.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (i, f) in _frames.indexed)
              Semantics(
                image: true,
                label: l10n.g4FrameN(i + 1),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    f,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<bool> _checklist(int n) {
    final raw = _result?['checklist'];
    return [
      for (var i = 0; i < n; i++)
        raw is List && i < raw.length && raw[i] == true,
    ];
  }

  String _reason() =>
      '${_result?[guideLangOf(ref) == 'id' ? 'reason_id' : 'reason_en'] ?? ''}';

  Widget _approved(GuideContent? c) {
    final p = context.elio;
    final xp = _result?['xp_awarded'] is int
        ? _result!['xp_awarded'] as int
        : 0;
    final total = ref.watch(
      guideProgressProvider.select((s) => s.of(widget.guide.date).xp),
    );
    final must = c?.mustShow ?? const <String>[];
    return LearnListView(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ShapeDecoration(
            color: p.primary,
            shape: learnShape(learnRadiusXl),
          ),
          child: Column(
            children: [
              Text(
                l10n.g4BadgeUnlocked,
                style: context.text.labelMedium?.copyWith(
                  color: p.onPrimary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.secondaryText.withValues(alpha: 0.3),
                    width: 8,
                  ),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: p.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                c?.text('badge.name') ?? l10n.g4LabApproved,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(color: p.onPrimary),
              ),
              if (c?.text('badge.text') case final t?) ...[
                const SizedBox(height: 8),
                Text(
                  t,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: p.onPrimary),
                ),
              ],
              const SizedBox(height: 14),
              GuideChip(
                [
                  if (xp > 0) l10n.g4PlusXp(xp),
                  l10n.g4XpOf(total, widget.guide.xp.total),
                ].join(' · '),
                fill: p.surface,
                color: p.secondaryText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LearnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('✦ ${l10n.g4LabApprovedBy}', p.primaryText),
              const SizedBox(height: 6),
              Text(_reason(), style: context.text.bodyLarge),
              const SizedBox(height: 6),
              for (final (i, m) in must.indexed)
                _check(m, _checklist(must.length)[i]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.g4TeacherNote,
          style: context.text.labelMedium?.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }

  Widget _retry(GuideContent? c, bool teacher) {
    final p = context.elio;
    final must = c?.mustShow ?? const <String>[];
    return LearnListView(
      children: [
        LearnCard(
          color: p.errorText.withValues(alpha: 0.08),
          borderColor: p.errorText.withValues(alpha: 0.3),
          child: Row(
            children: [
              const SizedBox(
                width: 72,
                child: LearnIllustration(LearnArt.mascot, height: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher ? l10n.g4TeacherTitle : l10n.g4AlmostTitle,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher ? l10n.g4TeacherBody : l10n.g4AlmostBody,
                      style: context.text.bodySmall?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LearnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('✦ ${l10n.g4WhatAiSaw}', p.errorText),
              const SizedBox(height: 6),
              Text(_reason(), style: context.text.bodyLarge),
              const SizedBox(height: 6),
              for (final (i, m) in must.indexed)
                _check(m, _checklist(must.length)[i]),
            ],
          ),
        ),
        if (!teacher) ...[
          const SizedBox(height: 12),
          LearnCard(
            color: p.surfaceRaised,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: p.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.g4AskTeacherHint,
                    style: context.text.bodySmall?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
