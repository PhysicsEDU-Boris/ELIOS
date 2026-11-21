// Welcome pages and the main tour across the tabs (Figma ELIOS 3 · 18, rows
// A, B, D, G, J, K). The shell switches tab before each part.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../Screens/tabs/elearning/learn_content.dart' show LearnArt;
import '../../Screens/tabs/elearning/learn_hub_v3.dart' show LearnHeaderShell;
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../learn/learn_ui.dart' show LearnTheme;
import '../learn/learn_l3.dart' show LearnSquiggle;
import 'app_tour.dart';
import 'package:elio/l10n/l10n.dart';

class TourPart {
  const TourPart(this.id, this.tab, this.label, this.steps);

  /// 'home', 'learn', 'scan', 'history', 'profile'.
  final String id;

  /// HomeShell tab index.
  final int tab;
  final String Function() label;
  final List<TourStep> Function() steps;
}

final mainTourParts = <TourPart>[
  TourPart(
    'home',
    0,
    () => l10n.tourLblHome,
    () => [
      TourStep(TourKeys.homeHero, l10n.tourHome1T, l10n.tourHome1B),
      TourStep(TourKeys.homeStats, l10n.tourHome2T, l10n.tourHome2B),
      TourStep(TourKeys.homeQuests, l10n.tourHome3T, l10n.tourHome3B),
      TourStep(TourKeys.homeBins, l10n.tourHome4T, l10n.tourHome4B),
      TourStep(TourKeys.homeTop, l10n.tourHome5T, l10n.tourHome5B),
      TourStep(TourKeys.nav, l10n.tourHome6T, l10n.tourHome6B),
    ],
  ),
  TourPart(
    'learn',
    1,
    () => l10n.tourLblLearn,
    () => [
      TourStep(
        TourKeys.learnRing,
        l10n.tourLearn1T,
        l10n.tourLearn1B,
        round: true,
      ),
      TourStep(TourKeys.learnTicket, l10n.tourLearn2T, l10n.tourLearn2B),
      TourStep(TourKeys.learnArchive, l10n.tourLearn3T, l10n.tourLearn3B),
      TourStep(TourKeys.learnBubbles, l10n.tourLearn4T, l10n.tourLearn4B),
      TourStep(TourKeys.learnExplore, l10n.tourLearn5T, l10n.tourLearn5B),
    ],
  ),
  TourPart(
    'scan',
    2,
    () => l10n.tourLblScan,
    () => [
      TourStep(TourKeys.scanPhone, l10n.tourScan1T, l10n.tourScan1B),
      TourStep(TourKeys.scanRobot, l10n.tourScan2T, l10n.tourScan2B),
      TourStep(TourKeys.scanContribute, l10n.tourScan3T, l10n.tourScan3B),
    ],
  ),
  TourPart(
    'history',
    4,
    () => l10n.tourLblHistory,
    () => [
      TourStep(TourKeys.historyBins, l10n.tourHist1T, l10n.tourHist1B),
      TourStep(TourKeys.historyRecent, l10n.tourHist2T, l10n.tourHist2B),
      TourStep(TourKeys.historyReview, l10n.tourHist3T, l10n.tourHist3B),
    ],
  ),
  TourPart(
    'profile',
    5,
    () => l10n.tourLblProfile,
    () => [TourStep(TourKeys.profileTour, l10n.tourProf1T, l10n.tourProf1B)],
  ),
];

/// "You're ready, Eco Explorer!" after the whole tour.
Future<void> showTourFinish(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: Colors.black54,
  builder: (ctx) => ElioTheme.wrap(
    Center(
      child: Material(
        type: MaterialType.transparency,
        child: TourFinishCard(
          title: l10n.tourDoneTitle,
          body: l10n.tourDoneBody,
          buttonLabel: l10n.guideGo,
          onDone: () => Navigator.of(ctx).pop(),
        ),
      ),
    ),
  ),
);

/// First launch: three pages, then "Start the tour" (pops true) or skip (false).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final last = _page == 2;
    final copy = [
      (l10n.tourW1Title, l10n.tourW1Body),
      (l10n.tourW2Title, l10n.tourW2Body),
      (l10n.tourW3Title, l10n.tourW3Body),
    ];
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          // Short screens (phone landscape) skip the green header.
          if (MediaQuery.sizeOf(context).height > 600)
            LearnHeaderShell(
              top: Padding(
                padding: const EdgeInsets.only(right: 20, top: 24),
                child: Center(
                  child: ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/illustrations/control/elio_robot.svg',
                      height: 140,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('welcome_pages'),
              controller: _pages,
              itemCount: copy.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top,
                  24,
                  0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      copy[i].$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const LearnSquiggle(width: 64),
                    const SizedBox(height: 14),
                    Text(
                      copy[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    if (i == 1) ...[const SizedBox(height: 24), _ways(p)],
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < copy.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? p.primary : p.borderMedium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TourGreenButton(
                    key: const ValueKey('welcome_next'),
                    label: last ? l10n.tourStartTour : l10n.guideNext,
                    onTap: () => last
                        ? Navigator.of(context).pop(true)
                        : _pages.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('welcome_skip'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: p.textSecondary,
                    minimumSize: const Size(88, 44),
                  ),
                  child: Text(
                    last ? l10n.tourMaybeLater : l10n.guideSkip,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ways(ElioPalette p) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final (label, asset) in [
        (l10n.tourWayLearn, LearnArt.quizPaper),
        (l10n.tourWayScan, 'assets/illustrations/home/icon_scan.svg'),
        (l10n.tourWayRobot, 'assets/illustrations/control/elio_robot.svg'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.borderMedium, width: 2),
                ),
                child: ExcludeSemantics(child: SvgPicture.asset(asset)),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
