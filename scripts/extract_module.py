#!/usr/bin/env python3
"""Extract the course module PDF into traceable chunks (M3.2, decision 0014).

    pip install pypdf==5.1.0
    python3 scripts/extract_module.py [path/to.pdf]

Writes assets/module/module_chunks.json. No network. The text of every chunk
is the PDF's own extracted text (running headers removed, bullet glyph
normalized), so scripts/test_extract_module.py can find it verbatim in the PDF.

Chunking follows the module's own advice (p.3): one chunk per numbered
sub-chapter, each chapter's Ringkasan and Tanya-Jawab as separate chunks.
Front matter (pp.1-5: cover, contents, usage notes, learning outcomes) is not
chunked. Text before a chapter's first sub-chapter (Kata kunci, intro) stays
with that first chunk. A sub-chapter's chapter and title are fields; the
consumer puts them in front of the text (M3.3), so `text` stays verbatim.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

import pypdf

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PDF = ROOT / 'docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf'
OUT = ROOT / 'assets/module/module_chunks.json'
FIRST_CONTENT_PAGE = 6  # Bab 1 starts here (contents, p.2)

# Sub-chapters whose main content is one table (read from the PDF by hand).
TABLE_IDS = {'1.5', '1.6', '2.2', '2.3', '2.4', '2.5', '2.6', '2.7', '2.9', '3.5', '4.1',
             '4.7', '5.1', '7.2', '8.1', '8.2', '8.3', 'glosarium'}
SOURCE_QUALITY = {
    '4.6': {'flag': 'company_sourced',
            'note': 'All 4.6 sources come from or cover Tetra Pak; the module says no independent source exists yet.'},
}

# Tables rebuilt as one sentence per row (decision 0017): chunk -> (PDF page, header's
# first cell). pypdf's plain text loses cell borders; its positional visitor keeps them.
ROW_TABLES = {'1.6': (8, 'Kelompok'), '2.6': (13, 'Benda'), '2.7': (14, 'Zat'), '2.9': (15, 'Tingkat'),
              '4.7': (22, 'Sampah B3')}

HEADER_TITLE = 'Modul Pendidikan Fisika Lingkungan –'
HEADER_SUB = 'UNJ · Media ELIO'
HALAMAN = re.compile(r'Halaman (\d+)')
CHAPTER = re.compile(r'Bab (\d)\. ')
SUB = re.compile(r'(\d)\.(\d+) \S')


def normalize(text):
    """The only change made to the PDF's text: pypdf reads the bullet glyph as DEL."""
    return text.replace('\x7f', '•')


def page_lines(reader):
    """[(pdfPage, printedPage, lines)] with the 3-line running header removed."""
    pages = []
    for index, page in enumerate(reader.pages, 1):
        lines = [l.rstrip() for l in normalize(page.extract_text()).split('\n')]
        printed = None
        if index > 1:
            ok = (len(lines) > 3 and lines[0].startswith(HEADER_TITLE) and lines[1] == HEADER_SUB
                  and HALAMAN.fullmatch(lines[2]))
            if not ok:
                sys.exit(f'page {index}: running header not found: {lines[:3]}')
            printed = int(HALAMAN.fullmatch(lines[2])[1])
            lines = lines[3:]
        pages.append((index, printed, [l for l in lines if l.strip()]))
    return pages


def chapter_titles(pages):
    """Chapter titles from the contents page (p.2), one line each there."""
    titles = {}
    for line in pages[1][2]:
        m = CHAPTER.match(line)
        if m:
            titles[int(m[1])] = line
    return titles


def table_rows(reader, page, first_header_cell):
    """[[cell, ...], ...] for the table whose header starts with [first_header_cell]; row 0 is the header.

    Text runs come cell by cell in reading order, so consecutive runs at the same x
    form one cell, and returning to the first column starts a row. The table ends at
    the first run outside the header's columns. Only a cell's first line has an absolute
    y, and every cell of a row must share it, or the layout is not what we assume.
    """
    runs = []

    def visit(text, cm, tm, font, size):
        t = normalize(text).replace('\n', '').strip()
        if t:
            runs.append((round(tm[4] * cm[0] + cm[4], 1), round(tm[5] * cm[3] + cm[5], 1), t))

    reader.pages[page - 1].extract_text(visitor_text=visit)
    start = next(i for i, r in enumerate(runs) if r[2] == first_header_cell)
    columns = [x for x, y, _ in runs[start:] if y == runs[start][1]]
    cells = []
    for x, y, t in runs[start:]:
        if x not in columns:
            break
        if cells and cells[-1][0] == x:
            cells[-1][2].append(t)
        else:
            cells.append([x, y, [t]])
    rows = []
    for x, y, lines in cells:
        if x == columns[0]:
            rows.append([])
        rows[-1].append((y, ' '.join(lines)))
    for n, row in enumerate(rows):
        if len(row) != len(columns) or len({y for y, _ in row}) != 1:
            sys.exit(f'p.{page} table {first_header_cell!r} row {n}: cells do not line up: {row}')
    return [[cell for _, cell in row] for row in rows]


def row_sentences(rows):
    """'<first cell> — <header>: <cell> — ...' per data row, cells verbatim."""
    header = rows[0]
    return [' — '.join([row[0]] + [f'{h}: {c.rstrip(".")}' for h, c in zip(header[1:], row[1:])]) + '.'
            for row in rows[1:]]


def build(pdf=DEFAULT_PDF):
    data = Path(pdf).read_bytes()
    reader = pypdf.PdfReader(pdf)
    pages = page_lines(reader)
    titles = chapter_titles(pages)

    chunks = []
    chapter = chapter_title = current = next_sub = None

    def start(cid, ctype, title, page):
        nonlocal current
        current = {'id': cid, 'chapter': chapter_title, 'subchapter': title, 'type': ctype,
                   'pdfPage': page[0], 'printedPage': page[1], 'pdfPageEnd': page[0], 'lines': []}
        chunks.append(current)

    for page in pages[FIRST_CONTENT_PAGE - 1:]:
        lines = page[2]
        i = 0
        while i < len(lines):
            line = lines[i]
            m_chapter = CHAPTER.match(line)
            m_sub = SUB.match(line)
            if m_chapter and int(m_chapter[1]) == (chapter + 1 if isinstance(chapter, int) else 1):
                chapter = int(m_chapter[1])
                chapter_title = titles[chapter]
                next_sub = 1
                # A heading wrapped over two lines: the contents page has it on one.
                if len(line) < len(chapter_title) and i + 1 < len(lines) \
                        and f'{line} {lines[i + 1]}'.startswith(chapter_title):
                    i += 1
                    line = f'{line} {lines[i]}'
                # Bab 9 is one Q&A block; elsewhere the intro joins the first sub-chapter.
                start(f'{chapter}.qa' if chapter == 9 else f'{chapter}.intro',
                      'qa' if chapter == 9 else 'text', None, page)
                current['lines'].append(line)
            elif isinstance(chapter, int) and m_sub and int(m_sub[1]) == chapter and int(m_sub[2]) == next_sub:
                if line.count('(') > line.count(')') and i + 1 < len(lines):
                    i += 1
                    line = f'{line} {lines[i]}'
                cid = f'{chapter}.{next_sub}'
                intro = chunks.pop() if current['id'].endswith('.intro') else None
                start(cid, 'lkpd_key' if cid == '8.4' else 'table' if cid in TABLE_IDS else 'text',
                      line.split(' ', 1)[1], page)
                if intro:
                    current['lines'] = intro['lines']
                    current['pdfPage'], current['printedPage'] = intro['pdfPage'], intro['printedPage']
                current['lines'].append(line)
                next_sub += 1
            elif re.fullmatch(rf'Ringkasan Bab {chapter}', line or ''):
                start(f'{chapter}.summary', 'summary', line, page)
                current['lines'].append(line)
            elif re.fullmatch(rf'Tanya-Jawab Bab {chapter}', line or ''):
                start(f'{chapter}.qa', 'qa', line, page)
                current['lines'].append(line)
            elif line == 'Glosarium' and i == 0:
                chapter, chapter_title = 'glosarium', 'Glosarium'
                start('glosarium', 'table', None, page)
                current['lines'].append(line)
            elif line == 'Daftar Pustaka' and i == 0:
                chapter, chapter_title = 'pustaka', 'Daftar Pustaka'
                start('pustaka', 'sources', None, page)
                current['lines'].append(line)
            else:
                current['lines'].append(line)
            current['pdfPageEnd'] = page[0]
            i += 1

    out = []
    for c in chunks:
        text = '\n'.join(c.pop('lines'))
        c['text'] = text
        c['words'] = len(text.split())
        if c['id'] in SOURCE_QUALITY:
            c['sourceQuality'] = SOURCE_QUALITY[c['id']]
        if c['id'] in ROW_TABLES:
            c['rows'] = row_sentences(table_rows(reader, *ROW_TABLES[c['id']]))
        out.append(c)
    return {
        'source': 'docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf',
        'sourceSha256': hashlib.sha256(data).hexdigest(),
        'pdfPages': len(reader.pages),
        'extractor': f'scripts/extract_module.py, pypdf {pypdf.__version__}',
        'chunks': out,
    }


def dump(result):
    return json.dumps(result, ensure_ascii=False, indent=2) + '\n'


if __name__ == '__main__':
    result = build(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PDF)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(dump(result), encoding='utf-8')
    print(f'{len(result["chunks"])} chunks -> {OUT.relative_to(ROOT)}')
