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
    // Each rejection is logged (tester log on the phone) so a bad reply can be diagnosed.
    Null fail(String why) {
      debugPrint('[HistoryTranslation] rejected ($lang): $why');
      return null;
    }

    try {
      final sent = payloadFor(r, lang);
      // Bilingual reply (decision 0185): only the side for [lang] is used.
      final json = AiQuizService.bilingual(raw, lang)?.main;
      if (json == null) return fail('no "$lang" side');
      final qs = json['questions'];
      if (qs is! List || qs.length != r.questions.length) return fail('question count');
      String? text(Object? v, {bool empty = false}) =>
          v is String && v.length <= 4000 && (empty || v.trim().isNotEmpty)
          ? v.trim()
          : null;
      final withQuestions = sent.containsKey('item');
      final old = r.translations[lang];
      final item = withQuestions
          ? text(json['item'])
          : (old?.itemName ?? r.itemName);
      if (item == null) return fail('item');
      final out = <QuestionText>[];
      for (var i = 0; i < r.questions.length; i++) {
        final src = r.questions[i];
        final got = qs[i];
        if (got is! Map) return fail('question $i shape');
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
            return fail('question $i texts or option count');
          }
          final options = [for (final o in opts) text(o)].cast<String?>();
          if (options.contains(null)) return fail('question $i empty option');
          final list = options.cast<String>();
          // The same option must stay correct and chosen. The model may word an
          // answer slightly differently from its option, so each answer must be
          // closest to the option at the original index; the option text is shown.
          final rightAt = src.options.indexOf(src.rightAnswer);
          final yoursAt = src.options.indexOf(src.yourAnswer);
          if (rightAt >= 0 && closestOption(list, right) != rightAt) {
            return fail('question $i correct answer moved');
          }
          if (yoursAt >= 0 && closestOption(list, yours) != yoursAt) {
            return fail('question $i chosen answer moved');
          }
          final rightText = rightAt >= 0 ? list[rightAt] : right;
          final yoursText = yoursAt >= 0 ? list[yoursAt] : yours;
          if (src.yourAnswer == src.rightAnswer && yoursText != rightText) {
            return fail('question $i answers differ');
          }
          base = QuestionText(
            question: question,
            options: list,
            yourAnswer: yoursText,
            rightAnswer: rightText,
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
          if (e is! Map) return fail('explanation $i shape');
          final why = text(
            e['why_correct'],
            empty: s.correctAnswerReason.isEmpty,
          );
          // Feedback the source does not have is dropped, never invented.
          final wrong = s.selectedAnswerFeedback.isEmpty ? '' : text(e['why_wrong'], empty: true);
          final idea = text(e['key_idea'], empty: s.keyIdea.isEmpty);
          final feedback = (s.essayFeedback ?? '').isEmpty ? '' : text(e['essay_feedback'], empty: true);
          final steps = e['steps'];
          if (why == null ||
              wrong == null ||
              idea == null ||
              feedback == null ||
              wrong.isEmpty != s.selectedAnswerFeedback.isEmpty ||
              feedback.isEmpty != (s.essayFeedback ?? '').isEmpty ||
              steps is! List ||
              steps.length != s.steps.length) {
            return fail('explanation $i texts or step count');
          }
          final stepTexts = [for (final x in steps) text(x)];
          if (stepTexts.contains(null)) return fail('explanation $i empty step');
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
    } catch (e) {
      return fail('$e');
    }
  }

  /// Index of the option most like [answer]: exact (ignoring case and
  /// punctuation) first, else the clearly best word overlap; -1 if unclear.
  @visibleForTesting
  static int closestOption(List<String> options, String answer) {
    Set<String> words(String t) =>
        t.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toSet();
    final a = words(answer);
    final scores = [
      for (final o in options)
        () {
          final w = words(o);
          if (w.isEmpty || a.isEmpty) return 0.0;
          if (w.length == a.length && w.containsAll(a)) return 2.0;
          return w.intersection(a).length / w.union(a).length;
        }(),
    ];
    var best = -1;
    var top = 0.5; // below half the words in common: not the same option
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] > top) {
        top = scores[i];
        best = i;
      } else if (scores[i] == top && best >= 0) {
        best = -1; // a tie is not a match
      }
    }
    return best;
  }
}
