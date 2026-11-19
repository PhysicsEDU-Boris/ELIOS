"""Vector A4 PDF of the 3 bin AprilTags (tag36h11) at true size. Usage: make_bin_pdf.py OUT.pdf"""
import sys
import cv2
import numpy as np

OUT = sys.argv[1]
MM = 72 / 25.4
PRINT_MM = 30.0   # printed image side, white border included (same as id 0)
FRAC = 410.0 / 664.0  # black fraction, same as the arm tags (id 0)
BLACK = PRINT_MM * FRAC
TAGS = [(2, "ANORGANIK"), (3, "ORGANIK"), (4, "B3")]
D = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_APRILTAG_36h11)

ops = []
def text(x, y, s, size=9):
    ops.append(f"BT /F1 {size} Tf {x*MM:.3f} {y*MM:.3f} Td ({s}) Tj ET")
def rect(x, y, w, h, fill=True):
    ops.append(f"{x*MM:.4f} {y*MM:.4f} {w*MM:.4f} {h*MM:.4f} re {'f' if fill else 'S'}")

text(15, 280, "ELIOS bin AprilTags - tag36h11 - print at 100 % (Actual size), not Fit to page", 11)
text(15, 274, "Check: the ruler must measure exactly 100 mm and the square exactly 50 x 50 mm.")
text(15, 269, f"Cut on the grey line (outer edge of the white border). Keep the white border. Black square = {BLACK:.2f} mm.")
ops.append("0.3 w 0 g")
rect(15, 255, 100, 0.4)
for i in range(11):
    rect(15 + i * 10 - 0.15, 255, 0.3, 4 if i % 5 == 0 else 2.5)
text(15, 250, "0"); text(112, 250, "100 mm")
ops.append("0 G"); rect(140, 215, 50, 50, fill=False)
text(150, 239, "50 x 50 mm")

for row, (tid, name) in enumerate(TAGS):  # one row per bin, 4 copies
    y = 200 - row * 55
    for n in range(4):
        g = cv2.aruco.generateImageMarker(D, tid, 8) < 128  # 8x8 cells, True = black
        assert g[0].all() and g[-1].all() and g[:, 0].all() and g[:, -1].all()
        x = 15 + n * (PRINT_MM + 12)
        ops.append("0.6 G 0.2 w [1 1] 0 d"); rect(x, y - PRINT_MM, PRINT_MM, PRINT_MM, fill=False)
        ops.append("[] 0 d 0 g")
        bx, by = x + (PRINT_MM - BLACK) / 2, y - PRINT_MM + (PRINT_MM - BLACK) / 2
        rect(bx, by, BLACK, BLACK)
        ops.append("1 g")
        c = BLACK / 8
        for r in range(8):
            for k in range(8):
                if not g[r, k]:
                    rect(bx + k * c - .01, by + (7 - r) * c - .01, c + .02, c + .02)
        ops.append("0 g")
    text(15, y + 3, f"id {tid} - {name}: printed {PRINT_MM:g} mm, black square {BLACK:.2f} mm", 10)

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

det = cv2.aruco.ArucoDetector(D)
for tid, _ in TAGS:
    img = np.kron(~(cv2.aruco.generateImageMarker(D, tid, 8) < 128), np.ones((40, 40), bool)).astype(np.uint8) * 255
    _, ids, _ = det.detectMarkers(cv2.copyMakeBorder(img, 80, 80, 80, 80, cv2.BORDER_CONSTANT, value=255))
    assert ids is not None and ids.flatten().tolist() == [tid], (tid, ids)
print("wrote", OUT)
