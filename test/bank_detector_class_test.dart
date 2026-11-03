// Decision 0025: in a live scan the detector class decides the bank pool;
// Gemma's words pick an object only inside that class.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:flutter_test/flutter_test.dart';

final _bank = QuestionBank.fromJson(File('assets/quiz/object_bank_draft.json').readAsStringSync(),
    File('assets/quiz/question_bank_draft.json').readAsStringSync());

/// Bank ids of one label pool's items.
Set<String> _poolIds(String pool) => {
      for (final i in (jsonDecode(File('assets/quiz/question_bank_draft.json').readAsStringSync())['items'] as List))
        if (i['pool'] == pool) i['id'] as String,
    };

/// A live-scan scan, built as _identifyThenQuiz builds it.
ScannedWaste _live(String item, {String? material, String? category, String? detector}) =>
    ScannedWaste.fromLabel(item,
        material: material,
        categoryHint: category,
        detectorLabel: detector,
        hazardousEvidence: detector != null && ScannedWaste.fromLabel(detector).category?.id == 'hazardous');

void main() {
  test('every bank object names its detector class (0025 serves an object only on its class)', () {
    final objects = (jsonDecode(File('assets/quiz/object_bank_draft.json').readAsStringSync())['objects'] as List)
        .cast<Map<String, dynamic>>();
    for (final o in objects) {
      expect(ScannedWaste.detectorLabels.containsKey(o['label']) && o['label'] != 'Human_Hand', isTrue,
          reason: '${o['object']} has label ${o['label']}');
    }
  });

  test('detector E_Waste + Gemma "lampu neon": the lamp object again (T1b)', () {
    expect(_bank.selection(_live('lampu neon', detector: 'E_Waste')), (object: 'lampu_tl_cfl', pool: 'e_waste_b3'));
  });

  test('24 Oct: detector Plastic + Gemma "Label" (kertas): plastic pool, class mismatch noted', () {
    final scan = _live('Label', material: 'kertas', category: 'anorganik', detector: 'Plastic');
    expect(scan.rawLabel, 'Label', reason: "rawLabel stays Gemma's text");
    expect(_bank.selection(scan), (object: null, pool: 'plastic'));
    expect(_bank.classMismatch(scan), 'paper_family');
    final served = _bank.questionsFor(scan, QuizQuestionType.multipleChoice, random: Random(1));
    expect(served, isNotEmpty);
    expect(served.map((q) => q.bankId).toSet().difference(_poolIds('plastic')), isEmpty, reason: 'only plastic questions');
  });

  test('detector Plastic + Gemma "botol plastik": the plastic bottle object', () {
    final scan = _live('botol plastik', material: 'plastik', category: 'anorganik', detector: 'Plastic');
    expect(_bank.selection(scan), (object: 'botol_plastik', pool: 'plastic'));
    expect(_bank.classMismatch(scan), isNull);
  });

  test('detector Paper + Gemma matched to a plastic object: paper pool, not the plastic object', () {
    final scan = _live('botol plastik', material: 'plastik', category: 'anorganik', detector: 'Paper');
    expect(_bank.selection(scan), (object: null, pool: 'paper_family'));
    expect(_bank.classMismatch(scan), 'plastic');
    final ids = _bank.questionsFor(scan, QuizQuestionType.multipleChoice).map((q) => q.bankId).toSet();
    expect(ids.difference(_poolIds('paper_family')), isEmpty);
  });

  test('a class inside the same label pool is no mismatch (Paperboard box, Gemma "kardus")', () {
    final scan = _live('kardus', material: 'kertas', category: 'anorganik', detector: 'Paperboard');
    expect(_bank.selection(scan), (object: null, pool: 'paper_family'), reason: "kardus' label is Cardboard");
    expect(_bank.classMismatch(scan), isNull);
  });

  test('no detector class (phone camera, manual scan): unchanged', () {
    // The rule before 0025: the matched object and its pool, else poolFor.
    ({String? object, String? pool}) before(ScannedWaste s) {
      final o = _bank.matchObject(s);
      if (o != null) return (object: o, pool: _bank.selection(s).pool);
      return (object: null, pool: _bank.poolFor(s));
    }

    for (final scan in [
      _live('Label', material: 'kertas', category: 'anorganik'),
      _live('botol plastik', material: 'plastik'),
      _live('kulit pisang', category: 'organik'),
      _live('baterai', material: 'logam'),
      _live('limbah cair', category: 'residu'),
      ScannedWaste.fromLabel('Cardboard'),
      ScannedWaste.fromLabel('Glass'),
    ]) {
      expect(_bank.selection(scan), before(scan), reason: scan.displayName);
      expect(_bank.classMismatch(scan), isNull);
    }
    expect(_bank.selection(_live('Label', material: 'kertas', category: 'anorganik')).pool, 'paper_family');
    expect(_bank.selection(ScannedWaste.fromLabel('Glass')).pool, 'glass');
  });

  group('B3 rules unchanged', () {
    test('detector E_Waste + Gemma "Tiruan": the e_waste_b3 pool', () {
      final scan = _live('Tiruan', category: 'anorganik', detector: 'E_Waste');
      expect(scan.category?.id, 'hazardous');
      expect(_bank.selection(scan), (object: null, pool: 'e_waste_b3'));
    });

    test('detector E_Waste + Gemma "ponsel": the phone object', () {
      expect(_bank.selection(_live('ponsel', detector: 'E_Waste')), (object: 'ponsel', pool: 'e_waste_b3'));
    });

    test('a hazardous Gemma item on a Plastic box stays B3 (the detector class is not its bin)', () {
      final scan = _live('baterai', material: 'logam', category: 'B3', detector: 'Plastic');
      expect(_bank.selection(scan), (object: 'baterai', pool: 'e_waste_b3'));
      expect(_bank.classMismatch(scan), isNull);
    });

    test('a phone on a Plastic box: hazardous keywords win, the B3 object (unchanged)', () {
      final scan = _live('ponsel', material: 'plastik', category: 'anorganik', detector: 'Plastic');
      expect(scan.category?.id, 'hazardous');
      expect(_bank.selection(scan), (object: 'ponsel', pool: 'e_waste_b3'));
    });

    test('a non-B3 scan never gets the B3 pool or a B3 object', () {
      for (final det in ['Plastic', 'Paper', 'Metal', 'Glass', 'Cardboard', 'Tetra_Pak', 'Organic']) {
        final scan = _live('Label', category: det == 'Organic' ? 'organik' : 'anorganik', detector: det);
        expect(scan.category?.id, isNot('hazardous'));
        expect(_bank.selection(scan).pool, isNot('e_waste_b3'), reason: det);
      }
    });
  });

  test('mismatch card, user picked Gemma\'s bin: the detector class no longer decides', () {
    final scan = _live('kulit pisang', category: 'organik', detector: 'Plastic');
    expect(scan.category?.id, 'organic');
    expect(_bank.selection(scan), (object: 'kulit_pisang', pool: 'organik'));
  });

  test('Gemma mode: the detector class rides next to the category hint', () {
    String prompt(String? detector) => GemmaQuizService.questionPrompt(
        waste: _live('Label', material: 'kertas', category: 'anorganik', detector: detector),
        type: QuizQuestionType.multipleChoice,
        difficulty: QuizDifficulty.easy,
        angleText: 'massa');
    expect(prompt('Plastic'), contains('kategori: '));
    expect(prompt('Plastic'), contains('menurut detektor kamera: Plastik'));
    expect(prompt(null), isNot(contains('detektor')));
  });
}
