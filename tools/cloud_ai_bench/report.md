# Cloud AI benchmark: Gemini identify on ELIOS scan crops

Photos: 11. Calls: 41 (44 attempts). Thinking: gemini-2.5-flash-lite=minimal, gemini-2.5-flash=minimal, gemini-3-flash-preview=minimal, gemini-3.1-flash-lite=minimal, gemini-3.5-flash-lite=minimal, gemini-3.6-flash=minimal, gemini-3.8-flash=budget0, gemini-robotics-er-2-preview=minimal, gemma-4-31b-it=minimal. Free-tier key: timings are an upper bound. Latency uses unthrottled, successful calls only. A = identify; B = identify + one MC question (one call = one scan).

| Model | Bin acc A | Bin acc B | B3 hazard recall (A) | A p50/p95 s | B p50/p95 s | avg tokens A in/out (think) | avg tokens B in/out (think) | $/scan (B) | $/1k scans | JSON ok | blocked | 429 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gemini-3.6-flash | 10/10 | 8/8 | 6/6 | 2.1/10.0 | 2.7/3.4 | 1159/37 (0) | 1213/220 (0) | $0.00174 to 31 Dec 2026 / $0.00347 from 1 Jan 2027 | $1.74 to 31 Dec 2026 / $3.47 from 1 Jan 2027 | 18/20 | 0 | 12 |
| gemini-2.5-flash | 0/0 | 0/0 | 0/0 | -/- | -/- | - | - | - | - | 0/3 | 0 | 0 |
| gemini-2.5-flash-lite | 0/0 | 0/0 | 0/0 | -/- | -/- | - | - | - | - | 0/3 | 0 | 0 |
| gemini-3-flash-preview | 2/2 | 1/1 | 1/1 | 2.2/2.3 | 2.0/2.0 | 1157/38 (0) | 1227/180 (0) | $0.00115 | $1.15 | 3/3 | 0 | 0 |
| gemini-3.1-flash-lite | 2/2 | 0/0 | 1/1 | 2.5/24.2 | -/- | 1157/54 (0) | - | - | - | 2/3 | 0 | 0 |
| gemini-3.5-flash-lite | 2/2 | 1/1 | 1/1 | 1.8/2.3 | 1.8/1.8 | 1157/54 (0) | 1227/213 (0) | $0.00090 | $0.90 | 3/3 | 0 | 0 |
| gemini-3.8-flash | 0/0 | 0/0 | 0/0 | -/- | -/- | - | - | - | - | 0/2 | 0 | 0 |
| gemma-4-31b-it | 0/0 | 0/0 | 0/0 | -/- | -/- | - | - | free only | - | 0/2 | 0 | 0 |
| gemini-robotics-er-2-preview | 1/1 | 1/1 | 1/1 | 3.7/3.7 | 2.7/2.7 | 1175/54 (0) | 1227/252 (0) | $0.00249 to 31 Dec 2026 / $0.00497 from 1 Jan 2027 | $2.49 to 31 Dec 2026 / $4.97 from 1 Jan 2027 | 2/2 | 0 | 0 |

Photos with at least one answer: gemini-3.6-flash 10, gemini-2.5-flash 0, gemini-2.5-flash-lite 0, gemini-3-flash-preview 2, gemini-3.1-flash-lite 2, gemini-3.5-flash-lite 2, gemini-3.8-flash 0, gemma-4-31b-it 0, gemini-robotics-er-2-preview 1. **Too small to separate models**: fewer than 20 photos for gemini-3.6-flash, gemini-2.5-flash, gemini-2.5-flash-lite, gemini-3-flash-preview, gemini-3.1-flash-lite, gemini-3.5-flash-lite, gemini-3.8-flash, gemma-4-31b-it, gemini-robotics-er-2-preview. The run was stopped early (free-tier daily caps and 503 "high demand" errors).

Cost counts thinking tokens as output. Gemma on-device baseline (docs/handoff/lane-a.md, not re-measured): identify 20-27 s, questions 20-41 s.

## Wrong bin or failed calls (judge names by eye)

| Model | Call | File | Label | Got bin | object_name | Note |
|---|---|---|---|---|---|---|
| gemini-3.6-flash | B | garlic1.jpg | Organik |  |  | HTTP 503 |
| gemini-3.6-flash | A | foodwaste1.jpg | Organik |  |  | HTTP 429 |
| gemini-2.5-flash | A | keyboard2.jpg | B3 |  |  | HTTP 404 |
| gemini-2.5-flash-lite | A | keyboard2.jpg | B3 |  |  | HTTP 404 |
| gemini-3.8-flash | A | keyboard2.jpg | B3 |  |  | HTTP 503 |
| gemma-4-31b-it | A | keyboard2.jpg | B3 |  |  | HTTP 500 |
| gemini-2.5-flash | B | keyboard2.jpg | B3 |  |  | HTTP 404 |
| gemini-2.5-flash-lite | B | keyboard2.jpg | B3 |  |  | HTTP 404 |
| gemini-3.1-flash-lite | B | keyboard2.jpg | B3 |  |  | HTTP 503 |
| gemini-3.8-flash | B | keyboard2.jpg | B3 |  |  | HTTP 503 |
| gemma-4-31b-it | B | keyboard2.jpg | B3 |  |  | HTTP 503 |
| gemini-2.5-flash | A | glassbottle1.jpg | Anorganik |  |  | HTTP 404 |
| gemini-2.5-flash-lite | A | glassbottle1.jpg | Anorganik |  |  | HTTP 404 |

## All object names (call A, main run)

| File | Label | gemini-3.6-flash | gemini-2.5-flash | gemini-2.5-flash-lite | gemini-3-flash-preview | gemini-3.1-flash-lite | gemini-3.5-flash-lite | gemini-3.8-flash | gemma-4-31b-it | gemini-robotics-er-2-preview |
|---|---|---|---|---|---|---|---|---|---|---|
| keyboard1.jpg | B3 | papan ketik komputer | - | - | - | - | - | - | - | - |
| phone1.jpg | B3 | telepon pintar | - | - | - | - | - | - | - | - |
| mouse1.jpg | B3 | tetikus komputer | - | - | - | - | - | - | - | - |
| keyboard2.jpg | B3 | papan ketik |  |  | Keyboard Komputer | keyboard | Keyboard |  |  | keyboard komputer |
| remote1.jpg | B3 | remot kontrol | - | - | - | - | - | - | - | - |
| battery1.jpg | B3 | baterai kancing | - | - | - | - | - | - | - | - |
| gourd1.jpg | Organik | kulit labu botol | - | - | - | - | - | - | - | - |
| garlic1.jpg | Organik | bawang putih | - | - | - | - | - | - | - | - |
| fruit1.jpg | Organik | jeruk nipis | - | - | - | - | - | - | - | - |
| foodwaste1.jpg | Organik |  | - | - | - | - | - | - | - | - |
| glassbottle1.jpg | Anorganik | botol kaca cokelat |  |  | Botol kaca | botol kaca | botol kaca | - | - | - |
