# Quiz Bank Key & Distractor Verification (Key-Check)

This document records the comprehensive audit of all quiz items across the Object Bank, the Label-Pool Bank, and the source Course Module chunks (`docs/module/Modul_Sampah_B3_Daur_Ulang_ELIO.pdf`, `assets/module/module_chunks.json`, decision `0014`).

---

## 1. Summary of Items Checked

- **Label-Pool Bank (`assets/quiz/question_bank_draft.json`)**:
  - 7 pools: `organik`, `paper_family`, `plastic`, `glass`, `metal`, `tetra_pak`, `e_waste_b3`
  - 6 Multiple Choice questions per pool: **42 MCQ**
  - 2 Essay questions per pool: **14 Essays**
  - **Subtotal: 56 items**

- **Object Bank (`assets/quiz/object_bank_draft.json`)**:
  - 13 objects: `ponsel`, `laptop`, `perangkat_elektronik`, `baterai`, `lampu_tl_cfl`, `botol_plastik`, `gelas_plastik`, `toples_kaca`, `kaleng_aluminium`, `kardus`, `kertas`, `kulit_pisang`, `kotak_susu`
  - Multiple Choice questions (4 per object, 3 for `gelas_plastik`): **51 MCQ**
  - Essay questions (1 per object): **13 Essays**
  - **Subtotal: 64 items**

- **Total Items Audited**: **120 items (93 MCQ, 27 Essays)**

---

## 2. Verification Criteria

For every item in both banks, the following five criteria were verified against the module source chunks:
1. **Key Accuracy**: The marked correct option (`correct`) is factually accurate and faithful to the module text.
2. **Distractor Validity**: The distractors (`wrong[0..2]`) are plainly wrong, unambiguously distinct, and neither defensible nor viable alternatives per the module.
3. **Explanation Agreement**: The explanation directly supports and agrees with the marked key.
4. **Traceable Page References**: Every cited page reference (`pdfPage`) points to a real, valid page in the 36-page course module, and the supporting `quote` is verbatim in that page's text or table row.
5. **No Self-Answering Stems**: The question stem does not give away the correct answer or contain unintentional clues.

---

## 3. Audit Findings

Out of the **120 items** checked, **119 items** fully satisfy all five criteria.

**1 definite error** was identified in the Object Bank: `kardus-mc-01`.

---

## 4. Definite Error Report

### Item ID: `kardus-mc-01`
- **Object**: `kardus` (`paper_family`)
- **Difficulty**: Mudah
- **Type**: Multiple Choice (MCQ)

#### Problem
In the recent revision (commit `eed2036`), the question stem and correct answer were updated from a category question to a causal question:
- *Current Question*: `"Mengapa kardus polos tanpa lapisan plastik atau aluminium foil dapat terurai secara alami?"`
- *Current Correct*: `"Karena berasal dari serat tumbuhan yang dapat diuraikan mikroorganisme"`

However, the distractors and supporting quote were left in their pre-revision state:
- *Current Distractors*:
  1. `"Sampah B3 yang beracun"`
  2. `"Sampah non-organik dari bahan sintetis"`
  3. `"Sampah yang mengandung merkuri"`
- *Current Quote*: `"Kertas dan karton tanpa lapisan plastik, kardus polos tanpa lapisan aluminium foil, kayu tipis, dan bambu."` (p. 7, chunk `1.3`)

This causes two definite defects:
1. **Grammatical Disconnect & Obvious Key Giveaway (Test-Wiseness Flaw)**: The question asks `"Mengapa..."` (*Why...*). The distractors are bare noun phrases identifying waste categories rather than reasons or causes. Only the correct answer begins with `"Karena..."` (*Because...*) and provides a causal explanation. The distractors fail to grammatically or logically answer the question, making the correct answer immediately obvious without needing module knowledge.
2. **Supporting Quote Mismatch**: The cited quote from subsection 1.3.d merely enumerates plain cardboard as an example under *"d. Produk organik terurai lainnya"*. It does not state or prove *why* cardboard decomposes (i.e. that it originates from plant fiber and is broken down by microorganisms).

#### Module Quote with Page
- **Page 7, chunk `1.3` (Catatan klasifikasi)**:
  > *"Kertas dan karton berasal dari serat tumbuhan sehingga dapat terurai, tetapi di sistem pemilahan sehari-hari sering ditaruh pada kelompok anorganik daur ulang karena lebih bernilai bila didaur ulang menjadi kertas baru (lihat Bab 4)."*
- **Page 6, chunk `1.3` (Definisi)**:
  > *"Sampah organik adalah sampah yang berasal dari makhluk hidup (hewan dan tumbuhan) dan dapat terurai secara alami oleh mikroorganisme dalam jangka waktu tertentu."*

#### Proposed Fix
Update distractors to parallel causal clauses answering `"Mengapa..."`, and update the supporting quote to the causal statement on page 7 (chunk `1.3`):

```json
{
  "id": "kardus-mc-01",
  "object": "kardus",
  "type": "mc",
  "difficulty": "Mudah",
  "question": "Mengapa kardus polos tanpa lapisan plastik atau aluminium foil dapat terurai secara alami?",
  "correct": "Karena berasal dari serat tumbuhan yang dapat diuraikan mikroorganisme",
  "wrong": [
    "Karena terbuat dari bahan sintetis yang mudah larut dalam air",
    "Karena mengandung bahan kimia yang mempercepat pembusukan",
    "Karena telah dicampur dengan mikroorganisme pengurai sejak pembuatan"
  ],
  "explanation": "Kardus polos berasal dari serat tumbuhan yang dapat terurai secara alami oleh mikroorganisme; dalam pemilahan sehari-hari, kardus bersih ditaruh di anorganik daur ulang karena lebih bernilai bila didaur ulang.",
  "sourceChunk": "1.3",
  "pdfPage": 7,
  "quote": "Kertas dan karton berasal dari serat tumbuhan sehingga dapat terurai, tetapi di sistem pemilahan sehari-hari sering ditaruh pada kelompok anorganik daur ulang karena lebih bernilai bila didaur ulang menjadi kertas baru (lihat Bab 4).",
  "status": "accepted"
}
```

*(Note: Per task instructions, no edits were applied to bank files).*
