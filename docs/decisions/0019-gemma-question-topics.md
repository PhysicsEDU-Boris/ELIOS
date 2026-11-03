# 0019: Gemma questions ask about one physics angle, never LCA (M3.7)

- Status: Accepted
- Date: 2026-10-18
- Scope: Gemma question mode only (0018); bank mode unchanged.
- Code:
  - `lib/services/gemma_quiz_service.dart` (`questionAngles`, `pickAngle`, `questionPrompt`,
    `bannedTopicTerms`, level texts);
  - `lib/providers/waste_quiz_provider.dart` (`_usedAngles`, `angle` in the log line);
  - `lib/widgets/waste_quiz_popup.dart` (type chip).
- Tests: `test/gemma_topics_test.dart`.

## Step 1 findings (owner's recording, 18 Oct 11:26, plus 8 JSONL sessions)

The run had 4 Gemma sessions, all on Sulit with 5 questions each: Ponsel, Cup, Kertas and
Controller gaming. I read all 20 questions from frames cut at each `question_source` time.

- **16 of 20 mention LCA / siklus hidup or the circular economy:**
  - LCA or siklus hidup: 10;
  - ekonomi sirkular: 6, one only in an answer option.

  By object: Ponsel 4/5, Cup 4/5, Kertas 5/5, Controller 3/5. The other 4 are about policy
  ("kebijakan"), metal refining or handling risk.
- **Causes in the prompt** (`gemma_quiz_service.dart`):
  1. The Sulit level text: "menguji analisis mendalam, misalnya life-cycle assessment, kimia
     polimer atau logam, efisiensi energi daur ulang, kebijakan, atau perhitungan sederhana".
     All 20 prompts carried it.
  2. Two of the 7 random `_angles`: "siklus hidup produk dari produksi sampai pembuangan
     (life-cycle)" and "ekonomi sirkular dan nilai material yang bisa dipulihkan". "kebijakan dan
     sistem pengelolaan sampahnya" gave the policy questions.
  3. The avoid list copies earlier questions verbatim ("Jangan mengulang soal ini: …"), so one
     LCA question puts "LCA" into every later prompt of the session.

  The system instruction has no topic words.
- **Side finding:** the "Essay · maks 150 kata" chip showed on MC questions 2 and 4. The popup
  took the type from the question index with essays assumed on (0017 turned essays off). It
  now uses the shown question's own type.

## Decision

1. **Level texts:** no topic examples. Easy: "menguji pemahaman konsep inti, bukan hafalan
   sederhana"; Medium: "menguji penerapan konsep dan hubungan sebab-akibat"; Hard: "menguji
   analisis sebab-akibat yang lebih dalam".
2. **Angles:** one constant, `questionAngles`. It has 8 Fisika Lingkungan angles (density and
   floating, heat and melting, recycling energy, decomposition, electricity and batteries,
   light and UV ageing, physical sorting, handling safety). Each is tagged with the bins it fits:
   - electricity only for B3;
   - recycling energy and UV ageing not for organic.

   Every bin has at least 5 angles.
3. **Rotation:** the angle is chosen in code (`pickAngle`), from those this session has not used
   (`_usedAngles`, filled in generation order including prefetch). The retry gets another
   unused angle.
4. **Prompt:** "Buat SATU soal pilihan ganda tentang <angle> untuk "<object>"", plus the level
   text and one rule: ask the physics qualitatively, with no numbers, data or rule names to
   memorize, because the mode is ungrounded. No example names a topic.
5. **Post-filter:** `bannedTopicTerms` (lca, life cycle, life-cycle, siklus hidup, ekonomi
   sirkular, circular economy) is checked on the whole reply, whole words only. A match counts
   like a parse failure: retry once with another angle, then the fixed fallback (0018: never
   the bank).
6. The `correct` + `wrong[3]` schema and `parseQuestion` are unchanged. The angle id is kept on
   the question and in the `question_source` log line.

## Consequences

The avoid list still copies earlier questions. Those can no longer contain the banned terms,
but they can still pull later questions toward the same wording. The angle rotation is the
main guard; re-check on the robot.
