import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../models/scanned_waste.dart';

enum GemmaStatus { idle, installing, loading, ready, error }

enum QuizQuestionType { multipleChoice, essay }

@immutable
class GemmaProgress {
  final GemmaStatus status;
  final int installPercent;
  final String? error;
  const GemmaProgress(this.status, {this.installPercent = 0, this.error});
}

/// A question produced by Gemma (or the offline fallback bank).
@immutable
class GeneratedQuestion {
  final QuizQuestionType type;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const GeneratedQuestion({
    required this.type,
    required this.question,
    this.options = const [],
    this.correctIndex = -1,
    this.explanation = '',
  });
}

/// Quiz difficulty from Config Settings → Quiz → Difficulty. All levels are
/// university level; they differ in depth and in how many questions a scan
/// session has.
enum QuizDifficulty {
  easy(1, 'tingkat mahasiswa S1 tahun pertama: menguji pemahaman konsep inti '
      '(jenis dan sifat material, cara pengolahannya), bukan hafalan sederhana.'),
  medium(3, 'tingkat mahasiswa S1 menengah: menguji penerapan dan analisis, '
      'misalnya proses daur ulang, sifat kimia material, atau hubungan sebab-akibat dampak lingkungan.'),
  hard(5, 'tingkat mahasiswa S1 akhir: menguji analisis mendalam, misalnya life-cycle '
      'assessment, kimia polimer atau logam, efisiensi energi daur ulang, kebijakan, atau perhitungan sederhana.');

  const QuizDifficulty(this.questionCount, this.levelDescription);

  final int questionCount;
  final String levelDescription;

  /// Maps the settings value ('Easy' / 'Medium' / 'Hard').
  static QuizDifficulty fromSetting(String value) => switch (value.toLowerCase()) {
        'easy' => easy,
        'hard' => hard,
        _ => medium,
      };
}

/// Result of asking Gemma what object is in a photo.
@immutable
class PhotoIdentification {
  final String? item;
  final String? material;
  final String? category;
  final String? failure;

  const PhotoIdentification({required this.item, this.material, this.category}) : failure = null;
  const PhotoIdentification.failed(this.failure)
      : item = null,
        material = null,
        category = null;
}

/// Fully on-device Gemma 4 E2B inference (flutter_gemma + LiteRT-LM) for the
/// scan-triggered quiz. The model ships inside the APK as a Flutter asset;
/// nothing here touches the network.
///
/// Every public method returns `null` instead of throwing, so a device that
/// can't run the model degrades to the fallback question bank rather than
/// breaking the popup.
class GemmaQuizService {
  GemmaQuizService._();
  static final instance = GemmaQuizService._();

  static const modelFileName = 'gemma-4-E2B-it.litertlm';
  static const _assetPath = 'assets/models/$modelFileName';
  static const _tag = '[GemmaQuizService]';

  // Generation on a phone CPU can take tens of seconds; installation and
  // loading are deliberately NOT timed out (first launch copies ~2.4GB).
  static const _generationTimeout = Duration(seconds: 120);

  static const _systemInstruction =
      'You are ELIO, an offline teaching assistant on a waste-sorting robot '
      'used by Indonesian university students. Always write in Bahasa '
      'Indonesia. Follow the requested output format exactly: when a request '
      'asks for JSON, reply with only that JSON object; otherwise reply in '
      'plain sentences with no JSON, no code blocks and no markdown.';

  // University-level angles; one is picked at random per question.
  static const _angles = [
    'komposisi material serta sifat kimia atau fisikanya',
    'proses daur ulang atau pengolahan industrinya',
    'dampak lingkungannya beserta mekanisme penyebabnya',
    'siklus hidup produk dari produksi sampai pembuangan (life-cycle)',
    'kebijakan dan sistem pengelolaan sampahnya',
    'risiko kesehatan dan keselamatannya',
    'ekonomi sirkular dan nilai material yang bisa dipulihkan',
  ];

  final ValueNotifier<GemmaProgress> progress =
      ValueNotifier(const GemmaProgress(GemmaStatus.idle));
  final _random = Random();

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _loadedWithVision = false;
  bool _prepared = false;
  Future<bool>? _prepareFuture;
  Future<bool>? _readyFuture;

  bool _activeIsUser = false;
  Completer<String?>? _activeCompleter;
  Completer<String?>? _pendingCompleter;
  Future<String?> Function()? _pendingTask;

  @visibleForTesting
  Future<String?> Function(String prompt, {Uint8List? imageBytes, bool fresh, bool isUser, void Function(String)? onToken})? mockSendExecute;

  bool get isReady => _chat != null;
  bool get isPrepared => _prepared;

  void _log(String msg) => debugPrint('$_tag $msg');

  /// One-time copy of the bundled model out of the APK into app storage
  /// (the engine can't read files inside the APK). No network involved.
  /// Started at app launch so it never competes with the robot video stream;
  /// after the first successful run it returns almost immediately.
  Future<bool> prepare() {
    if (_prepared) return Future.value(true);
    return _prepareFuture ??= _install().whenComplete(() => _prepareFuture = null);
  }

  Future<bool> _install() async {
    final sw = Stopwatch()..start();
    try {
      if (_chat == null) progress.value = const GemmaProgress(GemmaStatus.installing);
      final bundled = _bundledModelPath();
      if (bundled != null) {
        // macOS/iOS: the model is already a plain file inside the app bundle,
        // so register it in place — no copy, ready in about a second. Drop
        // any record left by an earlier copy-based install so the plugin
        // can't keep loading a stale (possibly half-copied) duplicate.
        for (final id in await FlutterGemma.listInstalledModels()) {
          if (id.contains('gemma-4-E2B-it')) {
            try {
              await FlutterGemma.uninstallModel(id);
            } catch (e) {
              _log('could not remove old record $id: $e');
            }
          }
        }
        await FlutterGemma.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        ).fromFile(bundled).install();
      } else {
        // Android: the engine can't read inside the APK, so copy once. The
        // plugin's "with progress" copy posts a UI event per kilobyte
        // (~2.5 million for this model), which froze the app; use the plain
        // copy and poll the copied file's size for progress instead.
        final poller = _pollCopyProgress();
        try {
          await FlutterGemma.installModel(
            modelType: ModelType.gemma4,
            fileType: ModelFileType.litertlm,
          ).fromAsset(_assetPath).install();
        } finally {
          poller.cancel();
        }
      }
      _prepared = true;
      if (_chat == null) progress.value = const GemmaProgress(GemmaStatus.idle);
      _log('model prepared (${bundled != null ? 'in place' : 'copied'}, ${sw.elapsed.inSeconds}s)');
      return true;
    } catch (e) {
      _log('prepare failed: $e');
      progress.value = GemmaProgress(GemmaStatus.error, error: _friendlyError(e));
      return false;
    }
  }

  /// Path of the model inside the app bundle on Apple platforms, or null.
  String? _bundledModelPath() {
    if (kIsWeb || !(Platform.isMacOS || Platform.isIOS)) return null;
    final exe = File(Platform.resolvedExecutable);
    final candidate = Platform.isMacOS
        // ELIOS.app/Contents/MacOS/ELIOS → Contents/Frameworks/App.framework/...
        ? '${exe.parent.parent.path}/Frameworks/App.framework/Resources/flutter_assets/$_assetPath'
        // Runner.app/Runner → Runner.app/Frameworks/App.framework/flutter_assets/...
        : '${exe.parent.path}/Frameworks/App.framework/flutter_assets/$_assetPath';
    return File(candidate).existsSync() ? candidate : null;
  }

  static const _modelBytes = 2588147712;

  Timer _pollCopyProgress() {
    var last = -1;
    return Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        var size = 0;
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.contains('gemma-4-E2B-it')) {
            size = max(size, await entity.length());
          }
        }
        final percent = (size * 100 ~/ _modelBytes).clamp(0, 99);
        if (percent != last && _chat == null) {
          last = percent;
          progress.value = GemmaProgress(GemmaStatus.installing, installPercent: percent);
        }
      } catch (_) {
        // Progress is cosmetic; the copy itself is unaffected.
      }
    });
  }

  String _friendlyError(Object e) {
    final text = '$e'.toLowerCase();
    if (text.contains('space') || text.contains('enospc') || text.contains('no space')) {
      return 'Ruang penyimpanan tidak cukup (butuh ±2,6 GB kosong).';
    }
    if (text.contains('memory') || text.contains('oom') || text.contains('alloc')) {
      return 'Memori (RAM) perangkat tidak cukup untuk menjalankan AI.';
    }
    return 'AI gagal dimuat: $e';
  }

  /// Single-flight load. [vision] loads the image encoder too — only the
  /// device-camera scan needs it; the MaixCAM2 flow sends text only, which
  /// keeps memory use (and the risk of being killed on a phone) much lower.
  /// Switching to vision when a text-only model is loaded triggers a reload.
  Future<bool> ensureReady({bool vision = false}) async {
    if (_chat != null && (_loadedWithVision || !vision)) return true;
    final pending = _readyFuture;
    if (pending != null) {
      await pending;
      if (_chat != null && (_loadedWithVision || !vision)) return true;
    }
    if (_chat != null) await _closeModel();
    return _readyFuture ??= _initialize(vision).whenComplete(() => _readyFuture = null);
  }

  /// Prepares and loads in the background so the first quiz is fast.
  void warmUp({bool vision = false}) => unawaited(ensureReady(vision: vision));

  Future<bool> _initialize(bool vision) async {
    final sw = Stopwatch()..start();
    try {
      if (!await prepare()) return false;

      progress.value = const GemmaProgress(GemmaStatus.loading);
      final attempts = [
        (PreferredBackend.gpu, vision),
        (PreferredBackend.cpu, vision),
        if (vision) (PreferredBackend.cpu, false),
      ];
      Object? lastError;
      for (final (backend, image) in attempts) {
        try {
          final model = await FlutterGemma.getActiveModel(
            maxTokens: 1024,
            preferredBackend: backend,
            supportImage: image,
            maxNumImages: image ? 1 : null,
          );
          try {
            _chat = await model.createChat(
              systemInstruction: _systemInstruction,
              maxOutputTokens: 400,
              temperature: 0.9,
              topK: 40,
              topP: 0.95,
              randomSeed: _random.nextInt(1 << 30),
              supportImage: image,
            );
          } catch (e) {
            await model.close();
            rethrow;
          }
          _model = model;
          _loadedWithVision = image;
          _log('model ready on ${model.activeBackend ?? backend} '
              '(image=$image) in ${sw.elapsed.inSeconds}s');
          progress.value = const GemmaProgress(GemmaStatus.ready);
          return true;
        } catch (e) {
          lastError = e;
          _log('load failed on $backend (image=$image): $e');
        }
      }
      throw lastError ?? StateError('model failed to load');
    } catch (e) {
      _log('initialize failed: $e');
      progress.value = GemmaProgress(GemmaStatus.error, error: '$e');
      return false;
    }
  }

  Future<String?> _executeSend(String prompt, {Uint8List? imageBytes, bool fresh = false, bool isUser = false, void Function(String)? onToken}) async {
    _activeIsUser = isUser;
    final completer = Completer<String?>();
    _activeCompleter = completer;

    Future<void> run() async {
      try {
        if (mockSendExecute != null) {
           final res = await mockSendExecute!(prompt, imageBytes: imageBytes, fresh: fresh, isUser: isUser, onToken: onToken);
           if (!completer.isCompleted) completer.complete(res);
           return;
        }
        if (!await ensureReady(vision: imageBytes != null)) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final chat = _chat;
        if (chat == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        if (imageBytes != null && !_loadedWithVision) {
          _log('photo request but the image encoder is not available');
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        if (fresh) await chat.clearHistory();
        final sw = Stopwatch()..start();
        await chat.addQueryChunk(imageBytes == null
            ? Message.text(text: prompt, isUser: true)
            : Message.withImage(text: prompt, imageBytes: imageBytes, isUser: true));
            
        final stream = chat.generateChatResponseAsync();
        String fullText = '';
        int? firstTokenMs;
        
        stream.listen((response) {
           final token = switch (response) {
             TextResponse(:final token) => token,
             _ => response.toString(),
           };
           firstTokenMs ??= sw.elapsedMilliseconds;
           fullText += token;
           onToken?.call(token);
        }, onError: (e) {
           if (!completer.isCompleted) completer.completeError(e);
        }, onDone: () {
           final total = sw.elapsedMilliseconds;
           _log('generated ${fullText.length} chars (first token: ${firstTokenMs ?? 0}ms, total: ${total}ms)');
           if (!completer.isCompleted) completer.complete(fullText.isEmpty ? null : fullText.trim());
        });
      } catch (e) {
        _log('generation failed: $e');
        if (!completer.isCompleted) completer.complete(null);
      }
    }
    
    run();
    
    try {
      return await completer.future.timeout(_generationTimeout);
    } catch (e) {
      if (e is TimeoutException) {
        _log('generation timeout');
        try { _chat?.stopGeneration(); } catch (_) {}
      }
      return null;
    } finally {
      if (_activeCompleter == completer) {
        _activeCompleter = null;
        if (_pendingCompleter != null) {
           final nextTask = _pendingTask;
           final nextCompleter = _pendingCompleter;
           _pendingCompleter = null;
           _pendingTask = null;
           nextTask!().then((v) => nextCompleter!.complete(v)).catchError((e) => nextCompleter!.completeError(e));
        }
      }
    }
  }

  Future<String?> _send(String prompt, {Uint8List? imageBytes, bool fresh = false, bool isUser = false, void Function(String)? onToken}) async {
    if (_activeCompleter != null) {
      if (!isUser) {
        _log('slot busy, rejecting scan request');
        return 'BUSY';
      }
      
      if (!_activeIsUser) {
        _log('canceling active scan request to yield to user request');
        try { _chat?.stopGeneration(); } catch (_) {}
        if (!_activeCompleter!.isCompleted) {
           _activeCompleter!.complete(null);
        }
      }
      
      _pendingCompleter?.complete(null);
      final completer = Completer<String?>();
      _pendingCompleter = completer;
      _pendingTask = () => _executeSend(prompt, imageBytes: imageBytes, fresh: fresh, isUser: true, onToken: onToken);
      
      try {
        return await completer.future;
      } catch (e) {
        return null;
      }
    }
    
    return _executeSend(prompt, imageBytes: imageBytes, fresh: fresh, isUser: isUser, onToken: onToken);
  }

  void cancel() {
    _pendingCompleter?.complete(null);
    _pendingCompleter = null;
    _pendingTask = null;
    if (_activeCompleter != null) {
      _log('canceling active request');
      try { _chat?.stopGeneration(); } catch (_) {}
      if (!_activeCompleter!.isCompleted) {
        _activeCompleter!.complete(null);
      }
    }
  }

  /// Step 1 of a photo scan: name the object, with nothing else in the
  /// prompt to bias it. Loads the image encoder if needed.
  Future<PhotoIdentification> identifyItem(Uint8List imageBytes) async {
    const prompt =
        'Lihat foto ini dan sebutkan benda utama di dalamnya secara spesifik, '
        'misalnya "ponsel", "kardus", "kaleng aluminium", "botol plastik PET", '
        '"kulit pisang", "baterai", atau "kertas". Jika foto tidak jelas, tulis "tidak jelas". '
        'Balas HANYA JSON: {"item": "nama benda singkat", "material": "bahan utama", '
        '"category": "organik" atau "anorganik" atau "B3" atau "residu"}.';
    final raw = await _send(prompt, imageBytes: imageBytes, fresh: true, isUser: false);
    if (raw == 'BUSY') return const PhotoIdentification.failed('busy');
    if (raw == null) {
      return PhotoIdentification.failed(_chat != null && !_loadedWithVision
          ? 'AI di perangkat ini tidak bisa membaca foto (model gambar gagal dimuat). '
              'Pakai "Uji tanpa kamera" atau mode MaixCAM2.'
          : 'AI belum siap untuk membaca foto. Coba lagi sebentar lagi.');
    }
    final map = _jsonObject(raw);
    final item = (map?['item'] as String?)?.trim() ?? '';
    if (item.isEmpty || item.toLowerCase().contains('tidak jelas')) {
      return const PhotoIdentification.failed(
        'Benda di foto belum dikenali. Dekatkan kamera, pastikan terang, lalu scan lagi.',
      );
    }
    _log('photo identified as "$item"');
    return PhotoIdentification(
      item: item,
      material: (map?['material'] as String?)?.trim(),
      category: (map?['category'] as String?)?.trim(),
    );
  }

  /// One university-level question about the scanned item (text only).
  Future<GeneratedQuestion?> generateQuestion({
    required ScannedWaste waste,
    required QuizQuestionType type,
    required QuizDifficulty difficulty,
    List<String> avoid = const [],
  }) async {
    final angle = _angles[_random.nextInt(_angles.length)];
    final details = [
      if (waste.material != null && waste.material!.isNotEmpty) 'bahan: ${waste.material}',
      if (waste.category != null) 'kategori: ${waste.categoryNameId}',
    ].join(', ');
    final context = 'Sampah yang discan: "${waste.displayName}"${details.isEmpty ? '' : ' ($details)'}.';
    final avoidText = avoid.isEmpty
        ? ''
        : ' Jangan mengulang soal ini: ${avoid.map((q) => '"$q"').join('; ')}.';
    final shape = type == QuizQuestionType.multipleChoice
        ? 'Buat SATU soal pilihan ganda ${difficulty.levelDescription} Topik: $angle dari benda tersebut. '
            'Soal harus menguji pemahaman atau analisis, bukan sekadar menebak tempat sampah. '
            'Beri 4 pilihan singkat (maks 10 kata) yang semuanya masuk akal, hanya satu yang benar. '
            'Balas HANYA JSON: {"question": "...", "options": ["...", "...", "...", "..."], '
            '"correctIndex": 0, "explanation": "penjelasan 1-2 kalimat"}.'
        : 'Buat SATU soal essay ${difficulty.levelDescription} Topik: $angle dari benda tersebut. '
            'Soal meminta mahasiswa menjelaskan atau menganalisis dengan kata-katanya sendiri (maks 2 kalimat). '
            'Balas HANYA JSON: {"question": "...", "explanation": "poin-poin jawaban yang diharapkan"}.';
    final prompt = '$context $shape$avoidText';

    for (var attempt = 0; attempt < 2; attempt++) {
      final raw = await _send(prompt, fresh: true, isUser: false);
      if (raw == 'BUSY') return null;
      if (raw == null) return null;
      final parsed = _parse(raw, type);
      if (parsed != null) return parsed;
      _log('unparseable question (attempt ${attempt + 1}): $raw');
    }
    return null;
  }

  /// Answers a student's follow-up after they answered: each turn carries
  /// the question, the key and their answer, so replies stay on topic.
  Future<String?> discuss({
    required String quizContext,
    required List<({bool isUser, String text})> history,
    required String message,
  }) async {
    final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
    final transcript = recent.map((m) => '${m.isUser ? 'Mahasiswa' : 'ELIO'}: ${m.text}').join('\n');
    final prompt = '$quizContext\n'
        '${transcript.isEmpty ? '' : 'Percakapan sebelumnya:\n$transcript\n'}'
        'Pertanyaan mahasiswa sekarang: "$message"\n'
        'Jawab dalam Bahasa Indonesia dengan 2-5 kalimat teks biasa. Jangan pakai JSON, kode, atau markdown.';
    final raw = await _send(prompt, fresh: true, isUser: true);
    return raw == null || raw == 'BUSY' ? null : toPlainText(raw);
  }

  /// Grades an essay answer against the question and its expected points.
  Future<String?> reviewEssay({
    required String question,
    required String expectedPoints,
    required String answer,
  }) async {
    final prompt = 'Soal essay: "$question"\n'
        '${expectedPoints.isEmpty ? '' : 'Poin jawaban yang diharapkan: $expectedPoints\n'}'
        'Jawaban mahasiswa: "$answer"\n'
        'Mulai dengan "Benar", "Sebagian benar", atau "Kurang tepat", lalu jelaskan koreksinya '
        'dalam 2-4 kalimat teks biasa. Jangan pakai JSON, kode, atau markdown.';
    final raw = await _send(prompt, fresh: true, isUser: true);
    return raw == null || raw == 'BUSY' ? null : toPlainText(raw);
  }

  /// Turns a reply that came back as JSON or markdown into readable text.
  @visibleForTesting
  static String toPlainText(String raw) {
    var text = raw.trim().replaceAll(RegExp(r'^```[a-zA-Z]*\s*|\s*```$'), '').trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        final parts = <String>[];
        void walk(Object? v) {
          if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
          if (v is Map) v.values.forEach(walk);
          if (v is List) v.forEach(walk);
        }
        walk(jsonDecode(text));
        if (parts.isNotEmpty) text = parts.join(' ');
      } catch (_) {
        text = text.replaceAll(RegExp(r'[{}\[\]]'), '').replaceAll(RegExp(r'"\w+"\s*:\s*'), '').replaceAll('"', '');
      }
    }
    return text.replaceAll('**', '').replaceAll(RegExp(r'^#+\s*', multiLine: true), '').trim();
  }

  Map<String, dynamic>? _jsonObject(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  GeneratedQuestion? _parse(String raw, QuizQuestionType type) {
    final map = _jsonObject(raw);
    if (map == null) return null;
    final question = (map['question'] as String?)?.trim() ?? '';
    if (question.isEmpty) return null;
    final explanation = toPlainText('${map['explanation'] ?? ''}');
    if (type == QuizQuestionType.essay) {
      return GeneratedQuestion(type: type, question: question, explanation: explanation);
    }
    final options = (map['options'] as List?)?.map((o) => '$o'.trim()).toList();
    final correct = (map['correctIndex'] as num?)?.toInt();
    if (options == null || options.length != 4 || options.any((o) => o.isEmpty)) return null;
    if (correct == null || correct < 0 || correct > 3) return null;
    // Small models tend to put the right answer in the same slot; shuffle.
    final order = [0, 1, 2, 3]..shuffle(_random);
    return GeneratedQuestion(
      type: type,
      question: question,
      options: [for (final i in order) options[i]],
      correctIndex: order.indexOf(correct),
      explanation: explanation,
    );
  }

  Future<void> _closeModel() async {
    final model = _model;
    _model = null;
    _chat = null;
    _loadedWithVision = false;
    await model?.close();
  }

  /// Frees the model's memory (the prepared file stays on disk). Waits for
  /// any in-flight load or generation.
  Future<void> dispose() async {
    cancel();
    try {
      await _readyFuture;
    } catch (_) {}
    await _closeModel();
    progress.value = GemmaProgress(_prepared ? GemmaStatus.idle : progress.value.status);
  }
}
