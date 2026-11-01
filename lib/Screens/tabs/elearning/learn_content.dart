import '../../../models/guide_lesson.dart';
import '../../../models/learning_progress.dart';
import '../../../models/physics_module.dart';
import '../../../models/video_lesson.dart';

/// Bundled L1 v2 illustrations (Figma 293:2359). Placeholders and fallbacks
/// only: real thumbnails come from Firestore URLs (decision 0171).
abstract final class LearnArt {
  static const _dir = 'assets/illustrations/learn';
  static const mascot = '$_dir/elio_quiz_mascot.svg';
  static const coverOrganik = '$_dir/cover_organik.svg';
  static const coverAnorganik = '$_dir/cover_anorganik.svg';
  static const coverB3 = '$_dir/cover_b3.svg';
  static const coverIntro = '$_dir/cover_intro.svg';
  static const coverBiogas = '$_dir/cover_biogas.svg';
  static const coverReuse = '$_dir/cover_reuse.svg';
  static const coverSafeHandling = '$_dir/cover_safe_handling.svg';
  static const stateEmpty = '$_dir/state_empty.svg';
  static const stateOffline = '$_dir/state_offline.svg';
  static const binOrganik = '$_dir/bin_organik.svg';
  static const binAnorganik = '$_dir/bin_anorganik.svg';
  static const binB3 = '$_dir/bin_b3.svg';

  /// Module cover; [alt] picks the second cover of the module (Biogas,
  /// Reuse, Safe handling) so neighbouring cards differ.
  static String cover(String moduleId, {bool alt = false}) => switch (moduleId) {
    'organic' => alt ? coverBiogas : coverOrganik,
    'inorganic' => alt ? coverReuse : coverAnorganik,
    'hazardous' => alt ? coverSafeHandling : coverB3,
    _ => coverIntro,
  };

  static String bin(String moduleId) => switch (moduleId) {
    'inorganic' => binAnorganik,
    'hazardous' => binB3,
    _ => binOrganik,
  };

  /// Simulation canvas; deep-dive and the quiz have none, so they use the
  /// intro cover and the mascot.
  static String simulation(PhysicsModuleId id) => switch (id) {
    PhysicsModuleId.density => '$_dir/sim_densitas.svg',
    PhysicsModuleId.heat => '$_dir/sim_panas.svg',
    PhysicsModuleId.torque => '$_dir/sim_torsi.svg',
    PhysicsModuleId.workEnergy => '$_dir/sim_usaha.svg',
    PhysicsModuleId.kinematics => '$_dir/sim_kinematika.svg',
    PhysicsModuleId.pwm => '$_dir/sim_pwm.svg',
    PhysicsModuleId.power => '$_dir/sim_daya.svg',
    PhysicsModuleId.deepDive => coverIntro,
    PhysicsModuleId.quiz => mascot,
  };
}

/// Simulation linked to each waste module (module page "Simulation for
/// this module").
PhysicsModuleId relatedSimulation(String moduleId) => switch (moduleId) {
  'organic' => PhysicsModuleId.heat,
  'hazardous' => PhysicsModuleId.power,
  _ => PhysicsModuleId.density,
};

/// Short bin name used on Bin cards and chips.
String binLabel(String moduleId) => switch (moduleId) {
  'organic' => 'Organik',
  'inorganic' => 'Anorganik',
  'hazardous' => 'B3',
  _ => moduleId,
};

enum LessonState { start, inProgress, done }

/// A video or a guide, so the hub, module and lesson pages can list both.
class LearnLesson {
  const LearnLesson.video(VideoLesson this.video) : guide = null;
  const LearnLesson.guide(GuideLesson this.guide) : video = null;

  final VideoLesson? video;
  final GuideLesson? guide;

  bool get isVideo => video != null;
  String get id => video?.id ?? guide!.id;
  String get moduleId => video?.moduleId ?? guide!.moduleId;
  String get title => video?.title ?? guide!.title;
  String get description => video?.description ?? guide!.description;
  int get order => video?.order ?? guide!.order;
  String get imageUrl => video?.thumbnailUrl ?? guide!.coverUrl;

  /// Bundled cover used while [imageUrl] loads or when it is empty or
  /// fails: foundation lessons get Intro, others alternate the module's two
  /// covers by order.
  String get fallbackArt {
    final tag = '${video?.sectionTitle ?? ''} ${video?.level ?? ''}'.toLowerCase();
    if (tag.contains('foundation')) return LearnArt.coverIntro;
    return LearnArt.cover(moduleId, alt: order.isEven);
  }

  /// "Video · Science" / "Guide · Part 2" from the Firestore fields present.
  String get meta {
    if (video case final v?) {
      final tag = v.level.trim().isNotEmpty ? v.level : v.sectionTitle;
      return tag.trim().isEmpty ? 'Video' : 'Video · $tag';
    }
    return 'Guide · Part ${guide!.order}';
  }

  /// "7:22" for videos, "12 min" or "8 pages" for guides, else empty.
  String get lengthLabel {
    if (video case final v?) {
      if (v.durationLabel.trim().isNotEmpty) return v.durationLabel;
      final s = v.durationSeconds;
      return s > 0 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '';
    }
    final g = guide!;
    if (g.readTimeMinutes > 0) return '${g.readTimeMinutes} min';
    return g.pageCount > 0 ? '${g.pageCount} pages' : '';
  }

  double progress(LearningProgress? p) {
    if (p == null) return 0;
    if (video case final v?) {
      if (p.completedVideoIds.contains(v.id)) return 1;
      final watched = p.videoWatchProgress[v.id] ?? 0;
      return v.durationSeconds > 0
          ? (watched / v.durationSeconds).clamp(0.0, 0.99)
          : 0;
    }
    final g = guide!;
    if (p.completedGuideIds.contains(g.id)) return 1;
    final page = p.guideReadProgress[g.id] ?? 0;
    return g.pageCount > 0 ? (page / g.pageCount).clamp(0.0, 0.99) : 0;
  }

  DateTime? lastAccessed(LearningProgress? p) => isVideo
      ? p?.videoLastAccessed[id]
      : p?.guideLastAccessed[id];

  LessonState state(LearningProgress? p) {
    final value = progress(p);
    if (value >= 1) return LessonState.done;
    if (value > 0 || lastAccessed(p) != null) return LessonState.inProgress;
    return LessonState.start;
  }

  String actionLabel(LearningProgress? p) => switch (state(p)) {
    LessonState.start => 'Start',
    LessonState.inProgress => 'Continue',
    LessonState.done => isVideo ? 'Watch again' : 'Read again',
  };
}

/// Videos and guides of one module (or all), by Firestore `order`.
List<LearnLesson> mergeLessons(
  Iterable<GuideLesson> guides,
  Iterable<VideoLesson> videos,
) => [
  ...guides.map(LearnLesson.guide),
  ...videos.map(LearnLesson.video),
]..sort((a, b) => a.order.compareTo(b.order));

/// In-progress lessons, newest access first (hub "Continue learning").
List<LearnLesson> inProgressLessons(
  List<LearnLesson> lessons,
  LearningProgress? p,
) {
  final list = lessons
      .where((l) => l.state(p) == LessonState.inProgress)
      .toList();
  list.sort((a, b) {
    final da = a.lastAccessed(p), db = b.lastAccessed(p);
    if (da == null || db == null) return da == null ? 1 : -1;
    return db.compareTo(da);
  });
  return list;
}

/// Module progress 0..1 as the share of finished lessons plus the quiz.
double moduleProgress(
  String moduleId,
  List<LearnLesson> lessons,
  LearningProgress? p,
) {
  final own = lessons.where((l) => l.moduleId == moduleId).toList();
  final quizDone = p?.completedQuizModules.contains(moduleId) ?? false;
  final total = own.length + 1;
  final sum = own.fold<double>(0, (s, l) => s + l.progress(p)) +
      (quizDone ? 1 : 0);
  return (sum / total).clamp(0.0, 1.0);
}
