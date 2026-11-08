import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/guide_lesson.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:elio/services/history_cloud.dart';
import 'package:elio/services/scan_record_store.dart';

class MemoryCloud extends HistoryCloud {
  MemoryCloud(String uid) : super(ownerId: uid, token: () async => 'test');
  final records = <String, Map<String, dynamic>>{};
  bool offline = false;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    if (offline) throw const SocketException('offline');
    if (body['op'] == 'save') {
      records[body['id'] as String] = Map.from(body['data'] as Map);
    }
    return body['op'] == 'list'
        ? {
            'records': [
              for (final r in records.values) {'data': r, 'has_photo': false},
            ],
          }
        : {'ok': true};
  }
}

ScanRecord record(String id) => ScanRecord(
  id: id,
  time: DateTime(2026, 11, 8),
  itemName: 'Bottle',
  category: ScanCategory.recyclable,
  questions: const [
    RecordQuestion(
      question: 'Q',
      yourAnswer: 'A',
      rightAnswer: 'A',
      isCorrect: true,
    ),
  ],
);
void main() {
  test('recovered guide title and PDF follow both app languages', () {
    final guide = GuideLesson.fromMap({
      'title': 'Categories of Organic Waste',
      'pdfUrl':
          'https://res.cloudinary.com/ks5c3ln4/image/upload/v1783509989/Module2_Categories_of_Organic_Waste_cb4tbs.pdf',
    }, 'module2_organic_categories');
    debugSetL10n(const Locale('id'));
    expect(guide.title, 'Kategori Sampah Organik');
    expect(guide.pdfUrl, contains('_id.pdf'));
    debugSetL10n(const Locale('en'));
    expect(guide.title, 'Categories of Organic Waste');
    expect(guide.pdfUrl, contains('/zkebg27g/'));
    expect(guide.pdfUrl, isNot(contains('_id.pdf')));
    debugSetL10n(const Locale('id'));
  });
  test('failed local insert never appears as durable history', () async {
    final dir = await Directory.systemTemp.createTemp(
      'history-insert-failure-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/records.json');
    final store = ScanRecordStore(customFile: file);
    await store.load();
    Directory(file.path).createSync();
    await expectLater(
      store.addRecord(record('scan-failed')),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.records, isEmpty);
    expect(store.pendingCount, 0);
  });
  test(
    'guide selects the language PDF while keeping original serialized content',
    () {
      final guide = GuideLesson.fromMap({
        'pdfUrl': 'https://example.com/id.pdf',
        'i18n': {
          'en': {'pdfUrl': 'https://example.com/en.pdf'},
        },
      }, 'guide');
      debugSetL10n(const Locale('en'));
      expect(guide.pdfUrl, 'https://example.com/en.pdf');
      expect(guide.toMap()['pdfUrl'], 'https://example.com/id.pdf');
      debugSetL10n(const Locale('id'));
      expect(guide.pdfUrl, 'https://example.com/id.pdf');
    },
  );
  test(
    'offline queue survives restart and sync restores full records without duplicates',
    () async {
      final dir = await Directory.systemTemp.createTemp('history-cloud-');
      addTearDown(() => dir.delete(recursive: true));
      final cloud = MemoryCloud('A')..offline = true;
      final file = File('${dir.path}/a.json');
      final a = ScanRecordStore(customFile: file, ownerId: 'A', cloud: cloud)
        ..active = false;
      await a.addRecord(record('scan-1'));
      expect(a.pendingCount, 1);
      final reopened = ScanRecordStore(
        customFile: file,
        ownerId: 'A',
        cloud: cloud,
      );
      await reopened.load();
      expect(reopened.pendingCount, 1);
      await reopened.sync();
      expect(reopened.syncError, isNotNull);
      expect(reopened.records.single.questions.single.yourAnswer, 'A');
      cloud.offline = false;
      await reopened.sync();
      await reopened.sync();
      expect(reopened.pendingCount, 0);
      expect(reopened.records.length, 1);
      expect(cloud.records.length, 1);
      final otherDevice = ScanRecordStore(
        customFile: File('${dir.path}/new.json'),
        ownerId: 'A',
        cloud: cloud,
      );
      await otherDevice.sync();
      expect(otherDevice.totalTrophies, reopened.totalTrophies);
      expect(
        otherDevice.records.single.toJson(),
        reopened.records.single.toJson(),
      );
    },
  );
  test(
    'account switches detach old store and never expose legacy records',
    () async {
      final old = ScanRecordStore();
      ScanRecordStore.setInstanceForTesting(old);
      ScanRecordStore.selectAccount('A');
      final a = ScanRecordStore.instance;
      expect(old.active, false);
      expect(a.ownerId, 'A');
      ScanRecordStore.selectAccount('B');
      expect(a.active, false);
      expect(ScanRecordStore.instance.ownerId, 'B');
      ScanRecordStore.setInstanceForTesting(null);
    },
  );
}
