import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../services/device_health.dart';
import '../services/gemma_quiz_service.dart';
import '../services/tester_log.dart';

/// Gemma state label for the tester panel.
String gemmaStateLabel(GemmaProgress p) => switch (p.status) {
      GemmaStatus.idle => 'Belum dimuat',
      GemmaStatus.installing => 'Menyiapkan model…',
      GemmaStatus.loading => 'Memuat…',
      GemmaStatus.ready => 'Siap',
      GemmaStatus.error => 'Gagal: ${p.error ?? '-'}',
      GemmaStatus.missing => p.error ?? 'Model belum ada',
      GemmaStatus.paused => 'Dijeda: ponsel panas',
      GemmaStatus.killed => p.error ?? 'Gemma dihentikan sistem, mode bank aktif.',
    };

/// Settings block of the tester build (decision 0040): question source switch,
/// Gemma state, manual load, and the shareable log. Callers show it only when
/// [testerBuild] is true.
class TesterPanel extends ConsumerWidget {
  const TesterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(appPreferencesProvider.select((p) => p.questionSource));
    final service = GemmaQuizService.instance;
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
                ButtonSegment(value: QuestionSource.gemma, label: Text('Gemma')),
              ],
              selected: {source},
              onSelectionChanged: (s) =>
                  ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(questionSource: s.first)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<GemmaProgress>(
          valueListenable: service.progress,
          builder: (context, p, _) => Text('Gemma: ${gemmaStateLabel(p)}', key: const Key('gemma-state')),
        ),
        FutureBuilder<String?>(
          future: service.sideloadModelPath,
          builder: (context, snap) => snap.data == null
              ? const SizedBox.shrink()
              : Text('File model: ${snap.data}', style: const TextStyle(fontSize: 11)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () {
                service.clearKilled();
                service.ensureReady(vision: true);
              },
              child: const Text('Muat Gemma'),
            ),
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
