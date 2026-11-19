"""A4 vector ChArUco board (7x10 squares of 24 mm, 18 mm DICT_4X4_50 markers) for MaixCAM2 intrinsics.
4x4 markers, not tag36h11, so the board can never be mistaken for arm tag id 0/1."""
import sys
import cv2
import numpy as np

OUT = sys.argv[1]
COLS, ROWS, SQ, MK = 7, 10, 24.0, 18.0
UNIT = 3.0                      # mm per marker bit: square = 8 units, marker = 6 (4 bits + border)
MM = 72 / 25.4
board = cv2.aruco.CharucoBoard((COLS, ROWS), SQ, MK, cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50))
PX = 10                         # px per unit in OpenCV's own render
img = board.generateImage((COLS * 8 * PX, ROWS * 8 * PX), marginSize=0, borderBits=1)
cells = img[PX // 2::PX, PX // 2::PX] < 128   # (ROWS*8, COLS*8), True = black

ops = []
def text(x, y, s, size=9):
    ops.append(f"BT /F1 {size} Tf {x*MM:.3f} {y*MM:.3f} Td ({s}) Tj ET")
def rect(x, y, w, h):
    ops.append(f"{x*MM:.4f} {y*MM:.4f} {w*MM:.4f} {h*MM:.4f} re f")

text(21, 284, "ELIOS MaixCAM2 calibration board - ChArUco 7x10, DICT_4X4_50 - print at 100 % (Actual size)", 10)
text(21, 278, "Check: each chessboard square must be 24.0 mm. Glue flat on stiff card; it must not bend.")
x0, y0 = 21.0, 22.0                     # bottom-left of the board on A4 (210 x 297 mm)
H, W = cells.shape
todo = cells.copy()
for r in range(H):  # greedy rectangles (row run, extended down) so no seams show inside black areas
    k = 0
    while k < W:
        if not todo[r, k]:
            k += 1
            continue
        e = k
        while e < W and todo[r, e]:
            e += 1
        b = r + 1
        while b < H and todo[b, k:e].all():
            b += 1
        todo[r:b, k:e] = False
        rect(x0 + k * UNIT, y0 + (H - b) * UNIT, (e - k) * UNIT, (b - r) * UNIT)
        k = e
text(21, 14, "Hold 150-400 mm from the lens; tilt it; cover the corners of the picture too.", 8)

content = "\n".join(ops).encode()
objs = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.276 841.890] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
pdf, offs = bytearray(b"%PDF-1.4\n"), []
for i, o in enumerate(objs, 1):
    offs.append(len(pdf)); pdf += b"%d 0 obj\n" % i + o + b"\nendobj\n"
xref = len(pdf)
pdf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1) + b"".join(b"%010d 00000 n \n" % o for o in offs)
pdf += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
open(OUT, "wb").write(pdf)
print("wrote", OUT)
