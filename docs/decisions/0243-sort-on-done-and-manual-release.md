# 0243: Sort on Done, sorting bubble, manual RELEASE after a failed drop (sorting rework, step 2)

- Status: Accepted; unit and widget tests only, not yet checked on the robot.
- Date: 2026-11-26
- Builds on: [0240](0240-sim-control-settings.md) (bin run), [0241](0241-hil-toolkit-control-parity.md)
  (sort after the quiz), [0242](0242-robot-buttons-and-indicators.md).

## Goal

Owner, 26 Nov: the arm sorts when the student is done, shows that it is sorting, and when the drop
fails the student finishes it by hand without being asked over and over.

## Decisions

| Ask | Before (0241) | Now |
|-----|---------------|-----|
| Sort starts on Done/Finish | the bin run started 3 s after the last question, while the result page showed | the result page's **Done** starts it (`ScanQuizPages.onDone`), then the pages close; the 3 s wait stays. Closing with ✕ or Scan again does not sort |
| "Sorting in progress" on the camera | only the result card said so | a bubble over the bottom of the video (phone and tablet/Mac layouts): "Sorting into the Organik bin in 3 s", "Sorting in progress · Organik bin", then "Sorting successful" for 5 s |
| On failure, the student helps | a failed DROP ended the run: HOLD, HOME, "could not finish" | a DROP that fails **at the bin** (refused twice: bin tag not seen / not at bin, or no reply in 60 s) goes to `needsRelease`: the arm holds over the bin, the bubble says "Check the hand is over the Organik bin. Adjust it, then press RELEASE." The arm keys work (the run is not `busy`), LOCK/SCAN wait (`pending`). RELEASE opens the gripper (ARM_POSE); its `motion_done` sends HOME, then "Sorting successful" |
| Limit the asks | — | `BinRun.maxHelps = 2`: at most 2 sorts **in a row** ask; a third failed drop ends as failed (HOLD, HOME, top notification). A sort that drops by itself resets the count |

Failures on the way to the bin (tank, timeout during MOVE_TO_BIN, not sent) still end as failed:
the item is not over a bin, so RELEASE would drop it on the floor.

## Not changed

Arm and drive controls, the DROP guard on the MaixCAM2, the bin sequences.

## Tests

`bin_run_test.dart` (RELEASE path, no-reply DROP asks, limit of 2 and its reset, failures on the way
still fail), `scan_quiz_pages_test.dart` (Done calls `onDone` once before the pages close),
`phone_control_test.dart` (bubble on screen over the video). Break-checked against the old code.
