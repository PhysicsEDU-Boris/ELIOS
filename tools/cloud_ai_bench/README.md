# Cloud AI benchmark (spike, decision 0176)

Compares Gemini models on ELIOS scan crops: bin accuracy, B3 hazard recall, latency and cost.
It is a standalone script with no app changes. It needs only Python 3 and Pillow.

## Photos

Use a folder **outside the repo** with 25-30 object-only crops, EXIF stripped, and a `labels.csv`:

```
file,object_name,correct_bin
bottle1.jpg,botol plastik,Anorganik
```

`correct_bin` is `Organik`, `Anorganik` or `B3`. Each photo is resized to 512 px on the long side,
which is the size the app sends to Gemma (E1).

## Run

```
# first set GEMINI_API_KEY in this shell with export (never in a file)
python3 tools/cloud_ai_bench/bench.py run ~/path/to/photos
python3 tools/cloud_ai_bench/bench.py run ~/path/to/photos gemini-3.1-flash-lite,gemini-3.5-flash-lite
python3 tools/cloud_ai_bench/bench.py report
```

`run` calls models.list and picks the exact IDs by display name. For every photo it runs
call A (identify) and call B (identify plus one MC question) on each model, then 3 more A calls
on 5 photos per model. Calls are paced to the free-tier RPM limit (13 s for 3.6 Flash, 4.5 s otherwise). On HTTP 429 it backs off at 5/10/20/40/60 s
and then stops that model. A 5xx gets one retry. Rows are appended to `results.csv`; a rerun skips calls that already succeeded, so the same
command continues the next day after a free-tier daily limit. Delete the file for a fresh run. `raw/` holds the raw replies and is gitignored.
