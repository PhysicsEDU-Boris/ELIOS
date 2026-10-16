import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';
import '../models/scanned_waste.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../services/quiz_tts_service.dart';
import '../theme/elio_learning_colors.dart';

/// Scan-triggered quiz popup (Figma: "Android Compact · Quiz Popup").
///
/// Sized to the screen rather than a fixed desktop frame: two panes from
/// 600dp wide (question + 280dp AI chat), tabs below that. The question panel
/// and the chat scroll independently, so long questions or AI replies never
/// push content off-screen. Inert while idle so robot controls stay usable.
class WasteQuizPopup extends ConsumerWidget {
  const WasteQuizPopup({super.key});

  static const twoPaneMinWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wasteQuizProvider);
    final active = state.phase != WasteQuizPhase.idle;
    final showCard = active && !state.minimized;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !showCard,
            child: AnimatedOpacity(
              opacity: showCard ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
                        child: active ? SizedBox.expand(child: _QuizCard(state: state)) : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (active && state.minimized)
          Positioned(right: 16, bottom: 16, child: SafeArea(child: _MinimizedBubble())),
      ],
    );
  }
}

class _MinimizedBubble extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: elioPrimary,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => ref.read(wasteQuizProvider.notifier).restore(),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Kuis AI', style: GoogleFonts.manrope(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends ConsumerStatefulWidget {
  const _QuizCard({required this.state});
  final WasteQuizUiState state;

  @override
  ConsumerState<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends ConsumerState<_QuizCard> {
  final _answerController = TextEditingController();
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  int _wordCount = 0;
  int? _speakingIndex;
  int _tab = 0;
  int _seenMessages = 0;

  @override
  void initState() {
    super.initState();
    _seenMessages = widget.state.messages.length;
    _answerController.addListener(_onAnswerChanged);
    QuizTtsService.instance.status.addListener(_onTtsStatusChanged);
  }

  void _onAnswerChanged() {
    final text = _answerController.text.trim();
    final count = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    if (count != _wordCount) setState(() => _wordCount = count);
  }

  void _onTtsStatusChanged() {
    if (QuizTtsService.instance.status.value != TtsStatus.speaking && mounted) {
      setState(() => _speakingIndex = null);
    }
  }

  @override
  void didUpdateWidget(covariant _QuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.questionIndex != widget.state.questionIndex ||
        oldWidget.state.scan != widget.state.scan) {
      _answerController.clear();
    }
    if (widget.state.messages.length > oldWidget.state.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatScroll.hasClients) return;
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    QuizTtsService.instance.status.removeListener(_onTtsStatusChanged);
    _answerController.dispose();
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

  void _listen(int index, String text) {
    setState(() => _speakingIndex = index);
    ref.read(wasteQuizProvider.notifier).listen(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(wasteQuizProvider.notifier);

    final questionPanel = _QuestionPanel(
      state: state,
      answerController: _answerController,
      wordCount: _wordCount,
    );
    Widget chatPanel({required bool showHeader}) => _ChatPanel(
          state: state,
          showHeader: showHeader,
          chatController: _chatController,
          chatScroll: _chatScroll,
          speakingIndex: _speakingIndex,
          onSendChat: _sendChat,
          onListen: _listen,
        );

    return Material(
      color: elioBackground,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: elioOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= WasteQuizPopup.twoPaneMinWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: questionPanel),
                const VerticalDivider(width: 1, thickness: 1, color: elioOutlineVariant),
                SizedBox(
                  width: math.min(280, constraints.maxWidth * 0.36),
                  child: chatPanel(showHeader: true),
                ),
              ],
            );
          }
          final unread = state.messages.length - _seenMessages;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: elioOutlineVariant)),
                ),
                child: Row(
                  children: [
                    _TabButton(label: 'Soal', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 6),
                    _TabButton(
                      label: unread > 0 && _tab == 0 ? 'Asisten AI • $unread' : 'Asisten AI',
                      selected: _tab == 1,
                      onTap: () => setState(() {
                        _tab = 1;
                        _seenMessages = state.messages.length;
                      }),
                    ),
                    const Spacer(),
                    _WindowIconButton(icon: Icons.remove_rounded, tooltip: 'Kecilkan', onTap: notifier.minimize),
                    const SizedBox(width: 6),
                    _WindowIconButton(icon: Icons.close_rounded, tooltip: 'Tutup', onTap: notifier.dismiss),
                  ],
                ),
              ),
              Expanded(child: _tab == 0 ? questionPanel : chatPanel(showHeader: false)),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionPanel extends ConsumerWidget {
  const _QuestionPanel({
    required this.state,
    required this.answerController,
    required this.wordCount,
  });

  final WasteQuizUiState state;
  final TextEditingController answerController;
  final int wordCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(wasteQuizProvider.notifier);
    final q = state.question;
    final showAnswers = state.phase == WasteQuizPhase.active && q != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: 'Soal ${state.questionIndex + 1}/${state.totalQuestions} · '
                          '${switch (state.difficulty) {
                        QuizDifficulty.easy => 'Mudah',
                        QuizDifficulty.medium => 'Sedang',
                        QuizDifficulty.hard => 'Sulit',
                      }}',
                      bg: elioSecondaryContainer,
                      fg: elioOnSecondaryContainer,
                    ),
                    _Chip(
                      label: 'Terdeteksi: ${state.phase == WasteQuizPhase.identifying ? 'mengenali…' : state.scan?.displayName ?? '-'}',
                      bg: elioTertiaryContainer,
                      fg: Colors.white,
                    ),
                    _Chip(
                      label: questionTypeFor(state.questionIndex) == QuizQuestionType.multipleChoice
                          ? 'Pilihan ganda'
                          : 'Essay · maks ${_EssayCard.wordLimit} kata',
                      bg: elioSecondaryContainer,
                      fg: elioOnSecondaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _VoiceIconButton(on: state.voiceOn, onTap: notifier.toggleVoice),
            ],
          ),
          const SizedBox(height: 8),
          if (state.phase == WasteQuizPhase.finished)
            _SummaryCard(state: state, onClose: notifier.dismiss)
          else if (state.phase == WasteQuizPhase.confirmingHazard)
            _CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kemungkinan limbah B3: ${state.scan?.displayName ?? ""}',
                      style: GoogleFonts.sora(color: elioInk, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Jangan bongkar atau masukkan ke tempat sampah biasa. '
                      'Minta bantuan petugas untuk penanganannya. Lanjutkan kuis tentang benda ini?'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    FilledButton(onPressed: notifier.confirmHazard, child: const Text('Lanjut kuis')),
                    TextButton(onPressed: notifier.dismiss, child: const Text('Scan ulang')),
                  ]),
                ],
              ),
            )
          else if (state.phase == WasteQuizPhase.confirmingMismatch)
            _MismatchCard(state: state, notifier: notifier)
          else
            _QuestionCard(state: state),
          if (showAnswers) ...[
            const SizedBox(height: 8),
            if (q.type == QuizQuestionType.multipleChoice)
              _AnswerGrid(state: state, onSelect: notifier.selectOption)
            else
              _EssayCard(
                state: state,
                controller: answerController,
                wordCount: wordCount,
                onSubmit: () => notifier.submitEssay(answerController.text),
              ),
          ],
          if (showAnswers && !state.answered && ref.watch(appPreferencesProvider).skipAllowed) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: notifier.skipQuestion,
                style: TextButton.styleFrom(foregroundColor: elioMuted),
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: Text(state.isLastQuestion ? 'Lewati & selesai' : 'Lewati soal'),
              ),
            ),
          ],
          if (showAnswers && state.answered) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: state.sendingChat ? null : notifier.nextQuestion,
                style: FilledButton.styleFrom(
                  backgroundColor: elioPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(state.isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 18),
                label: Text(state.isLastQuestion ? 'Selesai' : 'Soal berikutnya'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.state});
  final WasteQuizUiState state;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: state.phase == WasteQuizPhase.loadingQuestion || state.question == null
          ? ValueListenableBuilder<GemmaProgress>(
              valueListenable: GemmaQuizService.instance.progress,
              builder: (context, p, _) {
                final text = switch (p.status) {
                  _ when state.phase == WasteQuizPhase.identifying => 'Looking…',
                  GemmaStatus.installing => p.installPercent > 0
                      ? 'Menyiapkan AI offline (hanya sekali)… ${p.installPercent}%'
                      : 'Menyiapkan AI offline (hanya sekali)…',
                  GemmaStatus.loading => 'Memuat model Gemma ke memori…',
                  // Questions 2+ are prefetched in the background (decision
                  // 0011): this only shows while this one isn't ready yet.
                  _ when state.questionIndex > 0 => 'Menyiapkan soal berikutnya…',
                  _ => 'Gemma sedang membuat soal tentang "${state.scan?.displayName ?? ''}"…',
                };
                return Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: elioPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: GoogleFonts.inter(color: elioInk, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                );
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.isFallback
                      ? 'SOAL CADANGAN (AI ON-DEVICE BELUM SIAP)'
                      : 'SOAL AI GEMMA · ON-DEVICE (DARI SAMPAH YANG DISCAN)',
                  style: GoogleFonts.manrope(color: elioPrimary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  state.question!.question,
                  style: GoogleFonts.sora(color: elioInk, fontSize: 16, height: 1.375, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state, required this.onClose});
  final WasteQuizUiState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.notice != null ? 'Scan belum berhasil' : 'Sesi selesai 🎉',
            style: GoogleFonts.sora(color: elioInk, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            state.notice ??
                'Pilihan ganda benar: ${state.correctCount} dari ${state.mcAnswered}.'
                    '${state.skippedCount > 0 ? ' ${state.skippedCount} soal dilewati.' : ''} '
                    'Scan sampah lain untuk mendapat soal baru.',
            style: GoogleFonts.inter(color: elioMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(backgroundColor: elioPrimary),
              child: const Text('Tutup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({required this.state, required this.onSelect});
  final WasteQuizUiState state;
  final ValueChanged<int> onSelect;

  static const _colors = [elioAnswerRed, elioAnswerBlue, elioAnswerYellow, elioAnswerGreen];

  @override
  Widget build(BuildContext context) {
    final q = state.question!;
    Widget tile(int i) => _AnswerTile(
          index: i,
          label: q.options[i],
          color: _colors[i % _colors.length],
          answered: state.selectedOption != null,
          isCorrect: i == q.correctIndex,
          isSelected: state.selectedOption == i,
          onTap: () => onSelect(i),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              for (var i = 0; i < q.options.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                tile(i),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var r = 0; r * 2 < q.options.length; r++) ...[
              if (r > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tile(r * 2)),
                    const SizedBox(width: 8),
                    Expanded(child: r * 2 + 1 < q.options.length ? tile(r * 2 + 1) : const SizedBox()),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.index,
    required this.label,
    required this.color,
    required this.answered,
    required this.isCorrect,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final String label;
  final Color color;
  final bool answered;
  final bool isCorrect;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = answered && !isCorrect && !isSelected;
    final resultIcon = !answered
        ? null
        : isCorrect
            ? Icons.check_circle_rounded
            : isSelected
                ? Icons.cancel_rounded
                : null;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: answered ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CustomPaint(size: const Size.square(18), painter: _ShapePainter(index)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, height: 1.3, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (resultIcon != null) ...[
                    const SizedBox(width: 6),
                    Icon(resultIcon, color: Colors.white, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Triangle / diamond / circle / square markers from the Figma answer tiles.
class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.index);
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final w = size.width;
    final h = size.height;
    switch (index % 4) {
      case 0:
        canvas.drawPath(Path()..moveTo(w / 2, 1)..lineTo(w, h - 1)..lineTo(0, h - 1)..close(), paint);
      case 1:
        canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h / 2)..lineTo(w / 2, h)..lineTo(0, h / 2)..close(), paint);
      case 2:
        canvas.drawCircle(Offset(w / 2, h / 2), w / 2, paint);
      default:
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) => old.index != index;
}

class _EssayCard extends StatelessWidget {
  const _EssayCard({
    required this.state,
    required this.controller,
    required this.wordCount,
    required this.onSubmit,
  });

  final WasteQuizUiState state;
  final TextEditingController controller;
  final int wordCount;
  final VoidCallback onSubmit;

  static const wordLimit = 150;

  @override
  Widget build(BuildContext context) {
    final overLimit = wordCount > wordLimit;
    final editable = !state.essaySubmitted && !state.sendingChat;
    final canSubmit = editable && wordCount > 0 && !overLimit;

    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'JAWABANMU',
            style: GoogleFonts.manrope(color: elioMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: editable,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: elioInk),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: elioSurfaceContainerLow,
              hintText: 'Ketik jawabanmu di sini...',
              hintStyle: GoogleFonts.inter(color: elioOutline, fontSize: 14),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: elioOutlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: elioOutlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = Text(
                '$wordCount / $wordLimit kata',
                style: GoogleFonts.manrope(color: overLimit ? elioDanger : elioOutline, fontSize: 11, fontWeight: FontWeight.w800),
              );
              final buttons = Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: editable && wordCount > 0 ? controller.clear : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: elioInk,
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: elioPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Hapus'),
                  ),
                  FilledButton(
                    onPressed: canSubmit ? onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: elioPrimary,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(state.essaySubmitted ? 'Terkirim' : 'Kirim Jawaban'),
                  ),
                ],
              );
              // Narrow panels: word count on its own line above the buttons.
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [count, const SizedBox(height: 6), Align(alignment: Alignment.centerRight, child: buttons)],
                );
              }
              return Row(children: [Expanded(child: count), buttons]);
            },
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends ConsumerWidget {
  const _ChatPanel({
    required this.state,
    required this.showHeader,
    required this.chatController,
    required this.chatScroll,
    required this.speakingIndex,
    required this.onSendChat,
    required this.onListen,
  });

  final WasteQuizUiState state;
  final bool showHeader;
  final TextEditingController chatController;
  final ScrollController chatScroll;
  final int? speakingIndex;
  final VoidCallback onSendChat;
  final void Function(int index, String text) onListen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(wasteQuizProvider.notifier);
    return ColoredBox(
      color: elioSurfaceContainerLow,
      child: Column(
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: elioOutlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: elioPrimary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asisten Koreksi AI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(color: elioInk, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _WindowIconButton(icon: Icons.remove_rounded, tooltip: 'Kecilkan', onTap: notifier.minimize),
                  const SizedBox(width: 6),
                  _WindowIconButton(icon: Icons.close_rounded, tooltip: 'Tutup', onTap: notifier.dismiss),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: chatScroll,
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length + (state.sendingChat ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == state.messages.length) return const _TypingBubble();
                final message = state.messages[i];
                return _ChatBubble(
                  message: message,
                  isSpeaking: speakingIndex == i,
                  onListen: () => onListen(i, message.text),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: elioOutlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    onSubmitted: (_) => onSendChat(),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.inter(fontSize: 13, color: elioInk),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Tanya AI untuk koreksi...',
                      hintStyle: GoogleFonts.inter(color: elioOutline, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: elioOutlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: elioOutlineVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: state.sendingChat ? elioOutlineVariant : elioPrimary,
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
              constraints: const BoxConstraints(maxWidth: 236),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? elioPrimary : elioSecondaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.caption != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.caption!,
                        style: GoogleFonts.manrope(
                          color: isUser ? Colors.white70 : elioOnSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: isUser ? Colors.white : elioInk,
                      fontSize: 13,
                      height: 1.38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
              child: CircularProgressIndicator(strokeWidth: 2, color: elioPrimary),
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
      color: playing ? elioPrimary : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: playing ? elioPrimary : elioOutlineVariant)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 14, color: playing ? Colors.white : elioMuted),
              const SizedBox(width: 6),
              Text(
                playing ? 'Playing' : 'Listen',
                style: GoogleFonts.manrope(color: playing ? Colors.white : elioMuted, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? elioPrimary : elioSurfaceContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.manrope(color: selected ? Colors.white : elioMuted, fontSize: 12, fontWeight: FontWeight.w800),
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
        color: elioSurfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18, color: elioInk)),
        ),
      ),
    );
  }
}

class _VoiceIconButton extends StatelessWidget {
  const _VoiceIconButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: on ? 'Suara aktif' : 'Suara mati',
      child: Material(
        color: on ? elioPrimary : elioSurfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 18, color: on ? Colors.white : elioMuted),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Detector and Gemma disagree on the bin: nothing runs until the user picks.
class _MismatchCard extends StatelessWidget {
  const _MismatchCard({required this.state, required this.notifier});
  final WasteQuizUiState state;
  final WasteQuizNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final detector = state.mismatchDetector ?? '-';
    final detectorCategory = ScannedWaste.detectorCategory(detector) ?? '-';
    final gemmaCategory = state.scan?.rawCategory ?? '-';
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategori belum pasti',
              style: GoogleFonts.sora(color: elioInk, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Detektor: $detector ($detectorCategory). '
              'Gemma: ${state.scan?.displayName ?? '-'} ($gemmaCategory). Pilih kategori yang benar.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: () => notifier.resolveMismatch(useDetector: true),
                child: Text('Pakai detektor ($detectorCategory)')),
            OutlinedButton(
                onPressed: () => notifier.resolveMismatch(useDetector: false),
                child: Text('Pakai Gemma ($gemmaCategory)')),
            TextButton(onPressed: notifier.dismiss, child: const Text('Scan ulang')),
          ]),
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
