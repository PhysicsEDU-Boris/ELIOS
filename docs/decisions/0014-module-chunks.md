# 0014: The course module as traceable chunks (M3.2)

- Status: Accepted
- Date: 2026-10-17
- Milestone: M3 step 2 (question bank grounded in the module; follows 0013)
- Code: `scripts/extract_module.py`, `assets/module/module_chunks.json`,
  `assets/module/label_to_chunks.json`, `pubspec.yaml` (`assets/module/`)
- Tests: `scripts/test_extract_module.py`, `test/module_assets_test.dart`
- Evidence: [m3-module-chunks](../test-results/m3-module-chunks.md)

## Context

Quiz questions must be grounded in the owner's course module, with page and section references.
The module (36 pages, selectable text) gives its own chunking advice on p.3: one chunk per
numbered sub-chapter, with the chapter and sub-chapter title in front, and each chapter's
Tanya-Jawab as a separate chunk. The PDF is on `main` only. It is read locally and not
committed on this branch (owner's decision).

## Decision

- One chunk per numbered sub-chapter (50 of them). Separate chunks for each chapter's Ringkasan
  (6) and Tanya-Jawab (8; Bab 9 is one block), plus Glosarium and Daftar Pustaka. 66 in total.
  Pages 1-5 are left out.
- `text` is the PDF's own extracted text. Only the running header is removed and the bullet
  glyph (`\x7f`) is turned into `•`. A test finds every chunk verbatim (whitespace collapsed) on
  its pages. The chapter and sub-chapter titles are fields, not text: M3.3 puts them in front
  when building a prompt.
- Text before a chapter's first sub-chapter (heading, Kata kunci, intro) stays with that first
  chunk. 4.6 keeps its own Kata kunci, Ringkasan 4.6 and Q&A pair.
- `type` is text, qa, table, summary, lkpd_key (8.4) or sources. `table` means the sub-chapter is
  mainly one table; that list was made by hand, in `TABLE_IDS`.
- Each chunk records `pdfPage`, `printedPage` (read from each page's header; equal to
  `pdfPage` everywhere) and `pdfPageEnd`.
- 4.6 carries `sourceQuality: company_sourced`: every source is Tetra Pak or covers Tetra Pak,
  and the module says there is no independent source.
- `label_to_chunks.json` is hand-written. It maps the 9 detector classes to their bin, chunk
  ids, coverage (covered / partial / not_covered) and evidence (page + heading). Human_Hand
  has no bin and `sendToGemma: false`. Paper, Paperboard and Cardboard keep the module's
  wording (1.3, Bab 9 Q&A): they are biodegradable, and sorting practice puts them in
  recyclable anorganik. Questions must never say flatly that they are anorganik.
- Output is reproducible: the same PDF and the same pypdf version give byte-identical JSON. A
  test runs the extractor twice and compares the result with the committed asset.

## Consequences

- The assets are bundled but not used yet. Wiring them into the quiz prompt is M3.3.
- Tables come out cell-per-line, and superscripts are flattened (`105` for 10⁵ in 6.6). M3.3
  should avoid quoting 6.6 numbers verbatim, or the owner fixes the PDF.
- `scripts/test_extract_module.py` skips without the PDF and pypdf. The Dart test needs
  neither and always checks the label map against `ScannedWaste.detectorLabels`.
- If the PDF changes, re-run the extractor: the sha256 in the JSON shows which PDF built the
  asset.

## Out of scope

Writing questions; reconstructing table rows; fixing the module's inconsistencies (listed in
the results doc for the owner).
