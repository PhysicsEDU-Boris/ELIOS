# Item photos

Put photos in `images/<label>/` (for example `images/Plastic/bottle.jpg`), using one of the 10
names in `../labels.yaml`. Each card in a scenario uses the first photo in its label's folder,
unless the item sets `photo:` itself (a path relative to `tools/fake_maixcam/`). A label without
photos gets a plain placeholder card with the label written on it.

The folders are gitignored: photos stay on your machine. The training set
(`~/datasets/waste-dataset-v8`, CC BY 4.0) is a good source of crops.
