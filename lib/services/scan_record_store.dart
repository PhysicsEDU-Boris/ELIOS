import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/scan_record.dart';
import '../models/trophy_rules.dart';
import 'gemma_quiz_service.dart';

/// Local storage service for [ScanRecord] items and cumulative trophies.
/// Data is persisted as a JSON file in the application documents directory.
class ScanRecordStore extends ChangeNotifier {
  ScanRecordStore({File? customFile}) : _customFile = customFile;

  static ScanRecordStore? _instance;
  static ScanRecordStore get instance {
    if (_instance == null) {
      _instance = ScanRecordStore();
      unawaited(_instance!.load());
    }
    return _instance!;
  }

  @visibleForTesting
  static void setInstanceForTesting(ScanRecordStore? store) {
    _instance = store;
  }

  final File? _customFile;
  List<ScanRecord> _records = [];
  bool _loaded = false;
  Future<List<ScanRecord>>? _loadFuture;
  Future<void>? _pendingOperation;

  Future<T> _synchronized<T>(Future<T> Function() operation) async {
    while (_pendingOperation != null) {
      try {
        await _pendingOperation;
      } catch (_) {}
    }
    final completer = Completer<void>();
    _pendingOperation = completer.future;
    try {
      return await operation();
    } finally {
      completer.complete();
      if (_pendingOperation == completer.future) {
        _pendingOperation = null;
      }
    }
  }

  List<ScanRecord> get records {
    if (!_loaded && _loadFuture == null) {
      unawaited(load());
    }
    return List.unmodifiable(_records);
  }

  bool get isLoaded => _loaded;

  int get totalTrophies {
    if (!_loaded && _loadFuture == null) {
      unawaited(load());
    }
    return _records.fold<int>(0, (sum, r) => sum + r.trophies);
  }

  StudentLevel get userLevel => StudentLevel.forTotal(totalTrophies);
  double get levelProgress => userLevel.progress(totalTrophies);

  Future<File> _getFile() async {
    if (_customFile != null) return _customFile;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/scan_records.json');
  }

  /// Loads records from disk. If the file does not exist, starts empty.
  Future<List<ScanRecord>> load({bool force = false}) {
    if (!force && _loaded && _loadFuture == null) {
      return Future.value(_records);
    }
    if (_loadFuture != null) {
      return _loadFuture!;
    }
    _loadFuture = _synchronized(() async {
      try {
        return await _doLoad();
      } finally {
        _loadFuture = null;
      }
    });
    return _loadFuture!;
  }

  Future<List<ScanRecord>> _doLoad() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) {
        _records = [];
        _loaded = true;
        notifyListeners();
        return _records;
      }
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) {
        _records = [];
      } else {
        final decoded = jsonDecode(content) as List<dynamic>;
        _records = decoded
            .map((item) => ScanRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ScanRecordStore] Load failed: $e');
      _records = [];
    } finally {
      _loaded = true;
    }
    notifyListeners();
    return _records;
  }

  /// Persists current records to disk.
  Future<void> save() {
    return _synchronized(() => _doSave());
  }

  Future<void> _doSave() async {
    try {
      final file = await _getFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final jsonString = jsonEncode(_records.map((r) => r.toJson()).toList());
      file.writeAsStringSync(jsonString, flush: true);
    } catch (e) {
      debugPrint('[ScanRecordStore] Save failed: $e');
    }
  }

  /// Inserts a new record at the top of the list and saves.
  /// Fully synchronized to guarantee overlapping writes never race or drop records.
  Future<void> addRecord(ScanRecord record) {
    return _synchronized(() async {
      if (!_loaded) {
        await _doLoad();
      }
      _records.insert(0, record);
      notifyListeners();
      await _doSave();
    });
  }

  /// Clears all stored records.
  Future<void> clearRecords() {
    return _synchronized(() async {
      if (!_loaded) {
        await _doLoad();
      }
      _records.clear();
      notifyListeners();
      await _doSave();
    });
  }

  /// Populates store with the sample records from Figma node 100:170 (for debug mode).
  Future<void> seedFigmaSampleRecords() async {
    final now = DateTime.now();
    final samples = [
      ScanRecord(
        id: 'sample-phone',
        time: now.subtract(const Duration(minutes: 15)),
        itemName: 'Phone',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.hard,
        questions: const [
          RecordQuestion(
            question: 'Which waste category does a used phone belong to?',
            yourAnswer: 'B3 (Hazardous waste)',
            rightAnswer: 'B3 (Hazardous waste)',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Why must a phone never be thrown in general waste?',
            yourAnswer: 'It is too heavy for the bin',
            rightAnswer: 'Its battery and circuits leak toxic metals',
            isCorrect: false,
            trophies: 0,
          ),
          RecordQuestion(
            question: 'Where should you take an old phone?',
            yourAnswer: 'E-waste drop-off point',
            rightAnswer: 'E-waste drop-off point',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 20,
      ),
      ScanRecord(
        id: 'sample-bottle',
        time: now.subtract(const Duration(hours: 2)),
        itemName: 'Plastic Bottle',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.medium,
        questions: const [
          RecordQuestion(
            question: 'What should you do before recycling a plastic bottle?',
            yourAnswer: 'Rinse and flatten it',
            rightAnswer: 'Rinse and flatten it',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Which recycling code commonly applies to beverage bottles?',
            yourAnswer: 'PET 1',
            rightAnswer: 'PET 1',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 20,
      ),
      ScanRecord(
        id: 'sample-battery',
        time: now.subtract(const Duration(hours: 5)),
        itemName: 'Battery',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.medium,
        questions: const [
          RecordQuestion(
            question: 'Which compartment accepts household batteries?',
            yourAnswer: 'B3 Hazardous',
            rightAnswer: 'B3 Hazardous',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'What risk do damaged lithium batteries pose?',
            yourAnswer: 'They turn into fertilizer',
            rightAnswer: 'They can cause chemical fire or toxic leaks',
            isCorrect: false,
            trophies: 0,
          ),
        ],
        trophies: 10,
      ),
      ScanRecord(
        id: 'sample-peel',
        time: now.subtract(const Duration(days: 1)),
        itemName: 'Banana Peel',
        category: ScanCategory.organic,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Which bin is appropriate for fruit peels?',
            yourAnswer: 'Plastic bin',
            rightAnswer: 'Organic waste bin',
            isCorrect: false,
            trophies: 0,
          ),
        ],
        trophies: 0,
      ),
    ];

    _records = samples;
    notifyListeners();
    await save();
  }
}
