// ELIOS 3 Scan to contribute (Figma 629:91042 recording, 629:91074 result),
// app-only check (owner, 10 Nov; decision 0198): pick the bin, record up to
// 9 s while dropping the item in, 3 photos go to the existing ELIOS AI
// identify, and a match is saved to History as a contribution (+10).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ElioHaptics.warning(); // no bin picked yet
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
    elioFeedback(ElioSfx.recStop, ElioHaptics.select);
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
    // Figma 13 · 30: approved = S9 short + H-success; otherwise S5 + H-error.
    matched
        ? elioFeedback(ElioSfx.sparkleShort, ElioHaptics.success)
        : elioFeedback(ElioSfx.knock, ElioHaptics.error);
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
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (ready)
                  _source.buildPreview()
                else
                  const Center(child: CircularProgressIndicator()),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: l10n.commonClose,
                              onPressed: () => Navigator.of(context).maybePop(),
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
                                  style: ElioTokens.subhead.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (_step == _Step.recording)
                              Semantics(
                                liveRegion: true,
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
                                      Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: p.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.contributeRec('$mm:$ss'),
                                        style: ElioTokens.button.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_step == _Step.pick || _step == _Step.recording)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scrim,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _step == _Step.pick
                                      ? l10n.contributePickBin
                                      : l10n.contributeDrop,
                                  style: ElioTokens.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  l10n.contributeKeepLabel,
                                  style: ElioTokens.caption.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                if (_step == _Step.pick) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final b in contributeBins)
                                        ChoiceChip(
                                          label: Text(binName(b)),
                                          selected: _bin == b,
                                          selectedColor: b.fg,
                                          labelStyle: ElioTokens.caption
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: _bin == b
                                                    ? Colors.white
                                                    : p.textPrimary,
                                              ),
                                          onSelected: (_) {
                                            elioFeedback(
                                              ElioSfx.tick,
                                              ElioHaptics.select,
                                            );
                                            setState(() => _bin = b);
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (_step == _Step.checking)
                        Semantics(
                          liveRegion: true,
                          child: _Sheet(
                            child: Column(
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.contributeChecking,
                                  style: ElioTokens.body.copyWith(
                                    color: p.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_step == _Step.done) _result(p),
                      if (_step == _Step.pick || _step == _Step.recording)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                          child: Semantics(
                            button: true,
                            label: _step == _Step.pick
                                ? l10n.contributeStart
                                : l10n.contributeStop,
                            excludeSemantics: true,
                            onTap: _step == _Step.pick ? _start : _stop,
                            child: GestureDetector(
                              onTap: _step == _Step.pick ? _start : _stop,
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
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
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
                    ],
                  ),
                ),
              ],
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
    return Semantics(
      liveRegion: true,
      child: _Sheet(
        child: Column(
          children: [
            // Approved: the medal drops in (spring/bounce, Figma 13 · 30).
            ElioPopIn(
              rise: _matched ? -40 : 6,
              scale: _matched ? 0.6 : 0.96,
              curve: _matched ? ElioMotion.bounce : ElioMotion.standard,
              duration: _matched
                  ? const Duration(milliseconds: 700)
                  : ElioMotion.base,
              child: Icon(
                _matched ? Icons.military_tech_rounded : Icons.replay_rounded,
                size: 56,
                color: _matched ? p.secondaryText : p.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ElioTokens.body.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
            ),
            if (_matched) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: p.secondaryText.withValues(alpha: 0.08),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l10n.contributeTrophies(contributionTrophies),
                  style: ElioTokens.button.copyWith(color: p.secondaryText),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.contributeSaved,
                style: ElioTokens.caption.copyWith(color: p.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _again,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.contributeAgain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: p.primary,
                      foregroundColor: p.onPrimary,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.notifDone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    decoration: BoxDecoration(
      color: context.elio.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: child,
  );
}
