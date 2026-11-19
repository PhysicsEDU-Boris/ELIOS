import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/scan_record_store.dart';

// Isolated widget fixture; never inserted into the owner's History.
const h3Explanation = QuizExplanation(
  summary: 'Pisahkan baterai sebelum mendaur ulang wadah.',
  correctAnswerReason:
      'Baterai dapat terbakar saat tergencet. Memisahkannya melindungi petugas dan menjaga plastik tetap bersih.',
  selectedAnswerFeedback:
      'Baterai memerlukan pengumpulan B3, terpisah dari plastik yang akan didaur ulang.',
  keyIdea:
      'Satu benda dapat memuat beberapa jenis sampah. Pisahkan bahan sebelum memilahnya.',
  steps: [
    'Keluarkan baterai dengan bantuan orang dewasa.',
    'Bersihkan wadah dan biarkan kering.',
    'Serahkan baterai ke tempat pengumpulan B3.',
  ],
  source: 'bank',
  bankId: 'test-reviewed',
  sourceTitle: 'SOURCE_MUST_NOT_RENDER',
  sourceSection: 'MODULE_MUST_NOT_RENDER',
  quote: 'QUOTE_MUST_NOT_RENDER',
  groundingStatus: GroundingStatus.bankGrounded,
);
ScanRecord h3Record({bool cached = true, bool essay = false, String? photo}) =>
    ScanRecord(
      id: 'h3-test',
      time: DateTime.now(),
      itemName: 'Wadah earphone',
      category: ScanCategory.b3,
      cropPhotoPath: photo,
      questions: [
        RecordQuestion(
          question:
              'Apa yang perlu dilakukan sebelum mendaur ulang wadah earphone?',
          options: const ['Pisahkan baterainya.', 'Campur dengan baterai.'],
          yourAnswer: 'Campur dengan baterai.',
          rightAnswer: 'Pisahkan baterainya.',
          isCorrect: false,
          isEssay: essay,
          essayScore: essay ? 7 : null,
          explanation: cached ? h3Explanation : null,
        ),
        const RecordQuestion(
          question: 'Mengapa plastik harus bersih?',
          yourAnswer: 'Agar bahan tetap murni.',
          rightAnswer: 'Agar bahan tetap murni.',
          isCorrect: true,
          explanation: h3Explanation,
        ),
      ],
    );

class HistoryTestStore extends ScanRecordStore {
  HistoryTestStore([List<ScanRecord> records = const []]) : data = records;
  List<ScanRecord> data;
  @override
  List<ScanRecord> get records => data;
  @override
  bool get isLoaded => true;
  @override
  int get totalTrophies => data.fold(0, (sum, r) => sum + r.trophies);
  @override
  Future<List<ScanRecord>> load({bool force = false}) async => data;
}
