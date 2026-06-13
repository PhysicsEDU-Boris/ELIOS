import 'package:cloud_firestore/cloud_firestore.dart';

class VideoLesson {
  final String id;
  final String moduleId;
  final String sectionTitle;
  final String title;
  final String description;
  final int durationMinutes;
  final String durationLabel;
  final String videoPath;
  final String thumbnailPath;
  final String youtubeId;
  final String thumbnailAsset;
  final String level;
  final String moduleLabel;
  final String status;
  final bool isFeatured;
  final int order;
  final bool isPublished;

  const VideoLesson({
    required this.id,
    required this.moduleId,
    required this.sectionTitle,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.durationLabel,
    required this.videoPath,
    required this.thumbnailPath,
    required this.youtubeId,
    required this.thumbnailAsset,
    required this.level,
    required this.moduleLabel,
    required this.status,
    required this.isFeatured,
    required this.order,
    required this.isPublished,
  });

  factory VideoLesson.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    return VideoLesson(
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      sectionTitle: map['sectionTitle'] is String
          ? map['sectionTitle'] as String
          : '',
      title: map['title'] is String ? map['title'] as String : '',
      description: map['description'] is String
          ? map['description'] as String
          : '',
      durationMinutes: map['durationMinutes'] is num
          ? (map['durationMinutes'] as num).toInt()
          : 0,
      durationLabel: map['durationLabel'] is String
          ? map['durationLabel'] as String
          : '',
      videoPath: map['videoPath'] is String ? map['videoPath'] as String : '',
      thumbnailPath: map['thumbnailPath'] is String
          ? map['thumbnailPath'] as String
          : '',
      youtubeId: map['youtubeId'] as String? ?? '',
      thumbnailAsset: map['thumbnailAsset'] as String? ?? '',
      level: map['level'] is String ? map['level'] as String : '',
      moduleLabel: map['moduleLabel'] is String
          ? map['moduleLabel'] as String
          : '',
      status: map['status'] is String ? map['status'] as String : 'soon',
      isFeatured: map['isFeatured'] is bool ? map['isFeatured'] as bool : false,
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
      isPublished: map['isPublished'] is bool
          ? map['isPublished'] as bool
          : false,
    );
  }

  factory VideoLesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return VideoLesson.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moduleId': moduleId,
      'sectionTitle': sectionTitle,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'durationLabel': durationLabel,
      'videoPath': videoPath,
      'thumbnailPath': thumbnailPath,
      'youtubeId': youtubeId,
      'thumbnailAsset': thumbnailAsset,
      'level': level,
      'moduleLabel': moduleLabel,
      'status': status,
      'isFeatured': isFeatured,
      'order': order,
      'isPublished': isPublished,
    };
  }
}
