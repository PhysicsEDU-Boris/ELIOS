# 0186: Keep essay focus during keyboard resizing

- Status: Accepted
- Date: 2026-11-05
- Base: `feature/live-scan`

## Problem

The supplied Android landscape recording shows the essay keyboard repeatedly opening and closing. Below 200 dp of available popup height, the essay layout replaced its TextField with a Row containing a new TextField. The original editor was disposed, losing focus and closing the keyboard.

## Decision

Keep one Row and TextField in both layouts. Key the Expanded editor container so hiding the question and footer does not replace it when its position in the Column changes. Only the compact Submit button is conditional. Existing grading, word limit, submission and normal footer behavior stay unchanged. No extra focus requests, keyboard reopening, dependencies or platform code.

## Validation

The widget regression focuses the field, enters a draft, moves the cursor and varies keyboard insets through the layout threshold in both directions. It verifies the same editor remains mounted, focused and editable, preserves text/selection, and keeps Submit inside the available height. Before the fix it fails because the original EditableTextState is disposed; after the fix it passes.

Robot acceptance: open an essay on a landscape phone, tap the answer, type, hide and reopen the keyboard several times, then submit. The keyboard should stay open while typing and the draft/cursor should survive resizing. The follow-up installed this fix on the connected Motorola in the existing localized build; see `docs/local-build-notes.md`. Robot firmware, app data and models are unchanged.

Checks: `flutter test`: 1255 passed, 20 skipped, one unrelated `test/theme/elio_tokens_test.dart` radius-parser null-check failure. That failure also reproduces in isolation; both the token source and test are identical to the base branch. `flutter analyze`: two existing style infos in `test/m2c_identification_test.dart` and `test/question_bank_integrity_test.dart`. Secret scan and `git diff --check` pass.

## Follow-up: question visible while typing

The owner screenshot after installation confirms the compact layout hides the question. Keep a scrollable question pane beside the answer in short layouts. Key the field wrapper to preserve the editor when that pane appears/disappears. The regression now checks question presence, placement, scrolling without focus loss, and a 240 dp keyboard inset; it fails on the first installed build because the question is absent. This uses the existing popup, submission, type size and normal layout.

Follow-up verification: all 64 popup tests and localized regression pass; full suite remains 1255 passed / 20 skipped / same unrelated token-radius failure, analyzer same two infos, secret/diff scans clean. Localized `dfb7f67` installed in place on the Motorola at 21:40:39 Jakarta; cold launch OK, both History files unchanged. Physical IME acceptance pending.
