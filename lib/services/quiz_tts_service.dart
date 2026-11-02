import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsStatus { idle, speaking, error }

/// Voice playback for the AI Correction Assistant's messages — same
/// approach as the ELIO-SANDBOX prototype's `TtsService`, using the
/// device's own TTS engine (no model download, so it's always available
/// even if the Gemma model isn't installed yet).
class QuizTtsService {
  QuizTtsService._() {
    _tts.setStartHandler(() => status.value = TtsStatus.speaking);
    _tts.setCompletionHandler(() => status.value = TtsStatus.idle);
    _tts.setCancelHandler(() => status.value = TtsStatus.idle);
    _tts.setErrorHandler((_) => status.value = TtsStatus.error);
  }
  static final instance = QuizTtsService._();

  // Gemma replies in whichever language the student used — this heuristic
  // only needs to tell apart the two languages this quiz actually uses.
  static const _indonesianMarkers = {
    'yang', 'dan', 'atau', 'adalah', 'ini', 'itu', 'tidak', 'dengan', 'untuk',
    'dari', 'pada', 'akan', 'dapat', 'karena', 'sehingga', 'juga', 'dalam',
    'oleh', 'sebagai', 'harus', 'bisa', 'tersebut', 'seperti', 'saya', 'kamu',
    'kita', 'mereka', 'jika', 'maka', 'agar', 'sangat', 'lebih', 'hanya',
    'sudah', 'belum', 'masih', 'bahwa', 'secara', 'menjadi', 'sampah',
    'daur', 'ulang', 'lingkungan', 'jawaban', 'benar',
  };

  static const _englishMarkers = {
    'the', 'and', 'is', 'are', 'this', 'that', 'with', 'for', 'of', 'to',
    'your', 'you', 'answer', 'correct', 'because', 'which', 'what',
  };

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<TtsStatus> status = ValueNotifier(TtsStatus.idle);
  bool _configured = false;
  String? _currentLanguage;
  List<Map<String, String>>? _voices;

  /// The app's content is Indonesian, so Indonesian is the default; English
  /// is used only for text that is clearly English.
  @visibleForTesting
  static String detectLanguage(String text) {
    final words = RegExp(r"[a-zA-Z']+").allMatches(text.toLowerCase()).map((m) => m[0]!).toList();
    final id = words.where(_indonesianMarkers.contains).length;
    final en = words.where(_englishMarkers.contains).length;
    return en >= 2 && en > id ? 'en-US' : 'id-ID';
  }

  /// Emoji and markup are read out literally by some engines; drop them.
  @visibleForTesting
  static String speakableText(String text) => text
      .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
      .replaceAll(RegExp(r'[*_#`{}\[\]"]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// `setLanguage` alone doesn't switch the voice on every platform (macOS
  /// kept the English default even with "Damayanti" installed), so pick an
  /// installed voice for the locale explicitly, then also set the language.
  Future<void> _useLanguage(String language) async {
    try {
      _voices ??= [
        for (final v in (await _tts.getVoices as List? ?? const []))
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
      ];
      final prefix = language.split('-').first.toLowerCase();
      final voice = _voices!.firstWhere(
        (v) => (v['locale'] ?? '').toLowerCase().replaceAll('_', '-').startsWith(prefix),
        orElse: () => const {},
      );
      if (voice['name'] != null && voice['locale'] != null) {
        await _tts.setVoice({'name': voice['name']!, 'locale': voice['locale']!});
      }
    } catch (e) {
      debugPrint('[QuizTtsService] voice selection failed: $e');
    }
    await _tts.setLanguage(language);
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _configured = true;
    } catch (e) {
      debugPrint('[QuizTtsService] Configure failed: $e');
    }
  }

  /// Utterances started (passed the empty-text check below), so a silent
  /// recording's debug overlay can still show that TTS ran.
  int get startedCount => _started;
  int _started = 0;

  /// Replaces the real engine in tests: called instead of `_tts.speak`, with
  /// the real `await stop()` (one slot) still enforced first.
  @visibleForTesting
  Future<void> Function(String text)? mockSpeak;

  /// Config → Settings → Master volume (0..1), set at each quiz start.
  double volume = 1.0;

  /// Speaks [text]. Always stops whatever was playing first (one slot: the
  /// new utterance replaces the old one). Never throws — a missing/broken
  /// TTS engine on a device just means voice playback silently does nothing.
  Future<void> speak(String text) async {
    final trimmed = speakableText(text);
    if (trimmed.isEmpty) return;
    _started++;
    try {
      await stop();
      if (mockSpeak != null) {
        await mockSpeak!(trimmed);
        return;
      }
      await _ensureConfigured();
      await _tts.setVolume(volume);
      final language = detectLanguage(trimmed);
      if (language != _currentLanguage) {
        await _useLanguage(language);
        _currentLanguage = language;
      }
      await _tts.speak(trimmed);
    } catch (e) {
      debugPrint('[QuizTtsService] speak failed: $e');
      status.value = TtsStatus.error;
    }
  }

  /// Replaces the real engine in tests, same as [mockSpeak].
  @visibleForTesting
  Future<void> Function()? mockStop;

  Future<void> stop() async {
    if (mockStop != null) {
      await mockStop!();
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore — nothing to stop.
    }
  }
}
