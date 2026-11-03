import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../services/device_health.dart';
import '../services/ai_quiz_service.dart';
import '../services/tester_log.dart';

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
        const Text('Mode penguji', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('Sumber soal')),
            SegmentedButton<QuestionSource>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: QuestionSource.bank, label: Text('Bank')),
                ButtonSegment(value: QuestionSource.ai, label: Text('ELIOS AI')),
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
              child: const Text('Bagikan log'),
            ),
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _tail()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log disalin')));
                }
              },
              child: const Text('Salin log'),
            ),
            OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Log penguji'),
                  content: SingleChildScrollView(
                    child: SelectableText(_tail(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
              ),
              child: const Text('Lihat log'),
            ),
            OutlinedButton(onPressed: TesterLog.instance.clear, child: const Text('Hapus log')),
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
