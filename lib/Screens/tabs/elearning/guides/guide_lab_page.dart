import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/frame_source/phone_frame_source.dart';
import '../../../../services/frame_source/viewfinder_crop.dart';
import '../../../../services/guide_progress.dart';
import '../../../../services/history_cloud.dart';
import '../../../../services/elio_feedback.dart';
import '../../../../theme/elio_motion.dart';
import '../../../../widgets/elio_celebration.dart';
import '../../../../widgets/learn/learn_l3.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../learn_content.dart';
import 'guide_widgets.dart';
import '../../../../widgets/xp_icon.dart';

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

  /// Bumped per photo: the white shutter flash replays.
  int _flash = 0;

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
    // Record: S8 start + H-medium; photos: the camera just opens (S2 + light).
    step == _Step.recording
        ? elioFeedback(ElioSfx.recStart, ElioHaptics.medium)
        : elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
    if (_step == _Step.recording) {
      elioFeedback(ElioSfx.recStop, ElioHaptics.light);
    }
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
    // S7 shutter + light tap, and a white flash over the preview.
    setState(() => _flash++);
    elioFeedback(ElioSfx.shutter, ElioHaptics.light);
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
        _resultFeedback(reply);
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

  /// Approved: the badge celebration (S9 + H-celebrate, leaves). Otherwise a
  /// soft knock and the warning pattern; the card shakes on its own.
  void _resultFeedback(Map<String, dynamic> reply) {
    if (reply['verdict'] == 'approved') {
      final c = ref
          .read(
            guideContentProvider((
              widget.guide,
              widget.guide.lang(guideLangOf(ref)),
            )),
          )
          .valueOrNull;
      ElioCelebration.show(
        context,
        art: const _BadgeArt(size: 120),
        title: c?.text('badge.name') ?? l10n.g4BadgeUnlocked,
        subtitle: l10n.g4BadgeUnlocked,
      );
    } else {
      unawaited(ElioSound.instance.play(ElioSfx.knock));
      unawaited(ElioHaptics.warning());
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
        action: _step == _Step.brief
            ? L3Sticker(
                label: l10n.g4PlusXp(g.xp.lab),
                color: p.secondaryText,
                angle: 0,
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: switch (_step) {
          _Step.brief => _brief(content),
          _Step.recording || _Step.photos => _capture(),
          _Step.review => _review(),
          _Step.checking => const _Checking(),
          _Step.result =>
            verdict == 'approved'
                ? _approved(content)
                : _retry(content, verdict == 'teacher'),
        },
      ),
      bottomNavigationBar: switch (_step) {
        _Step.brief => _bottom([
          L3Button(
            label: l10n.g4Record,
            height: 52,
            feedback: false,
            onPressed: content == null || content.mustShow.isEmpty
                ? null
                : () => _openCamera(_Step.recording),
          ),
          L3Button(
            label: l10n.g4ThreePhotos,
            secondary: true,
            chevron: false,
            height: 52,
            feedback: false,
            onPressed: content == null || content.mustShow.isEmpty
                ? null
                : () => _openCamera(_Step.photos),
          ),
        ]),
        _Step.review => _bottom([
          L3Button(
            label: l10n.g4Send,
            height: 52,
            onPressed: _frames.isEmpty ? null : () => _send(lang),
          ),
          L3Button(
            label: l10n.g4Retake,
            secondary: true,
            chevron: false,
            height: 52,
            onPressed: _discard,
          ),
        ]),
        _Step.result => _bottom(
          verdict == 'approved'
              ? [
                  L3Button(
                    label: l10n.lnDone,
                    height: 52,
                    chevron: false,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ]
              : [
                  L3Button(
                    label: l10n.g4TryAgain,
                    height: 52,
                    onPressed: () => setState(() {
                      _result = null;
                      _step = _Step.brief;
                    }),
                  ),
                  if (verdict != 'teacher')
                    L3Button(
                      label: l10n.g4AskTeacher,
                      secondary: true,
                      chevron: false,
                      height: 52,
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
                    ),
                ],
        ),
        _ => null,
      },
    );
  }

  Widget _bottom(List<Widget> buttons) => ElioPopIn(
    key: ValueKey(_step),
    rise: 80,
    scale: 1,
    duration: ElioMotion.base,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.elio.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: l3Shadow,
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
    ),
  );

  Widget _brief(GuideContent? c) {
    final p = context.elio;
    if (c == null) {
      return Center(child: LearnSpinner(label: l10n.lnLoadingGuide));
    }
    final xp = widget.guide.xp.lab;
    Widget rise(int i, Widget child) => ElioPopIn(index: i, child: child);
    return LearnListView(
      children: [
        // Hero: the thermometer hops in its bubble (8 s idle hint).
        rise(
          0,
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: ShapeDecoration(
              color: toneBg(p, LearnTone.warning),
              shape: RoundedRectangleBorder(
                borderRadius: leafL,
                side: BorderSide(color: toneBorder(p, LearnTone.warning)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                  ),
                  child: ElioIdleLoop(
                    builder: (context, w, child) => Transform.translate(
                      offset: Offset(0, -4 * w),
                      child: child,
                    ),
                    child: const LearnIllustration(LearnArt.miniLab),
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
                      Text(l10n.g4LabMeta(xp), style: captionStyle(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        rise(1, _label(l10n.g4WhatToDo, p.textSecondary)),
        const SizedBox(height: 10),
        // Steps: each number bubble pops in turn (spring/pop, 60 ms apart).
        for (final (i, step) in c.labSteps.indexed)
          ElioPopIn(
            index: i + 2,
            stagger: const Duration(milliseconds: 60),
            curve: ElioMotion.pop,
            scale: 0.8,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: ShapeDecoration(
                  color: p.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: leafS,
                    side: BorderSide(color: p.borderSubtle),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.rotate(
                      angle: (i.isEven ? -6 : 6) * 0.0175,
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: context.text.labelLarge?.copyWith(
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: context.text.bodyLarge)),
                  ],
                ),
              ),
            ),
          ),
        if (c.text('lab.question') case final q?)
          rise(
            c.labSteps.length + 2,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: ShapeDecoration(
                color: toneBg(p, LearnTone.info),
                shape: const RoundedRectangleBorder(borderRadius: leafS),
              ),
              child: Text(
                l10n.g4YourQuestion(q),
                style: context.text.bodyMedium,
              ),
            ),
          ),
        const SizedBox(height: 20),
        rise(
          c.labSteps.length + 3,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: leafL,
                side: BorderSide(color: p.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _label('✦ ${l10n.g4AiLooksFor}', p.primaryText),
                    ),
                    Transform.rotate(
                      angle: -0.1,
                      child: const RobotBuddy(
                        mood: RobotMood.searching,
                        height: 44,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final m in c.mustShow) _check(m, null),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        rise(
          c.labSteps.length + 4,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: p.surfaceRaised,
              shape: const RoundedRectangleBorder(borderRadius: leafS),
            ),
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
  Widget _check(String text, bool? pass, [int i = 0]) {
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
            // Results: each verdict ticks in turn (spring/pop, 120 ms apart).
            ElioPopIn(
              play: pass != null,
              delay: Duration(milliseconds: 380 + 120 * i),
              curve: ElioMotion.pop,
              scale: 0.3,
              rise: 0,
              child: Container(
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cam != null)
                      ListenableBuilder(
                        listenable: cam,
                        builder: (_, _) =>
                            SizedBox.expand(child: cam.buildPreview()),
                      ),
                    // Shutter: a white flash, 0.7 → 0 (fast).
                    IgnorePointer(
                      child: Replay(
                        trigger: _flash,
                        duration: ElioMotion.base,
                        curve: ElioMotion.exit,
                        builder: (context, v, _) => ColoredBox(
                          color: Colors.white.withValues(
                            alpha: _flash == 0 ? 0 : 0.7 * (1 - v),
                          ),
                        ),
                      ),
                    ),
                    if (recording)
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _RecPill(seconds: _seconds),
                      ),
                  ],
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
                    ? L3Button(
                        label: l10n.g4StopRecording,
                        height: 52,
                        chevron: false,
                        feedback: false,
                        onPressed: _seconds >= labMinSeconds ? _stop : null,
                      )
                    : L3Button(
                        label: l10n.g4TakePhoto,
                        height: 52,
                        chevron: false,
                        feedback: false,
                        onPressed: _photo,
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
              ElioPopIn(
                index: i,
                curve: ElioMotion.pop,
                scale: 0.7,
                child: Semantics(
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
        // Badge card: the badge drops in turning (spring/bounce), the rays
        // turn slowly behind it for 8 s, the XP sticker bounces on last.
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ShapeDecoration(
            color: p.primary,
            shape: const RoundedRectangleBorder(borderRadius: leafL),
          ),
          child: Column(
            children: [
              Text(
                l10n.g4BadgeUnlocked.toUpperCase(),
                style: context.text.labelSmall?.copyWith(color: p.onPrimary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ElioIdleLoop(
                      period: const Duration(seconds: 4),
                      builder: (context, w, child) =>
                          Transform.rotate(angle: w * 0.6, child: child),
                      child: CustomPaint(
                        size: const Size.square(150),
                        painter: _Rays(p.onPrimary.withValues(alpha: 0.18)),
                      ),
                    ),
                    ElioPopIn(
                      curve: ElioMotion.bounce,
                      scale: 0.3,
                      rise: -30,
                      duration: ElioMotion.celebrate,
                      child: const _BadgeArt(size: 112),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c?.text('badge.name') ?? l10n.g4LabApproved,
                textAlign: TextAlign.center,
                style: context.text.displaySmall?.copyWith(color: p.onPrimary),
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
              ElioPopIn(
                delay: const Duration(milliseconds: 600),
                curve: ElioMotion.bounce,
                scale: 0.3,
                child: L3Sticker(
                  label: [
                    if (xp > 0) l10n.g4PlusXp(xp),
                    l10n.g4XpOf(total, widget.guide.xp.total),
                  ].join(' · '),
                  color: p.secondaryText,
                  angle: -4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Leaf(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('✦ ${l10n.g4LabApprovedBy}', p.primaryText),
              const SizedBox(height: 6),
              Text(_reason(), style: context.text.bodyLarge),
              const SizedBox(height: 6),
              for (final (i, m) in must.indexed)
                _check(m, _checklist(must.length)[i], i),
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
        // Almost: the card shakes once and ELIO droops (Sad), then perks up
        // to Thinking for the teacher-review case.
        _ShakeOnce(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: toneBg(p, LearnTone.error),
              shape: RoundedRectangleBorder(
                borderRadius: leafL,
                side: BorderSide(color: toneBorder(p, LearnTone.error)),
              ),
            ),
            child: Row(
              children: [
                ElioPopIn(
                  curve: ElioMotion.pop,
                  scale: 0.5,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: RobotBuddy(
                      mood: teacher ? RobotMood.thinking : RobotMood.sad,
                      height: 68,
                    ),
                  ),
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
        ),
        const SizedBox(height: 12),
        _Leaf(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('✦ ${l10n.g4WhatAiSaw}', p.errorText),
              const SizedBox(height: 6),
              Text(_reason(), style: context.text.bodyLarge),
              const SizedBox(height: 6),
              for (final (i, m) in must.indexed)
                _check(m, _checklist(must.length)[i], i),
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

/// Checking: ELIO searches (bobbing, 4 s loops while it waits) above a soft
/// scanning bar and a dot-dot-dot line.
class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElioIdleLoop(
              length: const Duration(minutes: 2),
              period: const Duration(milliseconds: 1400),
              builder: (context, w, child) => Transform.translate(
                offset: Offset(0, -8 * w),
                child: Transform.rotate(angle: (w - 0.5) * 0.12, child: child),
              ),
              child: const RobotBuddy(mood: RobotMood.searching, height: 110),
            ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                color: p.primary,
                backgroundColor: p.borderSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// REC pill over the camera: a red dot that pulses and the seconds.
class _RecPill extends StatelessWidget {
  const _RecPill({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: ShapeDecoration(
        color: p.surface,
        shape: const StadiumBorder(),
        shadows: l3Shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElioIdleLoop(
            length: const Duration(minutes: 1),
            period: const Duration(milliseconds: 900),
            builder: (context, w, child) =>
                Opacity(opacity: 0.35 + 0.65 * (1 - w), child: child),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: p.errorText,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: context.text.labelLarge,
          ),
        ],
      ),
    );
  }
}

/// The lab badge: trophy in a ring.
class _BadgeArt extends StatelessWidget {
  const _BadgeArt({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: p.secondaryText.withValues(alpha: 0.3),
          width: size * 0.07,
        ),
        boxShadow: l3Shadow,
      ),
      child: Center(child: XpIcon(size * 0.45)),
    );
  }
}

/// Sun rays behind the badge.
class _Rays extends CustomPainter {
  _Rays(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final paint = Paint()..color = color;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + math.cos(a - 0.12) * s.width / 2,
          c.dy + math.sin(a - 0.12) * s.width / 2,
        )
        ..lineTo(
          c.dx + math.cos(a + 0.12) * s.width / 2,
          c.dy + math.sin(a + 0.12) * s.width / 2,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => old.color != color;
}

/// Shakes its child once, 3 × 6 px, right after it shows.
class _ShakeOnce extends StatefulWidget {
  const _ShakeOnce({required this.child});
  final Widget child;
  @override
  State<_ShakeOnce> createState() => _ShakeOnceState();
}

class _ShakeOnceState extends State<_ShakeOnce> {
  Object? _trigger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _trigger = 1);
    });
  }

  @override
  Widget build(BuildContext context) =>
      ElioShake(trigger: _trigger, child: widget.child);
}

/// Surface card with leaf corners 22/8/22/8 and a subtle edge.
class _Leaf extends StatelessWidget {
  const _Leaf({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: ShapeDecoration(
      color: context.elio.surface,
      shape: RoundedRectangleBorder(
        borderRadius: leafS,
        side: BorderSide(color: context.elio.borderSubtle),
      ),
    ),
    child: child,
  );
}
