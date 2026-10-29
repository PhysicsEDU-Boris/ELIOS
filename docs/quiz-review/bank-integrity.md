# Bank integrity and acceptance — C1

The owner accepted all 120 current items (56 pool, 64 object) on 29 Oct 2026.
Both JSON banks and every item now have `status: accepted`. Asset filenames
retain `_draft` so existing bundle paths keep working.

Run `tools/quiz/check_bank` from any directory. It exits non-zero for broken
answer options, missing explanations or source references, duplicate normalized
question text across either bank, and the existing module-grounding rules.
MC answers use `correct` plus `wrong[3]`, so the correct option exists before
shuffling; the Flutter test checks the resulting index and answer for every item.
Essay explanations and sources come from their rubric points.

`flutter test` runs the checker, its deliberate corruption tests, and the legacy
bank validator tests via `test/question_bank_integrity_test.dart`; Python 3 is
required on the test host.

`QuestionBank.questionsFor` applies one status filter to both object and pool
items, for MC and essays. Accepted items are always eligible; drafts require
`kDebugMode`. Profile and release therefore serve accepted items only. Tests
exercise that same accepted-only path with `includeDrafts: false` and inject
draft, rejected and missing statuses into both banks. Debug also serves drafts.
This controls serving; the bundled JSON assets still contain all statuses.

Wording changes:

- Kardus Q1 asks about biodegradability, with an explanation distinguishing
  material properties from everyday recycling classification.
- The chip says “Sesi Mudah/Sedang/Sulit”: this is the session setting, while
  bank items keep their existing Mudah-first, object-then-pool order.
- The first pool questions reached after object items (often Q5) use concrete
  material situations rather than a generic module recall prompt.
- Questions no longer ask students to answer “menurut modul”; evidence quotes
  and source references remain intact.

Break-check: removing `includeDrafts` from the filter caused the release-path
test to fail with both `ponsel-mc-01-draft` and `e_waste_b3-mc-01-draft` leaked.
The filter was restored before final verification. No release binary was built.
