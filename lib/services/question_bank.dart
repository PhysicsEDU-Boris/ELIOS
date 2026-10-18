import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../models/scanned_waste.dart';
import 'gemma_quiz_service.dart';

/// Pre-written, module-grounded questions (decision 0017): first the scanned
/// object's own questions, then its label pool's (decision 0015). No model.
class QuestionBank {
  QuestionBank._(this._objects, this._pools, this._labelPools);

  factory QuestionBank.fromJson(String objectBankJson, String poolBankJson) {
    final objects = [
      for (final o in (jsonDecode(objectBankJson) as Map<String, dynamic>)['objects'] as List)
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

  /// Loaded once from the bundled assets.
  static Future<QuestionBank> load() => _loading ??= () async {
        return QuestionBank.fromJson(
          await rootBundle.loadString('assets/quiz/object_bank_draft.json'),
          await rootBundle.loadString('assets/quiz/question_bank_draft.json'),
        );
      }();

  final List<_BankObject> _objects;
  final Map<String, List<Map<String, dynamic>>> _pools;
  final Map<String, String> _labelPools;

  static String normalize(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static bool _has(String normalized, String phrase) => normalized.contains(normalize(phrase));

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
      if ((o.pool == 'e_waste_b3') != hazardous && scan.category != null) continue;
      for (final syn in o.synonyms) {
        final words = normalize(syn).trim().split(' ').length;
        final score = _has(item, syn) ? 100 + words : (withMaterial.any((c) => _has(c, syn)) ? words : 0);
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
    ('karton minuman', 'tetra_pak'), ('kotak susu', 'tetra_pak'),
    ('plastik', 'plastic'), ('kaca', 'glass'),
    ('kaleng', 'metal'), ('aluminium', 'metal'), ('logam', 'metal'), ('besi', 'metal'), ('baja', 'metal'),
    ('kardus', 'paper_family'), ('karton', 'paper_family'), ('kertas', 'paper_family'),
  ];

  /// The label pool: the detector class when known, else the bin, else item/material words.
  String? poolFor(ScannedWaste scan) {
    final label = _labelPools[scan.rawLabel.trim()];
    if (label != null) return label;
    switch (scan.category?.id) {
      case 'hazardous':
        return 'e_waste_b3';
      case 'organic':
        return 'organik';
    }
    final text = normalize('${scan.displayName} ${scan.material ?? ''}');
    for (final (word, pool) in _poolWords) {
      if (_has(text, word)) return pool;
    }
    return null;
  }

  /// This session's questions of [type], in serving order: the object's own,
  /// then its pool's (the object's pool when matched). Options are shuffled.
  List<GeneratedQuestion> questionsFor(ScannedWaste scan, QuizQuestionType type, {Random? random}) {
    final rng = random ?? Random();
    final object = _match(scan);
    final pool = object?.pool ?? poolFor(scan);
    final kind = type == QuizQuestionType.multipleChoice ? 'mc' : 'essay';
    final items = [
      ...?object?.items,
      ...?_pools[pool],
    ].where((i) => i['type'] == kind);
    return [for (final i in items) _toQuestion(i, type, rng)];
  }

  static GeneratedQuestion _toQuestion(Map<String, dynamic> item, QuizQuestionType type, Random rng) {
    if (type == QuizQuestionType.essay) {
      final points = [for (final p in item['rubricPoints'] as List) (p as Map)['point'] as String];
      return GeneratedQuestion(type: type, question: item['question'] as String, explanation: points.join(' '),
          bankId: item['id'] as String);
    }
    final correct = item['correct'] as String;
    final options = [correct, ...(item['wrong'] as List).cast<String>()]..shuffle(rng);
    return GeneratedQuestion(
      type: type,
      question: item['question'] as String,
      options: options,
      correctIndex: options.indexOf(correct),
      explanation: item['explanation'] as String,
      bankId: item['id'] as String,
    );
  }
}

class _BankObject {
  _BankObject(this.name, this.pool, this.synonyms, this.notIf, this.items);

  factory _BankObject.fromJson(Map<String, dynamic> j) => _BankObject(
        j['object'] as String,
        j['pool'] as String,
        [for (final s in j['synonyms'] as List) s as String],
        [for (final s in (j['notIf'] as List?) ?? const []) s as String],
        [for (final i in j['items'] as List) i as Map<String, dynamic>],
      );

  final String name;
  final String pool;
  final List<String> synonyms;
  final List<String> notIf;
  final List<Map<String, dynamic>> items;
}
