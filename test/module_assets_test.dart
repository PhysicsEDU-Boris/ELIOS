// Module chunk assets (decision 0014): the label map agrees with the
// detector bins in ScannedWaste and only points at chunks that exist.
import 'dart:convert';
import 'dart:io';

import 'package:elio/models/scanned_waste.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final chunks = (_json('assets/module/module_chunks.json')['chunks'] as List).cast<Map<String, dynamic>>();
  final labels = (_json('assets/module/label_to_chunks.json')['labels'] as Map).cast<String, Map<String, dynamic>>();

  test('every detector class has a label entry with the same bin as ScannedWaste', () {
    expect(labels.keys.toSet(), ScannedWaste.detectorLabels.keys.toSet());
    for (final label in ScannedWaste.detectorLabels.keys) {
      expect(labels[label]!['bin'], ScannedWaste.detectorCategory(label), reason: label);
    }
    expect(labels['Human_Hand']!['sendToGemma'], isFalse);
  });

  test('label chunks exist and every chunk has its trace fields', () {
    final ids = {for (final c in chunks) c['id'] as String};
    expect(ids, hasLength(chunks.length), reason: 'duplicate chunk id');
    for (final entry in labels.entries) {
      expect(ids, containsAll((entry.value['chunks'] as List).cast<String>()), reason: entry.key);
    }
    for (final c in chunks) {
      expect(c['pdfPage'], isA<int>(), reason: c['id']);
      expect(['text', 'qa', 'table', 'summary', 'lkpd_key', 'sources'], contains(c['type']), reason: c['id']);
      expect((c['text'] as String).split(RegExp(r'\s+')).length, lessThanOrEqualTo(700), reason: c['id']);
    }
  });
}
