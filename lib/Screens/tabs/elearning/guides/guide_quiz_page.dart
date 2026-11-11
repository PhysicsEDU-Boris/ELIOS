import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/guide_progress.dart';
import '../../../../services/quiz_tts_service.dart';
import '../../../../services/elio_feedback.dart';
import '../../../../theme/elio_motion.dart';
import '../../../../widgets/learn/learn_l3.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../learn_content.dart';
import 'guide_lab_page.dart';
import 'guide_widgets.dart';

/// The quick-quiz deck as a plain state machine: answer -> check -> next card -> result.
/// Buttons drive it; nothing here reacts to swipes.
class QuizDeck {
  QuizDeck(this.questions) : assert(questions.isNotEmpty);
  final List<GuideQuestion> questions;
  final Map<int, int> choices = {};
  final Set<int> checked = {};
  int current = 0;

  /// The answered card shown again read-only from the result (null = result card).
  int? reviewing;

  bool get finished => current >= questions.length;
  bool get canCheck =>
      !finished && choices[current] != null && !checked.contains(current);
  int get score => [
    for (final i in checked)
      if (choices[i] == questions[i].answer) i,
  ].length;
  bool correct(int i) =>
      checked.contains(i) && choices[i] == questions[i].answer;

  void select(int option) {
    if (!finished && !checked.contains(current)) choices[current] = option;
  }

  void check() {
    if (canCheck) checked.add(current);
  }

  void next() {
    if (!finished && checked.contains(current)) current++;
  }

  void review(int? i) {
    if (finished && (i == null || checked.contains(i))) reviewing = i;
  }

  List<({String qid, String choice})> get answers => [
    for (final (i, q) in questions.indexed)
      (qid: q.qid, choice: 'abcd'[choices[i] ?? 0]),
  ];

  /// Three spare questions not seen yet (then the least recent ones), for "Try the quiz again".
  static List<GuideQuestion> retry(List<GuideQuestion> pool, Set<String> seen) {
    final fresh = [
      for (final q in pool)
        if (!seen.contains(q.qid)) q,
    ];
    return [
      ...fresh,
      for (final q in pool)
        if (seen.contains(q.qid)) q,
    ].take(3).toList();
  }
}

/// Quick quiz 551:3673 (one route): floating cards, answered cards parked left, result on the same page.
class GuideQuizPage extends ConsumerStatefulWidget {
  const GuideQuizPage({super.key, required this.guide});
  final DailyGuide guide;

  @override
  ConsumerState<GuideQuizPage> createState() => _GuideQuizPageState();
}

class _GuideQuizPageState extends ConsumerState<GuideQuizPage> {
  QuizDeck? _deck;
  final _seen = <String>{};
  bool _retry = false;
  bool _wasPassed = false;
  Map<String, dynamic>? _server;
  bool _sending = false;
  String? _deckLang;

  @override
  void dispose() {
    unawaited(QuizTtsService.instance.stop());
    super.dispose();
  }

  void _start(GuideContent content) {
    final questions = _retry
        ? QuizDeck.retry(content.pool, _seen)
        : content.printed;
    if (questions.isEmpty) return;
    _seen.addAll(questions.map((q) => q.qid));
    _deck = QuizDeck(questions);
    _server = null;
    _wasPassed = ref
        .read(guideProgressProvider)
        .of(widget.guide.date)
        .quizPassed;
  }

  Future<void> _finish(String lang) async {
    final deck = _deck!;
    setState(() => _sending = true);
    final reply = await ref
        .read(guideProgressProvider.notifier)
        .submitQuiz(widget.guide.date, lang, deck.answers);
    if (mounted) {
      setState(() {
        _server = reply;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final lang = g.lang(guideLangOf(ref));
    final content = ref.watch(guideContentProvider((g, lang)));
    final p = context.elio;
    final data = content.valueOrNull;
    // A language switch mid-quiz restarts the deck in the new language (no XP is lost: nothing was sent).
    if (data != null &&
        (_deck == null || (_deckLang != lang && !(_deck!.finished)))) {
      _deckLang = lang;
      _start(data);
    }
    final deck = _deck;
    return Scaffold(
      backgroundColor: p.background,
      appBar: GuideTopBar(
        title: l10n.g4QuickQuiz,
        subtitle: l10n.g4StopMissionSub,
        leadingIcon: Icons.close_rounded,
        // XP on offer only before the first pass (a retry earns none).
        action: _wasPassed
            ? null
            : L3Sticker(
                label: l10n.g4PlusXp(g.xp.quiz),
                color: p.secondaryText,
                angle: 0,
              ),
      ),
      body: SafeArea(
        top: false,
        child: deck == null
            ? Center(
                child: content.isLoading
                    ? LearnSpinner(label: l10n.lnLoadingGuide)
                    : LearnStateView(
                        asset: LearnArt.stateOffline,
                        title: l10n.g4QuizUnavailable,
                        message: l10n.lnCheckOpenAgain,
                      ),
              )
            : Column(
                // Full width: a short hint line must not shrink the page and push the deck left.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Dots(deck: deck),
                  Expanded(child: _deckView(deck, lang)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                    child: Text(
                      deck.finished
                          ? l10n.g4QuizResultHint
                          : l10n.g4QuizParkedHint,
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _deckView(QuizDeck deck, String lang) {
    final reduce = context.reduceMotion;
    return LayoutBuilder(
      builder: (context, box) {
        final cardW = math.min(box.maxWidth - 64, 420.0);
        Widget card(int i, {bool readOnly = false}) => _QuizCard(
          key: ValueKey('card-${deck.questions[i].qid}'),
          deck: deck,
          index: i,
          lang: lang,
          readOnly: readOnly,
          width: cardW,
          onChanged: () => setState(() {}),
          onNext: readOnly
              ? () => setState(() => deck.review(null))
              : () {
                  setState(deck.next);
                  if (deck.finished) {
                    // Result: a pass sparkles, a miss gets a soft warning.
                    deck.score >= 2
                        ? elioFeedback(ElioSfx.sparkle, ElioHaptics.celebrate)
                        : unawaited(ElioHaptics.warning());
                    unawaited(_finish(lang));
                  } else {
                    elioFeedback(ElioSfx.tick, ElioHaptics.select);
                  }
                },
        );
        final result = _ResultCard(
          key: const ValueKey('result'),
          deck: deck,
          width: cardW,
          guide: widget.guide,
          server: _server,
          sending: _sending,
          firstPass: !_wasPassed,
          onReview: (i) => setState(() => deck.review(i)),
          onRetry: () => setState(() {
            _retry = true;
            final data = ref
                .read(guideContentProvider((widget.guide, lang)))
                .valueOrNull;
            if (data != null) _start(data);
          }),
        );
        if (reduce) {
          // Reduced motion: a 150 ms cross-fade between the front card and the result.
          final front = deck.finished
              ? (deck.reviewing == null
                    ? result
                    : card(deck.reviewing!, readOnly: true))
              : card(deck.current);
          return Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: front,
            ),
          );
        }
        final n = deck.questions.length;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = n - 1; i >= 0; i--)
              if (!deck.finished || deck.reviewing != i)
                _placed(
                  key: ValueKey('slot-$i'),
                  i: i,
                  deck: deck,
                  // Only the front card is tappable and read by screen readers.
                  child: _DealIn(
                    index: n - 1 - i,
                    child: IgnorePointer(
                      ignoring: i != deck.current,
                      child: ExcludeSemantics(
                        excluding: i != deck.current,
                        child: card(i),
                      ),
                    ),
                  ),
                ),
            if (deck.finished)
              TweenAnimationBuilder<double>(
                key: ValueKey('rise-${deck.questions.first.qid}'),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, t, child) => Transform.translate(
                  offset: Offset(0, 80 * t),
                  child: Opacity(opacity: 1 - t, child: child),
                ),
                child: deck.reviewing == null
                    ? result
                    : card(deck.reviewing!, readOnly: true),
              ),
          ],
        );
      },
    );
  }

  /// Card role -> transform. Front centred; upcoming stacked right (tilted); answered parked left;
  /// after Q3 all three fan out behind the result card.
  Widget _placed({
    required Key key,
    required int i,
    required QuizDeck deck,
    required Widget child,
  }) {
    final double x, rot, scale;
    final Duration d;
    if (deck.finished) {
      x = (i - 1) * 0.08;
      rot = (i - 1) * 6.0;
      scale = 0.92;
      d = const Duration(milliseconds: 300);
    } else if (i < deck.current) {
      x = -0.95; // ponytail: Figma parks answered cards with a sliver showing (spec motion: -110 %)
      rot = -6;
      scale = 0.9;
      d = const Duration(milliseconds: 280);
    } else if (i == deck.current) {
      x = 0;
      rot = 0;
      scale = 1;
      d = const Duration(milliseconds: 320);
    } else {
      final k = i - deck.current;
      x = 0.1 * k;
      rot = 4.0 * k;
      scale = 0.94 - 0.03 * (k - 1);
      d = const Duration(milliseconds: 320);
    }
    return AnimatedSlide(
      key: key,
      offset: Offset(x, deck.finished ? -0.04 : 0),
      duration: d,
      curve: ElioMotion.emphasized,
      child: AnimatedRotation(
        turns: rot / 360,
        duration: d,
        curve: ElioMotion.soft,
        child: AnimatedScale(
          scale: scale,
          duration: d,
          curve: ElioMotion.soft,
          child: child,
        ),
      ),
    );
  }
}

/// Q1–Q3 chips. The current one is green; a checked one flips to ✓ / ✗
/// with a pop (spring/pop).
class _Dots extends StatelessWidget {
  const _Dots({required this.deck});
  final QuizDeck deck;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    Widget chip(int i) {
      if (deck.checked.contains(i)) {
        return GuideChip(
          deck.correct(i) ? '✓ Q${i + 1}' : '✗ Q${i + 1}',
          tone: deck.correct(i) ? LearnTone.success : LearnTone.error,
        );
      }
      if (i == deck.current) {
        return GuideChip('Q${i + 1}', fill: p.primary, color: p.onPrimary);
      }
      return GuideChip('Q${i + 1}');
    }

    String state(int i) => deck.checked.contains(i)
        ? 'c${deck.correct(i)}'
        : i == deck.current
        ? 'now'
        : 'next';
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (var i = 0; i < deck.questions.length; i++)
            AnimatedSwitcher(
              duration: ElioMotion.slow,
              switchInCurve: ElioMotion.pop,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: KeyedSubtree(
                key: ValueKey('$i-${state(i)}'),
                child: chip(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cards are dealt in from the right on open, back card first (spring/soft,
/// 80 ms apart). Reduced motion: at rest.
class _DealIn extends StatelessWidget {
  const _DealIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    final start = index * 0.12;
    return ElioAfterFirstFrame(
      builder: (context, ready) => TweenAnimationBuilder<double>(
        tween: Tween(end: ready ? 1 : 0),
        duration: const Duration(milliseconds: 620),
        builder: (context, v, child) {
          final t = ElioMotion.soft.transform(
            Interval(start, math.min(1, start + 0.7)).transform(v),
          );
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(260 * (1 - t), 0),
              child: Transform.rotate(angle: 0.35 * (1 - t), child: child),
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    super.key,
    required this.deck,
    required this.index,
    required this.lang,
    required this.width,
    required this.onChanged,
    required this.onNext,
    this.readOnly = false,
  });

  final QuizDeck deck;
  final int index;
  final String lang;
  final double width;
  final bool readOnly;
  final VoidCallback onChanged, onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final q = deck.questions[index];
    final checked = deck.checked.contains(index);
    final choice = deck.choices[index];
    final right = checked && choice == q.answer;
    final last = index == deck.questions.length - 1;
    final feedback = !checked
        ? null
        : right
        ? l10n.qzCorrect
        : choice != null && q.wrong[choice] != null
        ? q.wrong[choice]!
        : l10n.g4NotQuite;
    return _CardShell(
      width: width,
      // Front card only: Thinking while you answer, Excited or Sad once
      // checked (cross-fade).
      buddy: index != deck.current && !readOnly
          ? null
          : ElioPopIn(
              delay: const Duration(milliseconds: 300),
              curve: ElioMotion.pop,
              scale: 0.4,
              child: RobotBuddy(
                mood: !checked
                    ? RobotMood.thinking
                    : right
                    ? RobotMood.excited
                    : RobotMood.sad,
                height: 56,
              ),
            ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GuideChip('Q${index + 1}', fill: p.primary, color: p.onPrimary),
                const Spacer(),
                const SizedBox(width: 48),
                IconButton.outlined(
                  tooltip: l10n.g4Listen,
                  onPressed: () => QuizTtsService.instance.speak(
                    [
                      q.question,
                      for (final (i, o) in q.options.indexed)
                        '${'ABCD'[i]}. $o',
                    ].join('. '),
                    lang: lang,
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(q.question, style: context.text.titleLarge),
            const SizedBox(height: 12),
            for (final (i, o) in q.options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: QuizAnswerOption(
                  index: i,
                  label: o,
                  selected: choice == i,
                  isCorrect: i == q.answer,
                  answered: checked,
                  onTap: () {
                    deck.select(i);
                    elioFeedback(ElioSfx.tick, ElioHaptics.select);
                    onChanged();
                  },
                ),
              ),
            if (feedback != null)
              ElioPopIn(
                key: ValueKey('fb-$index-$right'),
                curve: ElioMotion.pop,
                scale: 0.9,
                rise: 8,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: toneBg(
                      p,
                      right ? LearnTone.success : LearnTone.error,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: leafS,
                      side: BorderSide(
                        color: toneBorder(
                          p,
                          right ? LearnTone.success : LearnTone.error,
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback,
                          style: context.text.titleSmall?.copyWith(
                            color: right ? p.primaryText : p.errorText,
                          ),
                        ),
                        if (q.explanation != null) ...[
                          const SizedBox(height: 4),
                          Text(q.explanation!, style: context.text.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (readOnly)
              L3Button(
                label: l10n.g4BackToResult,
                secondary: true,
                chevron: false,
                height: 52,
                onPressed: onNext,
              )
            else
              L3Button(
                label: !checked
                    ? l10n.g4Check
                    : last
                    ? l10n.g4SeeResult
                    : l10n.g4NextCard,
                height: 52,
                chevron: checked,
                feedback: false,
                onPressed: checked
                    ? onNext
                    : deck.canCheck
                    ? () {
                        deck.check();
                        // Right: S4 + success; wrong: S5 + error (the option shakes).
                        deck.correct(index)
                            ? elioFeedback(ElioSfx.chime, ElioHaptics.success)
                            : elioFeedback(ElioSfx.knock, ElioHaptics.error);
                        onChanged();
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Quiz card: leaf 30/10/30/10 on the surface. [buddy] peeks over the top
/// right corner (the ELIO robot buddy, tilted −8°).
class _CardShell extends StatelessWidget {
  const _CardShell({required this.width, required this.child, this.buddy});
  final double width;
  final Widget child;
  final Widget? buddy;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final card = Container(
      width: width,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: leafL,
          side: BorderSide(color: p.borderSubtle),
        ),
        shadows: p.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
    if (buddy == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: -6,
          top: -34,
          child: IgnorePointer(
            child: Transform.rotate(angle: -0.14, child: buddy),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.deck,
    required this.width,
    required this.guide,
    required this.server,
    required this.sending,
    required this.firstPass,
    required this.onReview,
    required this.onRetry,
  });

  final QuizDeck deck;
  final double width;
  final DailyGuide guide;
  final Map<String, dynamic>? server;
  final bool sending, firstPass;
  final ValueChanged<int> onReview;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final score = deck.score;
    final passed = score >= 2;
    // The server's award is the record; before it answers, show what a first pass earns.
    final xp = server?['xp_awarded'] is int
        ? server!['xp_awarded'] as int
        : (passed && firstPass ? guide.xp.quiz : 0);
    Widget pop(int ms, Widget child, {Curve curve = ElioMotion.pop}) =>
        ElioPopIn(
          delay: Duration(milliseconds: ms),
          curve: curve,
          scale: 0.5,
          rise: 0,
          child: child,
        );
    return _CardShell(
      width: width,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ELIO jumps up happy for a pass, droops for a miss.
            pop(
              120,
              curve: ElioMotion.bounce,
              RobotBuddy(
                mood: passed ? RobotMood.excited : RobotMood.sad,
                height: 84,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              label: l10n.g4ScoreOf(score, deck.questions.length),
              excludeSemantics: true,
              child: ElioCountUp(
                value: score,
                builder: (context, v) => Text(
                  l10n.g4ScoreOf(v, deck.questions.length),
                  style: context.text.displaySmall,
                ),
              ),
            ),
            const SquiggleDraw(width: 120),
            const SizedBox(height: 4),
            Text(
              passed ? l10n.g4QuizNice : l10n.g4QuizAlmost,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            if (xp > 0)
              pop(
                340,
                curve: ElioMotion.bounce,
                L3Sticker(
                  label: l10n.g4PlusXp(xp),
                  color: p.secondaryText,
                  angle: -4,
                  border: true,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sending
                      ? Icons.sync_rounded
                      : server != null
                      ? Icons.check_rounded
                      : Icons.cloud_off_rounded,
                  size: 16,
                  color: server != null ? p.primaryText : p.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    sending
                        ? l10n.g4Saving
                        : server != null
                        ? l10n.g4SavedAccount
                        : l10n.g4SavedPhone,
                    style: context.text.labelMedium?.copyWith(
                      color: server != null ? p.primaryText : p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < deck.questions.length; i++)
                  pop(
                    260 + 60 * i,
                    Semantics(
                      container: true,
                      button: true,
                      label: l10n.g4ReviewQuestion(i + 1),
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () {
                          elioFeedback(ElioSfx.tick, ElioHaptics.select);
                          onReview(i);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            minWidth: 48,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: GuideChip(
                              deck.correct(i) ? '✓ Q${i + 1}' : '✗ Q${i + 1}',
                              tone: deck.correct(i)
                                  ? LearnTone.success
                                  : LearnTone.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            L3Button(
              label: l10n.g4StartLab,
              height: 52,
              onPressed: () => Navigator.of(
                context,
              ).pushReplacement(learnRoute<void>(GuideLabPage(guide: guide))),
            ),
            const SizedBox(height: 8),
            L3Button(
              label: l10n.g4TryQuizAgain,
              secondary: true,
              chevron: false,
              height: 52,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
