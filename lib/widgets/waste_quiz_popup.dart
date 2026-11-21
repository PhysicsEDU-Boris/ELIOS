import 'package:elio/Screens/question_explanation_screen.dart'
    show QuestionExportSheet, showQuizReportSheet;
import 'tour/app_tour.dart';
import 'package:elio/widgets/quiz/essay_review.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../models/scanned_waste.dart';
import '../models/trophy_rules.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/ai_quiz_service.dart';
import '../services/question_bank.dart';
import '../services/quiz_explanation_service.dart';
import '../services/quiz_tts_service.dart';
import '../services/scan_record_store.dart';
import '../Screens/home/home_parts.dart' show homeArt, homeWeight;
import '../services/elio_feedback.dart';
import '../theme/elio_learning_colors.dart';
import '../theme/elio_motion.dart';
import '../theme/elio_tokens.dart';
import 'history_ui.dart'
    show
        HistoryLoadingLayout,
        HistorySkeleton,
        HistoryTone,
        historyOutlineStyle,
        historyTint;
import 'learn/learn_l3.dart' show L3Hero, RobotBuddy, RobotMood;
import 'learn/learn_ui.dart' show LearnTheme;
import 'package:elio/l10n/l10n.dart';
import 'xp_icon.dart';

part 'quiz/quiz_r3.dart';
part 'quiz/quiz_scan_pages.dart';

/// Scan-triggered quiz popup (Figma: "Android Compact · Quiz Popup").
///
/// Sized to the screen rather than a fixed desktop frame: two panes from
/// 600dp wide (question + 280dp AI chat), tabs below that. The question panel
/// and the chat scroll independently, so long questions or AI replies never
/// push content off-screen. Inert while idle so robot controls stay usable.
/// Where the shown question came from (decisions 0017, 0018). An AI question
/// never claims to be from the module.
String questionSourceHeader(WasteQuizUiState state) {
  if (state.question?.bankId != null) return l10n.quizSrcBank;
  if (!state.isFallback) return l10n.quizSrcAi;
  return state.questionSource == QuestionSource.ai
      ? l10n.quizSrcFallback
      : l10n.quizSrcGeneric;
}

class WasteQuizPopup extends ConsumerWidget {
  const WasteQuizPopup({
    super.key,
    this.onStop,
    this.onRescan,
    this.showLauncher = true,
  });

  /// The emergency stop, as the compact STOP in the header (decision 0026): the
  /// open quiz covers the screen's own STOP.
  final VoidCallback? onStop;

  /// Triggered when the student taps "Scan lagi" on the result card (decision 0030).
  final VoidCallback? onRescan;

  /// The Quiz button that reopens a minimised quiz, bottom right. Control places its own.
  final bool showLauncher;

  @visibleForTesting
  static bool get r1EnabledOverride => _ResultCard.r1EnabledOverride;
  @visibleForTesting
  static set r1EnabledOverride(bool val) => _ResultCard.r1EnabledOverride = val;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wasteQuizProvider);
    final showCard = state.phase != WasteQuizPhase.idle && !state.minimized;
    final p = context.elio;
    final phone = MediaQuery.sizeOf(context).shortestSide < 600;
    return Stack(
      children: [
        if (showCard)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: p.isDark ? 0.55 : 0.35),
              child: SafeArea(
                child: Padding(
                  // Phones: the R3 popup fills the screen (Figma 393:2358); larger screens: centred.
                  padding: phone
                      ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                      : const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1100,
                        maxHeight: 720,
                      ),
                      child: _QuizBody(
                        state: state,
                        onStop: onStop,
                        onRescan: onRescan,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showLauncher)
          const Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(child: QuizLauncherButton()),
          ),
      ],
    );
  }
}

/// Phone/ELIOS AI quiz button (393:2555): Waiting while the question is prepared,
/// then the badge. Nothing while no quiz is minimised.
class QuizLauncherButton extends ConsumerWidget {
  const QuizLauncherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wasteQuizProvider);
    if (state.phase == WasteQuizPhase.idle || !state.minimized) {
      return const SizedBox.shrink();
    }
    return QuizButton(
      waiting:
          state.phase == WasteQuizPhase.identifying ||
          state.phase == WasteQuizPhase.loadingQuestion,
      onTap: () => ref.read(wasteQuizProvider.notifier).restore(),
    );
  }
}

/// The R3 Quiz pill: ELIOS AI mark, "Quiz", and a spinner (Waiting) or the red count (Open).
class QuizButton extends StatelessWidget {
  const QuizButton({
    super.key,
    required this.waiting,
    required this.onTap,
    this.count = 1,
  });
  final bool waiting;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: waiting ? l10n.quizPreparing : l10n.quizReady,
      excludeSemantics: true,
      child: Container(
        key: ValueKey(waiting ? 'quiz_button_waiting' : 'quiz_button_ready'),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: p.primary, width: 2),
          boxShadow: [
            BoxShadow(color: p.borderMedium, offset: const Offset(0, 3)),
          ],
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EliosAiBadge(size: 32),
                const SizedBox(width: 6),
                Text(
                  l10n.quizWord,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                waiting
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: p.primary,
                        ),
                      )
                    : Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: p.onError,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.state,
    required this.onClose,
    this.onRescan,
  });

  final WasteQuizUiState state;
  final VoidCallback onClose;
  final VoidCallback? onRescan;

  @visibleForTesting
  static bool r1EnabledOverride = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.notice != null) {
      return _CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scanFailed,
              style: GoogleFonts.sora(
                color: elioInk,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.notice!,
              style: GoogleFonts.inter(
                color: elioMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('result_card_close_button'),
                onPressed: onClose,
                style: FilledButton.styleFrom(backgroundColor: elioPrimary),
                child: Text(context.l10n.commonClose),
              ),
            ),
          ],
        ),
      );
    }

    final scan = state.scan;
    final itemName = scan?.displayName ?? l10n.wasteGeneric;
    final category = ScanCategory.fromString(scan?.category?.id);

    final earnedTrophies = state.recordedQuestions.isNotEmpty
        ? state.recordedQuestions.fold<int>(0, (sum, q) => sum + q.trophies)
        : trophiesForScores(correctMcCount: state.correctCount);
    final totalQuestions = state.totalQuestions;
    final grade = gradeFor(
      trophies: earnedTrophies,
      totalQuestions: totalQuestions,
    );
    final gradingPending = state.recordedQuestions.any((q) => q.gradingPending);

    final store = ScanRecordStore.instance;
    final totalTrophies = store.totalTrophies;
    final userLevel = store.userLevel;
    final levelProgress = store.levelProgress;

    final isR1 = r1EnabledOverride || const bool.fromEnvironment('R1');
    final r1Pending = isR1 && ref.watch(r1DropPendingProvider);

    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  itemName,
                  style: GoogleFonts.sora(
                    color: elioInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: category.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.badgeLabel,
                  style: TextStyle(
                    color: category.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.wqCorrectOf(state.correctCount, totalQuestions),
                style: GoogleFonts.inter(
                  color: elioInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                key: const Key('result_card_trophies_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const XpIcon(16),
                    const SizedBox(width: 4),
                    Text(
                      l10n.trophiesEarned(earnedTrophies),
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('result_card_grade_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: elioPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  gradingPending ? l10n.awaitingGrading : grade.label,
                  style: const TextStyle(
                    color: elioPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: elioSurfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        userLevel.levelAndTitle,
                        key: const Key('result_card_level_text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: elioInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.trophiesTotal(totalTrophies),
                      style: GoogleFonts.inter(
                        color: elioMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: levelProgress,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      elioPrimary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          if (r1Pending) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('result_card_r1_drop_notice'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFACC15)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF854D0E),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.robotDropping,
                      style: TextStyle(
                        color: Color(0xFF854D0E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                key: const Key('result_card_rescan_button'),
                onPressed: r1Pending
                    ? null
                    : () {
                        ref.read(wasteQuizProvider.notifier).logRescanTapped();
                        onRescan?.call();
                        onClose();
                      },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(context.l10n.scanAgain),
                style: FilledButton.styleFrom(backgroundColor: elioPrimary),
              ),
              OutlinedButton.icon(
                key: const Key('result_card_export_pdf_button'),
                onPressed: () async {
                  final record = ScanRecord(
                    id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
                    time: DateTime.now(),
                    itemName: itemName,
                    category: category,
                    cropPhotoPath: state.historyPhotoPath,
                    difficulty: state.difficulty,
                    questions: state.recordedQuestions,
                    trophies: earnedTrophies,
                    lang: AiQuizService.replyLang,
                  );
                  // Theme choice, then Share (decision 0228).
                  await showQuizReportSheet(context, record);
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(context.l10n.exportPdf),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: elioOutlineVariant),
                ),
              ),
              OutlinedButton(
                key: const Key('result_card_close_button'),
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: elioOutlineVariant),
                ),
                child: Text(context.l10n.commonClose),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: elioOutlineVariant),
      ),
      child: child,
    );
  }
}
