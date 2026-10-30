# Next task — U4c combined native acceptance

Continue in this order: **U4c combined native acceptance → U7 Firebase sync → U8 documentation/Figma**.

## Context and working rules

- Base: `feature/live-scan` at `ae67416`; #51 U4b, #53 banks (0060), #52 History/PDF crops (0070) and #54 Android tester build (0040) are merged. #55 E1 (0041) is also merged: the "Bukan ini?" picker and background load are phone-verified.
- Read `CLAUDE.md`, [HANDOFF.md](HANDOFF.md), [Lane A](handoff/lane-a.md), the relevant decisions and the [UI plan](https://app.notion.com/p/4049675ed4f381649071ec29838b4f98) first.
- Preserve the owner's dirty `~/GITHUB/ELIO/elios-clean` checkout. Use a clean isolated worktree and one branch/PR per task against `feature/live-scan`; never merge or push to `main`.
- Use CodeGraph first when the worktree has an index. Indexing requires owner authorization.

## 1. U4c combined native acceptance

- The 29 Oct owner History record was overwritten and remains unrecovered. Never invent the original record or claim it was preserved.
- Back up the owner's records and read-verify the backup before any test. Prove a separate test store is active; never seed or reset the owner profile.
- Use real local Gemma and a localhost fake camera, with no physical robot. Verify MCQ explanation → next question, essay rubric with live frames, trophy math, saved review after quit/relaunch, and complete native PDF contents. Keep score-only/pending grading honest; distinguish injected failures from real-model results.
- Follow `CLAUDE.md` build hygiene: inventory apps/registrations and model stores first; replace the retained `~/Applications/ELIOS.app`, move the final bundle rather than copying it, and verify one registration. Preserve the runtime model, original build asset and signing/Keychain setup; record the actual app commit and model store.
- Launch signed Mac builds with `open`, never `flutter run`. Remove temporary private config copies. Prefer CUA for native checks and verify each result; never select a sharing recipient or send a report unless asked.

## 2. Then U7, then U8

- Proceed to U7 Firebase sync only after combined native acceptance; U8 documentation/Figma follows U7.
- Keep HANDOFF under 60 lines and report exact branch/commit, checks, native evidence and remaining limits. Leave PRs unmerged; leave #50 open.
- Firmware #47 remains unmerged with motion disabled. Firmware deployment, authenticated physical integration and owner watchdog validation are outside U4c; do not enable movement.
