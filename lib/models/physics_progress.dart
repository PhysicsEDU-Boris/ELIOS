import 'dart:convert';

class PhysicsProgress {
  final Set<String> viewedModuleIds;
  final Map<String, int> quizBestScores;
  final DateTime? lastUpdated;

  const PhysicsProgress({
    this.viewedModuleIds = const {},
    this.quizBestScores = const {},
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
    'viewedModuleIds': viewedModuleIds.toList(),
    'quizBestScores': quizBestScores,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory PhysicsProgress.fromMap(Map<String, dynamic> map) {
    return PhysicsProgress(
      viewedModuleIds: map['viewedModuleIds'] is List 
          ? (map['viewedModuleIds'] as List).whereType<String>().toSet() 
          : const {},
      quizBestScores: map['quizBestScores'] is Map
          ? (map['quizBestScores'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : const {},
      lastUpdated: map['lastUpdated'] is String
          ? DateTime.tryParse(map['lastUpdated'])
          : null,
    );
  }

  factory PhysicsProgress.empty() => const PhysicsProgress();

  String toJson() => jsonEncode(toMap());

  factory PhysicsProgress.fromJson(String source) => PhysicsProgress.fromMap(jsonDecode(source));
  
  PhysicsProgress copyWith({
    Set<String>? viewedModuleIds,
    Map<String, int>? quizBestScores,
    DateTime? lastUpdated,
  }) {
    return PhysicsProgress(
      viewedModuleIds: viewedModuleIds ?? this.viewedModuleIds,
      quizBestScores: quizBestScores ?? this.quizBestScores,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
