"""Vector A4 PDF of the arm AprilTags at true size (sizes from robotic_hand_sim tag_model.py)."""
import sys
import numpy as np
from PIL import Image

S = sys.argv[1]
OUT = sys.argv[2]
MM = 72 / 25.4
PNG_BLACK_FRACTION = 410.0 / 664.0
TAGS = [  # id, png, printed image side mm, black fraction of the print, where
    (0, f"{S}/id00_base_endeffector.png", 30.0, PNG_BLACK_FRACTION, "arm5 bottom (hand)"),
    # arm3 rear fits only 10 mm: a one-cell white border (10x10 grid) makes the black 8 mm, not 6.17
    (1, f"{S}/id01_armb.png", 10.0, 0.8, "arm3 rear, thin border"),
]
COPIES = 4


def grid(png):
    """8x8 cells of the black square (True = black), sampled at cell centres."""
    a = np.asarray(Image.open(png).convert("L")) < 128
    ys, xs = np.nonzero(a)
    x0, y0, side = xs.min(), ys.min(), xs.max() - xs.min() + 1
    assert abs(side - (ys.max() - y0 + 1)) <= 1 and abs(side / a.shape[1] - PNG_BLACK_FRACTION) < 0.01
    c = side / 8
    g = np.array([[a[int(y0 + (r + .5) * c), int(x0 + (k + .5) * c)] for k in range(8)] for r in range(8)])
    assert g[0].all() and g[-1].all() and g[:, 0].all() and g[:, -1].all(), "no black border"
    return g


ops = []
def text(x, y, s, size=9):
    s = s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    ops.append(f"BT /F1 {size} Tf {x*MM:.3f} {y*MM:.3f} Td ({s}) Tj ET")
def rect(x, y, w, h, fill=True):
    ops.append(f"{x*MM:.4f} {y*MM:.4f} {w*MM:.4f} {h*MM:.4f} re {'f' if fill else 'S'}")

# y is from the bottom of the A4 page (210 x 297 mm)
text(15, 280, "ELIOS arm AprilTags - tag36h11 - print at 100 % (Actual size), not Fit to page", 11)
text(15, 274, "Check: the ruler below must measure exactly 100 mm and the square exactly 50 x 50 mm.")
text(15, 269, "Cut on the grey line (outer edge of the white border). Keep the white border; it is part of the tag.")
ops.append("0.3 w")
rect(15, 255, 100, 0.4)                       # 100 mm ruler with 10 mm ticks
for i in range(11):
    rect(15 + i * 10 - 0.15, 255, 0.3, 4 if i % 5 == 0 else 2.5)
text(15, 250, "0"); text(112, 250, "100 mm")
ops.append("0 G"); rect(140, 215, 50, 50, fill=False)
text(150, 239, "50 x 50 mm")

y = 195
for tid, png, print_mm, frac, where in TAGS:
    g = grid(png)
    black = print_mm * frac
    cell = black / 8
    text(15, y + 8, f"id {tid} - {where}: printed {print_mm:g} mm, black square {black:.2f} mm "
                    f"(the size the camera uses)", 10)
    for n in range(COPIES):
        x = 15 + n * max(print_mm + 12, 30)
        ops.append("0.6 G 0.2 w [1 1] 0 d")
        rect(x, y - print_mm, print_mm, print_mm, fill=False)
        ops.append("[] 0 d 0 g")
        bx, by = x + (print_mm - black) / 2, y - print_mm + (print_mm - black) / 2
        rect(bx, by, black, black)  # one black square, white cells on top: no seams between black cells
        ops.append("1 g")
        for r in range(8):
            k = 0
            while k < 8:
                if g[r, k]:
                    k += 1
                    continue
                e = k
                while e < 8 and not g[r, e]:
                    e += 1
                rect(bx + k * cell, by + (7 - r) * cell, (e - k) * cell, cell)  # row 0 = image top
                k = e
        ops.append("0 g")
    y -= print_mm + 28

text(15, 20, "Source: robotic_hand_sim hil_toolkit/tags_toolkit/tag_model.py and paper/apriltags/*.png (664 px, 410 px black).", 7)

content = "\n".join(ops).encode()
objs = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.276 841.890] /Contents 4 0 R "
    b"/Resources << /Font << /F1 5 0 R >> >> >>",
    b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
]
pdf, offs = bytearray(b"%PDF-1.4\n"), []
for i, o in enumerate(objs, 1):
    offs.append(len(pdf))
    pdf += b"%d 0 obj\n" % i + o + b"\nendobj\n"
xref = len(pdf)
pdf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
pdf += b"".join(b"%010d 00000 n \n" % o for o in offs)
pdf += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
open(OUT, "wb").write(pdf)

# Self-check: each sampled grid, drawn with a white border, decodes to its id.
import cv2
det = cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_APRILTAG_36h11))
for tid, png, *_ in TAGS:
    img = np.kron(~grid(png), np.ones((40, 40), bool)).astype(np.uint8) * 255
    _, ids, _ = det.detectMarkers(cv2.copyMakeBorder(img, 80, 80, 80, 80, cv2.BORDER_CONSTANT, value=255))
    assert ids is not None and ids.flatten().tolist() == [tid], (tid, ids)
    print("id", tid, "grid decodes OK")
print("wrote", OUT)
