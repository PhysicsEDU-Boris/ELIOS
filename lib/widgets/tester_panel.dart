import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../services/device_health.dart';
import '../services/ai_quiz_service.dart';
import '../services/tester_log.dart';
import 'package:elio/l10n/l10n.dart';

/// Cloud AI state label for the tester panel: the model that last answered.
String aiStateLabel(AiStatus status, String? model) => switch (status) {
      AiStatus.idle => 'Belum dipakai',
      AiStatus.ready => 'Siap (${model ?? '-'})',
      AiStatus.offline => 'Tidak tersambung, mode bank',
    };

/// Settings block of the tester build (decision 0040): question source switch,
/// cloud AI state, and the shareable log. Callers show it only when
/// [testerBuild] is true.
class TesterPanel extends ConsumerWidget {
  const TesterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(appPreferencesProvider.select((p) => p.questionSource));
    final service = AiQuizService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(context.l10n.testerMode, style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(context.l10n.testerQuestionSource)),
            SegmentedButton<QuestionSource>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: QuestionSource.bank, label: Text(context.l10n.testerBank)),
                const ButtonSegment(value: QuestionSource.ai, label: Text('ELIOS AI')),
              ],
              selected: {source},
              onSelectionChanged: (s) =>
                  ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(questionSource: s.first)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<AiStatus>(
          valueListenable: service.status,
          builder: (context, status, _) =>
              Text('AI: ${aiStateLabel(status, service.lastModel)}', key: const Key('ai-state')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => DeviceHealth.shareText(_tail()),
              child: Text(context.l10n.testerShareLog),
            ),
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _tail()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.testerLogCopied)));
                }
              },
              child: Text(context.l10n.testerCopyLog),
            ),
            OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(context.l10n.testerLog),
                  content: SingleChildScrollView(
                    child: SelectableText(_tail(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
              ),
              child: Text(context.l10n.testerViewLog),
            ),
            OutlinedButton(onPressed: TesterLog.instance.clear, child: Text(context.l10n.testerClearLog)),
          ],
        ),
      ],
    );
  }

  /// The share/copy text is capped well under Android's intent size limit.
  static String _tail() {
    final all = TesterLog.instance.read();
    return all.length > 100000 ? all.substring(all.length - 100000) : all;
  }
}
