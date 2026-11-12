// ELIOS 3 History tab (Figma 629:99388 light, 629:100097 dark; decision 0215):
// curved green hero, leaf tiles, the latest 3 scans, By device and Questions
// to review. The entrance plays on every open, like Home (0209).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../models/scan_record.dart';
import '../../services/elio_feedback.dart';
import '../../services/scan_record_store.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/auth/auth_widgets.dart' show authPalette;
import '../../widgets/history_ui.dart';
import '../home/home_parts.dart';

const _introMs = 1500;
double _ms(int ms) => ms / _introMs;

const _side = EdgeInsets.symmetric(horizontal: 16);

/// Figma line icon from `assets/illustrations/history/`, tinted with [color].
Widget historyIcon(String name, double size, [Color? color]) =>
    SvgPicture.asset(
      'assets/illustrations/history/$name.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );

class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.store,
    required this.filter,
    required this.onFilter,
    required this.onOpenDetail,
    required this.onOpenTimeline,
    this.banner,
  });
  final ScanRecordStore store;
  final ScanCategory? filter;
  final ValueChanged<ScanCategory?> onFilter;
  final ValueChanged<ScanRecord> onOpenDetail;
  final void Function(HistoryDevice? device) onOpenTimeline;

  /// Shown under the hero (the legacy-import offer).
  final Widget? banner;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  final _seen = <Object>{};
  int _nextBeat = 0, _jump = 0, _locked = 0;
  bool _queued = false;

  // Once the hero has scrolled away, a page-coloured strip covers the status
  // bar so rows do not slide under the clock.
  final _scroll = ScrollController();
  final _scrim = ValueNotifier(false);

  // Same beats as Home: S2 as the tree lands, S4 (+ a light tap) as the level
  // bar closes, S9-short as the XP sticker lands.
  static const _beats = [
    (540, ElioSfx.pop, 0.6),
    (1040, ElioSfx.chime, 0.7),
    (1240, ElioSfx.sparkleShort, 0.5),
  ];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    )..addListener(_beat);
    _scroll.addListener(() => _scrim.value = _scroll.offset > 200);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queued) return;
    _queued = true;
    // Reduce Motion: everything at rest, no entrance sounds.
    if (ElioMotion.reduced(context)) {
      _nextBeat = _beats.length;
      _intro.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  void _beat() {
    final ms = _intro.value * _introMs;
    while (_nextBeat < _beats.length && ms >= _beats[_nextBeat].$1) {
      final (_, sfx, gain) = _beats[_nextBeat++];
      if (sfx == ElioSfx.chime) ElioHaptics.light();
      unawaited(ElioSound.instance.play(sfx, gain: gain));
    }
  }

  /// A quiet sound with its haptic, for a section landing.
  void _cue(ElioSfx sfx, void Function() haptic) {
    haptic();
    unawaited(ElioSound.instance.play(sfx, gain: 0.5));
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    _scrim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n, p = authPalette(context);
    final all = widget.store.records;
    final latest = [
      for (final r
          in all
              .where(
                (r) => widget.filter == null || r.category == widget.filter,
              )
              .take(3))
        r.localized(t.localeName),
    ];
    final toReview = [
      for (final r in all)
        if (r.questions.isNotEmpty && r.correctCount < r.totalQuestions)
          r.localized(t.localeName),
    ];
    ScanRecord? lastOf(HistoryDevice d) =>
        all.where((r) => historyDeviceOf(r) == d).firstOrNull;
    final list = ListView(
      key: const ValueKey('history_list'),
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _Hero(store: widget.store, a: _intro),
        ?widget.banner,
        const SizedBox(height: 20),
        Padding(padding: _side, child: _tiles(all)),
        const SizedBox(height: 24),
        HomeReveal(
          id: 'recent',
          seen: _seen,
          delay: const Duration(milliseconds: 700),
          builder: (context, a) => Padding(
            padding: _side,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHead(
                  a: a,
                  title: t.h3RecentScans,
                  squiggle: 84,
                  trailing: HomeRise(
                    a,
                    0.15,
                    0.6,
                    rise: 0,
                    dx: 28,
                    child: _SeeTimeline(
                      onTap: () {
                        elioFeedback(ElioSfx.pop, ElioHaptics.light);
                        widget.onOpenTimeline(null);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (latest.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      t.h3NoScansInCategory,
                      style: ElioTokens.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                for (final (i, r) in latest.indexed)
                  // Rows re-enter on a filter change: rise 8 px + fade.
                  ElioPopIn(
                    key: ValueKey('${widget.filter?.id}-${r.id}'),
                    play: _jump > 0,
                    index: i,
                    stagger: const Duration(milliseconds: 30),
                    rise: 8,
                    duration: ElioMotion.base,
                    child: HomeRise(
                      a,
                      0.25 + i * 0.12,
                      0.7 + i * 0.12,
                      rise: 14,
                      child: ElioPress(
                        child: _RecentRow(
                          a: a,
                          from: 0.35 + i * 0.12,
                          record: r,
                          day: historyDay(t, r.time),
                          onTap: () {
                            elioFeedback(ElioSfx.pop, ElioHaptics.light);
                            widget.onOpenDetail(r);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        HomeReveal(
          id: 'devices',
          seen: _seen,
          cues: [(0.3, () => _cue(ElioSfx.pop, ElioHaptics.light))],
          builder: (context, a) => Padding(
            padding: _side,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHead(a: a, title: t.histByDevice, squiggle: 72),
                const SizedBox(height: 6),
                HomeRise(
                  a,
                  0.15,
                  0.45,
                  rise: 8,
                  child: Text(t.histByDeviceSub, style: homeCaption(p)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final (i, d) in <HistoryDevice?>[
                      ...HistoryDevice.values,
                      null,
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(
                        child: HomeRise(
                          a,
                          0.1 + i * 0.1,
                          0.55 + i * 0.1,
                          rise: 28,
                          scale: 0.94,
                          child: d == null
                              // Locked: shakes with S5 and a warning buzz.
                              ? ElioShake(
                                  trigger: _locked == 0 ? null : _locked,
                                  child: _DeviceCard(
                                    a: a,
                                    from: 0.4,
                                    device: null,
                                    name: t.vehicleDrone,
                                    last: t.vehicleComingSoon,
                                    onTap: () {
                                      elioFeedback(
                                        ElioSfx.knock,
                                        ElioHaptics.warning,
                                      );
                                      setState(() => _locked++);
                                    },
                                  ),
                                )
                              : ElioPress(
                                  child: _DeviceCard(
                                    a: a,
                                    from: 0.2 + i * 0.1,
                                    device: d,
                                    name: historyDeviceName(t, d),
                                    last: lastOf(d) == null
                                        ? t.histNoScansYet
                                        : historyDay(t, lastOf(d)!.time),
                                    onTap: () {
                                      elioFeedback(
                                        ElioSfx.pop,
                                        ElioHaptics.light,
                                      );
                                      widget.onOpenTimeline(d);
                                    },
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (toReview.isNotEmpty) ...[
          const SizedBox(height: 28),
          HomeReveal(
            id: 'review',
            seen: _seen,
            cues: [(0.3, () => _cue(ElioSfx.tick, ElioHaptics.select))],
            builder: (context, a) => Padding(
              padding: _side,
              child: _Review(
                a: a,
                names: [
                  for (final r in toReview.take(2))
                    '${r.itemName} ${r.correctCount}/${r.totalQuestions}',
                ].join(' · '),
                onTap: () {
                  elioFeedback(ElioSfx.pop, ElioHaptics.light);
                  widget.onOpenDetail(toReview.first);
                },
              ),
            ),
          ),
        ],
      ],
    );
    return Stack(
      children: [
        list,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _scrim,
              builder: (context, on, _) => AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: ElioMotion.fast,
                child: ColoredBox(color: p.background),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2x2 leaf tiles; tapping one filters the recent scans (and the timeline).
  Widget _tiles(List<ScanRecord> all) {
    final t = context.l10n;
    Widget tile(int i, ScanCategory? c) => Expanded(
      child: HomeRise(
        _intro,
        _ms(480 + i * 70),
        _ms(900 + i * 70),
        rise: 18,
        scale: 0.92,
        curve: ElioMotion.pop,
        child: _Tile(
          a: _intro,
          from: _ms(620 + i * 70),
          category: c,
          label: c == null
              ? t.h3All
              : c == ScanCategory.b3
              ? t.h3CatB3Long
              : historyCategory(t, c),
          count: c == null
              ? all.length
              : all.where((r) => r.category == c).length,
          selected: widget.filter == c,
          flip: i == 1 || i == 2,
          jump: widget.filter == c && _jump > 0 ? _jump : null,
          onTap: () {
            elioFeedback(ElioSfx.tick, ElioHaptics.select);
            setState(() => _jump++);
            widget.onFilter(c);
          },
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile(0, null),
            const SizedBox(width: 16),
            tile(1, ScanCategory.b3),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            tile(2, ScanCategory.recyclable),
            const SizedBox(width: 16),
            tile(3, ScanCategory.organic),
          ],
        ),
      ],
    );
  }
}

/// A white sticker pill (Figma "Sticker"): surface, soft shadow, tilted.
Widget _sticker(
  Color color,
  double degrees,
  EdgeInsets padding,
  List<Widget> children,
) => Transform.rotate(
  angle: degrees * math.pi / 180,
  child: DecoratedBox(
    decoration: ShapeDecoration(
      color: color,
      shape: const StadiumBorder(),
      shadows: const [
        BoxShadow(
          color: Color(0x24000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: padding,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  ),
);

/// Hero zone (751:31190): green curve, title, sync sticker, eco tree, level
/// text and bar, XP sticker. It sits under the status bar.
class _Hero extends StatelessWidget {
  const _Hero({required this.store, required this.a});
  final ScanRecordStore store;
  final Animation<double> a;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final level = store.userLevel, total = store.totalTrophies;
    // Figma keeps 28 for the status bar; taller insets push the hero down.
    final top = math.max(0.0, MediaQuery.paddingOf(context).top - 28);
    final synced =
        !store.syncing &&
        store.syncError == null &&
        store.lastSynced != null &&
        store.pendingCount == 0;
    final next = level.nextLevelThreshold == null
        ? t.h3TopLevel
        : t.h3ToNextLevel(
            level.nextLevelThreshold! - total,
            level.levelNumber + 1,
          );
    final ink = p.onPrimary;
    Widget sparkle(double size, int at) => HomeRise(
      a,
      _ms(at),
      _ms(at + 380),
      rise: 0,
      scale: 0,
      turn: 1.2,
      curve: ElioMotion.pop,
      child: ElioIdleLoop(
        builder: (context, wave, child) =>
            Transform.scale(scale: 1 - 0.3 * wave, child: child),
        child: HistorySparkle(size, ink),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final k = box.maxWidth / 390;
        return SizedBox(
          height: 262 + top,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The curve drops in from above.
                      Positioned(
                        left: -245 * k,
                        width: 880 * k,
                        top: top - 350,
                        height: 600,
                        child: HomeRise(
                          a,
                          0,
                          _ms(420),
                          rise: -110,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.primary,
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(440 * k, 300),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: top - 90,
                        child: HomeRise(
                          a,
                          _ms(180),
                          _ms(600),
                          rise: 0,
                          scale: 0,
                          curve: ElioMotion.pop,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              color: p.primaryHover,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: top + 96,
                        child: sparkle(16, 420),
                      ),
                      Positioned(
                        left: 128,
                        top: top + 96,
                        child: sparkle(10, 520),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: top + 40,
                child: HomeRise(
                  a,
                  _ms(80),
                  _ms(420),
                  rise: 12,
                  child: Semantics(
                    header: true,
                    child: Text(
                      t.navHistory,
                      style: ElioTokens.headline.copyWith(color: p.textPrimary),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: top + 76,
                child: AnimatedBuilder(
                  animation: a,
                  builder: (context, _) => CustomPaint(
                    size: const Size(72, 10),
                    painter: HomeSquigglePainter(
                      ink,
                      homeSlice(a, _ms(160), _ms(560)),
                    ),
                  ),
                ),
              ),
              // The tree grows out of its pot, then sways; a tap rustles it.
              Positioned(
                left: 24,
                top: top + 108,
                child: ExcludeSemantics(
                  child: HomeBoing(
                    amp: 0.08,
                    turn: 0.05,
                    alignment: Alignment.bottomCenter,
                    child: HomeRise(
                      a,
                      _ms(200),
                      _ms(820),
                      rise: 0,
                      scale: 0.2,
                      curve: ElioMotion.pop,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.fromLTRB(7, 3.5, 7.5, 8),
                        decoration: BoxDecoration(
                          color: historyTint(p, HistoryTone.success).bg,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(45),
                            topRight: Radius.circular(14),
                            bottomRight: Radius.circular(45),
                            bottomLeft: Radius.circular(14),
                          ),
                        ),
                        child: ElioIdleLoop(
                          period: const Duration(seconds: 3),
                          length: const Duration(seconds: 9),
                          builder: (context, wave, child) => Transform.rotate(
                            angle: 0.035 * wave,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                          child: homeArt(
                            level.levelNumber >= 3 ? 'tree_lv3' : 'sprout_lv1',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 148,
                right: 20,
                top: top + 112,
                child: Semantics(
                  container: true,
                  label:
                      '${t.h3Trophies(total)}, ${level.levelAndTitle}. $next',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeRise(
                        a,
                        _ms(300),
                        _ms(640),
                        rise: 10,
                        child: Text(
                          t.histEcoLevel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeWeight(
                            ElioTokens.overline,
                            600,
                          ).copyWith(color: ink, letterSpacing: 1.1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      HomeRise(
                        a,
                        _ms(360),
                        _ms(720),
                        rise: 14,
                        child: Text(
                          level.levelAndTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ElioTokens.headline.copyWith(color: ink),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // The bar fills 0 → progress.
                      HomeRise(
                        a,
                        _ms(420),
                        _ms(700),
                        rise: 0,
                        child: AnimatedBuilder(
                          animation: a,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value:
                                  store.levelProgress.clamp(0.0, 1.0) *
                                  homeSlice(a, _ms(480), _ms(1040)),
                              minHeight: 6,
                              color: ink,
                              backgroundColor: ink.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      HomeRise(
                        a,
                        _ms(520),
                        _ms(860),
                        rise: 8,
                        child: Text(
                          synced || store.cloud == null
                              ? next
                              : '$next · ${t.h3SavedLocally.toLowerCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeCaption(p, color: ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // XP sticker: drops in turning, counts up, wobbles on a tap.
              Positioned(
                left: 22,
                top: top + 222,
                child: ExcludeSemantics(
                  child: HomeRise(
                    a,
                    _ms(900),
                    _ms(1300),
                    rise: -30,
                    turn: -0.5,
                    scale: 0.6,
                    curve: ElioMotion.pop,
                    child: HomeBoing(
                      turn: 0.12,
                      sfx: ElioSfx.sparkleShort,
                      child: _sticker(
                        p.surface,
                        4,
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        [
                          historyIcon('icon_xp', 16),
                          const SizedBox(width: 4),
                          AnimatedBuilder(
                            animation: a,
                            builder: (context, _) => Text(
                              t.homeTrophies(
                                (total *
                                        homeSlice(
                                          a,
                                          _ms(900),
                                          _ms(1500),
                                          ElioMotion.standard,
                                        ))
                                    .round(),
                              ),
                              style: homeWeight(
                                ElioTokens.button,
                                600,
                              ).copyWith(color: p.primaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Sync sticker (tap = sync now); 8 px of extra tap area.
              if (store.cloud != null)
                Positioned(
                  right: 28,
                  top: top + 36,
                  child: HomeRise(
                    a,
                    _ms(300),
                    _ms(700),
                    rise: -24,
                    turn: 0.4,
                    scale: 0.6,
                    curve: ElioMotion.pop,
                    child: Semantics(
                      button: true,
                      label: store.syncing
                          ? t.historySyncing
                          : synced
                          ? t.historySynced
                          : t.historyLocalOnly,
                      hint: t.historySyncRetry,
                      excludeSemantics: true,
                      child: HomeBoing(
                        turn: 0.1,
                        sfx: ElioSfx.tick,
                        haptic: ElioHaptics.select,
                        onTap: () {
                          if (!store.syncing) unawaited(store.sync());
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _sticker(
                            p.surface,
                            5,
                            const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            [
                              synced
                                  ? historyIcon(
                                      'icon_synced',
                                      14,
                                      p.primaryText,
                                    )
                                  : Icon(
                                      store.syncing
                                          ? Icons.cloud_sync_outlined
                                          : Icons.cloud_off_outlined,
                                      size: 14,
                                      color: p.textSecondary,
                                    ),
                              const SizedBox(width: 4),
                              Text(
                                store.syncing
                                    ? t.histSyncingShort
                                    : synced
                                    ? t.histSyncedShort
                                    : t.histNotSyncedShort,
                                style: homeCaption(
                                  p,
                                  color: synced
                                      ? p.primaryText
                                      : p.textSecondary,
                                  weight: 700,
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
      },
    );
  }
}

String _binName(ScanCategory c) => switch (c) {
  ScanCategory.b3 => 'b3',
  ScanCategory.organic => 'organik',
  _ => 'anorganik',
};

/// Category tile (629:99413): 98 high leaf, tone tint; selected = surface with
/// a 3 px green edge and a check on the top edge. The bin buddies hop in and
/// jump when their tile is picked.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.a,
    required this.from,
    required this.category,
    required this.label,
    required this.count,
    required this.selected,
    required this.flip,
    required this.jump,
    required this.onTap,
  });
  final Animation<double> a;
  final double from;
  final ScanCategory? category;
  final String label;
  final int count;
  final bool selected, flip;
  final Object? jump;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final tone = switch (category) {
      null => null,
      ScanCategory.b3 => HistoryTone.error,
      ScanCategory.organic => HistoryTone.success,
      _ => HistoryTone.info,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: flip ? homeLeafFlip : homeLeaf,
      side: selected
          ? BorderSide(color: p.primary, width: 3)
          : BorderSide(color: p.borderSubtle),
    );
    var wave = 0;
    Widget bin(String name, double w, double h) {
      final i = wave++;
      return HomeRise(
        a,
        from + _ms(60 * i),
        from + _ms(60 * i + 420),
        rise: 30,
        scale: 0.5,
        curve: ElioMotion.pop,
        alignment: Alignment.bottomCenter,
        child: ElioJump(
          trigger: jump,
          delay: Duration(milliseconds: 40 * i),
          child: homeArt('bin_$name', width: w, height: h),
        ),
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      child: SizedBox(
        height: 98,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: selected || tone == null
                    ? p.surface
                    : historyTint(p, tone).bg,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    children: [
                      if (category == null)
                        Positioned(
                          right: 7,
                          top: 28,
                          child: SizedBox(
                            width: 68,
                            height: 51,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 12,
                                  child: bin('organik', 32, 38),
                                ),
                                Positioned(
                                  left: 36,
                                  top: 12,
                                  child: bin('b3', 32, 38),
                                ),
                                Positioned(
                                  left: 16,
                                  top: 0,
                                  child: bin('anorganik', 38.4, 45.6),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Positioned(
                          right: 11,
                          bottom: -7,
                          child: bin(_binName(category!), 50, 59.3),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: homeWeight(
                                ElioTokens.body,
                                600,
                              ).copyWith(color: p.textPrimary, height: 1.5),
                            ),
                            // The count ticks up as the tile lands.
                            AnimatedBuilder(
                              animation: a,
                              builder: (context, _) => Text(
                                t.h3ScanCount(
                                  (count *
                                          homeSlice(
                                            a,
                                            from,
                                            from + _ms(500),
                                            ElioMotion.standard,
                                          ))
                                      .round(),
                                ),
                                style: homeCaption(
                                  p,
                                  color: selected
                                      ? p.primaryText
                                      : p.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -11,
                right: 5,
                // The check badge pops in (spring/pop).
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: ElioMotion.reduced(context)
                      ? Duration.zero
                      : ElioMotion.slow,
                  curve: ElioMotion.pop,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: p.onPrimary,
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

/// "See timeline" pill (629:99438); the chevron nudges for a moment.
class _SeeTimeline extends StatelessWidget {
  const _SeeTimeline({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final tint = historyTint(p, HistoryTone.success);
    return ElioPress(
      // 44 high tap area around the 38 high pill.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Material(
              color: tint.bg,
              shape: StadiumBorder(side: BorderSide(color: tint.border!)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      historyIcon('icon_timeline', 16, p.primaryText),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.histSeeTimeline,
                        style: homeWeight(
                          ElioTokens.button,
                          600,
                        ).copyWith(color: p.primaryText),
                      ),
                      const SizedBox(width: 6),
                      ElioIdleLoop(
                        builder: (context, wave, child) => Transform.translate(
                          offset: Offset(3 * wave, 0),
                          child: child,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: p.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _chip(Color bg, Color fg, String text, {Widget? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[icon, const SizedBox(width: 4)],
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: homeWeight(ElioTokens.caption, 700).copyWith(color: fg),
        ),
      ),
    ],
  ),
);

/// One recent scan (629:99448): leaf thumbnail, name, device and kind chips,
/// then the day and the XP. No card: the row sits on the page.
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.a,
    required this.from,
    required this.record,
    required this.day,
    required this.onTap,
  });
  final Animation<double> a;
  final double from;
  final ScanRecord record;
  final String day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final r = record;
    final device = historyDeviceOf(r);
    final info = historyTint(p, HistoryTone.info);
    final warn = historyTint(p, HistoryTone.warning);
    return Semantics(
      button: true,
      label:
          '${r.itemName}, ${historyCategory(t, r.category)}, $day, '
          '+${r.trophies}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              // The thumbnail pops in turning; it morphs into the detail photo.
              HomeRise(
                a,
                from,
                from + 0.35,
                rise: 0,
                scale: 0,
                turn: -0.4,
                curve: ElioMotion.pop,
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'history-photo-${r.id}',
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(19.44),
                            topRight: Radius.circular(6.48),
                            bottomRight: Radius.circular(19.44),
                            bottomLeft: Radius.circular(6.48),
                          ),
                          child: Container(
                            width: 54,
                            height: 54,
                            color: p.surfaceRaised,
                            child: historyHasPhoto(r)
                                ? Image.file(
                                    File(r.cropPhotoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) =>
                                        historyPhotoImage(r),
                                  )
                                : historyPhotoImage(r),
                          ),
                        ),
                      ),
                      if (r.isContribution)
                        Positioned(
                          left: 36,
                          top: 36,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: p.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: homeWeight(
                        ElioTokens.body,
                        600,
                      ).copyWith(color: p.textPrimary, height: 1.5),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (device != null)
                          _chip(
                            p.surface,
                            p.textSecondary,
                            historyDeviceName(t, device),
                            icon: historyIcon(
                              device == HistoryDevice.phone
                                  ? 'chip_phone'
                                  : 'chip_robot',
                              12,
                              p.textSecondary,
                            ),
                          ),
                        if (r.isContribution)
                          _chip(
                            warn.bg,
                            warn.fg,
                            t.histContribution,
                            icon: Icon(Icons.circle, size: 6, color: warn.fg),
                          )
                        else if (r.questions.isEmpty)
                          _chip(
                            p.surfaceRaised,
                            p.textSecondary,
                            t.histScanOnly,
                          )
                        else
                          _chip(
                            info.bg,
                            info.fg,
                            t.histQuiz(r.correctCount, r.totalQuestions),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(day, style: homeCaption(p, color: p.textTertiary)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      historyIcon('icon_xp', 14),
                      const SizedBox(width: 3),
                      // The XP counts up as the row lands.
                      AnimatedBuilder(
                        animation: a,
                        builder: (context, _) => Text(
                          '+${(r.trophies * homeSlice(a, from, from + 0.4, ElioMotion.standard)).round()}',
                          style: homeWeight(
                            ElioTokens.button,
                            600,
                          ).copyWith(color: p.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "By device" card (629:99525): Phone bubble, ELIOS robot or the locked
/// drone above the name and the last scan day. [device] null = the drone.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.a,
    required this.from,
    required this.device,
    required this.name,
    required this.last,
    required this.onTap,
  });
  final Animation<double> a;
  final double from;
  final HistoryDevice? device;
  final String name, last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final locked = device == null;
    final elios = device == HistoryDevice.elios;
    final art = switch (device) {
      // The bubble pops, then tilts for a moment.
      HistoryDevice.phone => Positioned(
        left: 11,
        top: -15,
        child: HomeRise(
          a,
          from,
          from + 0.35,
          rise: 0,
          scale: 0,
          curve: ElioMotion.pop,
          child: ElioIdleLoop(
            builder: (context, wave, child) =>
                Transform.rotate(angle: 0.1 * wave, child: child),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 4,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: historyIcon('icon_phone', 30, p.primaryText),
            ),
          ),
        ),
      ),
      // ELIOS rises out of the card and rocks.
      HistoryDevice.elios => Positioned(
        left: 7,
        top: -19,
        child: HomeRise(
          a,
          from,
          from + 0.4,
          rise: 26,
          scale: 0.7,
          curve: ElioMotion.pop,
          alignment: Alignment.bottomCenter,
          child: ElioIdleLoop(
            builder: (context, wave, child) => Transform.rotate(
              angle: 0.06 * wave,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
            child: SvgPicture.asset(
              'assets/illustrations/scan/elios_robot.svg',
              width: 84,
              height: 71.4,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
      // The drone flies in from the right and hovers.
      null => Positioned(
        left: 7,
        right: 7,
        top: 3,
        child: HomeRise(
          a,
          from,
          from + 0.45,
          rise: -10,
          dx: 44,
          child: ElioIdleLoop(
            builder: (context, wave, child) =>
                Transform.translate(offset: Offset(0, -4 * wave), child: child),
            child: AspectRatio(
              aspectRatio: 96 / 66,
              child: SvgPicture.asset(
                'assets/illustrations/scan/drone.svg',
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    };
    return Semantics(
      button: !locked,
      enabled: !locked,
      label: '$name, $last',
      excludeSemantics: true,
      child: SizedBox(
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: locked
                    ? p.surfaceRaised
                    : historyTint(
                        p,
                        elios ? HistoryTone.info : HistoryTone.success,
                      ).bg,
                shape: RoundedRectangleBorder(
                  borderRadius: elios ? homeLeafFlip : homeLeaf,
                  side: BorderSide(color: p.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 12,
                        right: locked ? 8 : 28,
                        top: 90,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeWeight(
                            ElioTokens.body,
                            700,
                          ).copyWith(color: p.textPrimary, height: 1.5),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 8,
                        top: 114,
                        child: Text(
                          last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeCaption(
                            p,
                            color: locked ? p.textTertiary : p.textSecondary,
                          ),
                        ),
                      ),
                      if (!locked)
                        Positioned(
                          right: 8,
                          top: 94,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Art overflows the card; taps fall through to it.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(clipBehavior: Clip.none, children: [art]),
              ),
            ),
            if (locked)
              Positioned(
                top: -7,
                right: 1,
                child: IgnorePointer(
                  child: HomeRise(
                    a,
                    0.7,
                    1,
                    rise: 0,
                    scale: 0,
                    curve: ElioMotion.pop,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: historyIcon('icon_lock', 13, p.background),
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

/// "Questions to review" (629:99549): warning leaf card with the quiz paper;
/// the paper pops in and wiggles, the Review pill pops last.
class _Review extends StatelessWidget {
  const _Review({required this.a, required this.names, required this.onTap});
  final Animation<double> a;
  final String names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final tint = historyTint(p, HistoryTone.warning);
    return HomeRise(
      a,
      0,
      0.5,
      rise: 24,
      child: ElioPress(
        child: Material(
          color: tint.bg,
          shape: RoundedRectangleBorder(
            borderRadius: homeLeaf,
            side: BorderSide(color: tint.border!),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  HomeRise(
                    a,
                    0.2,
                    0.65,
                    rise: 0,
                    scale: 0,
                    turn: -0.5,
                    curve: ElioMotion.pop,
                    child: ElioIdleLoop(
                      builder: (context, wave, child) =>
                          Transform.rotate(angle: 0.1 * wave, child: child),
                      child: SvgPicture.asset(
                        'assets/illustrations/learn/quiz_paper.svg',
                        width: 44,
                        height: 44,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.histToReview,
                          style: homeWeight(
                            ElioTokens.body,
                            700,
                          ).copyWith(color: p.textPrimary, height: 1.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          names,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: homeCaption(p),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  HomeRise(
                    a,
                    0.45,
                    0.9,
                    rise: 0,
                    scale: 0.5,
                    curve: ElioMotion.pop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: ShapeDecoration(
                        color: p.surface,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        t.histReview,
                        style: homeWeight(
                          ElioTokens.button,
                          600,
                        ).copyWith(color: p.secondaryText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
