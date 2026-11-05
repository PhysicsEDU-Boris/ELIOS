import 'package:elio/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsStatus { idle, speaking, error }

/// Voice playback for the AI Correction Assistant's messages — same
/// approach as the ELIO-SANDBOX prototype's `TtsService`, using the
/// device's own TTS engine (no model download, so it's always available
/// even when the AI is offline).
class QuizTtsService {
  QuizTtsService._() {
    _tts.setStartHandler(() => status.value = TtsStatus.speaking);
    _tts.setCompletionHandler(() => status.value = TtsStatus.idle);
    _tts.setCancelHandler(() => status.value = TtsStatus.idle);
    _tts.setErrorHandler((_) => status.value = TtsStatus.error);
  }
  static final instance = QuizTtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<TtsStatus> status = ValueNotifier(TtsStatus.idle);
  bool _configured = false;
  String? _currentLanguage;
  List<Map<String, String>>? _voices;

  /// The voice for text in [lang] ('en'/'id'); null = the app language
  /// (decision 0185: the voice follows the selected language).
  static String voiceFor([String? lang]) =>
      (lang ?? l10n.localeName) == 'en' ? 'en-US' : 'id-ID';

  /// Emoji and markup are read out literally by some engines; drop them.
  @visibleForTesting
  static String speakableText(String text) => text
      .replaceAll(
        RegExp(
          r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
          unicode: true,
        ),
        '',
      )
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
        (v) => (v['locale'] ?? '')
            .toLowerCase()
            .replaceAll('_', '-')
            .startsWith(prefix),
        orElse: () => const {},
      );
      if (voice['name'] != null && voice['locale'] != null) {
        await _tts.setVoice({
          'name': voice['name']!,
          'locale': voice['locale']!,
        });
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
  int _epoch = 0;

  /// Replaces the real engine in tests: called instead of `_tts.speak`, with
  /// the real `await stop()` (one slot) still enforced first.
  @visibleForTesting
  Future<void> Function(String text)? mockSpeak;

  /// Config → Settings → Master volume (0..1), set at each quiz start.
  double volume = 1.0;

  /// Speaks [text]. Always stops whatever was playing first (one slot: the
  /// new utterance replaces the old one). Never throws — a missing/broken
  /// TTS engine on a device just means voice playback silently does nothing.
  ///
  /// [lang] is the language of [text] when it differs from the app language
  /// (a record shown in its original language offline).
  Future<void> speak(String text, {String? lang}) async {
    final trimmed = speakableText(text);
    if (trimmed.isEmpty) return;
    _started++;
    final epoch = ++_epoch;
    try {
      await _stopEngine();
      if (epoch != _epoch) return;
      if (mockSpeak != null) {
        status.value = TtsStatus.speaking;
        await mockSpeak!(trimmed);
        if (epoch == _epoch) status.value = TtsStatus.idle;
        return;
      }
      await _ensureConfigured();
      await _tts.setVolume(volume);
      final language = voiceFor(lang);
      if (language != _currentLanguage) {
        await _useLanguage(language);
        _currentLanguage = language;
      }
      if (epoch != _epoch) return;
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
    _epoch++;
    await _stopEngine();
    status.value = TtsStatus.idle;
  }

  Future<void> _stopEngine() async {
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
