import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'ai_quiz_service.dart';
import 'history_cloud.dart';

/// Guide progress for one account (decision 0194). The backend writes XP; the phone keeps a durable
/// queue of idempotent events, shows them at once, and replaces its totals with each server reply.
class IssueProgress {
  const IssueProgress({
    this.stops = const {},
    this.quiz = const {},
    this.lab = const {},
    this.xp = 0,
  });
  final Map<String, String> stops;
  final Map<String, dynamic> quiz, lab;
  final int xp;

  bool get story => stops.containsKey('story');
  bool get physics => stops.containsKey('physics');
  bool get quizPassed => stops.containsKey('quiz');
  bool get labApproved => stops.containsKey('lab');
  bool get mission => quizPassed && labApproved;

  /// Quest stops done: story, physics, mission (quiz + lab).
  int get stopsDone => (story ? 1 : 0) + (physics ? 1 : 0) + (mission ? 1 : 0);

  static IssueProgress fromJson(Object? j) {
    if (j is! Map) return const IssueProgress();
    return IssueProgress(
      stops: {
        if (j['stops'] case final Map s)
          for (final e in s.entries)
            if (e.value is String) '${e.key}': e.value as String,
      },
      quiz: j['quiz'] is Map
          ? Map<String, dynamic>.from(j['quiz'] as Map)
          : const {},
      lab: j['lab'] is Map
          ? Map<String, dynamic>.from(j['lab'] as Map)
          : const {},
      xp: j['xp'] is int ? j['xp'] as int : 0,
    );
  }
}

class GuideProgressState {
  const GuideProgressState({
    this.issues = const {},
    this.streak = 0,
    this.bestStreak = 0,
    this.totalXp = 0,
    this.week = const [],
    this.pages = const {},
    this.guideLang,
    this.pending = 0,
    this.synced = false,
    this.guestImport,
  });

  final Map<String, IssueProgress> issues;
  final int streak, bestStreak, totalXp;

  /// Monday..Sunday: (date, read | missed | today | future | off).
  final List<(String, String)> week;

  /// Furthest PDF page reached per issue date (shared by both languages).
  final Map<String, int> pages;

  /// 'en' / 'id' when the student picked a guide language; null = the app language.
  final String? guideLang;
  final int pending;

  /// The last sync reached the server.
  final bool synced;

  /// A guest account's progress on this phone that may be imported into this account.
  final ({String uid, String claim, int xp})? guestImport;

  IssueProgress of(String date) => issues[date] ?? const IssueProgress();
}

/// Applies the server summary, then the events still queued on the phone on top.
@visibleForTesting
GuideProgressState progressView(
  Map<String, dynamic> stored, {
  required String today,
}) {
  final server = stored['server'] is Map ? stored['server'] as Map : const {};
  final issues = <String, IssueProgress>{
    if (server['issues'] case final Map m)
      for (final e in m.entries) '${e.key}': IssueProgress.fromJson(e.value),
  };
  final queue = stored['queue'] is List ? stored['queue'] as List : const [];
  var totalXp = server['total_xp'] is int ? server['total_xp'] as int : 0;
  var streak = server['streak'] is int ? server['streak'] as int : 0;
  final week = <(String, String)>[
    for (final d in server['week'] is List ? server['week'] as List : const [])
      if (d is Map && d['date'] is String && d['status'] is String)
        (d['date'] as String, d['status'] as String),
  ];
  for (final e in queue) {
    if (e is! Map || e['op'] != 'event') continue;
    final stop = {'story_read': 'story', 'physics_read': 'physics'}[e['type']];
    final date = e['date'];
    if (stop == null || date is! String) continue;
    final p = issues[date] ?? const IssueProgress();
    if (p.stops.containsKey(stop)) continue;
    final xp = e['xp'] is int ? e['xp'] as int : 0;
    issues[date] = IssueProgress(
      stops: {...p.stops, stop: '${e['at']}'},
      quiz: p.quiz,
      lab: p.lab,
      xp: p.xp + xp,
    );
    totalXp += xp;
    final i = week.indexWhere((d) => d.$1 == today);
    if (i >= 0 && week[i].$2 != 'read' && '${e['day']}' == today) {
      week[i] = (today, 'read');
      streak++;
    }
  }
  final guest = stored['guest_import'];
  return GuideProgressState(
    issues: issues,
    streak: streak,
    bestStreak: max(
      streak,
      server['best_streak'] is int ? server['best_streak'] as int : 0,
    ),
    totalXp: totalXp,
    week: week,
    pages: {
      if (stored['pages'] case final Map m)
        for (final e in m.entries)
          if (e.value is int) '${e.key}': e.value as int,
    },
    guideLang: stored['lang'] is String ? stored['lang'] as String : null,
    pending: queue.length,
    synced: stored['synced'] == true,
    guestImport:
        guest is Map && guest['uid'] is String && guest['claim'] is String
        ? (
            uid: guest['uid'] as String,
            claim: guest['claim'] as String,
            xp: guest['xp'] is int ? guest['xp'] as int : 0,
          )
        : null,
  );
}

/// Asia/Jakarta day of [t], the streak's calendar.
String jakartaDay(DateTime t) =>
    t.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);

String newEventId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

typedef GuidesCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// Files of guide progress per account, written with an atomic rename.
class GuideProgressFiles {
  GuideProgressFiles([this._dir]);
  final Future<Directory> Function()? _dir;

  Future<Directory> dir() async => Directory(
    '${(await (_dir ?? getApplicationSupportDirectory)()).path}/guides',
  )..createSync(recursive: true);

  Future<Map<String, dynamic>> read(String uid) async {
    try {
      final f = File('${(await dir()).path}/${Uri.encodeComponent(uid)}.json');
      if (!f.existsSync()) return {};
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> ? j : {};
    } catch (e) {
      debugPrint('[GuideProgress] read failed: $e');
      return {};
    }
  }

  Future<void> _writes = Future.value();

  /// Writes a snapshot of [data]; writes run one after another so two saves never share the temp file.
  Future<void> write(String uid, Map<String, dynamic> data) {
    final text = jsonEncode(data);
    final next = _writes.then((_) async {
      final d = await dir();
      final tmp = File('${d.path}/${Uri.encodeComponent(uid)}.json.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename('${d.path}/${Uri.encodeComponent(uid)}.json');
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  /// Other accounts' files on this phone (for the guest import offer).
  Future<List<(String, Map<String, dynamic>)>> others(String uid) async {
    final out = <(String, Map<String, dynamic>)>[];
    for (final f in (await dir()).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.json')) continue;
      final other = Uri.decodeComponent(name.substring(0, name.length - 5));
      if (other != uid) out.add((other, await read(other)));
    }
    return out;
  }
}

final guideProgressFilesProvider = Provider((ref) => GuideProgressFiles());

/// The backend call for an account; tests override it.
final guidesCallProvider = Provider<GuidesCall?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  const override = String.fromEnvironment('ELIOS_GUIDES_URL');
  final cloud = HistoryCloud.forUser(
    user,
    url: override.isEmpty
        ? Uri.parse(AiQuizService.workerUrl).replace(path: '/api/guides')
        : Uri.parse(override),
  );
  return cloud.call;
});

final guideProgressProvider =
    NotifierProvider<GuideProgressNotifier, GuideProgressState>(
      GuideProgressNotifier.new,
    );

class GuideProgressNotifier extends Notifier<GuideProgressState> {
  Map<String, dynamic> _data = {};
  String? _uid;
  Timer? _timer;
  Future<void>? _syncing;
  Future<void> _ready = Future.value();
  bool _disposed = false;

  GuidesCall? _call;
  late GuideProgressFiles _files;
  DateTime Function() now = DateTime.now;

  @override
  GuideProgressState build() {
    _uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    _call = ref.watch(guidesCallProvider);
    _files = ref.read(guideProgressFilesProvider);
    _disposed = false;
    final listener = AppLifecycleListener(onResume: () => unawaited(sync()));
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(sync()),
    );
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      listener.dispose();
    });
    _ready = _load();
    return const GuideProgressState();
  }

  Future<void> get ready => _ready;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    _data = await _files.read(uid);
    await _migratePrefs(uid);
    await _findGuest(uid);
    _emit();
    unawaited(sync());
  }

  /// #102 kept the furthest page per account in SharedPreferences; move it into this store once.
  Future<void> _migratePrefs(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'daily-guide-page:$uid:daily-';
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      if (keys.isEmpty) return;
      final pages = Map<String, dynamic>.from(_data['pages'] as Map? ?? {});
      for (final k in keys) {
        final date = k.substring(prefix.length);
        pages[date] = max(
          pages[date] is int ? pages[date] as int : 0,
          prefs.getInt(k) ?? 0,
        );
      }
      _data['pages'] = pages;
      await _save();
      for (final k in keys) {
        await prefs.remove(k);
      }
      // Pages already read still earn their stops.
      for (final e in pages.entries) {
        await _pageReached(e.key, e.value as int);
      }
    } catch (e) {
      debugPrint('[GuideProgress] page migration failed: $e');
    }
  }

  Future<void> _findGuest(String uid) async {
    if (_disposed) return;
    final user = ref.read(currentUserProvider);
    if (user == null || user.isAnonymous) return;
    final declined =
        (_data['guest_declined'] as List?)?.cast<String>() ?? const [];
    for (final (other, data) in await _files.others(uid)) {
      final server = data['server'];
      final claim = server is Map ? server['guest_claim'] : null;
      final xp = server is Map && server['total_xp'] is int
          ? server['total_xp'] as int
          : 0;
      if (claim is String && xp > 0 && !declined.contains(other)) {
        _data['guest_import'] = {'uid': other, 'claim': claim, 'xp': xp};
        return;
      }
    }
    _data.remove('guest_import');
  }

  void _emit() {
    if (!_disposed) state = progressView(_data, today: jakartaDay(now()));
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid != null) await _files.write(uid, _data);
  }

  Future<void> _enqueue(Map<String, dynamic> body) async {
    _data['queue'] = [...?(_data['queue'] as List?), body];
    await _save();
    _emit();
  }

  /// The furthest PDF page of [date]; page 2 finishes Stop 1 and page 3 Stop 2.
  Future<void> pageReached(
    String date,
    int page, {
    int storyXp = 10,
    int physicsXp = 20,
  }) async {
    await _ready;
    await _pageReached(date, page, storyXp: storyXp, physicsXp: physicsXp);
    unawaited(sync());
  }

  Future<void> _pageReached(
    String date,
    int page, {
    int storyXp = 10,
    int physicsXp = 20,
  }) async {
    final pages = Map<String, dynamic>.from(_data['pages'] as Map? ?? {});
    if ((pages[date] as int? ?? 0) < page) pages[date] = page;
    _data['pages'] = pages;
    // From the stored data (state may not be emitted yet during load); queued reads count as done.
    final p = progressView(_data, today: jakartaDay(now())).of(date);
    final t = now();
    for (final (type, at, xp, done) in [
      ('story_read', 2, storyXp, p.story),
      ('physics_read', 3, physicsXp, p.physics),
    ]) {
      if (page >= at && !done) {
        _data['queue'] = [
          ...?(_data['queue'] as List?),
          {
            'op': 'event',
            'id': newEventId(),
            'date': date,
            'type': type,
            'xp': xp,
            'at': t.toUtc().toIso8601String(),
            'day': jakartaDay(t),
          },
        ];
      }
    }
    await _save();
    _emit();
  }

  Future<void> setGuideLang(String? lang) async {
    await _ready;
    if (lang == null) {
      _data.remove('lang');
    } else {
      _data['lang'] = lang;
    }
    await _save();
    _emit();
  }

  /// Records a quiz attempt (queued, so an offline pass still counts). Returns the server's
  /// grading when it answered now, else null (the result card then says it will sync).
  Future<Map<String, dynamic>?> submitQuiz(
    String date,
    String lang,
    List<({String qid, String choice})> answers,
  ) async {
    await _ready;
    final id = newEventId();
    await _enqueue({
      'op': 'quiz',
      'id': id,
      'date': date,
      'lang': lang,
      'answers': [
        for (final a in answers) {'qid': a.qid, 'choice': a.choice},
      ],
    });
    await sync();
    final reply = (_data['replies'] as Map?)?.remove(id);
    return reply is Map<String, dynamic> ? reply : null;
  }

  /// Sends lab frames now (never queued: the check needs internet). Throws [CloudHttpException]
  /// for limits, anything else when offline.
  Future<Map<String, dynamic>> checkLab(
    String date,
    String lang,
    List<String> frames,
  ) async {
    await _ready;
    final call = _call;
    if (call == null) throw StateError('Sign in first');
    final reply = await call({
      'op': 'lab',
      'id': newEventId(),
      'date': date,
      'lang': lang,
      'frames': frames,
    });
    _applyServer(reply['progress']);
    await _save();
    _emit();
    return reply;
  }

  Future<void> requestReview(String date) async {
    await _ready;
    await _enqueue({'op': 'review', 'id': newEventId(), 'date': date});
    await sync();
  }

  Future<void> importGuest() async {
    await _ready;
    final g = state.guestImport;
    final call = _call;
    if (g == null || call == null) return;
    final reply = await call({
      'op': 'import',
      'guest_uid': g.uid,
      'guest_claim': g.claim,
    });
    _applyServer(reply['progress']);
    _data['guest_declined'] = [...?(_data['guest_declined'] as List?), g.uid];
    _data.remove('guest_import');
    await _save();
    _emit();
  }

  Future<void> declineGuest() async {
    await _ready;
    final g = state.guestImport;
    if (g == null) return;
    _data['guest_declined'] = [...?(_data['guest_declined'] as List?), g.uid];
    _data.remove('guest_import');
    await _save();
    _emit();
  }

  void _applyServer(Object? progress) {
    if (progress is Map<String, dynamic>) _data['server'] = progress;
  }

  /// Sends the queue in order, then fetches totals. One run at a time.
  Future<void> sync() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    await _ready;
    final call = _call;
    if (call == null || _uid == null || _disposed) return;
    var ok = true;
    try {
      while (!_disposed && (_data['queue'] as List? ?? const []).isNotEmpty) {
        final item = Map<String, dynamic>.from(
          (_data['queue'] as List).first as Map,
        );
        final body = {...item}
          ..removeWhere((k, _) => const ['xp', 'at', 'day'].contains(k));
        Map<String, dynamic>? reply;
        try {
          reply = await call(body);
        } on CloudHttpException catch (e) {
          // A request the server refuses (4xx) will never succeed; drop it. 5xx: try later.
          if (e.status >= 500) rethrow;
          debugPrint('[GuideProgress] dropped ${item['op']}: HTTP ${e.status}');
        }
        if (reply != null) {
          _applyServer(reply['progress']);
          if (item['op'] == 'quiz') {
            _data['replies'] = {
              ...?(_data['replies'] as Map?),
              item['id']: reply,
            };
          }
        }
        _data['queue'] = (_data['queue'] as List).skip(1).toList();
        await _save();
        _emit();
      }
      _applyServer(await call({'op': 'progress'}));
    } catch (e) {
      ok = false;
      debugPrint('[GuideProgress] sync later: $e');
    }
    _data['synced'] = ok;
    if (ok) await _findGuest(_uid!);
    await _save();
    _emit();
  }
}
