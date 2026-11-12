import 'history_cloud.dart';
import 'frame_source/viewfinder_crop.dart' show downscaleJpeg;
import '../models/quiz_explanation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/home_stats.dart' show questBonus;
import '../models/record_translation.dart';
import '../models/scan_record.dart';
import '../models/trophy_rules.dart';
import 'ai_quiz_service.dart';

/// `--dart-define=SCAN_RECORDS_FILE=scan_records_r3test.json`: a phone test build
/// keeps its records in a separate file, so the owner's `scan_records.json` is never written.
const _recordsFileName = String.fromEnvironment(
  'SCAN_RECORDS_FILE',
  defaultValue: 'scan_records.json',
);

/// History photos go next to their records: `scans/` normally, `scans_<file>/` in a test build.
const scanPhotosDirName = _recordsFileName == 'scan_records.json'
    ? 'scans'
    : 'scans_$_recordsFileName';

/// Local storage service for [ScanRecord] items and cumulative trophies.
/// Data is persisted as a JSON file in the application documents directory.
class ScanRecordStore extends ChangeNotifier {
  ScanRecordStore({File? customFile, this.ownerId, this.cloud})
    : _customFile = customFile;

  final String? ownerId;
  final HistoryCloud? cloud;
  bool active = true;
  bool syncing = false;
  Object? syncError;
  DateTime? lastSynced;
  Map<String, dynamic>? _cursor;
  final Set<String> _dirty = {};
  final Set<String> _uploadedPhotos = {};
  int get pendingCount => _dirty.length;

  static void selectAccount(String? uid, {HistoryCloud? cloud}) {
    _instance?.active = false;
    _instance = ScanRecordStore(ownerId: uid ?? 'signed-out', cloud: cloud);
  }

  Future<Directory> photoDirectory() async {
    final file = await _getFile();
    return Directory('${file.parent.path}/$scanPhotosDirName')
      ..createSync(recursive: true);
  }

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
  Object? loadError;
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
    // Daily quest rewards (decision 0144) and Daily Guide XP (0204) count too.
    return _records.fold<int>(0, (sum, r) => sum + r.trophies) +
        questBonus(_records) +
        _guideXp;
  }

  /// Daily Guide XP of the signed-in account, pushed from guide progress (0204).
  int get guideXp => _guideXp;
  int _guideXp = 0;
  set guideXp(int xp) {
    if (xp == _guideXp) return;
    _guideXp = xp;
    notifyListeners();
  }

  StudentLevel get userLevel => StudentLevel.forTotal(totalTrophies);
  double get levelProgress => userLevel.progress(totalTrophies);

  Future<File> _getFile() async {
    if (_customFile != null) return _customFile;
    final dir = await getApplicationDocumentsDirectory();
    final scope = ownerId == null
        ? ''
        : '/accounts/${base64Url.encode(utf8.encode(ownerId!)).replaceAll('=', '')}';
    return File('${dir.path}$scope/$_recordsFileName');
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
    loadError = null;
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
        final decoded = jsonDecode(content);
        final items = decoded is List ? decoded : decoded['records'] as List;
        _dirty.clear();
        _uploadedPhotos.clear();
        if (decoded is Map) {
          _cursor = decoded['cursor'] == null
              ? null
              : Map<String, dynamic>.from(decoded['cursor'] as Map);
          _dirty.addAll((decoded['pending'] as List? ?? []).cast<String>());
          _uploadedPhotos.addAll(
            (decoded['photos'] as List? ?? []).cast<String>(),
          );
        }
        _records = items
            .map((item) => ScanRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ScanRecordStore] Load failed: $e');
      loadError = e;
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

  Future<void> _doSave({bool propagateError = false}) async {
    try {
      final file = await _getFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      if (loadError != null) throw StateError('History could not be loaded');
      final records = _records.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(
        ownerId == null
            ? records
            : {
                'records': records,
                'pending': _dirty.toList(),
                'cursor': _cursor,
                'photos': _uploadedPhotos.toList(),
              },
      );
      final temporary = File('${file.path}.tmp');
      temporary.writeAsStringSync(jsonString, flush: true);
      temporary.renameSync(file.path);
    } catch (e) {
      debugPrint('[ScanRecordStore] Save failed: $e');
      if (propagateError) rethrow;
    }
  }

  /// Inserts a new record at the top of the list and saves.
  /// Fully synchronized to guarantee overlapping writes never race or drop records.
  Future<void> addRecord(ScanRecord record) {
    return _synchronized(() async {
      if (!_loaded) {
        await _doLoad();
      }
      if (loadError != null) throw StateError('History could not be loaded');
      if (_records.any((r) => r.id == record.id)) return;
      _records.insert(0, record);
      _dirty.add(record.id);
      try {
        await _doSave(propagateError: true);
      } catch (_) {
        _records.removeWhere((r) => r.id == record.id);
        _dirty.remove(record.id);
        rethrow;
      }
      notifyListeners();
      unawaited(sync());
    });
  }

  Future<void> saveExplanation(
    String recordId,
    int questionIndex,
    QuizExplanation explanation,
  ) {
    return _synchronized(() async {
      if (!_loaded) await _doLoad();
      if (loadError != null) throw StateError('History could not be loaded');
      final i = _records.indexWhere((r) => r.id == recordId);
      if (i < 0) {
        return; // The owner may have deleted the record while AI was running.
      }
      final record = _records[i];
      if (questionIndex < 0 || questionIndex >= record.questions.length) return;
      final questions = [...record.questions];
      questions[questionIndex] = questions[questionIndex].copyWith(
        explanation: explanation,
      );
      _records[i] = record.copyWith(questions: questions);
      _dirty.add(recordId);
      try {
        await _doSave(propagateError: true);
      } catch (_) {
        _records[i] = record;
        rethrow;
      }
      notifyListeners();
      unawaited(sync());
    });
  }

  /// Caches [translation] of record [recordId] in [lang] (decision 0185).
  Future<void> saveTranslation(
    String recordId,
    String lang,
    RecordTranslation translation,
  ) {
    return _synchronized(() async {
      if (!_loaded) await _doLoad();
      if (loadError != null) throw StateError('History could not be loaded');
      final i = _records.indexWhere((r) => r.id == recordId);
      if (i < 0) return;
      final record = _records[i];
      _dirty.add(recordId);
      _records[i] = record.copyWith(
        translations: {...record.translations, lang: translation},
      );
      try {
        await _doSave(propagateError: true);
      } catch (_) {
        _records[i] = record;
        rethrow;
      }
      notifyListeners();
      unawaited(sync());
    });
  }

  /// Clears all stored records.
  Future<void> clearRecords() {
    if (cloud != null) {
      throw StateError('Cloud history cannot be cleared locally');
    }
    return _synchronized(() async {
      if (!_loaded) {
        await _doLoad();
      }
      _records.clear();
      notifyListeners();
      await _doSave();
    });
  }

  Future<bool> hasLegacyHistory() async {
    if (ownerId == null || ownerId == 'signed-out') return false;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_recordsFileName').existsSync();
  }

  /// Only called after the student explicitly claims the unowned device history.
  Future<void> importLegacyHistory() async {
    if (ownerId == null || ownerId == 'signed-out') return;
    final dir = await getApplicationDocumentsDirectory();
    final legacy = ScanRecordStore(
      customFile: File('${dir.path}/$_recordsFileName'),
    );
    await legacy.load();
    if (legacy.loadError != null) {
      throw StateError('Previous history could not be loaded');
    }
    for (final record in legacy.records) {
      var imported = record;
      final path = record.cropPhotoPath;
      if (path != null && File(path).existsSync()) {
        final photos = await photoDirectory();
        final name = base64Url
            .encode(utf8.encode(record.id))
            .replaceAll('=', '');
        final target = File('${photos.path}/legacy-$name.jpg');
        if (!target.existsSync()) await File(path).copy(target.path);
        imported = record.copyWith(cropPhotoPath: target.path);
      }
      await addRecord(imported);
    }
  }

  /// Save locally first. Retry on launch, resume, or the next periodic sync.
  Future<void> sync() async {
    if (cloud == null || !active || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await load();
      if (loadError != null) throw StateError('History could not be loaded');
      final pending = await _synchronized(
        () async => [
          for (final r in _records)
            if (_dirty.contains(r.id)) r,
        ],
      );
      for (final record in pending) {
        if (!active) return;
        try {
          final data = record.toJson()..remove('cropPhotoPath');
          await cloud!.call({'op': 'save', 'id': record.id, 'data': data});
          final path = record.cropPhotoPath;
          if (path != null && !_uploadedPhotos.contains(record.id)) {
            final photo = File(path);
            if (!photo.existsSync()) {
              throw StateError('Scan photo missing locally');
            }
            final jpeg = await downscaleJpeg(
              await photo.readAsBytes(),
              maxSide: 1280,
            );
            await cloud!.call({
              'op': 'uploadPhoto',
              'id': record.id,
              'image': base64Encode(jpeg),
            });
            _uploadedPhotos.add(record.id);
          }
          await _synchronized(() async {
            final current = _records
                .where((r) => r.id == record.id)
                .firstOrNull;
            if (current != null &&
                jsonEncode(current.toJson()) == jsonEncode(record.toJson())) {
              _dirty.remove(record.id);
            }
            await _doSave(propagateError: true);
          });
        } catch (e) {
          syncError = e;
        }
      }
      while (active) {
        final page = await cloud!.call({'op': 'list', 'cursor': _cursor});
        final rows = page['records'] as List;
        for (final raw in rows) {
          if (!active) return;
          final data = Map<String, dynamic>.from(raw['data'] as Map)
            ..remove('cropPhotoPath');
          final id = data['id'] as String;
          if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
            throw const FormatException('Invalid scan ID');
          }
          final existing = _records.where((r) => r.id == id).firstOrNull;
          String? photoPath = existing?.cropPhotoPath;
          try {
            if (raw['has_photo'] == true) {
              final dir = await photoDirectory();
              final file = File('${dir.path}/$id.jpg');
              if (photoPath == null || !File(photoPath).existsSync()) {
                if (!file.existsSync()) {
                  final response = await cloud!.call({'op': 'photo', 'id': id});
                  final bytes = base64Decode(response['image'] as String);
                  final temporary = File('${file.path}.tmp');
                  await temporary.writeAsBytes(bytes, flush: true);
                  await temporary.rename(file.path);
                }
                photoPath = file.path;
              }
            }
          } catch (e) {
            syncError = e;
          }
          await _synchronized(() async {
            if (_dirty.contains(id)) {
              return; // A local edit made while downloading wins until uploaded.
            }
            final record = ScanRecord.fromJson({
              ...data,
              'cropPhotoPath': ?photoPath,
            });
            final i = _records.indexWhere((r) => r.id == id);
            if (i < 0) {
              _records.add(record);
            } else {
              _records[i] = record;
            }
            if (raw['has_photo'] == true) _uploadedPhotos.add(id);
          });
        }
        if (syncError == null &&
            rows.isNotEmpty &&
            rows.last['updated_at'] != null) {
          await _synchronized(() async {
            _cursor = {
              'time': rows.last['updated_at'],
              'id': rows.last['data']['id'],
            };
            await _doSave(propagateError: true);
          });
        } else if (syncError != null) {
          break; // Retry missing photos before advancing the durable cursor.
        }
        if (rows.length < 100) break;
      }
      await _synchronized(() async {
        _records.sort((a, b) => b.time.compareTo(a.time));
        await _doSave(propagateError: true);
      });
      if (syncError == null) lastSynced = DateTime.now();
    } catch (e) {
      syncError = e;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Populates store with the sample records from Figma node 100:170 (for debug mode).
  Future<void> seedFigmaSampleRecords() async {
    if (!kDebugMode || const bool.fromEnvironment('TESTER_BUILD')) return;
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
            question:
                'Which recycling code commonly applies to beverage bottles?',
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

    await _synchronized(() async {
      if (!_loaded) await _doLoad();
      for (final sample in samples) {
        if (!_records.any((record) => record.id == sample.id)) {
          _records.add(sample);
        }
      }
      notifyListeners();
      await _doSave();
    });
  }
}
