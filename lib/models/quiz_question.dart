import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_i18n.dart';

class QuizQuestion {
  /// Translated fields by language (decision 0185); empty when none.
  final Map<String, dynamic> i18n;
  final String id;
  final String moduleId;
  final String _question;
  String get question => contentText(i18n, 'question', _question);
  final String imageUrl;
  final List<String> _options;
  List<String> get options => contentList(i18n, 'options', _options);
  final int correctIndex;
  final String _explanation;
  String get explanation => contentText(i18n, 'explanation', _explanation);
  final String difficulty;
  final int order;

  const QuizQuestion({
    required this.id,
    required this.moduleId,
    required String question,
    required this.imageUrl,
    required List<String> options,
    required this.correctIndex,
    required String explanation,
    required this.difficulty,
    required this.order,
    this.i18n = const {},
  }) : _question = question, _explanation = explanation, _options = options;

  factory QuizQuestion.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? List<String>.from(rawOptions.map((item) => item.toString()))
        : <String>[];

    final imageUrl = _readString(map, 'imageUrl') ?? '';

    return QuizQuestion(
      i18n: contentI18n(map),
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      question: map['question'] is String ? map['question'] as String : '',
      imageUrl: imageUrl,
      options: options,
      correctIndex: map['correctIndex'] is num
          ? (map['correctIndex'] as num).toInt()
          : 0,
      explanation: map['explanation'] is String
          ? map['explanation'] as String
          : '',
      difficulty: map['difficulty'] is String
          ? map['difficulty'] as String
          : '',
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
    );
  }

  factory QuizQuestion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return QuizQuestion.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      if (i18n.isNotEmpty) 'i18n': i18n,
      'id': id,
      'moduleId': moduleId,
      'question': _question,
      'imageUrl': imageUrl,
      'options': _options,
      'correctIndex': correctIndex,
      'explanation': _explanation,
      'difficulty': difficulty,
      'order': order,
    };
  }

  /// Returns a non-empty String value for [key], or `null`.
  static String? _readString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }
}
