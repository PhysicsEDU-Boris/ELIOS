"""Tight per-class photo crops for the fake MaixCAM2's cards (decision 0024).

Reads a Roboflow YOLO export (data.yaml + <split>/images + <split>/labels;
a label line is a class id and either a box "cx cy w h" or a polygon
"x1 y1 x2 y2 ...", all normalised) and writes, for each class in
labels.yaml except Human_Hand, up to --per-class crops to
images/<label>/crops/ with a 10 % margin. Objects smaller than 80 px or
touching the image edge are skipped. Deterministic for a given --seed.

    python make_crops.py --dataset ~/datasets/waste-dataset-v8
"""
import argparse
import random
import sys
from pathlib import Path

import cv2
import yaml

HERE = Path(__file__).resolve().parent
SPLITS = ("train", "valid", "test")
MIN_SIDE_PX = 80
MARGIN = 0.10
SKIP = {"Human_Hand"}


def class_names(dataset, labels_yaml=HERE / "labels.yaml"):
    """labels.yaml's names; SystemExit when the dataset's data.yaml disagrees."""
    ours = yaml.safe_load(Path(labels_yaml).read_text())["names"]
    theirs = yaml.safe_load((Path(dataset) / "data.yaml").read_text())["names"]
    if list(theirs) != list(ours):
        raise SystemExit(f"class names differ: labels.yaml {ours} vs data.yaml {list(theirs)}")
    return ours


def objects(label_file):
    """(class id, (x0, y0, x1, y1) normalised) per line; boxes and polygons."""
    out = []
    for line in Path(label_file).read_text().splitlines():
        v = line.split()
        if len(v) < 5:
            continue
        cls, nums = int(v[0]), [float(x) for x in v[1:]]
        if len(nums) == 4:
            cx, cy, w, h = nums
            out.append((cls, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)))
        elif len(nums) >= 6 and len(nums) % 2 == 0:
            xs, ys = nums[0::2], nums[1::2]
            out.append((cls, (min(xs), min(ys), max(xs), max(ys))))
    return out


def crop_box(box, w, h):
    """Pixel crop with the margin, or None when too small or touching the edge."""
    x0, y0, x1, y1 = box[0] * w, box[1] * h, box[2] * w, box[3] * h
    if min(x1 - x0, y1 - y0) < MIN_SIDE_PX:
        return None
    if x0 <= 1 or y0 <= 1 or x1 >= w - 1 or y1 >= h - 1:
        return None
    mx, my = (x1 - x0) * MARGIN, (y1 - y0) * MARGIN
    return (int(max(0, x0 - mx)), int(max(0, y0 - my)), int(min(w, x1 + mx)), int(min(h, y1 + my)))


def make_crops(dataset, out_dir=HERE / "images", per_class=20, seed=0, labels_yaml=HERE / "labels.yaml"):
    """Writes the crops; returns {label: count}."""
    names = class_names(dataset, labels_yaml)
    wanted = {n: per_class for n in names if n not in SKIP}
    files = sorted((s, f) for s in SPLITS for f in (Path(dataset) / s / "labels").glob("*.txt"))
    random.Random(seed).shuffle(files)
    for n in wanted:  # a fresh, exact set
        d = Path(out_dir) / n / "crops"
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob("*.jpg"):
            old.unlink()
    counts = {n: 0 for n in wanted}
    for split, label_file in files:
        if all(counts[n] >= wanted[n] for n in wanted):
            break
        objs = [(names[c], b) for c, b in objects(label_file) if 0 <= c < len(names)]
        objs = [(n, b) for n, b in objs if n in wanted and counts[n] < wanted[n]]
        if not objs:
            continue
        images = list((Path(dataset) / split / "images").glob(label_file.stem + ".*"))
        img = cv2.imread(str(images[0])) if images else None
        if img is None:
            continue
        h, w = img.shape[:2]
        for i, (n, box) in enumerate(objs):
            c = crop_box(box, w, h)
            if c is None or counts[n] >= wanted[n]:
                continue
            x0, y0, x1, y1 = c
            cv2.imwrite(str(Path(out_dir) / n / "crops" / f"{split}_{label_file.stem[:40]}_{i}.jpg"), img[y0:y1, x0:x1])
            counts[n] += 1
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dataset", required=True, help="Roboflow YOLO export with data.yaml")
    ap.add_argument("--per-class", type=int, default=20)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    counts = make_crops(args.dataset, per_class=args.per_class, seed=args.seed)
    for n, c in counts.items():
        print(f"{n:12s} {c}")
    short = [n for n, c in counts.items() if c < args.per_class]
    if short:
        print("fewer than --per-class:", ", ".join(short), file=sys.stderr)


if __name__ == "__main__":
    main()
