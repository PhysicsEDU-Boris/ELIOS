import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String id;
  final String moduleId;
  final String question;
  final String imagePath;
  final String imageAsset;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;
  final int order;

  const QuizQuestion({
    required this.id,
    required this.moduleId,
    required this.question,
    required this.imagePath,
    required this.imageAsset,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.difficulty,
    required this.order,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? List<String>.from(rawOptions.map((item) => item.toString()))
        : <String>[];

    return QuizQuestion(
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      question: map['question'] is String ? map['question'] as String : '',
      imagePath: map['imagePath'] is String ? map['imagePath'] as String : '',
      imageAsset: map['imageAsset'] as String? ?? '',
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
      'id': id,
      'moduleId': moduleId,
      'question': question,
      'imagePath': imagePath,
      'imageAsset': imageAsset,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'difficulty': difficulty,
      'order': order,
    };
  }
}
