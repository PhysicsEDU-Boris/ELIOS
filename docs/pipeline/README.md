# Pipeline charts and milestones

Source: Figma file `J2jSbARJSyJCStNFeWkWDj`, board node
[74:130 "ELIOS PIPELINE"](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=74-130).
Plan: [Notion "ELIOS"](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405).

Chart images are not exported into the repo. Open the Figma links.

## Charts

| Chart | Figma node | Title | Milestones | Plan sections |
|---|---|---|---|---|
| Architecture | [79:135](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=79-135) | ELIOS System Architecture | context for all | 3 |
| ERD | [81:153](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=81-153) | ELIOS Database ERD | later (scan history) | 1.3, 2.7 |
| 1 | [82:283](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=82-283) | App launch and sign-in | none (existing flow) | |
| 2 | [82:353](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=82-353) | Home shell and navigation | none (existing flow) | |
| 3 | [84:295](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=84-295) | E-learning and progress | none (existing flow) | |
| 4 | [84:373](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=84-373) | Configure and camera source | FrameSource follow-ups | 2.4 |
| 5 | [85:305](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=85-305) | Phone camera scan and Gemma quiz | M0 (Gemma slot), M1 to M4 | 1.1 to 1.3, 2.1 to 2.3 |
| 6 | [85:415](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=85-415) | Robot control and automatic quiz | robot link | 2.6 |
| 7 | [112:479](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=112-479) | ByteTrack-assisted pipeline, two camera sources (planned) | M6 | 2.5 |

New quiz overlay designs: nodes
[96:130](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=96-130) and
[96:246](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=96-246) (M4).

## Milestones

| Milestone | What | Charts | Gate before the next step |
|---|---|---|---|
| M0 | Prove stage 2 for real | 5 | Real timings, real cancel test, full test run |
| M1 | Stage 3a: stabilizer with tests | 5 | Unit tests for lock, dropout and re-arm |
| M2 | Stage 3b: state machine, TTS slot, camera stays alive | 5 | Manual macOS check, no duplicate Gemma or TTS |
| M3 | Stage 4: question bank | 5 | Content reviewed by the owner |
| M4 | New overlay UI with phone layout | 5, overlay 96:130 and 96:246 | Both Figma versions match |
| M5 | Android device test: heat, memory, 30 minute soak | 5, 6 | Acceptance checks pass on a phone |
| M6 | ByteTrack decision and firmware | 7 | Moving-object and two-object test |
| M7 | Release hygiene: model delivery, backup, GitHub, keys | none | History scan clean, keys regenerated |

Milestone rows are copied from the Notion "Suggested order" table. If the
plan changes, update Notion first, then this file.
