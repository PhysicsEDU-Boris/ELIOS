# Handoff — 31 Oct 2026 (evening)

- Base: `feature/live-scan` at `f6179aa` (merge of #64).
- Merged today: #57 design-system foundation (0090); #59 U9 splash and login (0100); #60 design file font and shape scale (0091); #61 T1 light default and display mode (0130); #58 Option B icon (0110); #64 light Android icon as primary. Earlier: #51 U4b, #52 History crops (0070), #53 banks (0060), #54 tester build (0040), #55 E1 (0041), #56 docs sync.
- Open PRs: #62 P1 phone check of U9 (docs only, branch `test/p1-u9-phone-check`); #50 docs wrap-up (older content is carried here); #47 firmware (motion disabled, `ARM_MOTION_ENABLED=false`); #24 (latency gate failed).

## Design system state

- App is light by default; dark is a user option behind `DARK_MODE_OPTION` or `TESTER_BUILD` (0130). Only splash and login use the new tokens; legacy screens keep their look until the S-lane.
- `docs/design.md` specifies Google Sans Flex and Google Sans Code and the M3 corner scale (0091). The code still bundles Inter and JetBrains Mono, so 2 tests in `test/theme/elio_tokens_test.dart` fail on the base. DS2 (decision 0120) is the fix, pending a font licence check.
- `google_fonts` is still used by about 10 legacy screens and fetches at runtime (the robot is offline). Screen lanes remove it.

## Phone evidence

- E1 timings are in [lane-a.md](handoff/lane-a.md) (Edge 60 Fusion, GPU): identify first token 14.9-18.9 s, request 19.8-23.9 s; load 4.3-9.2 s cached, 41-50 s cold.
- P1 (#62, see its lane-p.md) found U9 issues for U9b: stale validation errors after the Sign in/Sign up toggle, a guest session dropped on later launches, landscape inset, heavy light-mode focus ring.

## Owner data incident

- The 29 Oct owner History record was overwritten and is still unrecovered. Do not invent or reconstruct its missing answers.

## Next

- See [NEXT_TASK.md](NEXT_TASK.md): DS2, then U9b, then the S-lane restyle, then U4c native acceptance, U7, U8 and the robot lane.
