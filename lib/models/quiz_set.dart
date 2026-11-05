import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_i18n.dart';

class QuizSet {
  /// Translated fields by language (decision 0185); empty when none.
  final Map<String, dynamic> i18n;
  final String id;
  final String moduleId;
  final String _title;
  String get title => contentText(i18n, 'title', _title);
  final String _description;
  String get description => contentText(i18n, 'description', _description);
  final String level;
  final int questionCount;
  final String iconType;
  final String theme;
  final int order;
  final bool isPublished;

  const QuizSet({
    required this.id,
    required this.moduleId,
    required String title,
    required String description,
    required this.level,
    required this.questionCount,
    required this.iconType,
    required this.theme,
    required this.order,
    required this.isPublished,
    this.i18n = const {},
  }) : _title = title, _description = description;

  factory QuizSet.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;

    return QuizSet(
      i18n: contentI18n(map),
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      title: map['title'] is String ? map['title'] as String : '',
      description: map['description'] is String
          ? map['description'] as String
          : '',
      level: map['level'] is String ? map['level'] as String : '',
      questionCount: map['questionCount'] is num
          ? (map['questionCount'] as num).toInt()
          : 0,
      iconType: map['iconType'] is String ? map['iconType'] as String : '',
      theme: map['theme'] is String ? map['theme'] as String : '',
      order: map['order'] is num ? (map['order'] as num).toInt() : 0,
      isPublished: map['isPublished'] is bool
          ? map['isPublished'] as bool
          : false,
    );
  }

  factory QuizSet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return QuizSet.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      if (i18n.isNotEmpty) 'i18n': i18n,
      'id': id,
      'moduleId': moduleId,
      'title': _title,
      'description': _description,
      'level': level,
      'questionCount': questionCount,
      'iconType': iconType,
      'theme': theme,
      'order': order,
      'isPublished': isPublished,
    };
  }
}
