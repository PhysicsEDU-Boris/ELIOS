# 0225 — A new scan no longer writes its explanations into the previous scan

Date: 17 November 2026. Branch `fix/explanation-wrong-scan` (from `feature/live-scan` 86f078e).
Found in the owner's History data on 16 Nov: a plastic-bottle question carried a laptop
explanation, and an older laptop scan carried a plastic-bottle one.

## Cause

When a quiz ends, the provider keeps the saved record's id (`_savedExplanationRecordId`) so an
explanation that arrives late can still be stored in History. That id was cleared only by
`_startSession` (scans that start from a label). Photo scans and robot scans start in
`identifying` through `_freshSession` and kept the old id, so every explanation generated in
the new scan was also written into the **previous** scan's record at the same question number.

## Decision

`_freshSession`, which every scan start goes through, clears the id. A late explanation of
the finished scan is still saved as long as no new scan has started.

## Not done

Records already holding another item's explanation are not repaired: nothing in the saved
data says which explanation is foreign. The live quiz was never affected, only History.

## Tests

`test/explanation_wrong_scan_test.dart`: finish scan A, start scan B from a photo, answer its
first question; nothing is saved into A's record. Break-check: fails on the old code (B's
explanation is saved under A's id).
