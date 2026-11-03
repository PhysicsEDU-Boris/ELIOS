import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';

/// Debug switch between the reviewed question bank and cloud AI questions
/// (decision 0018). Applies from the next scan; saved with the other app
/// preferences (the Config quiz tiles set the same value).
class QuestionSourceSwitch extends ConsumerWidget {
  const QuestionSourceSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(appPreferencesProvider.select((p) => p.questionSource));
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SegmentedButton<QuestionSource>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            foregroundColor: Colors.white,
            selectedForegroundColor: Colors.black,
            selectedBackgroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          segments: const [
            ButtonSegment(value: QuestionSource.bank, label: Text('Bank soal')),
            ButtonSegment(value: QuestionSource.ai, label: Text('ELIOS AI')),
          ],
          selected: {source},
          onSelectionChanged: (s) =>
              ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(questionSource: s.first)),
        ),
      ),
    );
  }
}
