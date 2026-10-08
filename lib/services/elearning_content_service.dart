import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/elearning_module.dart';
import '../models/guide_lesson.dart';
import '../models/quiz_question.dart';
import '../models/quiz_set.dart';
import '../models/video_lesson.dart';

class ElearningContentService {
  static const _validModuleIds = {'organic', 'inorganic', 'hazardous'};

  final FirebaseFirestore _firestore;

  ElearningContentService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ElearningModule>> watchModules() {
    return _firestore
        .collection('elearning_modules')
        .where('isPublished', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ElearningModule.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<VideoLesson>> watchVideoLessons({String? moduleId}) {
    final validatedModuleId = _validatedModuleId(moduleId);
    Query<Map<String, dynamic>> query = _firestore
        .collection('video_lessons')
        .where('isPublished', isEqualTo: true);

    if (validatedModuleId != null) {
      query = query.where('moduleId', isEqualTo: validatedModuleId);
    }

    return query
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(VideoLesson.fromFirestore)
              .where((lesson) => _validModuleIds.contains(lesson.moduleId))
              .toList(growable: false),
        );
  }

  Stream<List<GuideLesson>> watchGuideLessons({String? moduleId}) {
    final validatedModuleId = _validatedModuleId(moduleId);
    Query<Map<String, dynamic>> query = _firestore
        .collection('guide_lessons')
        .where('isPublished', isEqualTo: true);

    if (validatedModuleId != null) {
      query = query.where('moduleId', isEqualTo: validatedModuleId);
    }

    return query
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GuideLesson.fromFirestore)
              .where((lesson) => _validModuleIds.contains(lesson.moduleId))
              .toList(growable: false),
        );
  }

  Stream<List<QuizSet>> watchQuizSets({String? moduleId}) {
    final validatedModuleId = _validatedModuleId(moduleId);
    Query<Map<String, dynamic>> query = _firestore
        .collection('quiz_sets')
        .where('isPublished', isEqualTo: true);

    if (validatedModuleId != null) {
      query = query.where('moduleId', isEqualTo: validatedModuleId);
    }

    return query
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(QuizSet.fromFirestore)
              .where((quizSet) => _validModuleIds.contains(quizSet.moduleId))
              .toList(growable: false),
        );
  }

  Future<List<QuizQuestion>> fetchQuizQuestions(String moduleId) async {
    final validatedModuleId = _validatedModuleId(moduleId);
    if (validatedModuleId == null) {
      throw ArgumentError.value(moduleId, 'moduleId', 'Must not be empty.');
    }

    final snapshot = await _firestore
        .collection('quizzes')
        .doc(validatedModuleId)
        .collection('questions')
        .orderBy('order')
        .get();

    return snapshot.docs
        .map(QuizQuestion.fromFirestore)
        .toList(growable: false);
  }

  String? _validatedModuleId(String? moduleId) {
    final normalized = moduleId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (!_validModuleIds.contains(normalized)) {
      throw ArgumentError.value(
        moduleId,
        'moduleId',
        'Must be organic, inorganic, or hazardous.',
      );
    }
    return normalized;
  }
}
