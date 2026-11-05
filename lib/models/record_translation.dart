import 'quiz_explanation.dart';

/// The texts of one saved question in another language (decision 0185).
/// Correctness, trophies, scores and source metadata stay on the original.
class QuestionText {
  const QuestionText({
    required this.question,
    this.options = const [],
    required this.yourAnswer,
    required this.rightAnswer,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final String yourAnswer;
  final String rightAnswer;

  /// The saved explanation translated, or null when the original had none
  /// when this translation was made.
  final QuizExplanation? explanation;

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'yourAnswer': yourAnswer,
    'rightAnswer': rightAnswer,
    if (explanation != null) 'explanation': explanation!.toJson(),
  };

  factory QuestionText.fromJson(Map<String, dynamic> json) => QuestionText(
    question: json['question'] as String? ?? '',
    options: (json['options'] as List?)?.cast<String>() ?? const [],
    yourAnswer: json['yourAnswer'] as String? ?? '',
    rightAnswer: json['rightAnswer'] as String? ?? '',
    explanation: json['explanation'] is Map
        ? QuizExplanation.fromJson(
            Map<String, dynamic>.from(json['explanation'] as Map),
          )
        : null,
  );
}

/// A whole record translated once into one language and cached with it.
class RecordTranslation {
  const RecordTranslation({required this.itemName, required this.questions});

  final String itemName;
  final List<QuestionText> questions;

  Map<String, dynamic> toJson() => {
    'itemName': itemName,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory RecordTranslation.fromJson(Map<String, dynamic> json) =>
      RecordTranslation(
        itemName: json['itemName'] as String? ?? '',
        questions: [
          for (final q in json['questions'] as List? ?? const [])
            QuestionText.fromJson(Map<String, dynamic>.from(q as Map)),
        ],
      );
}
