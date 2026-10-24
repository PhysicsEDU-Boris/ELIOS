"""make_crops.py on a tiny synthetic Roboflow export (no hardware, no simulator)."""
from pathlib import Path

import cv2
import numpy as np
import pytest
import yaml

import make_crops as mc

NAMES = yaml.safe_load((mc.HERE / "labels.yaml").read_text())["names"]
W, H = 400, 300


def write_dataset(root, lines_by_image, names=NAMES):
    root = Path(root)
    root.mkdir(parents=True)
    (root / "data.yaml").write_text(yaml.safe_dump({"nc": len(names), "names": names}))
    for split, stem, lines in lines_by_image:
        (root / split / "images").mkdir(parents=True, exist_ok=True)
        (root / split / "labels").mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(root / split / "images" / f"{stem}.jpg"), np.full((H, W, 3), 128, np.uint8))
        (root / split / "labels" / f"{stem}.txt").write_text("\n".join(lines))
    return root


def box(cls, x0, y0, x1, y1):  # pixels -> a YOLO box line
    return f"{NAMES.index(cls)} {(x0 + x1) / 2 / W} {(y0 + y1) / 2 / H} {(x1 - x0) / W} {(y1 - y0) / H}"


def poly(cls, x0, y0, x1, y1):  # pixels -> a YOLO-seg polygon line (a diamond inside the box)
    pts = [((x0 + x1) / 2, y0), (x1, (y0 + y1) / 2), ((x0 + x1) / 2, y1), (x0, (y0 + y1) / 2)]
    return f"{NAMES.index(cls)} " + " ".join(f"{x / W} {y / H}" for x, y in pts)


def crops(out, cls):
    return sorted((Path(out) / cls / "crops").glob("*.jpg"))


def test_box_and_polygon_labels_with_margin(tmp_path):
    ds = write_dataset(tmp_path / "ds", [
        ("train", "a", [box("Plastic", 100, 50, 200, 150)]),
        ("valid", "b", [poly("Glass", 50, 60, 170, 240)]),
    ])
    counts = mc.make_crops(ds, tmp_path / "out")
    assert counts["Plastic"] == 1 and counts["Glass"] == 1
    assert cv2.imread(str(crops(tmp_path / "out", "Plastic")[0])).shape[:2] == (120, 120)  # 100 px + 10 % each side
    assert cv2.imread(str(crops(tmp_path / "out", "Glass")[0])).shape[:2] == (216, 144)   # 180 x 120 + 10 %
    assert "Human_Hand" not in counts


def test_small_edge_and_hand_objects_are_skipped(tmp_path):
    ds = write_dataset(tmp_path / "ds", [
        ("train", "small", [box("Metal", 100, 100, 179, 200)]),     # 79 px wide
        ("train", "edge", [box("Metal", 0, 50, 120, 200)]),         # touches the left edge
        ("test", "edge2", [poly("Metal", 250, 150, 400, 300)]),     # touches right and bottom
        ("train", "hand", [box("Human_Hand", 100, 50, 300, 250)]),
        ("train", "ok", [box("Metal", 100, 100, 182, 200)]),        # 82 px: kept
    ])
    counts = mc.make_crops(ds, tmp_path / "out")
    assert counts["Metal"] == 1
    assert not (tmp_path / "out" / "Human_Hand").exists()


def test_per_class_limit_and_seed_repeatability(tmp_path):
    ds = write_dataset(tmp_path / "ds", [("train", f"i{k}", [box("Paper", 100, 50, 200, 150)]) for k in range(8)])
    names = []
    for seed, out in ((1, "o1"), (1, "o2"), (2, "o3")):
        assert mc.make_crops(ds, tmp_path / out, per_class=3, seed=seed)["Paper"] == 3
        names.append([p.name for p in crops(tmp_path / out, "Paper")])
    assert names[0] == names[1], "same seed, same crops"
    assert names[0] != names[2], "another seed picks others"
    mc.make_crops(ds, tmp_path / "o1", per_class=2, seed=1)
    assert len(crops(tmp_path / "o1", "Paper")) == 2, "a rerun replaces the old set"


def test_class_name_mismatch_stops(tmp_path):
    renamed = ["Carton" if n == "Cardboard" else n for n in NAMES]
    ds = write_dataset(tmp_path / "ds", [("train", "a", [box("Plastic", 100, 50, 200, 150)])], names=renamed)
    with pytest.raises(SystemExit, match="class names differ"):
        mc.make_crops(ds, tmp_path / "out")
    assert not (tmp_path / "out").exists(), "nothing written"
