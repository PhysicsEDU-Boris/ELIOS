# 0202 — ELIOS 3 motion (micro-interactions)

Date: 10 November 2026

Seventh PR of the ELIOS 3 series (owner asked after testing #112), stacked on
`feat/elios3-motion-sound` (0201). Figma J2jSbARJSyJCStNFeWkWDj section 13.

- **Tokens** (`lib/theme/elio_motion.dart`): durations 90/150/220/320/480/900 ms; curves
  standard (0.2,0,0,1), exit (0.4,0,1,1), emphasized (0.3,0,0,1); springs soft (380/30), pop
  (520/22), bounce (300/14) as `ElioSpringCurve`s for implicit animations.
- **Widgets**: `ElioPopIn` (opacity, rise, 0.96→1 scale, stagger ≤ 6 items; the stagger is part of
  the animation, no timers), `ElioPress` (0.98 while held, spring back), `ElioShimmer` (sweep band
  1200 ms, 28 % / 15 % dark), `ElioCountUp`, `ElioAfterFirstFrame`. Entrances start after the first
  frame is on screen: on the phone the first frame of Home in a debug build takes longer than the
  animation, which hid it completely (seen in a screen recording).
- **Applied**: bottom nav — one active stroke slides (spring/soft), icons cross-fade outline→filled
  with a 0.9→1 pop, label colour fades; Scan orb — press 0.92, release spring/pop; segmented pills
  — the green pill slides (280 spring/soft), labels recolour after it; Scan hub cards rise in from
  the orb (stagger 60) with press feel; Home — dial arc sweeps to the level progress, tree grows
  in, trophy sticker drops in tilting, pebbles float in and numbers count up, quest cards pop in,
  resume card slides down; Home entrance plays once per app session (latched per visit); Home
  skeleton matches the L4 geometry under the shimmer; History rows re-enter on a filter change;
  Learn clover sticker bounces on a new clover; account menu popover 200 ms emphasized; contribute
  medal drops in (spring/bounce); camera shutter flash. Reduced motion: fades only, static
  shimmer, numbers shown at once.

Not done: dark-mode circular reveal, quiz answer shake/check pop, level-up confetti and medal
celebration, heatmap stagger, page container transforms, breathing idle hints and the bin-tile
buddy jump.
