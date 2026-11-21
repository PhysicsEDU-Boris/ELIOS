// A skipped / time's-up answer shows in the app's language, whatever language
// it was saved in (found on the phone 21 Nov: "(waktu habis)" in English).
import 'package:elio/models/scan_record.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecord _record(String answer, {String lang = 'id'}) => ScanRecord(
  id: 'r',
  time: DateTime(2026, 11, 21),
  itemName: 'Plastic cup',
  category: ScanCategory.recyclable,
  lang: lang,
  questions: [
    RecordQuestion(
      question: 'Why does a plastic cup float?',
      yourAnswer: answer,
      rightAnswer: 'Lower density',
      isCorrect: false,
    ),
  ],
);

String _shown(ScanRecord r, String lang) =>
    r.localized(lang).questions.single.yourAnswer;

void main() {
  test('time up saved in Indonesian reads "(time\'s up)" in English', () {
    expect(_shown(_record('(waktu habis)'), 'en'), "(time's up)");
    expect(_shown(_record('(waktu habis)'), 'id'), '(waktu habis)');
  });

  test('skipped follows the app language both ways', () {
    expect(_shown(_record('(skipped)', lang: 'en'), 'id'), isNot('(skipped)'));
    final id = _shown(_record('(skipped)', lang: 'en'), 'id');
    expect(_shown(_record(id), 'en'), '(skipped)');
  });

  test('a real answer is never changed', () {
    expect(_shown(_record('Lower weight'), 'en'), 'Lower weight');
    expect(_shown(_record('(waktu habis)', lang: ''), ''), '(waktu habis)');
  });
}
