import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';
import '../models/quiz_explanation.dart';
import '../services/quiz_pdf_service.dart';
import '../providers/waste_quiz_provider.dart';
import '../theme/elio_learning_colors.dart';
import 'package:elio/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Design tokens (Figma node 96:130 / 96:246)
// ---------------------------------------------------------------------------
const _elioGreen = Color(0xFF00694C);
const _elioGreenLight = Color(0xFFD0E4E2);
const _elioTeal = Color(0xFF007F9C);
const _elioSurface = Color(0xFFF8FAF9);
const _elioBorder = Color(0xFFBCCAC1);
const _elioInk = Color(0xFF191C1C);
const _elioSubtext = Color(0xFF3D4943);
const _elioCaption = Color(0xFF6D7A73);
const _elioIncorrect = Color(0xFFE74C3C);

// ---------------------------------------------------------------------------
// MCQ Explanation Overlay
// ---------------------------------------------------------------------------

/// Full-screen overlay shown when [WasteQuizPhase.explaining] is active and
/// the current question is multiple-choice.
class QuizExplanationOverlay extends ConsumerStatefulWidget {
  const QuizExplanationOverlay({super.key, this.onStop});
  final VoidCallback? onStop;

  @override
  ConsumerState<QuizExplanationOverlay> createState() => _QuizExplanationOverlayState();
}

class _QuizExplanationOverlayState extends ConsumerState<QuizExplanationOverlay> {
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  int? _speakingIndex;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ref.read(wasteQuizProvider.notifier).sendChatMessage(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wasteQuizProvider);
    final notifier = ref.read(wasteQuizProvider.notifier);
    final q = state.question;
    if (q == null) return const SizedBox.shrink();

    return _OverlayScaffold(
      onStop: widget.onStop,
      leftPanel: _McqLeftPanel(state: state, notifier: notifier),
      rightPanel: _ChatRightPanel(
        state: state,
        notifier: notifier,
        chatController: _chatController,
        chatScroll: _chatScroll,
        speakingIndex: _speakingIndex,
        onSendChat: _sendChat,
        onListen: (i, text) {
          setState(() => _speakingIndex = i);
          notifier.listen(text);
        },
        onStop: widget.onStop,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Essay Explanation Overlay
// ---------------------------------------------------------------------------

/// Full-screen overlay shown when [WasteQuizPhase.explaining] is active and
/// the current question is an essay.
class QuizEssayExplanationOverlay extends ConsumerStatefulWidget {
  const QuizEssayExplanationOverlay({super.key, this.onStop});
  final VoidCallback? onStop;

  @override
  ConsumerState<QuizEssayExplanationOverlay> createState() =>
      _QuizEssayExplanationOverlayState();
}

class _QuizEssayExplanationOverlayState extends ConsumerState<QuizEssayExplanationOverlay> {
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  int? _speakingIndex;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ref.read(wasteQuizProvider.notifier).sendChatMessage(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wasteQuizProvider);
    final notifier = ref.read(wasteQuizProvider.notifier);
    final q = state.question;
    if (q == null) return const SizedBox.shrink();

    return _OverlayScaffold(
      onStop: widget.onStop,
      leftPanel: _EssayLeftPanel(state: state, notifier: notifier),
      rightPanel: _ChatRightPanel(
        state: state,
        notifier: notifier,
        chatController: _chatController,
        chatScroll: _chatScroll,
        speakingIndex: _speakingIndex,
        onSendChat: _sendChat,
        onListen: (i, text) {
          setState(() => _speakingIndex = i);
          notifier.listen(text);
        },
        onStop: widget.onStop,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared overlay scaffold
// ---------------------------------------------------------------------------

class _OverlayScaffold extends StatelessWidget {
  const _OverlayScaffold({
    required this.leftPanel,
    required this.rightPanel,
    this.onStop,
  });

  final Widget leftPanel;
  final Widget rightPanel;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed backdrop
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
        ),
        // Centered popup
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1270, maxHeight: 672),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _elioSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _elioBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 48,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left panel: ~60%
                      Expanded(flex: 60, child: leftPanel),
                      // Divider
                      Container(width: 1, color: _elioBorder),
                      // Right panel: ~40%
                      Expanded(flex: 40, child: rightPanel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MCQ Left Panel
// ---------------------------------------------------------------------------

class _McqLeftPanel extends StatelessWidget {
  const _McqLeftPanel({required this.state, required this.notifier});
  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final q = state.question!;
    final isCorrect = state.selectedOption == q.correctIndex;
    final exp = state.currentExplanation;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiz Meta row
          _QuizMetaRow(
            state: state,
            notifier: notifier,
            extraChips: const [],
          ),
          const SizedBox(height: 16),
          // Result Banner
          _ResultBanner(
            isCorrect: isCorrect,
            isEssay: false,
            correctAnswer: q.options.isNotEmpty ? q.options[q.correctIndex] : '',
            itemName: state.scan?.displayName ?? '',
            trophies: isCorrect ? 10 : 0,
          ),
          const SizedBox(height: 16),
          // Explanation Page (scrollable)
          Expanded(
            child: _ExplanationPage(
              state: state,
              explanation: exp,
              questionIndex: state.questionIndex,
            ),
          ),
          const SizedBox(height: 16),
          // Actions row
          _ActionsRow(state: state, notifier: notifier),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Essay Left Panel
// ---------------------------------------------------------------------------

class _EssayLeftPanel extends StatelessWidget {
  const _EssayLeftPanel({required this.state, required this.notifier});
  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final exp = state.currentExplanation;
    final essayScore = exp?.essayScore;
    final isCorrect = (essayScore ?? 0) >= 6;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiz Meta row (with essay type chip)
          _QuizMetaRow(
            state: state,
            notifier: notifier,
            extraChips: [
              _InfoChip(
                label: l10n.ovEssayMax,
                bg: _elioGreenLight,
                fg: _elioSubtext,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Result Banner with essay score
          _ResultBanner(
            isCorrect: isCorrect,
            isEssay: true,
            correctAnswer: '',
            itemName: state.scan?.displayName ?? '',
            trophies: essayScore ?? 0,
            essayScore: essayScore,
          ),
          const SizedBox(height: 16),
          // Explanation Page
          Expanded(
            child: _ExplanationPage(
              state: state,
              explanation: exp,
              questionIndex: state.questionIndex,
            ),
          ),
          const SizedBox(height: 16),
          _ActionsRow(state: state, notifier: notifier),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quiz Meta Row
// ---------------------------------------------------------------------------

class _QuizMetaRow extends StatelessWidget {
  const _QuizMetaRow({
    required this.state,
    required this.notifier,
    required this.extraChips,
  });
  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;
  final List<Widget> extraChips;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoChip(
                  label: l10n.qzQuestionOf(state.questionIndex + 1, state.totalQuestions),
                  bg: _elioGreenLight,
                  fg: _elioInk,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  label: state.scan?.displayName ?? '-',
                  bg: _elioTeal,
                  fg: Colors.white,
                ),
                ...extraChips.map((c) => Padding(padding: const EdgeInsets.only(left: 8), child: c)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _VoiceToggle(on: state.voiceOn, onToggle: notifier.toggleVoice),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result Banner
// ---------------------------------------------------------------------------

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.isCorrect,
    required this.isEssay,
    required this.correctAnswer,
    required this.itemName,
    required this.trophies,
    this.essayScore,
  });

  final bool isCorrect;
  final bool isEssay;
  final String correctAnswer;
  final String itemName;
  final int trophies;
  final int? essayScore;

  @override
  Widget build(BuildContext context) {
    final pending = isEssay && essayScore == null;
    final bg = pending ? _elioGreenLight : isCorrect
        ? const Color(0xFF00694C).withValues(alpha: 0.1)
        : _elioIncorrect.withValues(alpha: 0.08);
    final border = pending ? _elioBorder : isCorrect
        ? const Color(0xFF00694C).withValues(alpha: 0.35)
        : _elioIncorrect.withValues(alpha: 0.35);
    final iconBg = pending ? _elioSubtext : isCorrect ? const Color(0xFF00694C) : _elioIncorrect;
    final icon = pending ? Icons.hourglass_empty_rounded : isCorrect ? Icons.emoji_events_rounded : Icons.close_rounded;

    final String title;
    final String subtitle;

    if (pending) {
      title = l10n.awaitingGrading;
      subtitle = l10n.ovPendingSub;
    } else if (isEssay) {
      final score = essayScore ?? trophies;
      title = l10n.ovEssayScore(score);
      subtitle = isCorrect ? l10n.ovGood : l10n.ovNeedsWork;
    } else if (isCorrect) {
      title = l10n.ovRight;
      subtitle = itemName;
    } else {
      title = l10n.ovWrong;
      subtitle = l10n.ovRightAnswer(correctAnswer);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(
                    color: iconBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: _elioSubtext, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explanation Page
// ---------------------------------------------------------------------------

class _ExplanationPage extends StatelessWidget {
  const _ExplanationPage({
    required this.state,
    required this.explanation,
    required this.questionIndex,
  });

  final WasteQuizUiState state;
  final QuizExplanation? explanation;
  final int questionIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _elioBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Page Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _elioGreen, width: 1.5)),
            ),
            child: Row(
              children: [
                Text(
                  'ELIO',
                  style: GoogleFonts.sora(
                    color: _elioGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.ovExplanationN(questionIndex + 1),
                  style: GoogleFonts.manrope(
                    color: _elioSubtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable body
          Expanded(
            child: state.explanationLoading && explanation == null
                ? const Center(child: CircularProgressIndicator(color: _elioGreen))
                : explanation == null || explanation!.isUnavailable
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            l10n.ovNoExplanation,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: _elioCaption, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ExplanationBody(explanation: explanation!),
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ExplanationBody — reusable in history screen
// ---------------------------------------------------------------------------

/// Renders the full explanation content (summary, table, takeaway, source).
/// Can be reused in [ScanHistoryScreen].
class ExplanationBody extends StatelessWidget {
  const ExplanationBody({super.key, required this.explanation});
  final QuizExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (explanation.summary.isNotEmpty) ...[
          Text(
            explanation.summary,
            style: GoogleFonts.inter(
              color: _elioInk,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 10),
        ],
        if (explanation.correctAnswerReason.isNotEmpty) ...[
          Text(
            explanation.correctAnswerReason,
            style: GoogleFonts.inter(color: _elioSubtext, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
        ],
        if (explanation.selectedAnswerFeedback.isNotEmpty) ...[
          Text(
            explanation.selectedAnswerFeedback,
            style: GoogleFonts.inter(color: _elioIncorrect, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
        ],
        if (explanation.conceptExplanation.isNotEmpty) ...[
          Text(
            explanation.conceptExplanation,
            style: GoogleFonts.inter(color: _elioInk, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
        ],
        // Essay: rubric rows
        if (explanation.rubricRows != null && explanation.rubricRows!.isNotEmpty) ...[
          Text(
            l10n.qzScoringTable,
            style: GoogleFonts.manrope(
              color: _elioSubtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _RubricTable(rows: explanation.rubricRows!),
          const SizedBox(height: 10),
        ],
        // MCQ: comparison rows
        if (explanation.comparisonRows.isNotEmpty) ...[
          Text(
            l10n.ovCompareTable,
            style: GoogleFonts.manrope(
              color: _elioSubtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _ComparisonTable(rows: explanation.comparisonRows),
          const SizedBox(height: 10),
        ],
        if (explanation.learningTakeaway.isNotEmpty) ...[
          Text(
            explanation.learningTakeaway,
            style: GoogleFonts.inter(
              color: _elioSubtext,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (explanation.referenceAnswer != null) ...[
          Text(
            l10n.ovReference(explanation.referenceAnswer ?? ''),
            style: GoogleFonts.inter(color: _elioSubtext, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
        ],
        if (explanation.quote != null) ...[
          Text('"${explanation.quote}"',
              style: GoogleFonts.inter(color: _elioCaption, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
        ],
        if (QuizPdfService.sourceLine(explanation) != null)
          Text(
            QuizPdfService.sourceLine(explanation)!,
            style: GoogleFonts.inter(color: _elioCaption, fontSize: 12),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Comparison and Rubric tables
// ---------------------------------------------------------------------------

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.rows});
  final List<ComparisonRow> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: _elioBorder, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _elioGreenLight),
          children: [l10n.ovCategory, l10n.ovMaterial, l10n.ovAccepted].map((h) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                h,
                style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _elioInk),
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          final hl = row.isCorrect;
          return TableRow(
            decoration: hl
                ? BoxDecoration(color: _elioGreen.withValues(alpha: 0.08))
                : null,
            children: [row.bin, row.material, row.accepted].map((cell) {
              return Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  cell,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hl ? _elioGreen : _elioInk,
                    fontWeight: hl ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}

class _RubricTable extends StatelessWidget {
  const _RubricTable({required this.rows});
  final List<RubricRow> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: _elioBorder, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FixedColumnWidth(44),
        2: FixedColumnWidth(56),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _elioGreenLight),
          children: [l10n.ovCriteria, l10n.ovMax, l10n.ovAwarded, l10n.ovComment].map((h) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                h,
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: _elioInk),
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          final isGood = row.awardedScore >= row.maxScore * 0.6;
          return TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(row.criterion, style: GoogleFonts.inter(fontSize: 12, color: _elioInk))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('${row.maxScore}', style: GoogleFonts.inter(fontSize: 12, color: _elioInk))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '${row.awardedScore}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isGood ? _elioGreen : _elioIncorrect,
                    fontWeight: FontWeight.w600,
                  ),
                )),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(row.comment, style: GoogleFonts.inter(fontSize: 11, color: _elioCaption))),
          ]);
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Actions Row
// ---------------------------------------------------------------------------

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.state, required this.notifier});
  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isLast = state.isLastQuestion;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        // Secondary: back (visual only)
        OutlinedButton.icon(
          onPressed: null, // disabled per spec
          style: OutlinedButton.styleFrom(
            foregroundColor: _elioSubtext,
            side: const BorderSide(color: _elioBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(context.l10n.backToQuestion),
        ),
        // Primary: next or finish
        FilledButton.icon(
          onPressed: notifier.nextQuestion,
          style: FilledButton.styleFrom(
            backgroundColor: _elioGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 16),
          label: Text(isLast ? l10n.ovFinish : l10n.ovNext),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Right Panel — Chat
// ---------------------------------------------------------------------------

class _ChatRightPanel extends StatelessWidget {
  const _ChatRightPanel({
    required this.state,
    required this.notifier,
    required this.chatController,
    required this.chatScroll,
    required this.speakingIndex,
    required this.onSendChat,
    required this.onListen,
    this.onStop,
  });

  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;
  final TextEditingController chatController;
  final ScrollController chatScroll;
  final int? speakingIndex;
  final VoidCallback onSendChat;
  final void Function(int index, String text) onListen;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F4F3),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _elioBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _elioGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ovAssistant,
                    style: GoogleFonts.sora(
                        color: _elioInk, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                if (onStop != null) ...[_StopPill(onStop: onStop!), const SizedBox(width: 6)],
                _WindowIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.qzMinimise,
                  onTap: notifier.minimize,
                ),
                const SizedBox(width: 6),
                _WindowIconButton(
                  icon: Icons.close_rounded,
                  tooltip: l10n.commonClose,
                  onTap: notifier.dismiss,
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: chatScroll,
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length + (state.sendingChat ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == state.messages.length) return const _TypingBubble();
                final msg = state.messages[i];
                return _ChatBubble(
                  message: msg,
                  isSpeaking: speakingIndex == i,
                  onListen: () => onListen(i, msg.text),
                );
              },
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _elioBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    onSubmitted: (_) => onSendChat(),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.inter(fontSize: 13, color: _elioInk),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: l10n.ovAskAi,
                      hintStyle: GoogleFonts.inter(color: elioOutline, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _elioBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _elioBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: state.sendingChat ? elioOutlineVariant : _elioGreen,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: state.sendingChat ? null : onSendChat,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble widgets (mirrors waste_quiz_popup.dart variants)
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isSpeaking, required this.onListen});

  final ChatMessage message;
  final bool isSpeaking;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? _elioGreen : elioSecondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  color: isUser ? Colors.white : _elioInk,
                  fontSize: 13,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 4),
              _ListenChip(playing: isSpeaking, onTap: onListen),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: elioSecondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _elioGreen),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListenChip extends StatelessWidget {
  const _ListenChip({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing ? _elioGreen : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: playing ? _elioGreen : _elioBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                size: 14,
                color: playing ? Colors.white : elioMuted,
              ),
              const SizedBox(width: 6),
              Text(
                playing ? l10n.qzPlaying : l10n.qzListen,
                style: GoogleFonts.manrope(
                    color: playing ? Colors.white : elioMuted, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        label,
        style: GoogleFonts.inter(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _VoiceToggle extends StatelessWidget {
  const _VoiceToggle({required this.on, required this.onToggle});
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: const BorderSide(color: _elioBorder)),
      child: InkWell(
        onTap: onToggle,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 16,
                color: on ? _elioGreen : elioMuted,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.ovVoice,
                style: GoogleFonts.inter(
                    color: on ? _elioGreen : elioMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowIconButton extends StatelessWidget {
  const _WindowIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFECEEED),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18, color: _elioInk)),
        ),
      ),
    );
  }
}

class _StopPill extends StatelessWidget {
  const _StopPill({required this.onStop});
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: l10n.ctlEmergencyStop,
      child: Material(
        color: const Color(0xFFD32F2F),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onStop,
          customBorder: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              'STOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
