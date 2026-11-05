import 'package:flutter/foundation.dart';

import '../models/quiz_explanation.dart';
import '../models/record_translation.dart';
import '../models/scan_record.dart';
import 'ai_quiz_service.dart';
import 'scan_record_store.dart';

/// Translates a saved History record once per language with one ELIOS AI
/// call and caches it on the record (decision 0185). Offline or on an invalid
/// reply nothing is saved and the caller shows the original language.
class HistoryTranslationService {
  static final _pending = <(ScanRecordStore, String, String), Future<bool>>{};

  /// True when [record] can be shown in [lang] from the cache (after at most
  /// one AI call); false when it must stay in its original language for now.
  static Future<bool> ensure(
    ScanRecordStore store,
    ScanRecord record,
    String lang,
  ) {
    final current =
        store.records.where((r) => r.id == record.id).firstOrNull ?? record;
    if (!current.needsTranslation(lang)) return Future.value(true);
    final key = (store, record.id, lang);
    return _pending.putIfAbsent(
      key,
      // Block body: returning the removed future would make it wait on itself.
      () => _translate(store, current, lang).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  static Future<bool> _translate(
    ScanRecordStore store,
    ScanRecord record,
    String lang,
  ) async {
    final payload = payloadFor(record, lang);
    final raw = await AiQuizService.instance.translateTexts(payload, lang);
    final translation = raw == null ? null : parse(raw, record, lang);
    if (translation == null) return false;
    try {
      await store.saveTranslation(record.id, lang, translation);
    } catch (e) {
      debugPrint('[HistoryTranslation] save failed: $e');
      return false;
    }
    return true;
  }

  static bool _needsQuestions(ScanRecord r, String lang) =>
      r.lang != lang && r.translations[lang] == null;

  static bool _needsExplanation(ScanRecord r, int i, String lang) {
    final e = r.questions[i].explanation;
    if (e == null || r.explanationLang(i) == lang || e.alt?.lang == lang) {
      return false;
    }
    final t = r.translations[lang];
    final cached = t != null && i < t.questions.length
        ? t.questions[i].explanation
        : null;
    return cached == null && (e.isComplete || e.essayFeedback != null);
  }

  /// What is sent: the question texts (when not cached yet) and every saved
  /// explanation not yet in [lang].
  @visibleForTesting
  static Map<String, dynamic> payloadFor(ScanRecord r, String lang) {
    final withQuestions = _needsQuestions(r, lang);
    return {
      if (withQuestions) 'item': r.itemName,
      'questions': [
        for (var i = 0; i < r.questions.length; i++)
          {
            if (withQuestions) ...{
              'question': r.questions[i].question,
              'options': r.questions[i].options,
              'yourAnswer': r.questions[i].yourAnswer,
              'rightAnswer': r.questions[i].rightAnswer,
            },
            if (_needsExplanation(r, i, lang))
              'explanation': {
                'why_correct': r.questions[i].explanation!.correctAnswerReason,
                'why_wrong': r.questions[i].explanation!.selectedAnswerFeedback,
                'key_idea': r.questions[i].explanation!.keyIdea,
                'steps': r.questions[i].explanation!.steps,
                'essay_feedback':
                    r.questions[i].explanation!.essayFeedback ?? '',
              },
          },
      ],
    };
  }

  /// The translation merged with the existing cache, or null when the reply
  /// is not a faithful translation: wrong counts, a changed correct or chosen
  /// option, missing or extra texts.
  @visibleForTesting
  static RecordTranslation? parse(String raw, ScanRecord r, String lang) {
    try {
      final sent = payloadFor(r, lang);
      // Bilingual reply (decision 0185): only the side for [lang] is used.
      final json = AiQuizService.bilingual(raw, lang)?.main;
      if (json == null) return null;
      final qs = json['questions'];
      if (qs is! List || qs.length != r.questions.length) return null;
      String? text(Object? v, {bool empty = false}) =>
          v is String && v.length <= 4000 && (empty || v.trim().isNotEmpty)
          ? v.trim()
          : null;
      final withQuestions = sent.containsKey('item');
      final old = r.translations[lang];
      final item = withQuestions
          ? text(json['item'])
          : (old?.itemName ?? r.itemName);
      if (item == null) return null;
      final out = <QuestionText>[];
      for (var i = 0; i < r.questions.length; i++) {
        final src = r.questions[i];
        final got = qs[i];
        if (got is! Map) return null;
        QuestionText base;
        if (withQuestions) {
          final question = text(got['question']);
          final yours = text(got['yourAnswer'], empty: src.yourAnswer.isEmpty);
          final right = text(
            got['rightAnswer'],
            empty: src.rightAnswer.isEmpty,
          );
          final opts = got['options'];
          if (question == null ||
              yours == null ||
              right == null ||
              opts is! List ||
              opts.length != src.options.length) {
            return null;
          }
          final options = [for (final o in opts) text(o)];
          if (options.contains(null)) return null;
          // Same option must stay correct and chosen: indexes are compared, not wording.
          final rightAt = src.options.indexOf(src.rightAnswer);
          final yoursAt = src.options.indexOf(src.yourAnswer);
          if (rightAt >= 0 && options[rightAt] != right) return null;
          if (yoursAt >= 0 && options[yoursAt] != yours) return null;
          if ((src.yourAnswer == src.rightAnswer) != (yours == right)) {
            return null;
          }
          base = QuestionText(
            question: question,
            options: options.cast<String>(),
            yourAnswer: yours,
            rightAnswer: right,
          );
        } else if (old != null && i < old.questions.length) {
          base = old.questions[i];
        } else {
          // Record already in [lang]: question texts are the originals.
          base = QuestionText(
            question: src.question,
            options: src.options,
            yourAnswer: src.yourAnswer,
            rightAnswer: src.rightAnswer,
          );
        }
        var explanation = base.explanation;
        final sentQ = (sent['questions'] as List)[i] as Map;
        if (sentQ.containsKey('explanation')) {
          final e = got['explanation'];
          final s = src.explanation!;
          if (e is! Map) return null;
          final why = text(
            e['why_correct'],
            empty: s.correctAnswerReason.isEmpty,
          );
          final wrong = text(e['why_wrong'], empty: true);
          final idea = text(e['key_idea'], empty: s.keyIdea.isEmpty);
          final feedback = text(e['essay_feedback'], empty: true);
          final steps = e['steps'];
          if (why == null ||
              wrong == null ||
              idea == null ||
              feedback == null ||
              wrong.isEmpty != s.selectedAnswerFeedback.isEmpty ||
              feedback.isEmpty != (s.essayFeedback ?? '').isEmpty ||
              steps is! List ||
              steps.length != s.steps.length) {
            return null;
          }
          final stepTexts = [for (final x in steps) text(x)];
          if (stepTexts.contains(null)) return null;
          explanation = QuizExplanation.fromJson({
            ...s.toJson(),
            'summary': why,
            'correctAnswerReason': why,
            'selectedAnswerFeedback': wrong,
            'keyIdea': idea,
            'learningTakeaway': idea,
            'steps': stepTexts,
            if (s.essayFeedback != null) 'essayFeedback': feedback,
            'lang': lang,
          });
        }
        out.add(
          QuestionText(
            question: base.question,
            options: base.options,
            yourAnswer: base.yourAnswer,
            rightAnswer: base.rightAnswer,
            explanation: explanation,
          ),
        );
      }
      return RecordTranslation(itemName: item, questions: out);
    } catch (_) {
      return null;
    }
  }
}
