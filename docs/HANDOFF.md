# Handoff — 31 Oct 2026

- Base: `feature/live-scan` at `ae67416`.
- Merged: #51 U4b essay rubric; #53 banks (decision 0060); #52 History/PDF crops (0070); #54 Android tester build (0040); #55 E1 (0041), with the "Bukan ini?" picker and background load phone-verified.
- Open PRs: #50 docs wrap-up (content carried into this docs sync); #47 firmware (motion disabled, `ARM_MOTION_ENABLED=false`); #24 (latency gate failed).

## Phone evidence — Edge 60 Fusion, GPU

- Load: 4.3–9.2 s cached or 41–50 s cold; identify: 19.8–23.9 s with the shorter prompt; questions: 20–41 s; essay grading: 16.5–25.4 s; memory: 3.3–3.7 GB.
- Thermal gate pauses at CRITICAL.
- The tester build keeps Gemma loaded after the scan screen closes (about 1.6 GB held until the app closes).
- Photo-size test: 512/384/256 px gave 24.8/24.3/23.6 s. Photo size does not change identify time in this test.
- See [Lane A handoff](handoff/lane-a.md) for details; its earlier measurements and pre-PR status predate the summary above.

## Owner data incident

- The 29 Oct owner History record was overwritten and is still unrecovered. Do not invent or reconstruct its missing answers from guesses.

## Next task — U4c combined native acceptance

- Back up the owner's records and read-verify the backup first. Prove a separate test store is active before interacting; never seed or reset the owner store.
- Complete real-Gemma/localhost-camera multi-question acceptance: MCQ explanation → next question, essay rubric during live frames, trophy math, quit/relaunch, saved review and complete native PDF export.
- Follow `CLAUDE.md` Mac build hygiene: reuse the retained app/model, inventory before building and verify one app registration afterwards. No physical robot movement or sharing recipient selection.
- Overall queue: U4c combined native acceptance, then U7 Firebase sync, then U8 documentation/Figma. See [NEXT_TASK.md](NEXT_TASK.md).
