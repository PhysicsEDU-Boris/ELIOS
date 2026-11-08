import 'dart:convert';

import 'package:elio/services/daily_guide_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> issue(String date) => {
  'date': date,
  'title': {'en': 'River flow', 'id': 'Aliran sungai'},
  'topic': {'en': 'Water physics', 'id': 'Fisika air'},
  'pdf': {
    for (final l in ['en', 'id']) l: 'issues/$date/river-$l.pdf',
  },
  'cover': {
    for (final l in ['en', 'id']) l: 'issues/$date/cover-$l.png',
  },
};

String manifest(List<Map<String, dynamic>> issues) =>
    jsonEncode({'guides': issues});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'sorts newest first, selects language, preserves bilingual issue id',
    () {
      final guides = DailyGuide.parse(
        manifest([issue('2026-11-07'), issue('2026-11-08')]),
      );
      expect(guides.first.date, '2026-11-08');
      final en = guides.first.lesson('en');
      final id = guides.first.lesson('id');
      expect(id.title, 'Aliran sungai');
      expect(en.title, 'River flow');
      expect(en.id, id.id);
      expect(id.pdfUrl, endsWith('/issues/2026-11-08/river-id.pdf'));
      expect(id.coverUrl, endsWith('/cover-id.png'));
      expect(guides.first.lesson('fr').pdfUrl, en.pdfUrl);
    },
  );

  test('corrected exports change cache URL without changing progress id', () {
    final data = issue('2026-11-08')..['revision'] = 'a' * 64;
    final before = DailyGuide.parse(manifest([data])).single.lesson('en');
    data['revision'] = 'b' * 64;
    final after = DailyGuide.parse(manifest([data])).single.lesson('en');
    expect(after.pdfUrl, isNot(before.pdfUrl));
    expect(after.id, before.id);
    expect(Uri.parse(after.pdfUrl).queryParameters['v'], 'b' * 64);
    data['revision'] = '../bad';
    expect(() => DailyGuide.parse(manifest([data])), throwsFormatException);
  });

  test('rejects external, traversal and non-PDF URLs', () {
    for (final url in [
      'https://example.com/river.pdf',
      'issues/2026-11-08/%2e%2e%2fprivate.pdf',
      'issues/2026-11-08/../../private.pdf',
      'issues/2026-11-08/river.html',
      'issues/2026-11-08/river.pdf?token=secret',
    ]) {
      final data = issue('2026-11-08');
      (data['pdf'] as Map)['en'] = url;
      expect(() => DailyGuide.parse(manifest([data])), throwsFormatException);
    }
  });

  test('rejects missing translations, bad dates and duplicate issues', () {
    final missing = issue('2026-11-08');
    (missing['title'] as Map).remove('id');
    for (final entries in [
      [missing],
      [issue('2026-02-30')],
      [issue('2026-11-08'), issue('2026-11-08')],
    ]) {
      expect(() => DailyGuide.parse(manifest(entries)), throwsFormatException);
    }
    expect(() => DailyGuide.parse('{}'), throwsFormatException);
    expect(DailyGuide.parse(manifest([])), isEmpty);
  });

  test(
    'refreshes network, falls back offline, never caches malformed feed',
    () async {
      var source = manifest([issue('2026-11-07')]);
      final service = DailyGuideService(fetch: () async => source);
      expect((await service.load()).offline, isFalse);
      source = manifest([issue('2026-11-08')]);
      expect((await service.load()).guides.single.date, '2026-11-08');
      source = 'broken';
      final fallback = await service.load();
      expect(fallback.offline, isTrue);
      expect(fallback.guides.single.date, '2026-11-08');
      final offline = DailyGuideService(
        fetch: () => Future.error(Exception('offline')),
      );
      expect((await offline.load()).guides.single.date, '2026-11-08');
    },
  );

  test('first use offline reports an error', () async {
    final service = DailyGuideService(
      fetch: () => Future.error(Exception('offline')),
    );
    await expectLater(service.load(), throwsException);
  });
}
