import 'package:cloud_firestore/cloud_firestore.dart';

class GuideLesson {
  final String id;
  final String moduleId;
  final String moduleTitle;
  final String title;
  final String description;
  final String pdfUrl;
  final String coverUrl;
  final int pageCount;
  final int readTimeMinutes;
  final int order;
  final bool isPublished;

  const GuideLesson({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    required this.description,
    required this.pdfUrl,
    required this.coverUrl,
    this.pageCount = 0,
    this.readTimeMinutes = 0,
    required this.order,
    required this.isPublished,
  });

  factory GuideLesson.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    final pdfUrl = _readString(map, 'pdfUrl') ?? '';
    final coverUrl = _readString(map, 'coverUrl') ?? '';

    return GuideLesson(
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      moduleTitle: map['moduleTitle'] is String
          ? map['moduleTitle'] as String
          : '',
      title: map['title'] is String ? map['title'] as String : '',
      description: map['description'] is String
          ? map['description'] as String
          : '',
      pdfUrl: pdfUrl,
      coverUrl: coverUrl,
      pageCount: map['pageCount'] is num
          ? (map['pageCount'] as num).toInt()
          : 0,
      readTimeMinutes: map['readTimeMinutes'] is num
          ? (map['readTimeMinutes'] as num).toInt()
          : 0,
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
      isPublished: map['isPublished'] is bool
          ? map['isPublished'] as bool
          : false,
    );
  }

  factory GuideLesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return GuideLesson.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'title': title,
      'description': description,
      'pdfUrl': pdfUrl,
      'coverUrl': coverUrl,
      'pageCount': pageCount,
      'readTimeMinutes': readTimeMinutes,
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
