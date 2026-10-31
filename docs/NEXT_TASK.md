# Next task — U4c combined native acceptance

Queue, in this order:

1. **DS2** fonts and shapes (decision 0120): bundle Google Sans Flex and Google Sans Code if the licence allows, apply the M3 corner scale to tokens and themes.
2. **U9b** login fixes: stable field keys, guest-session drop investigation, landscape inset, lighter focus ring.
3. **S-lane screen restyle**, after DS2 and the home screen: move legacy screens to tokens and remove `google_fonts`.
4. **U4c** combined native acceptance (below), then **U7** Firebase sync, then **U8** documentation/Figma.
5. **Robot lane**: firmware #47 stays unmerged with motion disabled; no movement without owner sign-off.

## Context and working rules

- Base: `feature/live-scan` at `f6179aa`; #51, #52, #53, #54, #55 and #57-#61, #64 are merged (see HANDOFF.md). The "Bukan ini?" picker and background load (E1) are phone-verified.
- Read `CLAUDE.md`, [HANDOFF.md](HANDOFF.md), [Lane A](handoff/lane-a.md), the relevant decisions and the [UI plan](https://app.notion.com/p/4049675ed4f381649071ec29838b4f98) first.
- Preserve the owner's dirty `~/GITHUB/ELIO/elios-clean` checkout. Use a clean isolated worktree and one branch/PR per task against `feature/live-scan`; never merge or push to `main`.
- Use CodeGraph first when the worktree has an index. Indexing requires owner authorization.

## U4c combined native acceptance

- The 29 Oct owner History record was overwritten and remains unrecovered. Never invent the original record or claim it was preserved.
- Back up the owner's records and read-verify the backup before any test. Prove a separate test store is active; never seed or reset the owner profile.
- Use real local Gemma and a localhost fake camera, with no physical robot. Verify MCQ explanation → next question, essay rubric with live frames, trophy math, saved review after quit/relaunch, and complete native PDF contents. Keep score-only/pending grading honest; distinguish injected failures from real-model results.
- Follow `CLAUDE.md` build hygiene: inventory apps/registrations and model stores first; replace the retained `~/Applications/ELIOS.app`, move the final bundle rather than copying it, and verify one registration. Preserve the runtime model, original build asset and signing/Keychain setup; record the actual app commit and model store.
- Launch signed Mac builds with `open`, never `flutter run`. Remove temporary private config copies. Prefer CUA for native checks and verify each result; never select a sharing recipient or send a report unless asked.

## Then U7, then U8

- Proceed to U7 Firebase sync only after combined native acceptance; U8 documentation/Figma follows U7.
- Keep HANDOFF under 60 lines and report exact branch/commit, checks, native evidence and remaining limits. Leave PRs unmerged; leave #50 open.
- Firmware #47 remains unmerged with motion disabled. Firmware deployment, authenticated physical integration and owner watchdog validation are outside U4c; do not enable movement.
