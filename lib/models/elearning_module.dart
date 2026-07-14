import 'package:cloud_firestore/cloud_firestore.dart';

class ElearningModule {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final int durationMinutes;
  final int lessonCount;
  final String thumbnailUrl;
  final String guideUrl;
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
    required this.thumbnailUrl,
    required this.guideUrl,
    required this.order,
    required this.isPublished,
  });

  factory ElearningModule.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    final thumbnailUrl = _readString(map, 'thumbnailUrl') ?? '';
    final guideUrl = _readString(map, 'guideUrl') ?? '';

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
      thumbnailUrl: thumbnailUrl,
      guideUrl: guideUrl,
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
      'thumbnailUrl': thumbnailUrl,
      'guideUrl': guideUrl,
      'order': order,
      'isPublished': isPublished,
    };
  }

  /// Returns a non-empty String value for [key], or `null`.
  static String? _readString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }
}
