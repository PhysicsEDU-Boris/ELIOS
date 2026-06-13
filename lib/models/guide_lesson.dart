import 'package:cloud_firestore/cloud_firestore.dart';

class GuideLesson {
  final String id;
  final String moduleId;
  final String moduleTitle;
  final String title;
  final String description;
  final String pdfPath;
  final String pdfAsset;
  final String coverAsset;
  final int order;
  final bool isPublished;

  const GuideLesson({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    required this.description,
    required this.pdfPath,
    required this.pdfAsset,
    required this.coverAsset,
    required this.order,
    required this.isPublished,
  });

  factory GuideLesson.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

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
      pdfPath: map['pdfPath'] is String ? map['pdfPath'] as String : '',
      pdfAsset: map['pdfAsset'] as String? ?? '',
      coverAsset: map['coverAsset'] as String? ?? '',
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
      'pdfPath': pdfPath,
      'pdfAsset': pdfAsset,
      'coverAsset': coverAsset,
      'order': order,
      'isPublished': isPublished,
    };
  }
}
