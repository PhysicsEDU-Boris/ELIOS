// G4 Daily Guides test fixture: manifest v1/v2, issue JSON (en/id), a fake backend and photo cache.
// Isolated: in-memory storage by default, never the owner's data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:elio/providers/auth_provider.dart';
import 'package:elio/providers/physics_progress_provider.dart';
import 'package:elio/services/progress_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:elio/services/daily_guide_service.dart';
import 'package:elio/services/guide_progress.dart';
import 'package:elio/services/history_cloud.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

const date = '2026-11-08';
const older = '2026-11-06';

Map<String, dynamic> entry(
  String d, {
  bool v2 = true,
  String theme = 'water',
  bool photo = true,
}) => {
  'revision': 'a' * 64,
  'date': d,
  'issue': d == date ? '01' : '00',
  'slug': 'river',
  'xp': 60,
  'title': {
    'en': 'How fast rivers carve deep rocks',
    'id': 'Secepat apa sungai mengikis batu',
  },
  'topic': {'en': 'Water flow', 'id': 'Aliran air'},
  'cover': {
    for (final l in ['en', 'id']) l: 'issues/$d/cover-$l.png',
  },
  'pdf': {
    for (final l in ['en', 'id']) l: 'issues/$d/guide-$l.pdf',
  },
  'content': {
    for (final l in ['en', 'id']) l: 'issues/$d/$l.json',
  },
  if (v2) ...{
    'schema': 2,
    'theme': theme,
    'photo': photo
        ? {
            'src': 'issues/$d/photo.jpg',
            'thumb': 'issues/$d/photo-800.jpg',
            'w': 2000,
            'h': 1333,
            'caption': {'en': 'Goosenecks, Utah', 'id': 'Goosenecks, Utah'},
            'credit': 'Jstuby / Wikimedia Commons',
            'license': 'CC0',
            'source_url':
                'https://commons.wikimedia.org/wiki/File:Goosenecks.jpg',
          }
        : null,
    'content_sha': {'en': 'b' * 64, 'id': 'c' * 64},
    'xp_parts': {'story': 10, 'physics': 20, 'quiz': 10, 'lab': 20},
    'pages': 4,
  },
};

String manifest(List<Map<String, dynamic>> guides) =>
    jsonEncode({'guides': guides});

final content = <String, Map<String, dynamic>>{
  'en': {
    'cover.subtitle':
        'NASA photos of Utah river loops, and the physics of speed.',
    'cover.image_caption': 'Goosenecks, Utah',
    'cover.news_date': 'News: 6 Nov 2026',
    'cover.place': 'Utah, USA',
    'cover.subject': 'Physics · Motion',
    'cover.level': 'SMP · grade 7–9',
    'cover.read_time': '12 min',
    'cover.fun_fact':
        'These river loops cut through rock millions of years old.',
    'quest.1.desc': 'How rivers carve canyons',
    'quest.2.desc': 'Use v = s ÷ t for water speed',
    'quest.3.desc': 'Quick quiz, mini lab and badge',
    'quiz.1.question': 'What equation calculates speed?',
    'quiz.1.a': 'v = s × t',
    'quiz.1.b': 'v = s ÷ t',
    'quiz.1.c': 'v = t ÷ s',
    'quiz.1.d': 'v = m × v',
    'quiz.2.question':
        'If distance s is 120 m and time t is 20 s, what is speed v?',
    'quiz.2.a': '6 m/s',
    'quiz.2.b': '100 m/s',
    'quiz.2.c': '2,400 m/s',
    'quiz.2.d': '24 m/s',
    'quiz.3.question': 'Why do fast-flowing rivers erode rock faster?',
    'quiz.3.a': 'They are colder',
    'quiz.3.b': 'They contain salt',
    'quiz.3.c': 'More energy and sediment',
    'quiz.3.d': 'They have more sunlight',
    '_answers': {'1': 'b', '2': 'a', '3': 'c'},
    '_quiz_explain': {
      '1': {'why': 'Speed is distance divided by time.'},
      '2': {
        'why': 'Speed = distance ÷ time: 120 m ÷ 20 s = 6 m/s.',
        'wrong': {'c': 'Not quite. You multiplied.'},
      },
    },
    '_quiz_pool': [
      for (var i = 0; i < 5; i++)
        {
          'question': 'Spare question ${i + 1}?',
          'options': ['w', 'x', 'y', 'z'],
          'answer': 1,
          'explanation': 'Spare ${i + 1}.',
        },
    ],
    '_lab_rubric': {
      'must_show': [
        'A tray or board with water on a slope',
        'A floating object like a cork or leaf',
        'A ruler or timer measuring the movement',
      ],
      'safety': ['No faces, no flame, no heat, no chemicals.'],
      'pass_if': 'all three are visible',
    },
    'lab.title': 'Measure stream speed at home',
    'lab.step_1':
        'Mark a 2-metre track along a sloped gutter or plastic tray with water.',
    'lab.step_2': 'Drop a small floating leaf or cork at the start line.',
    'lab.step_3': 'Time how many seconds it takes to reach the finish line.',
    'lab.question': 'v = s ÷ t. What speed did you get?',
    'badge.name': 'Stream Tracker',
    'badge.text': 'You mastered river flow and speed physics.',
    'source.1':
        '[1] NASA Earth Observatory, Taking a Gander at Utah’s Goosenecks, 6 Nov 2026',
    'source.2': '[2] BMKG, Dam water levels, 7 Nov 2026',
    '_sources': [
      {
        'n': 1,
        'publisher': 'NASA Earth Observatory',
        'url': 'https://science.nasa.gov/earth/earth-observatory/',
      },
      {'n': 2, 'publisher': 'BMKG', 'url': 'https://www.bmkg.go.id/berita'},
    ],
    'credit.images': 'Cover: Jstuby / Wikimedia Commons (CC0).',
  },
};

Map<String, dynamic> idContent() => {
  ...content['en']!,
  'cover.subtitle':
      'Foto NASA tentang kelokan sungai di Utah, dan fisika kecepatan.',
  'cover.news_date': 'Berita: 6 Nov 2026',
  'cover.read_time': '12 menit',
  'cover.fun_fact': 'Kelokan sungai ini memotong batu berumur jutaan tahun.',
  'quest.1.desc': 'Bagaimana sungai mengukir ngarai',
  'quest.2.desc': 'Pakai v = s ÷ t untuk kecepatan air',
  'quest.3.desc': 'Kuis cepat, lab mini dan lencana',
  'quiz.1.question': 'Persamaan apa yang menghitung kecepatan?',
  'quiz.2.question': 'Jika jarak s 120 m dan waktu t 20 s, berapa kecepatan v?',
  'quiz.3.question': 'Mengapa sungai yang deras mengikis batu lebih cepat?',
  'quiz.3.a': 'Airnya lebih dingin',
  'quiz.3.b': 'Mengandung garam',
  'quiz.3.c': 'Lebih banyak energi dan sedimen',
  'quiz.3.d': 'Lebih banyak sinar matahari',
  '_quiz_explain': {
    '1': {'why': 'Kecepatan adalah jarak dibagi waktu.'},
    '2': {
      'why': 'Kecepatan = jarak ÷ waktu: 120 m ÷ 20 s = 6 m/s.',
      'wrong': {'c': 'Belum tepat. Kamu mengalikan.'},
    },
  },
  '_lab_rubric': {
    'must_show': [
      'Nampan atau papan berair yang miring',
      'Benda terapung seperti gabus atau daun',
      'Penggaris atau pengatur waktu',
    ],
    'safety': ['Tanpa wajah, api, panas, atau bahan kimia.'],
  },
  'lab.title': 'Ukur kecepatan aliran di rumah',
  'lab.step_1':
      'Tandai lintasan 2 meter di talang miring atau nampan plastik berisi air.',
  'lab.step_2': 'Jatuhkan daun atau gabus kecil di garis awal.',
  'lab.step_3': 'Hitung berapa detik sampai garis akhir.',
  'lab.question': 'v = s ÷ t. Berapa kecepatanmu?',
  'badge.name': 'Pelacak Arus',
  'badge.text': 'Kamu menguasai aliran sungai dan fisika kecepatan.',
};

DailyGuideService fakeService({String? source, List<Uri>? contentUrls}) =>
    DailyGuideService(
      fetch: () async =>
          source ??
          manifest([entry(date), entry(older, theme: 'heat', photo: false)]),
      fetchContent: (url) async {
        contentUrls?.add(url);
        return jsonEncode(
          url.path.endsWith('/id.json') ? idContent() : content['en'],
        );
      },
    );

/// A backend stand-in with the same awarding rules (stop XP once, first quiz pass, lab approval).
class FakeGuidesServer {
  final calls = <Map<String, dynamic>>[];
  final events = <String>{};
  final stops = <String, Map<String, String>>{};
  bool offline = false;
  Map<String, dynamic> lab = {
    'verdict': 'approved',
    'reason_en': 'All three are visible.',
    'reason_id': 'Ketiganya terlihat.',
    'checklist': [true, true, true],
  };
  static const xp = {'story': 10, 'physics': 20, 'quiz': 10, 'lab': 20};

  Map<String, dynamic> get summary => {
    'issues': {
      for (final e in stops.entries)
        e.key: {
          'stops': e.value,
          'quiz': {},
          'lab': {},
          'xp': e.value.keys.fold<int>(0, (s, k) => s + xp[k]!),
        },
    },
    'streak': stops.isEmpty ? 0 : 1,
    'best_streak': stops.isEmpty ? 0 : 1,
    'week': [
      for (final (i, s) in [
        'missed',
        'off',
        'read',
        'off',
        'read',
        'read',
        'today',
      ].indexed)
        {'date': '2026-11-0${3 + i}', 'status': s},
    ],
    'total_xp': stops.values.fold<int>(
      0,
      (s, m) => s + m.keys.fold<int>(0, (a, k) => a + xp[k]!),
    ),
  };

  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    if (offline) throw const SocketException('offline');
    calls.add(body);
    String? award(String stop) {
      final m = stops.putIfAbsent('${body['date']}', () => {});
      if (m.containsKey(stop)) return null;
      m[stop] = '2026-11-08T03:00:00.000Z';
      return stop;
    }

    switch (body['op']) {
      case 'event':
        if (!events.add('${body['id']}')) {
          return {'ok': true, 'duplicate': true, 'progress': summary};
        }
        award(body['type'] == 'story_read' ? 'story' : 'physics');
        return {'ok': true, 'progress': summary};
      case 'quiz':
        final answers = {
          for (final a in body['answers'] as List) a['qid']: a['choice'],
        };
        final score = [
          answers['p1'] == 'b',
          answers['p2'] == 'a',
          answers['p3'] == 'c',
        ].where((x) => x).length;
        final got = score >= 2 && events.add('${body['id']}')
            ? award('quiz')
            : null;
        return {
          'score': score,
          'passed': score >= 2,
          'xp_awarded': got == null ? 0 : 10,
          'results': [],
          'progress': summary,
        };
      case 'lab':
        final got = lab['verdict'] == 'approved' ? award('lab') : null;
        return {
          ...lab,
          'xp_awarded': got == null ? 0 : 20,
          'progress': summary,
        };
      case 'review':
        return {'ok': true, 'progress': summary};
      case 'bad':
        throw CloudHttpException(400, 'bad');
      default:
        return summary;
    }
  }
}

/// Serves one in-memory JPEG for every guide photo URL and records the URLs.
class PhotoCache implements BaseCacheManager {
  PhotoCache(this.bytes);
  final Uint8List bytes;
  final urls = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    urls.add(url);
    final f = await MemoryCacheSystem().createFile('photo.jpg');
    await f.writeAsBytes(bytes);
    yield FileInfo(f, FileSource.Cache, DateTime(2100), url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A river-ish test photo (bands of colour), 600 x 400.
Uint8List testPhoto() {
  final im = img.Image(width: 600, height: 400);
  for (var y = 0; y < 400; y++) {
    for (var x = 0; x < 600; x++) {
      final band = ((x + y * 2) ~/ 60) % 3;
      im.setPixelRgb(
        x,
        y,
        [120, 96, 70][band],
        [94, 110, 84][band],
        [80, 120, 130][band],
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 85));
}

/// Progress files in memory (widget tests run in fake time, where real file I/O stalls).
class MemoryProgressFiles extends GuideProgressFiles {
  final files = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> read(String uid) async => files[uid] == null
      ? {}
      : jsonDecode(jsonEncode(files[uid])) as Map<String, dynamic>;

  @override
  Future<void> write(String uid, Map<String, dynamic> data) async =>
      files[uid] = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  @override
  Future<List<(String, Map<String, dynamic>)>> others(String uid) async => [
    for (final e in files.entries)
      if (e.key != uid) (e.key, e.value),
  ];
}

/// Overrides for an isolated account with in-memory progress by default.
List<Override> guideOverrides({
  required FakeGuidesServer server,
  DailyGuideService? service,
  GuideProgressFiles? files,
  User? user,
}) {
  return [
    dailyGuideServiceProvider.overrideWithValue(service ?? fakeService()),
    guidesCallProvider.overrideWithValue(server.call),
    guideProgressFilesProvider.overrideWithValue(
      files ?? MemoryProgressFiles(),
    ),
    currentUserProvider.overrideWithValue(
      user ?? MockUser(uid: 'student-1', isAnonymous: false),
    ),
    // The Learn clover sticker counts opened simulations (0211).
    physicsProgressProvider.overrideWith(
      (ref) => PhysicsProgressNotifier(
        ProgressService(firestore: FakeFirebaseFirestore()),
        null,
        false,
      ),
    ),
  ];
}
