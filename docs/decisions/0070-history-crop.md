# 0070: Separate History photos from identification crops

- Status: Accepted
- Date: 2026-10-29
- Scope: Lane D, PR #52.

Identification keeps the original detection box with no margin and the original
JPEG encoding call/settings. Its pixel dimensions, diagnostic bounds and exact
submitted bytes must not change when adjusting a History photo.

For History and PDF, crop the same paired clean frame separately with a 5% margin
on each side of the detection box. Map coordinates to the decoded frame, round
outwards and clamp at the frame edges. Preserve native pixels: never resize or
upscale the saved crop. Encode this saved photo at JPEG quality 100.

`prepareDetectionCrop` returns identification bytes and separate `historyBytes`.
The provider keeps them in `_cropBytes` and `_historyPhotoBytes`; only the latter
is preferred when writing `ScanRecord.cropPhotoPath`. PDF reads the saved photo.
If a separate clean photo is unavailable, preserve the existing supplied crop
(the `ponytail:` marker records this limit). Legacy photos are not rewritten.

Blur and the dark mask halo come from the source frame; changing the History
margin or JPEG quality cannot restore detail or remove them. Do not paint pixels,
substitute mask colours, sharpen, or attempt halo removal. History and PDF display
the saved image at its true aspect with containment on a neutral surface, and
show a placeholder if its file is missing or unreadable.

Regression checks must independently verify the unchanged identification crop,
the padded quality-100 History photo, and the bytes actually persisted using
temporary stores only. Native macOS PDF picker acceptance remains separate.
