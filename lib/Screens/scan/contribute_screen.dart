// ELIOS 3 Scan to contribute (Figma 629:91042 recording, 629:91074 result),
// app-only check (owner, 10 Nov; decision 0198): pick the bin, record up to
// 9 s while dropping the item in, 3 photos go to the existing ELIOS AI
// identify, and a match is saved to History as a contribution (+10).
import '../../widgets/tour/app_tour.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../models/scan_record.dart';
import '../../models/scanned_waste.dart';
import '../../providers/esp_config_provider.dart';
import '../../services/ai_quiz_service.dart';
import '../../services/frame_source/phone_frame_source.dart';
import '../../services/scan_record_store.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/learn/learn_ui.dart';
import '../../services/elio_feedback.dart';
import '../../widgets/elio_celebration.dart' show ElioLeafConfetti;
import '../config/config_parts.dart' show AiCardState, EliosAiLogo;
import '../home/home_parts.dart' show homeArt, homeWeight;

const _shots = 3;
const _shotEvery = Duration(seconds: 3);

/// The three bins a student can drop into (residu goes to Anorganik).
const contributeBins = [
  ScanCategory.organic,
  ScanCategory.recyclable,
  ScanCategory.b3,
];

/// What the check found: the item and its bin, or null when the AI named
/// nothing in any photo.
typedef ContributionCheck = ({String item, ScanCategory category})?;

/// The most common bin among the identified photos, with the first item
/// named for it. Exposed for tests.
ContributionCheck pickContribution(List<PhotoIdentification> results) {
  final named = [
    for (final r in results)
      if (r.item != null)
        (
          item: r.item!,
          category: ScanCategory.fromString(
            ScannedWaste.fromLabel(
              r.item!,
              categoryHint: r.category,
            ).category?.id,
          ),
        ),
  ];
  if (named.isEmpty) return null;
  final counts = <ScanCategory, int>{};
  for (final n in named) {
    counts[n.category] = (counts[n.category] ?? 0) + 1;
  }
  final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  return named.firstWhere((n) => n.category == best);
}

String _upper(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String binName(ScanCategory c) => switch (c) {
  ScanCategory.organic => l10n.h3CatOrganic,
  ScanCategory.b3 => l10n.h3CatB3Long,
  _ => l10n.h3CatRecyclable,
};

enum _Step { pick, recording, checking, done }

class ContributeScreen extends ConsumerStatefulWidget {
  const ContributeScreen({super.key, this.source, this.store});

  /// Test seams.
  final PhoneFrameSource? source;
  final ScanRecordStore? store;

  @override
  ConsumerState<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends ConsumerState<ContributeScreen> {
  late final PhoneFrameSource _source =
      widget.source ??
      PhoneFrameSource(
        resolutionPreset: ref
            .read(espConfigProvider)
            .valueOrNull
            ?.resolutionPreset,
      );
  ScanCategory? _bin;
  _Step _step = _Step.pick;
  final _photos = <Uint8List>[];
  Timer? _timer;
  int _seconds = 0;
  int _nudge = 0;
  ContributionCheck _found;
  bool _matched = false;

  @override
  void initState() {
    super.initState();
    _source.addListener(_changed);
    _source.initialize();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _source.removeListener(_changed);
    if (widget.source == null) _source.dispose();
    unawaited(AiQuizService.instance.cancel());
    super.dispose();
  }

  Future<void> _shoot() async {
    try {
      final frame = await _source.capture();
      if (frame != null && mounted) _photos.add(frame.bytes);
    } catch (e) {
      debugPrint('[Contribute] capture failed: $e');
    }
  }

  void _start() {
    if (_bin == null || !_source.isInitialized) {
      ElioHaptics.warning(); // no bin picked yet: the bin question shakes
      setState(() => _nudge++);
      return;
    }
    elioFeedback(ElioSfx.recStart, ElioHaptics.medium); // Figma 13 · 29
    _photos.clear();
    setState(() {
      _step = _Step.recording;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds % _shotEvery.inSeconds == 0) unawaited(_shoot());
      if (_seconds >= _shots * _shotEvery.inSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    if (_step != _Step.recording) return;
    elioFeedback(ElioSfx.recStop, ElioHaptics.light); // Figma 13 · 29
    // Stopped before the first photo: take one now.
    if (_photos.isEmpty) await _shoot();
    if (!mounted) return;
    setState(() => _step = _Step.checking);
    final results = <PhotoIdentification>[];
    for (final photo in List.of(_photos)) {
      results.add(
        await AiQuizService.instance.identifyItem(photo, wholeFrame: true),
      );
      if (!mounted) return;
    }
    final found = pickContribution(results);
    final matched = found != null && contributionMatches(found.category, _bin!);
    if (matched) await _save(found);
    if (!mounted) return;
    // Figma 13 · 30: approved = S9 + H-celebrate; try again = S5 + H-warning.
    matched
        ? elioFeedback(ElioSfx.sparkleShort, ElioHaptics.celebrate)
        : elioFeedback(ElioSfx.knock, ElioHaptics.warning);
    setState(() {
      _found = found;
      _matched = matched;
      _step = _Step.done;
    });
  }

  Future<void> _save(({String item, ScanCategory category}) found) async {
    final store = widget.store ?? ScanRecordStore.instance;
    String? photoPath;
    try {
      final dir = await store.photoDirectory();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File(
        '${dir.path}/contribution_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      file.writeAsBytesSync(_photos.last, flush: true);
      photoPath = file.path;
    } catch (e) {
      debugPrint('[Contribute] photo not saved: $e');
    }
    try {
      await store.addRecord(
        ScanRecord(
          id: 'contrib-${DateTime.now().microsecondsSinceEpoch}',
          time: DateTime.now(),
          itemName: found.item,
          category: found.category,
          cropPhotoPath: photoPath,
          questions: const [],
          trophies: contributionTrophies,
          lang: AiQuizService.replyLang,
          kind: ScanRecord.contributionKind,
          device: 'phone',
        ),
      );
    } catch (e) {
      debugPrint('[Contribute] record not saved: $e');
    }
  }

  void _again() => setState(() {
    _step = _Step.pick;
    _found = null;
    _matched = false;
  });

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          const scrim = Color(0x8C0F172A);
          final ready = _source.isInitialized && _source.error == null;
          final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
          final ss = (_seconds % 60).toString().padLeft(2, '0');
          return TourTip(
            id: 'contribute',
            label: () => l10n.tourLblContribute,
            steps: (k) => [
              TourStep(k[0], l10n.tipContribT, l10n.tipContribB, round: true),
            ],
            builder: (context, k) => Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (ready)
                    _source.buildPreview()
                  else
                    const Center(child: CircularProgressIndicator()),
                  SafeArea(
                    // The sheets reach the screen edge; they pad themselves.
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: l10n.commonClose,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                style: IconButton.styleFrom(
                                  backgroundColor: scrim,
                                  minimumSize: const Size.square(48),
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    l10n.contributeTitle,
                                    overflow: TextOverflow.ellipsis,
                                    style: homeWeight(
                                      ElioTokens.subhead,
                                      700,
                                    ).copyWith(color: Colors.white),
                                  ),
                                ),
                              ),
                              if (_step == _Step.recording)
                                Semantics(
                                  liveRegion: true,
                                  child: _SlideIn(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: const ShapeDecoration(
                                        color: scrim,
                                        shape: StadiumBorder(),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // The REC dot blinks once a second.
                                          ElioIdleLoop(
                                            period: const Duration(seconds: 1),
                                            length: const Duration(minutes: 3),
                                            builder: (context, w, child) =>
                                                Opacity(
                                                  opacity: 1 - 0.75 * w,
                                                  child: child,
                                                ),
                                            child: Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: p.error,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            l10n.contributeRec('$mm:$ss'),
                                            style:
                                                homeWeight(
                                                  ElioTokens.button,
                                                  600,
                                                ).copyWith(
                                                  color: Colors.white,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_step != _Step.done) const Spacer(),
                        if (_step == _Step.pick || _step == _Step.recording)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ElioPopIn(
                              child: ElioShake(
                                trigger: _nudge == 0 ? null : _nudge,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: scrim,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _step == _Step.pick
                                            ? l10n.contributePickBin
                                            : l10n.contributeDrop,
                                        style: homeWeight(
                                          ElioTokens.bodySmall,
                                          600,
                                        ).copyWith(color: Colors.white),
                                      ),
                                      Text(
                                        l10n.contributeKeepLabel,
                                        style: ElioTokens.caption.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      if (_step == _Step.pick) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            for (final b in contributeBins) ...[
                                              if (b != contributeBins.first)
                                                const SizedBox(width: 8),
                                              Expanded(
                                                child: _BinChoice(
                                                  bin: b,
                                                  selected: _bin == b,
                                                  onTap: () {
                                                    elioFeedback(
                                                      ElioSfx.tick,
                                                      ElioHaptics.select,
                                                    );
                                                    setState(() => _bin = b);
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_step == _Step.checking)
                          Semantics(
                            liveRegion: true,
                            child: _Sheet(
                              child: Column(
                                children: [
                                  // Slow "checking" leaf spinner over the
                                  // result skeleton (Figma 635:25912).
                                  const EliosAiLogo(
                                    state: AiCardState.active,
                                    size: 56,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.contributeChecking,
                                    textAlign: TextAlign.center,
                                    style: homeWeight(
                                      ElioTokens.body,
                                      600,
                                    ).copyWith(color: p.textPrimary),
                                  ),
                                  const SizedBox(height: 14),
                                  ElioShimmer(
                                    child: Column(
                                      children: [
                                        for (final w in const [260.0, 120.0])
                                          Container(
                                            width: w,
                                            height: 14,
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.surfaceRaised,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                          ),
                                        Container(
                                          height: 52,
                                          decoration: ShapeDecoration(
                                            color: p.surfaceRaised,
                                            shape: const StadiumBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Short (landscape) screens scroll the result sheet.
                        if (_step == _Step.done)
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _result(p),
                            ),
                          ),
                        if (_step == _Step.pick || _step == _Step.recording)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              20,
                              0,
                              24 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Semantics(
                              key: k[0],
                              button: true,
                              label: _step == _Step.pick
                                  ? l10n.contributeStart
                                  : l10n.contributeStop,
                              excludeSemantics: true,
                              onTap: _step == _Step.pick ? _start : _stop,
                              child: GestureDetector(
                                onTap: _step == _Step.pick ? _start : _stop,
                                child: ElioPress(
                                  pressed: 0.92,
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    // Record: the circle morphs to a rounded
                                    // square (200 ms, emphasized) and back.
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: ElioMotion.emphasized,
                                      margin: EdgeInsets.all(
                                        _step == _Step.recording ? 6 : 0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _bin == null || !ready
                                            ? p.error.withValues(alpha: 0.4)
                                            : p.error,
                                        borderRadius: BorderRadius.circular(
                                          _step == _Step.recording ? 8 : 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _result(ElioPalette p) {
    final found = _found;
    final title = _matched
        ? l10n.contributeNice
        : found == null
        ? l10n.contributeNotChecked
        : l10n.contributeNotQuite;
    final body = found == null
        ? l10n.contributeNoItem
        : _matched
        ? l10n.contributeWentInto(_upper(found.item), binName(_bin!))
        : l10n.contributeBelongs(_upper(found.item), binName(found.category));
    final reduced = ElioMotion.reduced(context);
    Widget pill(String label, VoidCallback onTap, {required bool primary}) =>
        Expanded(
          child: ElioPress(
            pressed: 0.96,
            child: FilledButton(
              onPressed: () {
                elioFeedback(ElioSfx.pop, ElioHaptics.light);
                onTap();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: primary ? p.primary : p.surfaceRaised,
                foregroundColor: primary ? p.onPrimary : p.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: homeWeight(
                    ElioTokens.button,
                    600,
                  ).copyWith(color: primary ? p.onPrimary : p.textPrimary),
                ),
              ),
            ),
          ),
        );
    return Semantics(
      liveRegion: true,
      child: _Sheet(
        nudge: !_matched,
        child: Stack(
          children: [
            // Approved: 12 leaves fall over the sheet (900 ms).
            if (_matched && !reduced)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: ElioMotion.celebrate,
                    builder: (context, t, _) => CustomPaint(
                      painter: ElioLeafConfetti(
                        t: t,
                        count: 12,
                        colors: [p.primary, p.secondaryText, p.tertiaryText],
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              children: [
                // Approved: the medal drops and swings 12° → −6° → 0
                // (spring/bounce, ~700 ms). Try again: it stays grey.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, v, child) => Transform.translate(
                    offset: Offset(
                      0,
                      _matched ? -40 * (1 - ElioMotion.bounce.transform(v)) : 0,
                    ),
                    child: Transform.rotate(
                      alignment: Alignment.topCenter,
                      angle: _matched
                          ? math.cos(v * math.pi * 1.5) *
                                (1 - v) *
                                12 *
                                math.pi /
                                180
                          : 0,
                      child: Opacity(
                        opacity: (v * 3).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  ),
                  child: homeArt(
                    _matched ? 'medal_gold' : 'medal_locked',
                    height: 76,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: homeWeight(
                    ElioTokens.headline,
                    700,
                  ).copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 6),
                // Try again: the hint line is highlighted.
                Container(
                  padding: _matched
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _matched
                        ? null
                        : p.secondaryText.withValues(
                            alpha: p.isDark ? 0.14 : 0.08,
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: ElioTokens.bodySmall.copyWith(
                      color: _matched ? p.textSecondary : p.textPrimary,
                    ),
                  ),
                ),
                if (_matched) ...[
                  const SizedBox(height: 14),
                  ElioPopIn(
                    rise: 0,
                    scale: 0.7,
                    curve: ElioMotion.pop,
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: p.secondaryText.withValues(
                          alpha: p.isDark ? 0.14 : 0.06,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/illustrations/history/icon_xp.svg',
                            width: 18,
                            height: 18,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 6),
                          // XP counts up (600 ms).
                          ElioCountUp(
                            value: contributionTrophies,
                            builder: (context, v) => Text(
                              l10n.contributeTrophies(v),
                              style: homeWeight(
                                ElioTokens.button,
                                700,
                              ).copyWith(color: p.secondaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.contributeSaved,
                    textAlign: TextAlign.center,
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    pill(l10n.contributeAgain, _again, primary: false),
                    const SizedBox(width: 12),
                    pill(
                      l10n.notifDone,
                      () => Navigator.of(context).maybePop(),
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A chip that slides in from the right (220 ms).
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: ElioMotion.reduced(context) ? 1 : 0, end: 1),
    duration: ElioMotion.base,
    curve: ElioMotion.emphasized,
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(40 * (1 - v), 0), child: child),
    ),
    child: child,
  );
}

/// One bin to pick: its art and name in the bin's colour (owner, 12 Nov
/// 2026: organic green, recyclable orange, B3 red); filled when selected.
class _BinChoice extends StatelessWidget {
  const _BinChoice({
    required this.bin,
    required this.selected,
    required this.onTap,
  });
  final ScanCategory bin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (bin) {
      ScanCategory.organic => const Color(0xFF22C55E),
      ScanCategory.b3 => const Color(0xFFEF4444),
      _ => const Color(0xFFF97316),
    };
    return Semantics(
      button: true,
      selected: selected,
      child: ElioPress(
        pressed: 0.95,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: ElioMotion.fast,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: selected ? 3 : 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: ElioMotion.base,
                  curve: ElioMotion.pop,
                  child: homeArt(switch (bin) {
                    ScanCategory.organic => 'bin_organik',
                    ScanCategory.b3 => 'bin_b3',
                    _ => 'bin_anorganik',
                  }, height: 40),
                ),
                const SizedBox(height: 6),
                Text(
                  binName(bin),
                  textAlign: TextAlign.center,
                  style: homeWeight(
                    ElioTokens.caption,
                    700,
                  ).copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Result sheet (629:91074): handle, rounded top; slides up when it opens
/// and nudges 6 px up and back for "try again".
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.nudge = false});
  final Widget child;
  final bool nudge;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final sheet = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: ShapeDecoration(
                color: p.borderMedium,
                shape: const StadiumBorder(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
    if (ElioMotion.reduced(context)) return sheet;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: nudge ? ElioMotion.base : ElioMotion.slow,
      curve: nudge ? Curves.linear : ElioMotion.emphasized,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, nudge ? -6 * math.sin(v * math.pi) : 80 * (1 - v)),
        child: child,
      ),
      child: sheet,
    );
  }
}
