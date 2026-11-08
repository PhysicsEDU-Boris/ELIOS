import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/guide_lesson.dart';

final dailyGuideServiceProvider = Provider((ref) => DailyGuideService());

class DailyGuide {
  static final base = Uri.parse(
    'https://physicsedu-boris.github.io/elios-guides/',
  );
  final String date;
  final Map<String, dynamic> _data;

  DailyGuide._(this.date, this._data);

  static List<DailyGuide> parse(String source) {
    final data = jsonDecode(source);
    if (data is! Map || data['guides'] is! List) {
      throw const FormatException('Invalid daily guide catalogue');
    }
    final dates = <String>{};
    final result = <DailyGuide>[];
    for (final entry in data['guides']) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid daily guide');
      }
      final date = entry['date'];
      if (date is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date ||
          !dates.add(date)) {
        throw const FormatException('Invalid or duplicate issue date');
      }
      final revision = entry['revision'];
      if (revision != null &&
          (revision is! String ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision))) {
        throw const FormatException('Invalid guide revision');
      }
      for (final field in ['title', 'topic', 'pdf', 'cover']) {
        final translations = entry[field];
        for (final lang in ['en', 'id']) {
          final value = translations is Map ? translations[lang] : null;
          if (value is! String || value.trim().isEmpty) {
            throw FormatException('Missing $field/$lang');
          }
          if (field == 'pdf' || field == 'cover') {
            final extension = field == 'pdf' ? 'pdf' : 'png';
            if (!RegExp(
              '^issues/$date/[A-Za-z0-9_-]+\\.$extension\$',
            ).hasMatch(value)) {
              throw const FormatException('Invalid guide asset URL');
            }
          }
        }
      }
      result.add(DailyGuide._(date, entry));
    }
    return result..sort((a, b) => b.date.compareTo(a.date));
  }

  GuideLesson lesson(String language) {
    final lang = language == 'id' ? 'id' : 'en';
    String asset(String field) {
      final uri = base.resolve(_data[field][lang] as String);
      return _data['revision'] == null
          ? uri.toString()
          : uri
                .replace(queryParameters: {'v': _data['revision'] as String})
                .toString();
    }

    return GuideLesson(
      id: 'daily-$date',
      moduleId: 'daily',
      moduleTitle: date,
      title: _data['title'][lang] as String,
      description: _data['topic'][lang] as String,
      pdfUrl: asset('pdf'),
      coverUrl: asset('cover'),
      pageCount: 4,
      order: 0,
      isPublished: true,
    );
  }
}

class DailyGuideFeed {
  final List<DailyGuide> guides;
  final bool offline;
  const DailyGuideFeed(this.guides, {this.offline = false});
}

class DailyGuideService {
  static const _cacheKey = 'daily-guide-manifest-v1';
  final Future<String> Function() _fetch;

  DailyGuideService({Future<String> Function()? fetch})
    : _fetch = fetch ?? _download;

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
