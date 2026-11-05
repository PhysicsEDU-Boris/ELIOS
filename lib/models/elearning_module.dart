import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_i18n.dart';

class ElearningModule {
  /// Translated fields by language (decision 0185); empty when none.
  final Map<String, dynamic> i18n;
  final String id;
  final String _title;
  String get title => contentText(i18n, 'title', _title);
  final String _description;
  String get description => contentText(i18n, 'description', _description);
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
    required String title,
    required String description,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.lessonCount,
    required this.thumbnailUrl,
    required this.guideUrl,
    required this.order,
    required this.isPublished,
    this.i18n = const {},
  }) : _title = title, _description = description;

  factory ElearningModule.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    final thumbnailUrl = _readString(map, 'thumbnailUrl') ?? '';
    final guideUrl = _readString(map, 'guideUrl') ?? '';

    return ElearningModule(
      i18n: contentI18n(map),
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
      if (i18n.isNotEmpty) 'i18n': i18n,
      'id': id,
      'title': _title,
      'description': _description,
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
