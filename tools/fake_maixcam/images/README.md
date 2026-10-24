# Item photos

- `images/<label>/crops/`: tight crops written by `../make_crops.py` from the training dataset.
  They are used first.
- `images/<label>/`: your own whole photos, used when a class has no crops. They are
  centre-cropped to 4:3.
- An item may also name its own `photo:` (a path relative to `tools/fake_maixcam/`).

A class with neither gets a plain striped placeholder card without text, and a warning in the log.

Everything here is gitignored, so photos stay on your machine (licence and size). The training set
is `~/datasets/waste-dataset-v8` (Roboflow, CC BY 4.0).
