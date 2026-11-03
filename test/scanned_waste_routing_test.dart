import 'package:elio/models/scanned_waste.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final item in ['kulit pisang', 'kertas', 'benda misterius']) {
    test('residu routes $item to inorganic, preserving raw category', () {
      final scan = ScannedWaste.fromLabel(item, categoryHint: ' ReSiDu ');
      expect(scan.category?.id, 'inorganic');
      expect(scan.rawCategory, ' ReSiDu ');
      expect(scan.categoryNameId, contains('bukan jaminan dapat didaur ulang'));
    });
  }

  test('hazardous keywords and detector evidence veto residu routing', () {
    for (final scan in [
      ScannedWaste.fromLabel('baterai', categoryHint: 'residu'),
      ScannedWaste.fromLabel('E_Waste', categoryHint: 'residu'),
      ScannedWaste.fromLabel(
        'kulit pisang',
        categoryHint: 'residu',
        hazardousEvidence: true,
      ),
    ]) {
      expect(scan.category?.id, 'hazardous');
      expect(scan.rawCategory, 'residu');
      expect(scan.categoryNameId, 'limbah B3 (berbahaya)');
    }
  });

  test('other hints, hazard veto and label-only behavior stay intact', () {
    for (final (label, hint, destination) in [
      ('kertas', 'organik', 'organic'),
      ('kulit pisang', 'anorganik', 'inorganic'),
      ('benda misterius', 'B3', 'hazardous'),
      ('baterai', 'organik', 'hazardous'),
      ('kulit pisang', null, 'organic'),
      ('kertas', 'unknown', 'inorganic'),
      ('benda misterius', null, null),
    ]) {
      final scan = ScannedWaste.fromLabel(label, categoryHint: hint);
      expect(scan.category?.id, destination);
      expect(scan.rawCategory, hint);
    }
  });
}
