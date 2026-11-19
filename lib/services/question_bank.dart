import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

import '../models/scanned_waste.dart';
import 'ai_quiz_service.dart';

/// Pre-written, module-grounded questions (decision 0017): first the scanned
/// object's own questions, then its label pool's (decision 0015). No model.
class QuestionBank {
  QuestionBank._(this._objects, this._pools, this._labelPools);

  factory QuestionBank.fromJson(String objectBankJson, String poolBankJson) {
    final objects = [
      for (final o
          in (jsonDecode(objectBankJson) as Map<String, dynamic>)['objects']
              as List)
        _BankObject.fromJson(o as Map<String, dynamic>),
    ];
    final pool = jsonDecode(poolBankJson) as Map<String, dynamic>;
    final items = <String, List<Map<String, dynamic>>>{};
    for (final i in pool['items'] as List) {
      final item = i as Map<String, dynamic>;
      items.putIfAbsent(item['pool'] as String, () => []).add(item);
    }
    final labelPools = <String, String>{
      for (final e in (pool['pools'] as Map<String, dynamic>).entries)
        for (final label in e.value as List) label as String: e.key,
    };
    return QuestionBank._(objects, items, labelPools);
  }

  static Future<QuestionBank>? _loading;

  /// The bank once [load] has finished (for synchronous lookups such as logging).
  static QuestionBank? loaded;

  /// Loaded once from the bundled assets: the reviewed Indonesian bank and,
  /// when bundled, its English twin (decision 0185).
  static Future<QuestionBank> load() => _loading ??= () async {
    final bank = QuestionBank.fromJson(
      await rootBundle.loadString('assets/quiz/object_bank_draft.json'),
      await rootBundle.loadString('assets/quiz/question_bank_draft.json'),
    );
    try {
      bank.addEnglish(
        await rootBundle.loadString('assets/quiz/object_bank_draft.en.json'),
        await rootBundle.loadString('assets/quiz/question_bank_draft.en.json'),
      );
    } catch (e) {
      debugPrint('[QuestionBank] no English bank: $e');
    }
    return loaded = bank;
  }();

  /// English items by id (same ids, option order and answers as Indonesian).
  final _english = <String, Map<String, dynamic>>{};

  /// Adds the English files: items become bilingual and English item names
  /// ("plastic bottle") match the same objects.
  void addEnglish(String objectBankJson, String poolBankJson) {
    for (final o
        in (jsonDecode(objectBankJson) as Map<String, dynamic>)['objects']
            as List) {
      final obj = o as Map<String, dynamic>;
      final target = _objects.where((x) => x.name == obj['object']).firstOrNull;
      for (final syn in obj['synonyms'] as List) {
        if (target != null && !target.synonyms.contains(syn)) {
          target.synonyms.add(syn as String);
        }
      }
      for (final i in obj['items'] as List) {
        _english[(i as Map)['id'] as String] = Map<String, dynamic>.from(i);
      }
    }
    for (final i
        in (jsonDecode(poolBankJson) as Map<String, dynamic>)['items']
            as List) {
      _english[(i as Map)['id'] as String] = Map<String, dynamic>.from(i);
    }
  }

  final List<_BankObject> _objects;
  final Map<String, List<Map<String, dynamic>>> _pools;
  final Map<String, String> _labelPools;

  /// What the "Bukan ini?" picker offers: each bank object by its main name,
  /// with the bin its detector class implies (null when it has none).
  List<({String name, String? category})> get pickerItems => [
    for (final o in _objects)
      (
        name: o.synonyms.first,
        category: o.label == null
            ? null
            : ScannedWaste.detectorCategory(o.label!),
      ),
  ];

  static String normalize(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static bool _has(String normalized, String phrase) =>
      normalized.contains(normalize(phrase));

  /// The bank object for the scanned item: the longest synonym found in the item
  /// name wins; a synonym found only with a material word ("botol" + "plastik")
  /// counts less. `notIf` words veto an object ("kaleng aerosol" is not an
  /// aluminium can). A B3 object never serves a non-B3 scan, or the reverse.
  String? matchObject(ScannedWaste scan) => _match(scan)?.name;

  _BankObject? _match(ScannedWaste scan) {
    final item = normalize(scan.displayName);
    final material = normalize(scan.material ?? '');
    final everything = '$item$material';
    final withMaterial = [
      for (final w in material.trim().split(' '))
        if (w.length > 2) normalize('$item $w'),
    ];
    final hazardous = scan.category?.id == 'hazardous';
    _BankObject? best;
    var bestScore = 0;
    for (final o in _objects) {
      if (o.notIf.any((w) => _has(everything, w))) continue;
      if ((o.pool == 'e_waste_b3') != hazardous && scan.category != null) {
        continue;
      }
      for (final syn in o.synonyms) {
        final words = normalize(syn).trim().split(' ').length;
        final score = _has(item, syn)
            ? 100 + words
            : (withMaterial.any((c) => _has(c, syn)) ? words : 0);
        if (score > bestScore) {
          bestScore = score;
          best = o;
        }
      }
    }
    return best;
  }

  // Item/material words -> label pool when no object matches.
  static const _poolWords = <(String, String)>[
    ('karton minuman', 'tetra_pak'),
    ('kotak susu', 'tetra_pak'),
    ('drink carton', 'tetra_pak'),
    ('milk carton', 'tetra_pak'),
    ('juice box', 'tetra_pak'),
    ('plastic', 'plastic'),
    ('glass', 'glass'),
    ('can', 'metal'),
    ('aluminum', 'metal'),
    ('metal', 'metal'),
    ('iron', 'metal'),
    ('steel', 'metal'),
    ('cardboard', 'paper_family'),
    ('paper', 'paper_family'),
    ('plastik', 'plastic'),
    ('kaca', 'glass'),
    ('kaleng', 'metal'),
    ('aluminium', 'metal'),
    ('logam', 'metal'),
    ('besi', 'metal'),
    ('baja', 'metal'),
    ('kardus', 'paper_family'),
    ('karton', 'paper_family'),
    ('kertas', 'paper_family'),
  ];

  /// The detector class when it can decide (decision 0025): it has a label
  /// pool and its bin is the scan's resolved bin. Null for the phone camera, a
  /// manual scan, or a bin the user overrode in the mismatch card (and so for
  /// B3 against non-B3, both ways).
  String? _decidingClass(ScannedWaste scan) {
    final det = scan.detectorLabel?.trim();
    if (det == null || !_labelPools.containsKey(det)) return null;
    final bin = ScannedWaste.detectorLabels[det]?.$2;
    return bin != null && bin == scan.category?.id ? det : null;
  }

  /// What [scan] is served (decision 0025): (a) the bank object matched from
  /// The AI's words, if its `label` is the detector class (or no class decides);
  /// (b) else the detector class's label pool; (c) with no deciding class,
  /// today's fallback ([poolFor]).
  ({String? object, String? pool}) selection(ScannedWaste scan) {
    final det = _decidingClass(scan);
    final object = _match(scan);
    if (object != null && (det == null || object.label == det)) {
      return (object: object.name, pool: object.pool);
    }
    if (det != null) return (object: null, pool: _labelPools[det]);
    return (object: null, pool: poolFor(scan));
  }

  /// The label pool the AI's words point to, when the detector class decides and
  /// they point to a different one in the same bin (Plastic box, the AI
  /// "kertas"). Logged as `class_mismatch`; no card is shown (decision 0025).
  String? classMismatch(ScannedWaste scan) {
    final det = _decidingClass(scan);
    if (det == null) return null;
    final gemma = _match(scan)?.pool ?? _wordPool(scan);
    return gemma != null && gemma != _labelPools[det] ? gemma : null;
  }

  /// Without a deciding detector class: the raw label's pool (a detector class
  /// in a manual scan), else the bin, else item/material words.
  String? poolFor(ScannedWaste scan) {
    final label = _labelPools[scan.rawLabel.trim()];
    if (label != null) return label;
    switch (scan.category?.id) {
      case 'hazardous':
        return 'e_waste_b3';
      case 'organic':
        return 'organik';
    }
    return _wordPool(scan);
  }

  static String? _wordPool(ScannedWaste scan) {
    final text = normalize('${scan.displayName} ${scan.material ?? ''}');
    for (final (word, pool) in _poolWords) {
      if (_has(text, word)) return pool;
    }
    return null;
  }

  /// This session's questions of [type], in serving order: the object's own,
  /// then its pool's (the object's pool when matched). Options are shuffled.
  /// Drafts are available only in debug; other statuses are never served.
  List<GeneratedQuestion> questionsFor(
    ScannedWaste scan,
    QuizQuestionType type, {
    Random? random,
    bool includeDrafts = kDebugMode,
  }) {
    final rng = random ?? Random();
    final chosen = selection(scan);
    final object = _objects.where((o) => o.name == chosen.object).firstOrNull;
    final kind = type == QuizQuestionType.multipleChoice ? 'mc' : 'essay';
    final items = [...?object?.items, ...?_pools[chosen.pool]].where(
      (i) =>
          i['type'] == kind &&
          (i['status'] == 'accepted' ||
              (kDebugMode && includeDrafts && i['status'] == 'draft')),
    );
    return [for (final i in items) _bilingual(i, type, rng)];
  }

  /// The item in the app language with its twin in the other one, shuffled
  /// with one permutation so the correct index is shared (decision 0185).
  GeneratedQuestion _bilingual(
    Map<String, dynamic> item,
    QuizQuestionType type,
    Random rng,
  ) {
    final en = _english[item['id']];
    final wantEnglish = AiQuizService.replyLang == 'en' && en != null;
    final mainItem = wantEnglish ? en : item;
    final altItem = wantEnglish ? item : en;
    final seed = rng.nextInt(1 << 31);
    final main = _toQuestion(
      mainItem,
      type,
      Random(seed),
      lang: wantEnglish ? 'en' : 'id',
    );
    if (altItem == null) return main;
    final twin = _toQuestion(
      altItem,
      type,
      Random(seed),
      lang: wantEnglish ? 'id' : 'en',
    );
    if (twin.options.length != main.options.length ||
        twin.correctIndex != main.correctIndex) {
      return main;
    }
    return GeneratedQuestion(
      type: main.type,
      question: main.question,
      options: main.options,
      correctIndex: main.correctIndex,
      explanation: main.explanation,
      bankId: main.bankId,
      bankReviewed: main.bankReviewed,
      quote: main.quote,
      sourceSection: main.sourceSection,
      sourcePage: main.sourcePage,
      wrongWhy: main.wrongWhy,
      lang: main.lang,
      alt: (
        lang: twin.lang,
        question: twin.question,
        options: twin.options,
        explanation: twin.explanation,
      ),
    );
  }

  static GeneratedQuestion _toQuestion(
    Map<String, dynamic> item,
    QuizQuestionType type,
    Random rng, {
    String lang = 'id',
  }) {
    if (type == QuizQuestionType.essay) {
      final rubric = [for (final p in item['rubricPoints'] as List) p as Map];
      final points = [for (final p in rubric) p['point'] as String];
      // Essays cite their rubric points' own quotes, sections and pages.
      String? joined(String key) {
        final values = {
          for (final p in rubric)
            if (p[key] != null) '${p[key]}',
        };
        return values.isEmpty ? null : values.join(', ');
      }

      final quotes = [
        for (final p in rubric)
          if (p['quote'] != null) p['quote'] as String,
      ];
      return GeneratedQuestion(
        type: type,
        question: item['question'] as String,
        explanation: points.join(' '),
        lang: lang,
        bankId: item['id'] as String,
        bankReviewed: item['status'] == 'accepted',
        quote: quotes.isEmpty ? null : quotes.join(' … '),
        sourceSection: joined('sourceChunk') ?? item['sourceChunk'] as String?,
        sourcePage: joined('pdfPage') ?? item['pdfPage']?.toString(),
      );
    }
    final correct = item['correct'] as String;
    final options = [correct, ...(item['wrong'] as List).cast<String>()]
      ..shuffle(rng);
    return GeneratedQuestion(
      type: type,
      lang: lang,
      question: item['question'] as String,
      options: options,
      correctIndex: options.indexOf(correct),
      explanation: item['explanation'] as String,
      bankId: item['id'] as String,
      bankReviewed: item['status'] == 'accepted',
      quote: item['quote'] as String?,
      sourceSection: item['sourceChunk'] as String?,
      sourcePage: item['pdfPage']?.toString(),
      // Optional, reviewed per wrong option (decision 0175); never written by the app.
      wrongWhy: {
        for (final e in ((item['wrongWhy'] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      },
    );
  }
}

class _BankObject {
  _BankObject(
    this.name,
    this.label,
    this.pool,
    this.synonyms,
    this.notIf,
    this.items,
  );

  factory _BankObject.fromJson(Map<String, dynamic> j) => _BankObject(
    j['object'] as String,
    j['label'] as String?,
    j['pool'] as String,
    [for (final s in j['synonyms'] as List) s as String],
    [for (final s in (j['notIf'] as List?) ?? const []) s as String],
    [for (final i in j['items'] as List) i as Map<String, dynamic>],
  );

  final String name;

  /// The detector class this object belongs to (null: none, e.g. lamps).
  final String? label;
  final String pool;
  final List<String> synonyms;
  final List<String> notIf;
  final List<Map<String, dynamic>> items;
}
