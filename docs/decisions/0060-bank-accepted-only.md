# 0060: Owner acceptance and accepted-only bank serving

- Status: Accepted
- Date: 2026-10-29
- Amends: [0015](0015-question-bank-draft.md) and [0017](0017-object-bank.md).
- PR: [#53](https://github.com/PhysicsEDU-Boris/ELIOS/pull/53).

## Decision

On 29 Oct 2026, the owner accepted all 120 current bank items: 56 label-pool
items and 64 object-specific items. Both banks and every current item have
`status: accepted`. The JSON asset filenames retain `_draft` for compatibility
with existing bundle paths.

Release and profile builds serve only items whose status is `accepted`.
Debug builds also serve `draft` items. Rejected, missing and unknown statuses
are never served. `QuestionBank.questionsFor` applies the same filter to
object and pool items, for multiple-choice and essay questions.

This is a serving rule: the bundled JSON assets still contain all statuses.
Future drafts require owner acceptance before becoming eligible for release.

## Verification

`tools/quiz/check_bank` checks answer options, explanations, source references
and duplicate question text. It runs with the Flutter suite through
`test/question_bank_integrity_test.dart`, alongside the checker corruption
tests and existing validator tests.

Regression tests inject draft, rejected and missing statuses into both banks
and exercise the accepted-only path. Deliberately disabling draft exclusion
made the test fail on leaked object and pool drafts; the filter was restored.
The checker and 95 targeted Flutter tests passed for PR #53. No release binary
was built.
