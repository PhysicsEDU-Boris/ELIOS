import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/guide_lesson.dart';

final dailyGuideServiceProvider = Provider((ref) => DailyGuideService());

/// Topic families from the elios-guides pipeline (manifest v2 "theme").
const guideThemes = ['water', 'heat', 'air', 'energy', 'waste', 'storm'];

/// Stop XP from the guide (G4: story 10, physics 20, quiz 10, lab 20).
class GuideXp {
  const GuideXp({
    this.story = 10,
    this.physics = 20,
    this.quiz = 10,
    this.lab = 20,
  });
  final int story, physics, quiz, lab;
  int get total => story + physics + quiz + lab;

  static GuideXp parse(Object? v) {
    if (v is! Map) return const GuideXp();
    int at(String k, int d) =>
        v[k] is int && (v[k] as int) >= 0 ? v[k] as int : d;
    return GuideXp(
      story: at('story', 10),
      physics: at('physics', 20),
      quiz: at('quiz', 10),
      lab: at('lab', 20),
    );
  }
}

class GuidePhoto {
  const GuidePhoto({
    required this.src,
    required this.thumb,
    required this.width,
    required this.height,
    this.caption = const {},
    this.credit,
    this.license,
    this.sourceUrl,
  });

  /// Paths inside the published site (`issues/<date>/...`); use [DailyGuide.asset] for the URL.
  final String src, thumb;
  final int width, height;
  final Map<String, String> caption;
  final String? credit, license, sourceUrl;
}

class DailyGuide {
  static final base = Uri.parse(
    'https://physicsedu-boris.github.io/elios-guides/',
  );
  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  DailyGuide._({
    required this.date,
    required this.issue,
    required this.title,
    required this.topic,
    required this.pdf,
    required this.cover,
    required this.content,
    required this.revision,
    required this.theme,
    required this.photo,
    required this.contentSha,
    required this.xp,
    required this.pages,
  });

  final String date;
  final String? issue;
  final Map<String, String> title, topic, pdf, cover, content, contentSha;
  final String? revision;

  /// One of [guideThemes]; v1 entries get it from their English topic words.
  final String? theme;
  final GuidePhoto? photo;
  final GuideXp xp;
  final int pages;

  DateTime get day => DateTime.parse(date);

  /// [language] when the issue has it, else the other language (shown with a note).
  String lang(String language) {
    final want = language == 'id' ? 'id' : 'en';
    return title.containsKey(want) ? want : title.keys.first;
  }

  bool hasLang(String language) =>
      title.containsKey(language == 'id' ? 'id' : 'en');

  /// Asset URL with the revision as a cache key, so a republished issue downloads again.
  Uri asset(String path, {String? lang}) {
    final v = [
      revision,
      if (lang != null) contentSha[lang],
    ].whereType<String>().join('.');
    final uri = base.resolve(path);
    return v.isEmpty ? uri : uri.replace(queryParameters: {'v': v});
  }

  /// Parses the catalogue newest first. One bad entry is skipped and logged, so it never hides the rest.
  static List<DailyGuide> parse(String source) {
    final data = jsonDecode(source);
    if (data is! Map || data['guides'] is! List) {
      throw const FormatException('Invalid daily guide catalogue');
    }
    final seen = <String>{};
    final result = <DailyGuide>[];
    for (final entry in data['guides'] as List) {
      try {
        final guide = _parseOne(entry);
        if (!seen.add(guide.date)) {
          throw const FormatException('Duplicate issue date');
        }
        result.add(guide);
      } on FormatException catch (e) {
        debugPrint(
          '[DailyGuide] skipped entry ${entry is Map ? entry['date'] : '?'}: ${e.message}',
        );
      }
    }
    return result..sort((a, b) => b.date.compareTo(a.date));
  }

  static DailyGuide _parseOne(Object? entry) {
    if (entry is! Map) throw const FormatException('Invalid daily guide');
    final date = entry['date'];
    if (date is! String ||
        !_dateRe.hasMatch(date) ||
        DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid issue date');
    }
    final revision = entry['revision'];
    if (revision != null &&
        (revision is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision))) {
      throw const FormatException('Invalid guide revision');
    }
    Map<String, String> texts(String field, {String? asset}) {
      final v = entry[field];
      final out = <String, String>{};
      for (final lang in ['en', 'id']) {
        final s = v is Map ? v[lang] : null;
        if (s is! String || s.trim().isEmpty) continue;
        if (asset != null &&
            !RegExp('^issues/$date/[A-Za-z0-9_-]+\\.$asset\$').hasMatch(s)) {
          throw const FormatException('Invalid guide asset URL');
        }
        out[lang] = s;
      }
      return out;
    }

    final title = texts('title');
    final pdf = texts('pdf', asset: 'pdf');
    final cover = texts('cover', asset: 'png');
    final content = texts('content', asset: 'json');
    // A language counts only when it has its title, PDF and cover.
    title.removeWhere((l, _) => !pdf.containsKey(l) || !cover.containsKey(l));
    if (title.isEmpty) throw const FormatException('No complete language');
    final topic = texts('topic');
    final pages = entry['pages'];
    final theme = entry['theme'];
    final sha = entry['content_sha'];
    return DailyGuide._(
      date: date,
      issue: entry['issue'] is String ? entry['issue'] as String : null,
      title: title,
      topic: topic,
      pdf: pdf,
      cover: cover,
      content: content,
      revision: revision as String?,
      theme: guideThemes.contains(theme)
          ? theme as String
          : _themeFromTopic(topic['en'] ?? ''),
      photo: _photo(entry['photo'], date),
      contentSha: {
        for (final l in ['en', 'id'])
          if (sha is Map && sha[l] is String) l: sha[l] as String,
      },
      xp: GuideXp.parse(entry['xp_parts'] ?? entry['xp']),
      pages: pages is int && pages > 0 && pages < 100 ? pages : 4,
    );
  }

  static GuidePhoto? _photo(Object? p, String date) {
    if (p is! Map) return null;
    final path = RegExp('^issues/$date/[A-Za-z0-9_-]+\\.(jpg|jpeg|png|webp)\$');
    final src = p['src'], thumb = p['thumb'], w = p['w'], h = p['h'];
    if (src is! String ||
        !path.hasMatch(src) ||
        w is! int ||
        h is! int ||
        w <= 0 ||
        h <= 0) {
      return null;
    }
    final caption = p['caption'];
    String? text(String k) =>
        p[k] is String && (p[k] as String).trim().isNotEmpty
        ? p[k] as String
        : null;
    return GuidePhoto(
      src: src,
      thumb: thumb is String && path.hasMatch(thumb) ? thumb : src,
      width: w,
      height: h,
      caption: {
        for (final l in ['en', 'id'])
          if (caption is Map && caption[l] is String) l: caption[l] as String,
      },
      credit: text('credit'),
      license: text('license'),
      sourceUrl: text('source_url'),
    );
  }

  // ponytail: keyword guess for v1 entries only; v2 manifests send "theme".
  static String? _themeFromTopic(String topic) {
    final t = topic.toLowerCase();
    for (final (theme, words) in const [
      ('storm', ['storm', 'cyclone', 'thunder', 'lightning']),
      ('water', ['water', 'river', 'rain', 'flood', 'ocean', 'sea']),
      ('heat', ['heat', 'temperature', 'hot', 'thermal']),
      ('air', ['air', 'haze', 'wind', 'smog', 'pollution']),
      ('energy', ['energy', 'solar', 'power', 'electric', 'battery']),
      ('waste', ['waste', 'trash', 'recycl', 'plastic', 'garbage']),
    ]) {
      if (words.any(t.contains)) return theme;
    }
    return null;
  }

  GuideLesson lesson(String language) {
    final l = lang(language);
    return GuideLesson(
      id: 'daily-$date',
      moduleId: 'daily',
      moduleTitle: date,
      title: title[l]!,
      description: topic[l] ?? topic.values.firstOrNull ?? '',
      pdfUrl: asset(pdf[l]!).toString(),
      coverUrl: asset(cover[l]!).toString(),
      pageCount: pages,
      order: 0,
      isPublished: true,
    );
  }
}

/// One issue's published text (`issues/<date>/<lang>.json`), read by key.
class GuideContent {
  GuideContent(this.data);
  final Map<String, dynamic> data;

  String? text(String key) {
    final v = data[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  /// The 3 printed questions; a question without a valid answer key is left out.
  List<GuideQuestion> get printed => [
    for (var n = 1; n <= 3; n++)
      if (text('quiz.$n.question') case final q?)
        if ('abcd'.contains('${_answers['$n']}') &&
            '${_answers['$n']}'.length == 1 &&
            ['a', 'b', 'c', 'd'].every((o) => text('quiz.$n.$o') != null))
          GuideQuestion(
            qid: 'p$n',
            question: q,
            options: [
              for (final o in ['a', 'b', 'c', 'd']) text('quiz.$n.$o')!,
            ],
            answer: 'abcd'.indexOf('${_answers['$n']}'),
            explanation: _explain['$n']?['why'] is String
                ? _explain['$n']!['why'] as String
                : _poolExplanation(q),
            wrong: {
              if (_explain['$n']?['wrong'] case final Map w)
                for (final e in w.entries)
                  if (e.value is String &&
                      '${e.key}'.length == 1 &&
                      'abcd'.contains('${e.key}'))
                    'abcd'.indexOf('${e.key}'): e.value as String,
            },
          ),
  ];

  /// Spare questions for "Try the quiz again".
  List<GuideQuestion> get pool => [
    for (final (i, q) in _list('_quiz_pool').indexed)
      if (q is Map &&
          q['question'] is String &&
          q['options'] is List &&
          (q['options'] as List).length == 4 &&
          (q['options'] as List).every((o) => o is String) &&
          q['answer'] is int &&
          (q['answer'] as int) >= 0 &&
          (q['answer'] as int) < 4)
        GuideQuestion(
          qid: 'pool-$i',
          question: q['question'] as String,
          options: List<String>.from(q['options'] as List),
          answer: q['answer'] as int,
          explanation: q['explanation'] is String
              ? q['explanation'] as String
              : null,
        ),
  ];

  List<String> get mustShow => _strings(
    (data['_lab_rubric'] is Map
        ? data['_lab_rubric'] as Map
        : const {})['must_show'],
  );
  List<String> get safety => _strings(
    (data['_lab_rubric'] is Map
        ? data['_lab_rubric'] as Map
        : const {})['safety'],
  );
  List<String> get labSteps => [
    for (var n = 1; n <= 5; n++) ?text('lab.step_$n'),
  ];
  List<String> get sources => [for (var n = 1; n <= 5; n++) ?text('source.$n')];

  /// Source links by number from "_sources" (https only).
  Map<int, Uri> get sourceLinks => {
    for (final s in _list('_sources'))
      if (s is Map &&
          s['n'] is int &&
          s['url'] is String &&
          Uri.tryParse(s['url'] as String)?.scheme == 'https')
        s['n'] as int: Uri.parse(s['url'] as String),
  };

  List _list(String key) => data[key] is List ? data[key] as List : const [];
  Map get _answers =>
      data['_answers'] is Map ? data['_answers'] as Map : const {};
  Map<String, Map> get _explain => {
    if (data['_quiz_explain'] case final Map m)
      for (final e in m.entries)
        if (e.value is Map) '${e.key}': e.value as Map,
  };
  String? _poolExplanation(String question) {
    for (final q in _list('_quiz_pool')) {
      if (q is Map && q['question'] == question && q['explanation'] is String) {
        return q['explanation'] as String;
      }
    }
    return null;
  }

  static List<String> _strings(Object? v) => v is List
      ? [
          for (final s in v)
            if (s is String && s.trim().isNotEmpty) s,
        ]
      : const [];
}

class GuideQuestion {
  const GuideQuestion({
    required this.qid,
    required this.question,
    required this.options,
    required this.answer,
    this.explanation,
    this.wrong = const {},
  });
  final String qid, question;
  final List<String> options;
  final int answer;
  final String? explanation;
  final Map<int, String> wrong;
}

class DailyGuideFeed {
  final List<DailyGuide> guides;
  final bool offline;
  const DailyGuideFeed(this.guides, {this.offline = false});
}

class DailyGuideService {
  static const _cacheKey = 'daily-guide-manifest-v1';
  final Future<String> Function() _fetch;
  final Future<String> Function(Uri url) _fetchCached;

  DailyGuideService({
    Future<String> Function()? fetch,
    Future<String> Function(Uri url)? fetchContent,
  }) : _fetch = fetch ?? _download,
       _fetchCached = fetchContent ?? _cached;

  Future<DailyGuideFeed> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final source = await _fetch().timeout(const Duration(seconds: 20));
      final guides = DailyGuide.parse(source);
      await prefs.setString(_cacheKey, source);
      return DailyGuideFeed(guides);
    } catch (_) {
      final cached = prefs.getString(_cacheKey);
      if (cached == null) rethrow;
      return DailyGuideFeed(DailyGuide.parse(cached), offline: true);
    }
  }

  /// The issue text in [language] (or the other language when it is missing).
  Future<GuideContent?> content(DailyGuide guide, String language) async {
    final l = guide.content.containsKey(language)
        ? language
        : guide.content.keys.firstOrNull;
    if (l == null) return null;
    final data = jsonDecode(
      await _fetchCached(guide.asset(guide.content[l]!, lang: l)),
    );
    return data is Map<String, dynamic> ? GuideContent(data) : null;
  }

  // The URL carries revision + content_sha, so a republished issue is a new cache entry.
  static Future<String> _cached(Uri url) async =>
      (await DefaultCacheManager()
              .getSingleFile(url.toString())
              .timeout(const Duration(seconds: 20)))
          .readAsString();

  static Future<String> _download() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        DailyGuide.base.resolve('manifest.json'),
      );
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Guide catalogue HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const FormatException('Guide catalogue too large');
        }
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }
}
