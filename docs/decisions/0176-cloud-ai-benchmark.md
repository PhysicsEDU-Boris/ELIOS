# 0176: Cloud AI benchmark and a free-tier fallback chain (spike)

- Status: Accepted (owner, 3 Nov 2026): 3.5 Flash-Lite primary and the fallback chain below. Decisions 2-4 at the end are still open.
- Date: 2026-11-03
- Code: `tools/cloud_ai_bench/` only (script, README, `report.md`, `results.csv`). No app change.

## What was measured

`bench.py` sends each photo, resized to 512 px on the long side as in E1, to every Gemini model
the owner's free key can call. Call A asks for identify JSON only: object_name, bin, detector class
from 0012/0025, confidence and hazard. Call B adds one MC question in the bank item shape from 0019.
Both calls use a response schema and minimal thinking; the setting used is recorded per call.
Results are in [report.md](../../tools/cloud_ai_bench/report.md) and `results.csv`.

**Limits, stated plainly:**
- **Photos:** 28 public Roboflow training images (from `maixcam2_convert/datasets/train_images`), not
  ELIOS robot crops, and no detector box, so the whole image was sent.
- **Stopped early:** the owner stopped the run after 44 calls because free-tier daily caps (20 per
  day for most models) and 503 "high demand" errors made it slow.
- **Sample size:** at most 10 photos per model, too small to separate models on accuracy.
- **Timings:** free-tier timings, so an upper bound.

## Results (free tier, 3 Nov 2026)

| Model | Free limit (RPM / per day) | Worked | Identify p50 | $ per 1,000 scans (call B) |
|---|---|---|---|---|
| gemini-3.5-flash-lite | 15 / 500 | 3/3 | 1.8 s | $0.90 |
| gemini-3-flash-preview | 5 / 20 | 3/3 | 2.2 s | $1.15 |
| gemini-3.6-flash | 5 / 20 | 18/20, 10/10 bins right, 6/6 B3 flagged | 2.1 s | $1.74; $3.47 from 2027 |
| gemini-robotics-er-2-preview | 5 / 20 | 2/2 | 3.7 s | $2.49; $4.97 from 2027 |
| gemini-3.1-flash-lite | 15 / 500 | 2/4 (two 503s), one call took 24 s | 2.5 s | not measured |
| gemini-3.8-flash | 5 / 20 | 0/2 (503) | - | - |
| gemma-4-31b-it (API) | 30 / 14,400 | 0/2 (500, 503) | - | free only |
| gemini-2.5-flash, -lite | - | 404, not offered to this key | - | - |

Every answer that came back was in the right bin. For comparison, on-device Gemma takes 20-27 s
to identify and 20-41 s per question
([Lane A](../handoff/lane-a.md), not re-measured). Every cloud model that answered took 2-4 s.

## Proposal

**Primary: `gemini-3.5-flash-lite`** (accepted by the owner, 3 Nov). It was the fastest and cheapest model that answered every
call, and it has the largest free daily limit (500). Its evidence is only 3 calls, so it must be
confirmed before it is accepted.

**Fallback chain** for when a model is rate-limited, busy or down. The next model is tried
automatically:

1. gemini-3.5-flash-lite (500/day)
2. gemini-3.1-flash-lite (500/day; cheapest paid price, but busy today)
3. gemini-3-flash-preview (20/day)
4. gemini-3.6-flash (20/day; the most evidence)
5. gemini-robotics-er-2-preview (20/day)
6. Offline: the question bank only (on-device Gemma is dropped, see below).

On the free tier, the chain together gives about 1,060 calls per day and about 45 per minute.

**Switch rules:**
- **429, daily cap:** skip that model until the reset at midnight Pacific (15:00 WIB).
- **429, per minute:** skip it for the `retryDelay` the error gives.
- **5xx or a timeout of about 8 s:** go to the next model at once and rest that model 60 s.
- **404:** drop the model from the chain.
- **Invalid JSON:** one retry on the same model, then the next model.
- **Logging:** each scan records which model answered.

## On-device Gemma dropped (owner, 3 Nov 2026)

The target architecture no longer uses local Gemma: identify and question generation move to the
cloud API, and the question bank is the only offline fallback. This needs internet on the robot
path, so MaixCAM2 has to run in STA mode (joins the school Wi-Fi) instead of its own access point;
the owner will work that out. Until the cloud path is built, the app still contains Gemma and
nothing is removed; removing it (model download, load, thermal gate, Gemma settings) is a later
task, done together with the cloud switch so the app never has no AI path at all.

## Owner decisions

1. ~~Primary and chain~~: accepted 3 Nov. Re-check if a full run changes the picture.
2. **Free or paid tier for students:** on the free tier, Google may use the prompts and images to
   improve its products. A paid key also lifts the 20-per-day caps.
3. **Where the key lives:** a key built into the app can be extracted. The chain should run in a
   small backend, such as a Firebase Function, that holds the key.
4. **Finish the benchmark first?** Either one run on a paid key (about $1) or about 4 days of free
   reruns of the same command.
