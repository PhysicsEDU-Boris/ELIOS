import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import 'ai_quiz_service.dart';
import 'scan_record_store.dart';

/// One in-flight request per saved answer, including two routes opened together.
class HistoryExplanationService {
  static final _pending =
      <(ScanRecordStore, String, int), Future<QuizExplanation>>{};

  static Future<QuizExplanation> load(
    ScanRecordStore store,
    ScanRecord record,
    int index, {
    bool retry = false,
  }) {
    final current =
        store.records.where((r) => r.id == record.id).firstOrNull ?? record;
    final q = current.questions[index];
    final saved = q.explanation;
    if (saved != null &&
        (saved.isComplete ||
            q.isEssay ||
            (!retry && saved.generatedAt != null))) {
      return Future.value(saved);
    }
    final key = (store, record.id, index);
    return _pending.putIfAbsent(
      key,
      () => _generate(store, current, index).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  static Future<QuizExplanation> _generate(
    ScanRecordStore store,
    ScanRecord record,
    int index,
  ) async {
    final q = record.questions[index];
    final saved = q.explanation;
    if (q.isEssay) return saved ?? QuizExplanation.unavailable;
    final result = await AiQuizService.instance.explainAnswer(
      itemName: record.itemName,
      category: record.category.id,
      question: q.question,
      options: q.options,
      correctOption: q.rightAnswer,
      studentAnswer: q.yourAnswer,
      difficulty: record.difficulty.name,
      bankExplanation: q.bankExplanation,
      wrongWhy: {
        ...q.wrongWhy,
        if (saved?.source == 'bank' &&
            !q.isCorrect &&
            (saved?.selectedAnswerFeedback.isNotEmpty ?? false))
          q.yourAnswer: saved!.selectedAnswerFeedback,
      },
      bankId: saved?.bankId,
      quote: saved?.quote,
    );
    final fallback = saved ?? QuizExplanation.unavailable;
    final explanation = QuizExplanation.fromJson({
      ...(result ?? fallback).toJson(),
      'generatedAt': DateTime.now().toIso8601String(),
      if (saved?.sourceSection != null) 'sourceSection': saved!.sourceSection,
      if (saved?.sourcePage != null) 'sourcePage': saved!.sourcePage,
    });
    await store.saveExplanation(record.id, index, explanation);
    return explanation;
  }
}
