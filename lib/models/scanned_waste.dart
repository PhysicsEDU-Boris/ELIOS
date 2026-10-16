import 'waste_category.dart';

/// A waste item reported by the camera (MaixCAM2 label or debug phone scan),
/// normalized into the context Gemma needs to write relevant questions.
class ScannedWaste {
  final String rawLabel;
  final String displayName;

  /// Resolved destination compartment, not the raw model classification.
  final WasteCategory? category;
  final String? rawCategory;

  /// Main material, when known (photo scans report it).
  final String? material;

  const ScannedWaste._(
    this.rawLabel,
    this.displayName,
    this.category, [
    this.material,
    this.rawCategory,
  ]);

  /// All ten MaixCAM2 classes; the hand is deliberately not waste.
  static const detectorLabels = <String, (String, String?)>{
    'Cardboard': ('Kardus', 'inorganic'),
    'E_Waste': ('Sampah elektronik', 'hazardous'),
    'Glass': ('Kaca', 'inorganic'),
    'Human_Hand': ('Tangan', null),
    'Metal': ('Logam', 'inorganic'),
    'Organic': ('Sampah organik', 'organic'),
    'Paper': ('Kertas', 'inorganic'),
    'Paperboard': ('Karton', 'inorganic'),
    'Plastic': ('Plastik', 'inorganic'),
    'Tetra_Pak': ('Karton minuman berlapis', 'inorganic'),
  };

  // Keyword → category id. Labels arrive in Indonesian or English, often
  // hyphenated (e.g. "botol-plastik"), so match on normalized words.
  static const _keywords = <String, List<String>>{
    'hazardous': [
      'baterai', 'battery', 'aki', 'b3', 'lampu', 'bulb', 'elektronik',
      'ponsel', 'hp', 'handphone', 'smartphone', 'phone', 'laptop', 'charger', 'gadget',
      'electronic', 'e-waste', 'kabel', 'cable', 'cat', 'paint', 'obat',
      'medicine', 'pestisida', 'pesticide', 'oli', 'kimia', 'chemical',
      'termometer', 'jarum', 'needle',
    ],
    'organic': [
      'organik', 'organic', 'daun', 'leaf', 'leaves', 'makanan', 'food',
      'kulit', 'peel', 'pisang', 'banana', 'sayur', 'vegetable', 'buah',
      'fruit', 'kompos', 'compost', 'ranting', 'twig', 'tulang', 'bone',
      'cangkang', 'eggshell', 'telur', 'ampas', 'kopi', 'coffee', 'teh', 'tea',
    ],
    'inorganic': [
      'anorganik', 'inorganic', 'plastik', 'plastic', 'botol', 'bottle',
      'kaleng', 'can', 'kaca', 'glass', 'kertas', 'paper', 'kardus',
      'cardboard', 'logam', 'metal', 'styrofoam', 'sedotan', 'straw',
      'kantong', 'bag', 'gelas', 'cup', 'aluminium', 'aluminum', 'karet',
      'rubber', 'kemasan', 'wrapper', 'tutup', 'cap',
    ],
  };

  static const _categoryNamesId = {
    'organic': 'sampah organik',
    'inorganic': 'sampah anorganik (dapat didaur ulang)',
    'hazardous': 'limbah B3 (berbahaya)',
  };

  /// [categoryHint] is Gemma's own classification of a photo ("organik",
  /// "anorganik", "B3", "residu"); it wins over the keyword lookup.
  factory ScannedWaste.fromLabel(
    String label, {
    String? material,
    String? categoryHint,
    bool hazardousEvidence = false,
  }) {
    final hinted = switch (categoryHint?.toLowerCase().trim()) {
      'organik' => 'organic',
      'anorganik' => 'inorganic',
      'residu' => 'inorganic',
      'b3' => 'hazardous',
      _ => null,
    };
    final base = ScannedWaste._fromKeywords(label);
    // Hazardous keywords (batteries, phones, e-waste) beat the model's guess:
    // a phone must go to B3 even if Gemma calls it "anorganik".
    final hazard =
        hazardousEvidence ||
        hinted == 'hazardous' ||
        base.category?.id == 'hazardous';
    final destination = hazard ? 'hazardous' : hinted;
    final category = destination == null
        ? base.category
        : wasteCategories.where((c) => c.id == destination).firstOrNull;
    return ScannedWaste._(
      label,
      base.displayName,
      category,
      material,
      categoryHint,
    );
  }

  factory ScannedWaste._fromKeywords(String label) {
    final detector = detectorLabels[label.trim()];
    if (detector != null) {
      return ScannedWaste._(label, detector.$1,
          wasteCategories.where((c) => c.id == detector.$2).firstOrNull);
    }
    final words = label
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-./]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final display = words.isEmpty
        ? 'Benda tidak dikenal'
        : '${words[0].toUpperCase()}${words.substring(1)}';
    final tokens = words.split(' ').toSet();

    WasteCategory? match;
    // Hazardous first: "baterai plastik" must not be treated as recyclable.
    for (final id in const ['hazardous', 'organic', 'inorganic']) {
      if (_keywords[id]!.any((k) => k.contains(' ') ? words.contains(k) : tokens.contains(k))) {
        match = wasteCategories.where((c) => c.id == id).firstOrNull;
        break;
      }
    }
    return ScannedWaste._(label, display, match);
  }

  String get categoryNameId =>
      rawCategory?.trim().toLowerCase() == 'residu' &&
          category?.id == 'inorganic'
      ? 'sampah residu (kompartemen anorganik; bukan jaminan dapat didaur ulang)'
      : _categoryNamesId[category?.id] ?? 'tidak diketahui';
}
