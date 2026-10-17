import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/scanned_waste.dart';

/// One module passage (decision 0014 chunk) sent to Gemma.
class ModuleChunk {
  const ModuleChunk({required this.id, required this.type, required this.subchapter,
      required this.pdfPage, required this.text, required this.words});

  factory ModuleChunk.fromJson(Map<String, dynamic> j) => ModuleChunk(
        id: j['id'] as String,
        type: j['type'] as String,
        subchapter: j['subchapter'] as String?,
        pdfPage: j['pdfPage'] as int,
        text: j['text'] as String,
        words: j['words'] as int,
      );

  final String id;
  final String type;
  final String? subchapter;
  final int pdfPage;
  final String text;
  final int words;
}

/// Picks 2-3 module passages for a quiz question about one scanned object
/// (decision 0016). Deterministic: no model, no network, no randomness.
class ModuleRetriever {
  ModuleRetriever(List<ModuleChunk> chunks, this._labelChunks, {Map<String, String>? excluded, this.maxWords = 450})
      : excludedChunkIds = excluded ?? defaultExcluded,
        _chunks = {for (final c in chunks) c.id: c},
        _order = [for (final c in chunks) c.id];

  factory ModuleRetriever.fromJson(String chunksJson, String labelsJson, {Map<String, String>? excluded, int maxWords = 450}) {
    final chunks = [
      for (final c in (jsonDecode(chunksJson) as Map<String, dynamic>)['chunks'] as List)
        ModuleChunk.fromJson(c as Map<String, dynamic>),
    ];
    final labels = (jsonDecode(labelsJson) as Map<String, dynamic>)['labels'] as Map<String, dynamic>;
    return ModuleRetriever(chunks, {
      for (final e in labels.entries) e.key: [for (final id in (e.value as Map)['chunks'] as List) id as String],
    }, excluded: excluded, maxWords: maxWords);
  }

  static Future<ModuleRetriever> load({int maxWords = 450}) async => ModuleRetriever.fromJson(
        await rootBundle.loadString('assets/module/module_chunks.json'),
        await rootBundle.loadString('assets/module/label_to_chunks.json'),
        maxWords: maxWords,
      );

  /// Topics the owner has not fixed in the module yet (M3.2 results), with the reason.
  static const defaultExcluded = <String, String>{
    '3.2': 'composting steps and maturing time disagree with 3.qa and 8.4',
    '3.5': 'composting time disagrees with 3.2',
    '3.summary': 'repeats the composting maturing time',
    '3.qa': 'composting step list disagrees with 3.2 and 8.4',
    '8.4': 'LKPD composting key disagrees with 3.2',
    '1.5': 'decomposition times (wood in "minggu hingga 6 bulan")',
    '1.qa': 'repeats the decomposition time',
    '6.6': 'superscripts lost in extraction (10^5 reads as 105)',
    '2.10': 'robot/app text',
    '7.1': 'robot-use text', '7.2': 'robot-use text', '7.3': 'describes manual two-zone sorting, not this app',
    '7.4': 'robot-use text', '7.5': 'robot-use text', '7.6': 'robot-use text', '7.qa': 'robot-use text',
  };

  /// Only these chunk types are ever sent; tables lose their rows in extraction.
  static const pickableTypes = {'text', 'summary', 'qa'};
  /// Passage budget in words (decision 0016: 450; the M3.4 latency gate measured 300 too).
  final int maxWords;


  /// Words that name the same object; any one in an item pulls in the whole group.
  static const synonymGroups = <List<String>>[
    ['ponsel', 'hp', 'handphone', 'telepon genggam', 'smartphone', 'gawai'],
    ['laptop', 'komputer', 'notebook'],
    ['baterai', 'aki', 'battery'],
    ['botol', 'gelas'],
    ['kaleng', 'kaleng aluminium'],
    ['kardus', 'karton', 'kertas karton'],
    ['kotak susu', 'kotak jus', 'karton minuman', 'kemasan karton minuman', 'tetra pak'],
    ['toples kaca', 'botol kaca', 'kaca'],
    ['kulit pisang', 'kulit buah'],
    ['sisa makanan', 'sisa nasi'],
  ];

  // Item/material words -> module class (label_to_chunks key), first match wins:
  // multi-word objects before the materials they are made of.
  static const _classWords = <(String, String)>[
    ('kotak susu', 'Tetra_Pak'), ('kotak jus', 'Tetra_Pak'), ('karton minuman', 'Tetra_Pak'), ('tetra pak', 'Tetra_Pak'),
    ('ponsel', 'E_Waste'), ('hp', 'E_Waste'), ('handphone', 'E_Waste'), ('telepon genggam', 'E_Waste'),
    ('smartphone', 'E_Waste'), ('laptop', 'E_Waste'), ('charger', 'E_Waste'), ('elektronik', 'E_Waste'),
    ('baterai', 'E_Waste'), ('aki', 'E_Waste'), ('kabel', 'E_Waste'),
    ('plastik', 'Plastic'), ('kresek', 'Plastic'), ('styrofoam', 'Plastic'), ('pet', 'Plastic'),
    ('kaca', 'Glass'), ('cermin', 'Glass'),
    ('kaleng', 'Metal'), ('aluminium', 'Metal'), ('logam', 'Metal'), ('besi', 'Metal'), ('baja', 'Metal'),
    ('kardus', 'Cardboard'), ('karton', 'Paperboard'), ('kertas', 'Paper'),
    ('kulit', 'Organic'), ('daun', 'Organic'), ('sisa makanan', 'Organic'), ('organik', 'Organic'),
  ];

  // Extra words each class's chunks are found by (weight below item words).
  static const _classTerms = <String, List<String>>{
    'E_Waste': ['elektronik', 'e-waste', 'baterai', 'b3'],
    'Plastic': ['plastik'], 'Glass': ['kaca'], 'Metal': ['logam', 'aluminium'],
    'Cardboard': ['kardus', 'karton', 'kertas'], 'Paperboard': ['karton', 'kertas'], 'Paper': ['kertas'],
    'Tetra_Pak': ['karton minuman', 'kemasan karton minuman'], 'Organic': ['organik', 'kompos'],
  };
  static const _stopWords = {'dan', 'atau', 'bahan', 'dengan', 'yang', 'dari', 'berlapis', 'campuran'};

  final Map<String, String> excludedChunkIds;
  final Map<String, ModuleChunk> _chunks;
  final List<String> _order;
  final Map<String, List<String>> _labelChunks;

  ModuleChunk? chunk(String id) => _chunks[id];

  static String normalize(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\- ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  // "gas rumah kaca" is not glass.
  static String _normalizeChunk(String s) => normalize(s).replaceAll(' rumah kaca ', ' rumah_kaca ');

  static bool _has(String normalizedText, String term) => normalizedText.contains(' ${normalize(term).trim()} ');

  /// The item's words plus every synonym group they touch. An item that is
  /// itself a group phrase ("kotak susu") uses the group only, so a loose word
  /// ("susu") does not pull in unrelated passages.
  static List<String> objectTerms(ScannedWaste waste) {
    final item = normalize(waste.displayName);
    final own = synonymGroups.where((g) => g.any((t) => normalize(t) == item)).toList();
    final terms = <String>{
      if (own.isEmpty) ...item.trim().split(' ').where((w) => w.length > 2 && !_stopWords.contains(w)),
      if (item.trim().isNotEmpty) item.trim(),
    };
    for (final group in own.isEmpty ? synonymGroups.where((g) => g.any((t) => _has(item, t))) : own) {
      terms.addAll(group);
    }
    return terms.toList()..sort();
  }

  static List<String> _materialTerms(ScannedWaste waste) => normalize(waste.material ?? '')
      .trim()
      .split(' ')
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toList();

  /// The module class this object belongs to, or null when nothing matches.
  String? moduleClass(ScannedWaste waste) {
    if (_labelChunks.containsKey(waste.rawLabel.trim()) && waste.rawLabel.trim() != 'Human_Hand') {
      return waste.rawLabel.trim();
    }
    for (final text in [normalize(waste.displayName), normalize(waste.material ?? '')]) {
      for (final (word, cls) in _classWords) {
        if (_has(text, word)) return cls;
      }
    }
    return switch (waste.category?.id) {
      'organic' => 'Organic',
      'hazardous' => 'E_Waste',
      _ => null,
    };
  }

  bool _pickable(String id) {
    final c = _chunks[id];
    return c != null && pickableTypes.contains(c.type) && !excludedChunkIds.containsKey(id);
  }

  bool _isB3(ScannedWaste waste) => waste.category?.id == 'hazardous' || moduleClass(waste) == 'E_Waste';

  /// Higher is better; 0 means not eligible. Eligible: in the class's base set
  /// or naming the object/class. Then item words (3 each), class words (2),
  /// material words (1, only boost), plain text over Q&A/summary. Bab 2 (B3)
  /// passages go only to B3 objects: its CFL steps mention "toples kaca" and
  /// "kertas karton", which would mislead a glass jar or cardboard question.
  int score(String id, ScannedWaste waste) {
    final c = _chunks[id]!;
    if (id.startsWith('2.') && !_isB3(waste)) return 0;
    final text = _normalizeChunk(c.text);
    final cls = moduleClass(waste);
    final base = cls != null && (_labelChunks[cls] ?? const []).contains(id);
    var hits = 0;
    for (final t in objectTerms(waste)) {
      if (_has(text, t)) hits += 3;
    }
    for (final t in _classTerms[cls] ?? const <String>[]) {
      if (_has(text, t)) hits += 2;
    }
    if (!base && hits == 0) return 0;
    var s = (base ? 6 : 0) + hits;
    for (final t in _materialTerms(waste)) {
      if (_has(text, t)) s += 1;
    }
    if (c.type == 'text') s += 1;
    return s;
  }

  /// The longest verbatim prefix of [c] that ends a sentence within [budget] words.
  static ModuleChunk _cut(ModuleChunk c, int budget) {
    if (c.words <= budget) return c;
    var end = 0;
    for (final m in RegExp(r'[.?!](?=\s)').allMatches(c.text)) {
      if (c.text.substring(0, m.end).split(RegExp(r'\s+')).length > budget) break;
      end = m.end;
    }
    if (end == 0) return c;
    final text = c.text.substring(0, end);
    return ModuleChunk(id: c.id, type: c.type, subchapter: c.subchapter, pdfPage: c.pdfPage,
        text: text, words: text.split(RegExp(r'\s+')).length);
  }

  /// 2-3 passages for question [questionIndex] (0-based): up to 2 topic chunks,
  /// then the category-definition chunk, cut at a sentence end so the total
  /// stays within [maxWords]. Chunks in [usedChunkIds] (cited by earlier
  /// questions this session) are skipped unless nothing else is left.
  List<ModuleChunk> retrieve(ScannedWaste waste, {int questionIndex = 0, Iterable<String> usedChunkIds = const []}) {
    final used = usedChunkIds.toSet();
    final definition = _chunks[definitionChunkId(waste)]!;
    final scores = {for (final id in _order) id: _pickable(id) && id != definition.id ? score(id, waste) : 0};
    final ranked = [for (final id in _order) if (scores[id]! > 0) id]
      ..sort((a, b) {
        final byScore = scores[b]!.compareTo(scores[a]!);
        return byScore != 0 ? byScore : _order.indexOf(a).compareTo(_order.indexOf(b));
      });
    var fresh = ranked.where((id) => !used.contains(id)).toList();
    if (fresh.isEmpty) fresh = ranked; // nothing new left: reuse rather than send no topic
    // With no history (an earlier question fell back), still vary by index among the top few.
    if (used.isEmpty && questionIndex > 0 && fresh.length > 1) {
      final top = fresh.take(3).toList();
      final start = questionIndex % top.length;
      fresh = [...top.sublist(start), ...top.sublist(0, start), ...fresh.skip(3)];
    }

    final topics = <ModuleChunk>[];
    var words = 0;
    for (final id in fresh) {
      final c = _chunks[id]!;
      if (words + c.words > maxWords - minDefinitionWords) continue;
      topics.add(c);
      words += c.words;
      if (topics.length == 2) break;
    }
    return [...topics, _cut(definition, maxWords - words)];
  }

  /// The definition chunk keeps at least this many words when cut.
  static const minDefinitionWords = 80;

  /// The category-definition chunk, always sent so every question has grounding.
  /// Paper, cardboard and drink cartons are defined in 1.3 (with its sorting
  /// note); 1.6 (three groups) is a table chunk, so B3 uses 2.1's prose definition.
  String definitionChunkId(ScannedWaste waste) {
    if (waste.category?.id == 'hazardous') return '2.1';
    return switch (moduleClass(waste)) {
      'Organic' || 'Paper' || 'Paperboard' || 'Cardboard' || 'Tetra_Pak' => '1.3',
      'E_Waste' => '2.1',
      'Plastic' || 'Glass' || 'Metal' => '1.4',
      _ => waste.category?.id == 'organic' ? '1.3' : '1.4',
    };
  }
}
