import 'dart:io';

import 'package:elio/services/guide_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../guides/g4_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late FakeGuidesServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('g4-progress-');
    server = FakeGuidesServer();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(ProviderContainer, GuideProgressNotifier)> open() async {
    final c = ProviderContainer(
      overrides: guideOverrides(server: server, dir: dir),
    );
    final n = c.read(guideProgressProvider.notifier);
    await n.ready;
    await n.sync();
    return (c, n);
  }

  test(
    'page 2 finishes Stop 1 and page 3 Stop 2, each once; totals come from the server',
    () async {
      final (c, n) = await open();
      await n.pageReached(date, 2);
      await n.sync();
      expect(c.read(guideProgressProvider).of(date).story, isTrue);
      expect(c.read(guideProgressProvider).of(date).physics, isFalse);
      await n.pageReached(date, 3);
      await n.pageReached(date, 3);
      await n.pageReached(date, 4);
      await n.sync();
      final events = server.calls.where((b) => b['op'] == 'event').toList();
      expect(events.map((e) => e['type']), ['story_read', 'physics_read']);
      expect(
        events.every((e) => !e.containsKey('xp')),
        isTrue,
        reason: 'the phone never sends XP',
      );
      expect(c.read(guideProgressProvider).totalXp, 30);
      expect(c.read(guideProgressProvider).pages[date], 4);
      c.dispose();
    },
  );

  test(
    'offline: events show at once, survive a restart and are sent once with the same id',
    () async {
      server.offline = true;
      var (c, n) = await open();
      await n.pageReached(date, 3);
      await n.pageReached(date, 3);
      expect(
        await n.submitQuiz(date, 'en', [
          (qid: 'p1', choice: 'b'),
          (qid: 'p2', choice: 'a'),
          (qid: 'p3', choice: 'c'),
        ]),
        isNull,
      );
      final shown = c.read(guideProgressProvider);
      expect(
        shown.of(date).stopsDone,
        2,
        reason: 'shown immediately from the queue',
      );
      expect(shown.totalXp, 30);
      expect(
        shown.pending,
        3,
        reason: 'story, physics and the quiz, each once',
      );
      c.dispose();

      server.offline = false;
      (c, n) = await open(); // app restart
      expect(c.read(guideProgressProvider).pending, 0);
      final sent = server.calls.where((b) => b['op'] == 'event').toList();
      expect(sent.length, 2);
      expect(
        server.calls.where((b) => b['op'] == 'quiz').length,
        1,
        reason: 'the offline quiz pass is sent after restart',
      );
      expect(c.read(guideProgressProvider).of(date).quizPassed, isTrue);
      await n.sync();
      expect(
        server.calls.where((b) => b['op'] == 'event').length,
        2,
        reason: 'sent once',
      );
      expect(c.read(guideProgressProvider).totalXp, 40);
      c.dispose();
    },
  );

  test(
    'quiz: first pass XP is the server\'s; a refused request is dropped, not retried forever',
    () async {
      final (c, n) = await open();
      final pass = await n.submitQuiz(date, 'en', [
        (qid: 'p1', choice: 'b'),
        (qid: 'p2', choice: 'a'),
        (qid: 'p3', choice: 'a'),
      ]);
      expect(pass!['xp_awarded'], 10);
      final again = await n.submitQuiz(date, 'en', [
        (qid: 'p1', choice: 'b'),
        (qid: 'p2', choice: 'a'),
        (qid: 'p3', choice: 'c'),
      ]);
      expect(again!['xp_awarded'], 0);
      expect(c.read(guideProgressProvider).of(date).quizPassed, isTrue);
      expect(c.read(guideProgressProvider).totalXp, 10);
      c.dispose();
    },
  );

  test('lab approval comes back with the server totals', () async {
    final (c, n) = await open();
    final r = await n.checkLab(date, 'en', ['/9j/AAAA']);
    expect(r['verdict'], 'approved');
    expect(c.read(guideProgressProvider).of(date).labApproved, isTrue);
    expect(c.read(guideProgressProvider).totalXp, 20);
    c.dispose();
  });

  test(
    '#102 page positions move into the store for this account only',
    () async {
      SharedPreferences.setMockInitialValues({
        'daily-guide-page:student-1:daily-$date': 3,
        'daily-guide-page:someone-else:daily-$date': 4,
      });
      final (c, _) = await open();
      final s = c.read(guideProgressProvider);
      expect(s.pages[date], 3);
      expect(s.of(date).physics, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'daily-guide-page:someone-else:daily-$date'});
      c.dispose();
    },
  );

  test('week dots and streak come from the server data', () async {
    await server.call({
      'op': 'event',
      'id': 'x',
      'date': date,
      'type': 'story_read',
    });
    final (c, _) = await open();
    final s = c.read(guideProgressProvider);
    expect(s.streak, 1);
    expect(s.week.map((d) => d.$2), [
      'missed',
      'off',
      'read',
      'off',
      'read',
      'read',
      'today',
    ]);
    c.dispose();
  });

  test('a queued read today marks today read before the server answers', () {
    final view = progressView({
      'server': {
        'week': [
          {'date': '2026-11-09', 'status': 'today'},
        ],
        'streak': 2,
      },
      'queue': [
        {
          'op': 'event',
          'type': 'story_read',
          'date': date,
          'xp': 10,
          'at': 'x',
          'day': '2026-11-09',
        },
      ],
    }, today: '2026-11-09');
    expect(view.week.single.$2, 'read');
    expect(view.streak, 3);
    expect(view.totalXp, 10);
  });
}
