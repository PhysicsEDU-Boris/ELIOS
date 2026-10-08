import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/physics/quiz/physics_quiz_state.dart';

void main() {
  group('PhysicsQuiz Distractor Uniqueness', () {
    test('All options (including conceptual distractors) produce unique values for at least some random seed', () {
      final rand = Random(42); // Fixed seed for reproducibility in this test
      
      for (final q in physicsQuizQuestions) {
        bool foundUnique = false;
        
        // Try up to 100 times to find a random set of inputs where all 4 options are different.
        // It's possible for some random inputs that two wrong distractors accidentally equal each other
        // (or equal the correct answer), but over 100 tries, we should find at least one where they are distinct.
        for (int i = 0; i < 100; i++) {
          final data = q.randomize(rand);
          final options = q.options(data);
          
          final uniqueOptions = options.toSet();
          if (uniqueOptions.length == 4) {
            foundUnique = true;
            break;
          }
        }
        
        expect(
          foundUnique, 
          isTrue, 
          reason: 'Module ${q.moduleId} failed to produce 4 distinct options across 100 random tries. '
                  'Check your distractor formulas to ensure they do not collapse to the same value.'
        );
      }
    });
  });
}
