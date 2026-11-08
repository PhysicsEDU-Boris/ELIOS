import 'dart:convert';

import 'package:elio/services/daily_guide_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guides/g4_fixture.dart' as g4;

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
      expect(guides.first.lesson('fr').pdfUrl, en.pdfUrl);
    },
  );

  test(
    'v1 entries parse with defaults: 4 pages, default XP, theme from the topic, no photo',
    () {
      final g = DailyGuide.parse(
        g4.manifest([g4.entry(g4.date, v2: false)]),
      ).single;
      expect(g.pages, 4);
      expect(g.xp.total, 60);
      expect(g.theme, 'water');
      expect(g.photo, isNull);
      expect(g.lesson('en').pageCount, 4);
    },
  );

  test(
    'v2 entries carry theme, photo, content_sha, XP parts and the real page count',
    () {
      final data = g4.entry(g4.date)..['pages'] = 6;
      final g = DailyGuide.parse(g4.manifest([data])).single;
      expect(g.theme, 'water');
      expect(g.pages, 6);
      expect(g.lesson('en').pageCount, 6);
      expect(g.photo!.src, 'issues/2026-11-08/photo.jpg');
      expect(g.photo!.thumb, 'issues/2026-11-08/photo-800.jpg');
      expect((g.photo!.width, g.photo!.height), (2000, 1333));
      expect(g.photo!.caption['en'], 'Goosenecks, Utah');
      expect(g.xp.total, 60);
      // An unknown theme or a photo outside the issue folder is dropped, not trusted.
      data['theme'] = 'lava';
      (data['photo'] as Map)['src'] = 'https://evil.example/x.jpg';
      final bad = DailyGuide.parse(g4.manifest([data])).single;
      expect(bad.photo, isNull);
      expect(bad.theme, 'water', reason: 'falls back to the topic words');
    },
  );

  test('one invalid entry is skipped and never hides the archive', () {
    final bad = [
      issue('2026-02-30'),
      {...issue('2026-11-05'), 'revision': '../bad'},
      {
        ...issue('2026-11-04'),
        'pdf': {
          'en': 'https://example.com/river.pdf',
          'id': 'issues/2026-11-04/../../x.pdf',
        },
      },
      issue('2026-11-07'),
      issue('2026-11-07'),
      'not a map',
    ];
    final guides = DailyGuide.parse(
      jsonEncode({
        'guides': [issue('2026-11-08'), ...bad],
      }),
    );
    expect(guides.map((g) => g.date), ['2026-11-08', '2026-11-07']);
    expect(() => DailyGuide.parse('{}'), throwsFormatException);
    expect(DailyGuide.parse(manifest([])), isEmpty);
  });

  test('a missing language falls back to the other one', () {
    final data = issue('2026-11-08');
    (data['title'] as Map).remove('id');
    final g = DailyGuide.parse(manifest([data])).single;
    expect(g.hasLang('id'), isFalse);
    expect(g.lang('id'), 'en');
    expect(g.lesson('id').title, 'River flow');
  });

  test(
    'a new revision or content_sha changes the download URL but not the issue key',
    () {
      final data = g4.entry(g4.date);
      final before = DailyGuide.parse(g4.manifest([data])).single;
      data['revision'] = 'd' * 64;
      final after = DailyGuide.parse(g4.manifest([data])).single;
      expect(after.lesson('en').pdfUrl, isNot(before.lesson('en').pdfUrl));
      expect(after.date, before.date);
      expect(after.lesson('en').id, before.lesson('en').id);
      (data['content_sha'] as Map)['en'] = 'e' * 64;
      final edited = DailyGuide.parse(g4.manifest([data])).single;
      expect(
        edited.asset('issues/2026-11-08/en.json', lang: 'en'),
        isNot(after.asset('issues/2026-11-08/en.json', lang: 'en')),
      );
    },
  );

  test(
    'content: printed questions with explanations, pool fallback, never invented',
    () async {
      final urls = <Uri>[];
      final service = g4.fakeService(contentUrls: urls);
      final guide = (await service.load()).guides.first;
      final c = (await service.content(guide, 'en'))!;
      expect(urls.single.queryParameters['v'], '${'a' * 64}.${'b' * 64}');
      final q = c.printed;
      expect(q.map((x) => x.qid), ['p1', 'p2', 'p3']);
      expect(q[1].answer, 0);
      expect(q[1].wrong[2], 'Not quite. You multiplied.');
      expect(q[2].explanation, isNull);
      expect(c.pool.length, 5);
      expect(c.mustShow.length, 3);
      final matched = GuideContent({
        'quiz.1.question': 'Same?',
        'quiz.1.a': 'a',
        'quiz.1.b': 'b',
        'quiz.1.c': 'c',
        'quiz.1.d': 'd',
        '_answers': {'1': 'a'},
        '_quiz_pool': [
          {
            'question': 'Same?',
            'options': ['a', 'b', 'c', 'd'],
            'answer': 0,
            'explanation': 'From the pool.',
          },
          {
            'question': 'Bad index',
            'options': ['a', 'b', 'c', 'd'],
            'answer': 7,
          },
        ],
      });
      expect(matched.printed.single.explanation, 'From the pool.');
      expect(
        matched.pool.length,
        1,
        reason: 'a pool question with an out-of-range answer is dropped',
      );
    },
  );

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
    },
  );

  test('first use offline reports an error', () async {
    final service = DailyGuideService(
      fetch: () => Future.error(Exception('offline')),
    );
    await expectLater(service.load(), throwsException);
  });
}
