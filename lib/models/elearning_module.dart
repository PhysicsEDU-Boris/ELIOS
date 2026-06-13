import 'package:cloud_firestore/cloud_firestore.dart';

class ElearningModule {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final int durationMinutes;
  final int lessonCount;
  final String thumbnailPath;
  final String guidePath;
  final int order;
  final bool isPublished;

  const ElearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.lessonCount,
    required this.thumbnailPath,
    required this.guidePath,
    required this.order,
    required this.isPublished,
  });

  factory ElearningModule.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    return ElearningModule(
      id: parsedId,
      title: map['title'] is String ? map['title'] as String : '',
      description: map['description'] is String
          ? map['description'] as String
          : '',
      category: map['category'] is String ? map['category'] as String : '',
      level: map['level'] is String ? map['level'] as String : '',
      durationMinutes: map['durationMinutes'] is num
          ? (map['durationMinutes'] as num).toInt()
          : 0,
      lessonCount: map['lessonCount'] is num
          ? (map['lessonCount'] as num).toInt()
          : 0,
      thumbnailPath: map['thumbnailPath'] is String
          ? map['thumbnailPath'] as String
          : '',
      guidePath: map['guidePath'] is String ? map['guidePath'] as String : '',
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
      isPublished: map['isPublished'] is bool
          ? map['isPublished'] as bool
          : false,
    );
  }

  factory ElearningModule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ElearningModule.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'level': level,
      'durationMinutes': durationMinutes,
      'lessonCount': lessonCount,
      'thumbnailPath': thumbnailPath,
      'guidePath': guidePath,
      'order': order,
      'isPublished': isPublished,
    };
  }
}
