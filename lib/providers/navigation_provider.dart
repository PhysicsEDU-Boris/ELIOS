import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

enum LearningResumeType { video, guide, quiz }

class LearningResumeIntent {
  final LearningResumeType type;
  final String id;
  final String? moduleId;

  const LearningResumeIntent({
    required this.type,
    required this.id,
    this.moduleId,
  });
}

final learningResumeIntentProvider = StateProvider<LearningResumeIntent?>(
  (ref) => null,
);
