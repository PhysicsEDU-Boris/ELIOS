# M3.2: course module chunks and label coverage

- Date: 2026-10-17. Source: `docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf`
  (from origin/main ce9854c, sha256 `5fd520fdeab9368d…`, 36 pages; not committed here).
- Extractor: `scripts/extract_module.py` (pypdf 5.1.0, no network) ->
  `assets/module/module_chunks.json`. Label map (hand-written):
  `assets/module/label_to_chunks.json`.
- Checks: `python3 scripts/test_extract_module.py` (8 pass) and
  `flutter test test/module_assets_test.dart` (2 pass).

## Pages

No offset: PDF pages 2-36 each print `Halaman N` with N equal to the PDF page index (checked per
page). Page 1 (cover) has no header. The 3-line running header (title, `UNJ · Media ELIO`,
`Halaman N`) is removed. There is no separate footer.

## Chunks: 66

| Chapter (contents page) | Starts p. | Sub-chapters | Summary | Q&A |
|---|---|---|---|---|
| Bab 1. Jenis-Jenis Sampah | 6 | 1.1-1.6 | yes | yes |
| Bab 2. Sampah B3 | 10 | 2.1-2.10 | yes | yes |
| Bab 3. Daur Ulang Sampah Organik | 17 | 3.1-3.5 | yes | yes |
| Bab 4. Daur Ulang Non-Organik dan Pengelolaan B3 | 20 | 4.1-4.8 | yes | yes |
| Bab 5. Sampah dan Empati Lingkungan | 24 | 5.1-5.3 | yes | yes |
| Bab 6. Fisika dalam Pengelolaan Sampah | 26 | 6.1-6.8 | yes | yes |
| Bab 7. Panduan Robot dan Aplikasi ELIO | 29 | 7.1-7.6 | - | yes |
| Bab 8. Pertemuan, Penilaian, Kunci LKPD | 31 | 8.1-8.4 | - | - |
| Bab 9. Bank Tanya-Jawab Lintas Bab | 34 | - | - | one block |
| Glosarium / Daftar Pustaka | 35 / 36 | one chunk each | | |

By type: 32 text, 18 table, 8 qa, 6 summary, 1 lkpd_key (8.4), 1 sources. The largest chunk is
317 words (9.qa); the limit is 700. Pages 1-5 (cover, contents, usage notes, learning outcomes)
are not chunked.

## Label coverage

| Class | Bin | Coverage | Evidence (PDF page, heading) |
|---|---|---|---|
| Cardboard | anorganik | partial | p.7 1.3d "kardus polos" + Catatan klasifikasi; p.21 4.3 (paper in general) |
| E_Waste | B3 | covered | p.7 1.4b; p.13 2.6; p.14 2.7; p.22 4.7 |
| Glass | anorganik | covered | p.7 1.4c; p.21 4.5 |
| Metal | anorganik | covered | p.7 1.4b; p.21 4.4; p.26 6.2; p.27 6.8 |
| Organic | organik | covered | p.6 1.3; pp.17-18 3.2-3.5 |
| Paper | anorganik | covered | p.7 1.3d + Catatan; p.21 4.3; p.34 Bab 9 Q&A; p.32 8.4 |
| Paperboard | anorganik | partial | p.7 1.3d "karton" + Catatan; p.21 4.3 (the word "paperboard" never appears) |
| Plastic | anorganik | covered | p.7 1.4a; pp.20-21 4.2; p.26 6.1 |
| Tetra_Pak | anorganik | covered | pp.21-22 4.6 (sourceQuality: company_sourced) |
| Human_Hand | none | none | not waste, never sent to Gemma |

Paper, Paperboard and Cardboard carry the module's own wording (1.3 p.7, Bab 9 Q&A p.34): these
items are biodegradable, and sorting practice puts them in recyclable anorganik.

## Mapping check (`ScannedWaste.detectorLabels` / `detectorCategory`)

All 9 waste classes are present and match the bin table; Human_Hand maps to no bin. No difference.
The Dart test now enforces this.

## Where tables break extraction

pypdf writes one cell per line. A wrapped cell becomes several lines, and the line breaks
between rows are lost, so a row reads as a run of cell lines. Worst cases:
- 2.6 (10 rows x 4 columns) and 2.4, which spans pp.11-12 and repeats its header row.
- The 4.2 resin table.
- The 8.1/8.2 lesson plans.

Superscripts and subscripts are flattened:
- 6.6 `10−2` means 10⁻², and `10−2 ÷ 10−7 = 105` means 10⁵.
- `cm3`, `m3`, `CO2`, `CH4`.

The 8.1/8.2 headings wrap ("(100 menit)").

## In the PDF, worth a look by the owner

1. Composting steps differ in three places. 3.2 gives "6 langkah" with penyusunan tumpukan and
   pematangan. 3.qa (p.19) lists 7 steps, adding pemakaian kompos. The LKPD 2 key in 8.4 (p.32)
   lists 6 steps, without penyusunan tumpukan and with penggunaan kompos. A question keyed to
   one source contradicts the others.
2. Aerobic composting time: 3.2 says pematangan takes about 2-3 months, while the 3.5 table says
   "Sekitar 2-3 bulan (+ pematangan)".
3. 7.3 says sorting is done by a human operator into two zones, with no automatic recognition
   (RPS). This app does recognize items automatically and uses three bins (7.6 calls a B3 zone
   optional). Questions must not use 7.3 to describe this app.
4. 1.5 gives a decomposition time of "minggu hingga sekitar 6 bulan" with kayu as an example.
   Wood (and the bamboo in 1.3d) usually takes longer.
5. 6.6 "= 105" reads as one hundred and five once extracted (see above). A generated question
   could repeat it.
