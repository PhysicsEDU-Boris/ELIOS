import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_i18n.dart';
import 'content_media.dart';

class VideoLesson {
  /// Translated fields by language (decision 0185); empty when none.
  final Map<String, dynamic> i18n;
  final String id;
  final String moduleId;
  final String _sectionTitle;
  String get sectionTitle => contentText(i18n, 'sectionTitle', _sectionTitle);
  final String _title;
  String get title => contentText(i18n, 'title', _title);
  final String _description;
  String get description => contentText(i18n, 'description', _description);
  final int durationMinutes;
  final int durationSeconds;
  final String durationLabel;
  final String videoUrl;
  final String _thumbnailUrl;
  String get thumbnailUrl => contentMediaUrl(_thumbnailUrl);
  final String youtubeId;
  final String level;
  final String moduleLabel;
  final String status;
  final bool isFeatured;
  final int order;
  final bool isPublished;

  const VideoLesson({
    required this.id,
    required this.moduleId,
    required String sectionTitle,
    required String title,
    required String description,
    required this.durationMinutes,
    this.durationSeconds = 0,
    required this.durationLabel,
    required this.videoUrl,
    required String thumbnailUrl,
    required this.youtubeId,
    required this.level,
    required this.moduleLabel,
    required this.status,
    required this.isFeatured,
    required this.order,
    required this.isPublished,
    this.i18n = const {},
  }) : _thumbnailUrl = thumbnailUrl,
       _sectionTitle = sectionTitle,
       _title = title,
       _description = description;

  factory VideoLesson.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['id'];
    final parsedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId
        : documentId;
    final durationLabel = map['durationLabel'] is String
        ? map['durationLabel'] as String
        : '';
    final durationMinutes = map['durationMinutes'] is num
        ? (map['durationMinutes'] as num).toInt()
        : 0;

    final videoUrl = _readString(map, 'videoUrl') ?? '';
    final thumbnailUrl = _readString(map, 'thumbnailUrl') ?? '';

    return VideoLesson(
      i18n: contentI18n(map),
      id: parsedId,
      moduleId: map['moduleId'] is String ? map['moduleId'] as String : '',
      sectionTitle: map['sectionTitle'] is String
          ? map['sectionTitle'] as String
          : '',
      title: map['title'] is String ? map['title'] as String : '',
      description: map['description'] is String
          ? map['description'] as String
          : '',
      durationMinutes: durationMinutes,
      durationSeconds: map['durationSeconds'] is num
          ? (map['durationSeconds'] as num).toInt()
          : _durationSecondsFromLabel(durationLabel) ?? durationMinutes * 60,
      durationLabel: durationLabel,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      youtubeId: map['youtubeId'] as String? ?? '',
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
      if (i18n.isNotEmpty) 'i18n': i18n,
      'id': id,
      'moduleId': moduleId,
      'sectionTitle': _sectionTitle,
      'title': _title,
      'description': _description,
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'durationLabel': durationLabel,
      'videoUrl': videoUrl,
      'thumbnailUrl': _thumbnailUrl,
      'youtubeId': youtubeId,
      'level': level,
      'moduleLabel': moduleLabel,
      'status': status,
      'isFeatured': isFeatured,
      'order': order,
      'isPublished': isPublished,
    };
  }

  /// [youtubeId], or the id parsed from [videoUrl] (watch?v=, youtu.be/,
  /// /embed/, /shorts/, /live/). Empty when neither has one.
  String get resolvedYoutubeId {
    final id = youtubeId.trim();
    if (id.isNotEmpty) return id;
    return parseYoutubeId(videoUrl) ?? '';
  }

  static final _youtubeIdPattern = RegExp(
    r'(?:youtube(?:-nocookie)?\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|live/|v/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  );

  static String? parseYoutubeId(String url) =>
      _youtubeIdPattern.firstMatch(url.trim())?.group(1);

  /// Returns a non-empty String value for [key], or `null`.
  static String? _readString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  static int? _durationSecondsFromLabel(String label) {
    final parts = label.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    var total = 0;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0) return null;
      total = total * 60 + value;
    }
    return total;
  }
}
