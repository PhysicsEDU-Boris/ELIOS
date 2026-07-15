# ELIO Physics Lab — Module Content (Materi Pembelajaran)

**Companion to:** `ELIO Physics Lab — Flutter/Riverpod Integration Plan`
**Purpose:** This document supplies the actual learner-facing content
(Bahasa Indonesia) for every `DeepExplainCard` / content block that the
integration plan references as "port from v1" or "reuse verbatim." Where
the integration plan only sketched a bullet list, this document writes it
out in full, textbook style, so it can be pasted directly into each
module's content source (a `.dart` constants file, a Firestore doc, or
inline strings — whichever your `DeepExplainCard` expects).

Structure per module: **Konsep Inti** (core concept) → **Penurunan/Makna
Rumus** (what the formula means) → **Aplikasi di ELIO** (how the robot
actually uses this physics) → **Contoh Soal Terselesaikan** (one worked
example matching the unit-test numbers in the integration plan) →
**Catatan Akurasi** (accuracy disclaimers, only where the integration plan
flags a number as illustrative/approximate).

Formula variable names are kept untranslated, per the integration plan's
language notes.

---

## Modul A — Densitas & Klasifikasi Sampah

### Konsep Inti

Densitas (massa jenis) adalah ukuran seberapa "padat" materi tersusun di
dalam suatu benda. Dua benda bisa punya ukuran (volume) yang sama tapi
berat yang jauh berbeda — itu karena partikel penyusunnya dikemas dengan
kerapatan berbeda. Besi terasa berat digenggam bukan karena besi "lebih
banyak," tapi karena atom-atomnya lebih rapat per satuan ruang dibanding,
katakanlah, plastik.

Konsep ini penting untuk ELIO karena **densitas adalah salah satu sinyal
paling murah dan paling cepat untuk menebak jenis material** — jauh lebih
murah dibanding, misalnya, menganalisis spektrum inframerah tiap benda.

### Makna Rumus

$$\rho = \frac{m}{V}$$

- **ρ (rho)** — densitas, satuan g/cm³ (atau kg/m³ dalam SI)
- **m** — massa benda, dalam gram
- **V** — volume benda, dalam cm³

Air murni punya ρ = 1.0 g/cm³ — ini adalah **titik referensi** yang dipakai
untuk menjelaskan kenapa sebagian plastik mengapung dan sebagian tenggelam.

**Rentang klasifikasi yang dipakai modul ini:**

| Kategori          | Rentang ρ (g/cm³) | Contoh material                               |
| ----------------- | ----------------- | --------------------------------------------- |
| Plastik           | 0.9 – 1.4         | HDPE (≈0.95), PET (≈1.38)                     |
| Kaca              | 2.4 – 2.6         | Botol kaca, pecahan kaca                      |
| Logam             | ≥ 2.7             | Aluminium (≈2.7), besi jauh lebih tinggi lagi |
| Di luar jangkauan | selainnya         | Perlu sensor tambahan                         |

### Kenapa HDPE Mengapung tapi PET Tenggelam

Ini teknik pemilahan plastik nyata yang dipakai industri daur ulang skala
besar, disebut **flotasi/tangki pemisah air (sink-float separation)**:

1. Sampah plastik campuran dimasukkan ke tangki berisi air.
2. Plastik dengan ρ < 1.0 g/cm³ (seperti HDPE, PP) **mengapung** di
   permukaan.
3. Plastik dengan ρ > 1.0 g/cm³ (seperti PET, PVC) **tenggelam** ke dasar.
4. Dua lapisan ini kemudian diambil terpisah oleh mesin skimmer dan
   conveyor dasar tangki.

Ini menjelaskan kenapa densitas bukan sekadar angka abstrak di kelas fisika
— ia benar-benar dipakai sebagai mesin pemilah fisik di pabrik daur ulang
sungguhan, dan ELIO meniru prinsip yang sama secara optik.

### Aplikasi di ELIO

ELIO tidak mencelupkan sampah ke air. Sebagai gantinya, ELIO memakai:

- **Load-cell (sensor berat)** di nampan penampung — untuk mengukur _m_.
- **Kamera 3D / depth camera** — untuk mengestimasi _V_ dari bentuk dan
  dimensi benda.
- Dari dua angka ini, mikrokontroler ELIO menghitung ρ = m/V secara
  real-time dan mencocokkannya ke tabel rentang di atas untuk menebak
  kategori material — persis seperti perhitungan yang dilakukan modul
  simulasi ini.

**Catatan efisiensi:** benda yang tidak dipipihkan (misalnya botol plastik
yang masih menggembung) akan terbaca _V_ lebih besar dari sebenarnya
sehingga ρ terhitung lebih kecil dan berisiko salah kategori. Inilah alasan
petunjuk operasional ELIO selalu meminta pengguna **"tekan botolnya dulu"**
sebelum dimasukkan — bukan sekadar menghemat ruang, tapi menjaga akurasi
sensor densitas.

### Contoh Soal Terselesaikan

> Sebuah benda memiliki massa 1250 g dan volume 500 cm³. Termasuk kategori
> apa benda ini?

**Penyelesaian:**
$$\rho = \frac{1250}{500} = 2.5 \text{ g/cm}^3$$

2.5 g/cm³ berada dalam rentang 2.4–2.6 → **kategori Kaca**.

### Miskonsepsi yang Perlu Diwaspadai (untuk distractor kuis)

Kesalahan konsep paling umum adalah **menukar posisi m dan V**, menghitung
V/m alih-alih m/V. Ini bukan cuma salah hitung — ini salah paham tentang
apa yang diukur "per satuan": densitas adalah massa _per volume_, bukan
volume _per massa_. Menukar keduanya bisa mengubah kategori benda secara
drastis (mis. 500/1250 = 0.4 g/cm³, salah kategori total).

---

## Modul B — Kalor & Termodinamika Pengomposan

### Konsep Inti

Saat mikroorganisme di tumpukan kompos memecah sampah organik, mereka
melepaskan energi dalam bentuk **kalor (heat)** — ini disebut proses
eksotermik biologis. Suhu tumpukan kompos naik bukan karena api atau listrik,
tapi karena aktivitas metabolisme jutaan bakteri dan jamur yang bekerja
memecah rantai molekul organik.

Modul ini memodelkan **berapa banyak kalor** yang perlu diserap atau
dilepas suatu massa kompos untuk mengalami perubahan suhu tertentu, dan
menghubungkannya ke fase biologis nyata dari proses pengomposan.

### Makna Rumus

$$Q = m \cdot c \cdot \Delta T$$

- **Q** — jumlah kalor, dalam Joule (J)
- **m** — massa material, dalam kg
- **c** — kalor jenis (specific heat capacity), seberapa banyak energi
  dibutuhkan untuk menaikkan suhu 1 kg material sebesar 1°C. Modul ini
  memakai c = 4000 J/kg°C sebagai pendekatan untuk material organik lembap
  (mendekati nilai air yang c-nya 4186 J/kg°C, karena sampah organik
  didominasi kandungan air).
- **ΔT** — perubahan suhu, dalam °C

### Tiga Fase Biologis Pengomposan

| Fase                       | Suhu akhir | Apa yang terjadi                                                                                        |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------------------------- |
| Mesofilik                  | < 55°C     | Bakteri suhu-sedang mulai memecah gula & protein sederhana                                              |
| Termofilik                 | 55–60°C    | Bakteri tahan-panas mendominasi, penguraian tercepat, sekaligus fase yang membunuh patogen & biji gulma |
| Terlalu panas (overheated) | > 60°C     | Aktivitas mikroba justru mulai terhambat/mati; perlu diaduk untuk melepas panas                         |

Fase termofilik sebenarnya **diinginkan**, bukan masalah — suhu tinggi di
titik ini adalah tanda proses berjalan sehat dan sedang membunuh
mikroorganisme berbahaya. Masalah baru muncul kalau suhu melewati ~60°C
tanpa henti, karena itu justru membunuh bakteri baik yang sedang bekerja.

### Hubungan dengan Porositas (Keterkaitan Antar-Modul)

Kalor yang dihasilkan tumpukan kompos sangat bergantung pada **berapa
banyak oksigen yang bisa masuk ke sela-sela tumpukan** — ini diukur sebagai
porositas (lihat Modul Organik di Waste Deep-Dive). Ketika porositas rendah
(< 25%) DAN suhu akhir sudah di atas 55°C, tumpukan berisiko masuk kondisi
**anaerobik** — oksigen habis, mikroba pembusuk anaerob mengambil alih, dan
proses ini menghasilkan **gas metana (CH₄)**, bukan hanya CO₂ seperti proses
aerobik normal. Metana berbahaya karena mudah terbakar dan merupakan gas
rumah kaca yang jauh lebih kuat dari CO₂.

Inilah kenapa simulasi ini menampilkan **peringatan "anaerob — risiko
metana"** secara eksplisit ketika kedua kondisi itu terpenuhi bersamaan,
bukan cuma menunjukkan angka suhu saja.

### Aplikasi di ELIO

ELIO memakai **sensor inframerah (IR)** untuk membaca suhu permukaan
tumpukan organik tanpa kontak langsung, lalu memicu prompt **"balik
kompos"** ke operator ketika pola suhu menunjukkan tanda-tanda anaerobik
(suhu tinggi tapi porositas rendah/tumpukan terlalu padat). Solusi yang
disarankan sistem: menambahkan bahan berpori seperti ranting kering
(dry-twig porosity fix) untuk membuka jalur udara di dalam tumpukan.

### Contoh Soal Terselesaikan

> Massa kompos 2 kg mengalami kenaikan suhu 20°C dari suhu awal 25°C.
> Berapa kalor yang diserap, berapa suhu akhirnya, dan termasuk fase apa?

**Penyelesaian:**
$$Q = 2 \times 4000 \times 20 = 160{.}000 \text{ J}$$
$$T_{akhir} = 25 + 20 = 45°C$$

45°C < 55°C → **fase Mesofilik**.

### Catatan Akurasi

Nilai c = 4000 J/kg°C adalah **pendekatan**, bukan nilai terukur presisi
untuk semua jenis sampah organik — kadar air dan komposisi bahan (sisa
sayur vs daun kering vs sisa buah) mengubah c secara nyata. Tandai ini
sebagai simplifikasi ilustratif di kode maupun UI.

---

## Modul C — Torsi (Torque)

_(Konten modul ini sudah ada dari build v1 dan tidak diulang di sini —
lihat `torque_simulation_page.dart` yang sudah dimigrasikan pada Fase 0.
Ringkasan formula untuk referensi silang:)_

$$\tau = r \cdot F \cdot \sin(\theta)$$

- **τ** — torsi (N·m)
- **r** — jarak dari titik putar ke titik gaya diberikan (lengan momen)
- **F** — besar gaya yang diberikan
- **θ** — sudut antara arah gaya dan lengan momen
- Batas aman ELIO: **8 N·m** — melewati ini berisiko merusak motor lengan
  penjepit.

Miskonsepsi umum: menghitung `r·F` saja dan **melupakan sin θ** — ini
membuat perhitungan benar hanya kalau gaya tegak lurus sempurna (θ = 90°,
sin θ = 1) terhadap lengan momen. Di sudut lain, ini melebih-lebihkan
torsi sebenarnya.

---

## Modul D — Usaha & Energi Potensial Gravitasi

### Konsep Inti

Setiap kali ELIO mengangkat sampah dari nampan ke tempat penampungan yang
lebih tinggi, ia melakukan **usaha (work)** melawan gravitasi. Usaha ini
tersimpan sebagai **energi potensial gravitasi** pada benda yang diangkat
— energi yang "siap dilepas" kalau benda itu dijatuhkan kembali.

Ini bukan sekadar konsep abstrak: setiap Joule usaha yang dilakukan motor
lengan ELIO untuk mengangkat sesuatu **berasal dari baterai**, sehingga
modul ini secara langsung menjelaskan kenapa mengangkat beban berat lebih
sering ke ketinggian lebih tinggi = baterai ELIO lebih cepat habis.

### Makna Rumus

$$W = E_p = m \cdot g \cdot h$$

- **W / Ep** — usaha / energi potensial gravitasi, dalam Joule (J)
- **m** — massa benda, dalam kg
- **g** — percepatan gravitasi, dibulatkan 10 m/s² untuk kemudahan hitung
  (nilai sebenarnya di permukaan bumi ≈ 9.8 m/s²)
- **h** — ketinggian benda diangkat, dalam meter

### Kenapa Sampah Organik "Lebih Mahal" Diangkat

Sampah organik cenderung memiliki massa lebih besar per volume dibanding
plastik (bandingkan dengan Modul A — plastik ρ ≈ 0.9–1.4 vs sisa makanan
basah yang jauh lebih padat). Untuk beban tipikal organik seberat
**3.5 kg** (kTypicalOrganicLoadKg), mengangkatnya ke ketinggian yang sama
dengan plastik ringan membutuhkan usaha jauh lebih besar — angka ini
sengaja dipakai identik di Modul A dan Modul D supaya pelajar melihat
langsung bahwa ini bukan dua topik terpisah, tapi konsekuensi fisika yang
sama dilihat dari dua sudut.

### Menghubungkan Usaha ke Baterai

Kapasitas baterai ELIO yang dipakai dalam simulasi ini adalah
**50.000 Joule** (kBatteryCapacityJ — nilai yang sama dipakai lagi di
Modul G). Setiap kali motor lengan melakukan usaha W joule untuk
mengangkat beban, persentase baterai yang terpakai dihitung sebagai:

$$\%\text{terpakai} = \frac{W}{50.000} \times 100\%$$

### Contoh Soal Terselesaikan

> ELIO mengangkat beban 1.5 kg setinggi 0.8 m. Berapa usaha yang
> dilakukan, dan berapa persen baterai yang tersisa setelahnya (asumsi
> baterai penuh sebelum operasi ini)?

**Penyelesaian:**
$$W = 1.5 \times 10 \times 0.8 = 12 \text{ J}$$
$$\%\text{tersisa} = 100 - \frac{12}{50.000}\times100 = 96{,}0\%$$

Perhatikan betapa kecil satu kali angkatan dibanding kapasitas total
baterai — ini poin pedagogis penting: baterai habis bukan dari satu
angkatan berat, tapi dari **akumulasi ratusan siklus angkat-turun** yang
kecil-kecil sepanjang hari operasi.

---

## Modul E — Kinematika (Gerak Lurus Beraturan)

### Konsep Inti

Ketika ELIO bergerak menuju target (misalnya menuju tempat sampah tujuan
setelah klasifikasi selesai), pergerakannya — dalam kondisi ideal, tanpa
percepatan/perlambatan — mengikuti **Gerak Lurus Beraturan (GLB)**:
kecepatan konstan, jarak tempuh bertambah linear terhadap waktu.

### Makna Rumus

$$v = \frac{s}{t}$$

- **v** — kecepatan (m/s)
- **s** — jarak tempuh (m)
- **t** — waktu tempuh (s)

Rumus yang sama bisa disusun ulang untuk memprediksi waktu tempuh:
$$t = \frac{s}{v}$$

Ini yang dipakai simulasi untuk menghitung `predictedTimeS` — berapa lama
robot akan sampai ke target sebelum simulasi dijalankan, lalu dibandingkan
dengan animasi real-time-nya.

### GLB vs GLBB (bagian opsional)

GLB (Gerak Lurus Beraturan) mengasumsikan kecepatan tetap sepanjang
perjalanan — cocok untuk menjelaskan konsep dasar v = s/t. Tapi ELIO yang
sesungguhnya, seperti kebanyakan robot bergerak, sebenarnya **mengalami
percepatan** saat mulai bergerak dari diam dan **perlambatan** saat
mendekati target (supaya tidak menabrak). Ini disebut GLBB (Gerak Lurus
Berubah Beraturan), dengan persamaan tambahan:

$$s = v_0 t + \frac{1}{2}at^2$$

Bagian ini sengaja diletakkan sebagai bonus yang bisa dilipat (expandable),
supaya pelajar yang baru belajar GLB tidak langsung dibebani dua konsep
sekaligus — cukup pahami v = s/t dulu sampai benar-benar matang.

### Aplikasi di ELIO

Simulasi ini meniru **umpan kamera dari atas (top-down camera feed)** yang
sebenarnya dipakai ELIO untuk melacak posisinya relatif ke target
menggunakan penanda visual di lantai (floor markers) atau odometri roda.
Timer HUD pada simulasi mencerminkan bagaimana sistem kendali ELIO
membandingkan waktu prediksi vs waktu aktual untuk mendeteksi hambatan
(misalnya roda selip atau terhalang objek).

### Contoh Soal Terselesaikan

> ELIO perlu menempuh jarak 12 meter dengan kecepatan konstan 0.4 m/s.
> Berapa lama waktu yang dibutuhkan?

**Penyelesaian:**
$$t = \frac{12}{0.4} = 30 \text{ detik}$$

### Miskonsepsi yang Perlu Diwaspadai

Kesalahan konsep yang sering muncul: mengalikan s × v alih-alih membaginya
(s/v). Ini biasanya berasal dari kebingungan rumus, bukan sekadar salah
input angka — pelajar yang salah paham v = s/t sering menganggap
"kecepatan lebih besar = butuh dikalikan dengan jarak," padahal
sebetulnya kecepatan besar seharusnya membuat waktu tempuh **lebih
singkat**, bukan lebih lama.

---

## Modul F — PWM & Tegangan Efektif Motor

### Konsep Inti

Motor DC pada ELIO (misalnya motor roda atau motor lengan) tidak selalu
diberi tegangan penuh terus-menerus. Untuk mengatur kecepatan motor tanpa
membuang energi sebagai panas, ELIO memakai teknik **PWM (Pulse Width
Modulation)** — menyalakan dan mematikan tegangan penuh secara sangat
cepat (ratusan hingga ribuan kali per detik), dan mengatur **berapa lama
proporsi waktu tegangan itu menyala** dalam satu siklus.

### Makna Rumus

$$V_{avg} = D \cdot V_{max}$$

- **V_avg** — tegangan rata-rata efektif yang "dirasakan" motor
- **D** — duty cycle, persentase waktu sinyal dalam kondisi "menyala"
  dalam satu periode (0–100%)
- **V_max** — tegangan puncak sumber daya, tetap di 12V untuk ELIO

Duty cycle 60% berarti dalam satu periode gelombang kotak, tegangan
menyala penuh (12V) selama 60% waktu dan mati (0V) selama 40% sisanya —
motor "merasakan" ini sebagai rata-rata 7.2V, bukan benar-benar tegangan
konstan 7.2V.

### Kenapa PWM Lebih Baik dari Pembagi Tegangan Linear

Cara lama mengatur kecepatan motor adalah memakai **pembagi tegangan
resistif** (resistor/potensiometer) untuk menurunkan tegangan secara
langsung. Masalahnya, kelebihan energi pada metode ini **dibuang sebagai
panas** di resistor — energi terbuang percuma dan komponen jadi panas.

PWM tidak pernah benar-benar "menurunkan" tegangan — ia hanya
menyalakan-mematikan tegangan penuh dengan sangat cepat. Karena motor
punya inersia mekanis dan induktansi kumparan yang meredam
"kedutan" on/off ini menjadi gerakan halus, hasil akhirnya terasa seperti
tegangan lebih rendah, tapi **tanpa membuang energi sebagai panas
resistif** — hanya rugi-rugi sambungan (switching loss) yang jauh lebih
kecil.

### Batasan Model Linear (Penting — Catatan Akurasi)

Perkiraan RPM pada simulasi ini,

$$RPM_{approx} \approx \frac{D}{100} \times 300$$

adalah **pendekatan linear**, BUKAN fakta terukur. Pada motor nyata,
hubungan antara duty cycle dan RPM aktual **tidak sepenuhnya linear**
begitu motor dibebani torsi (misalnya mengangkat beban lebih berat, atau
melawan gesekan roda). Karena itu UI wajib melabeli angka ini sebagai
**"Perkiraan (aproksimasi linear)"**, bukan sebagai spesifikasi motor yang
presisi.

Hal yang sama berlaku untuk klaim "penurunan tegangan rata-rata = penurunan
arus rata-rata secara proporsional" — ini **hanya benar kalau beban murni
resistif**. Pada motor (beban induktif + mekanis), penurunan arus tidak
mengikuti penurunan tegangan secara linear sederhana. Klaim seperti
"turun duty 60% = arus turun 40%" harus selalu disertai catatan bahwa ini
adalah penyederhanaan, bukan hasil pengukuran motor sesungguhnya.

### Contoh Soal Terselesaikan

> Duty cycle diatur ke 60%. Berapa tegangan rata-rata efektif, dan berapa
> perkiraan RPM?

**Penyelesaian:**
$$V_{avg} = 0.6 \times 12 = 7.2\text{V}$$
$$RPM_{approx} \approx 0.6 \times 300 = 180 \text{ RPM (perkiraan)}$$

---

## Modul G — Daya & Anggaran Baterai

### Konsep Inti

Setiap komponen ELIO yang menyala — kamera, motor penggerak, motor lengan
— menarik daya listrik dari baterai yang sama. Modul ini mengajarkan cara
menghitung **berapa lama baterai akan bertahan** tergantung kombinasi
komponen mana saja yang sedang aktif, sebuah keputusan yang benar-benar
diambil oleh sistem kendali ELIO secara real-time untuk menghemat daya.

### Makna Rumus

$$P = V \cdot I \qquad E = P \cdot t$$

- **P** — daya (Watt), sudah ditetapkan sebagai preset tetap per komponen
  untuk menyederhanakan simulasi ini (bukan dihitung dari V dan I secara
  terpisah oleh pengguna): kamera 10W, motor penggerak 36W, motor lengan
  18W
- **E** — energi total terpakai (Joule), dari daya dikali waktu
- **t** — waktu penggunaan (detik)

Sisa persentase baterai dihitung relatif terhadap kapasitas total 50.000 J
(nilai yang sama dengan Modul D):

$$\%\text{tersisa} = 100 - \frac{E}{50.000}\times 100$$

Dan estimasi berapa lama komponen-komponen itu bisa menyala sampai baterai
habis:

$$t_{estimasi} = \frac{50.000}{P_{total}}$$

Kalau tidak ada komponen menyala (P_total = 0), waktu bertahan secara
matematis **tak hingga** — UI harus menampilkan simbol "∞", bukan crash
atau NaN, karena pembagian dengan nol tidak boleh diproses sebagai error.

### Tiga Skenario Operasi ELIO

| Skenario     | Komponen aktif     | Daya total | Perkiraan waktu bertahan |
| ------------ | ------------------ | ---------- | ------------------------ |
| Mode Sortir  | Lengan + Kamera    | 28W        | ≈1786 s                  |
| Mode Jelajah | Penggerak + Kamera | 46W        | ≈1087 s                  |
| Idle         | Kamera saja        | 10W        | ≈5000 s                  |

Perilaku hemat daya nyata ELIO meniru logika ini secara langsung: motor
penggerak **dimatikan** saat sedang menyortir (karena robot diam di
tempat), dan kamera **dimatikan** saat sedang berpindah tempat jika tidak
sedang menganalisis objek — setiap watt yang tidak perlu menyala berarti
detik operasi tambahan sebelum baterai perlu diisi ulang.

### Contoh Soal Terselesaikan

> Kamera, motor penggerak, dan motor lengan semuanya menyala selama 600
> detik. Berapa energi total yang terpakai?

**Penyelesaian:**
$$P_{total} = 10 + 36 + 18 = 64\text{W}$$
$$E = 64 \times 600 = 38.400 \text{ J}$$

---

## Waste Physics Deep-Dive

Tiga kartu ini menjelaskan **kenapa setiap kategori sampah butuh metode
pemilahan fisik yang berbeda** — masing-masing kartu wajib menutup dengan
jawaban eksplisit atas pertanyaan itu, bukan hanya di kesimpulan tab.

### 8.1 Kartu Organik — Porositas & Aliran Oksigen

**Konsep Inti:** Porositas adalah persentase ruang kosong (berisi udara) di
antara partikel padat dalam tumpukan kompos. Porositas tinggi = udara bisa
mengalir bebas ke seluruh tumpukan = proses aerobik (butuh oksigen)
berjalan sehat. Porositas rendah = tumpukan terlalu padat = oksigen cepat
habis di bagian dalam = mikroba anaerobik mengambil alih.

**Fisika Kunci (ringkas, bukan derivasi penuh):**

- **Hukum Fick (difusi)** — laju perpindahan oksigen ke dalam tumpukan
  sebanding dengan luas jalur pori dan berbanding terbalik dengan jarak
  tempuh; tumpukan padat = jalur difusi lebih panjang dan sempit = laju
  oksigen masuk melambat drastis.
- **Konduksi kalor**, $\frac{Q}{t} = \frac{kA\Delta T}{L}$ — panas yang
  dihasilkan mikroba di inti tumpukan merambat keluar lewat konduksi;
  tumpukan padat menghambat pelepasan ini juga, memperparah risiko
  overheating (lihat Modul B).
- **Hukum Jurin (kapilaritas)** — menjelaskan bagaimana kelembapan naik
  atau tertahan di antara partikel kecil, memengaruhi seberapa "basah"
  pori-pori tetap dari waktu ke waktu.

**Ambang anaerobik:** porositas < 25%. Panah animasi difusi oksigen pada
simulasi melambat dan menjadi jarang saat porositas turun mendekati
ambang ini.

**Kenapa organik tidak bisa dipilah seperti inorganik/B3:** sampah organik
tidak punya sifat listrik (konduktivitas), optik (reflektansi NIR), atau
kimia berbahaya (volatilitas/reaktivitas) yang bisa dijadikan sinyal
pemilahan otomatis — satu-satunya variabel fisik yang relevan justru
adalah **struktur pori dan kelembapannya sendiri**, karena tujuan
pemrosesannya bukan memisahkan jenis material, tapi mengelola proses
biologis penguraian itu sendiri.

### 8.2 Kartu Inorganik — Tiga Sub-Simulasi

**a) Pegas Hooke**

$$F = k \cdot x$$

- **F** — gaya (N), **k** — konstanta pegas = 50 N/m (tetap), **x** —
  pemampatan pegas (m)

Prinsip ini dipakai ELIO pada mekanisme penjepit/pendorong berpegas untuk
menguji **kekerasan/elastisitas** benda — plastik keras (mis. tutup botol
PP) memberi gaya reaksi berbeda dibanding logam tipis atau kaca saat
ditekan dengan jarak kompresi yang sama, membantu klasifikasi tambahan
di luar sensor optik.

**b) Reflektansi Near-Infrared (NIR)**

Setiap jenis plastik menyerap dan memantulkan cahaya inframerah-dekat pada
panjang gelombang karakteristik yang berbeda, membentuk semacam "sidik
jari optik." Simulasi menampilkan kurva reflektansi Gaussian untuk tiga
jenis plastik (PET, HDPE, PP), dengan kurva yang dipilih disorot.

> ⚠ **Catatan akurasi wajib:** angka panjang gelombang puncak (mis. PET
> ≈1660nm, HDPE ≈1730nm, PP ≈1410nm) yang dipakai dalam simulasi ini
> **harus diverifikasi ulang terhadap referensi sorting NIR industri yang
> valid sebelum dirilis ke pengguna**. Sensor NIR sungguhan mengukur
> puncak/lembah absorbansi pada rentang tertentu yang bisa bervariasi
> tergantung alat dan kalibrasi; jangan menyajikan angka placeholder
> sebagai fakta terukur tanpa verifikasi ini.

**c) Arus Eddy (ilustratif, tanpa state numerik)**

Ketika logam bergerak melalui medan magnet yang berubah, arus pusar (eddy
current) terinduksi di dalam logam tersebut, menciptakan medan magnet
lawan yang **menolak** logam non-magnetik seperti aluminium menjauh dari
sumber magnet — sementara logam feromagnetik seperti besi justru
**tertarik** langsung ke magnet. ELIO memanfaatkan perbedaan perilaku ini
untuk memisahkan logam feromagnetik dari logam non-feromagnetik tanpa
kontak fisik sama sekali.

**Kenapa inorganik tidak bisa dipilah seperti organik/B3:** material
inorganik (plastik, kaca, logam) tidak mengalami proses biologis apa pun
yang perlu dikelola (beda dengan organik), dan sebagian besar tidak
reaktif secara kimiawi/berbahaya (beda dengan B3) — sinyal pemilahan yang
paling efektif justru sifat fisiknya yang stabil: kekerasan (Hooke),
identitas optik (NIR), dan sifat magnetik/konduktif (arus eddy).

### 8.3 Kartu B3 (Bahan Berbahaya & Beracun) — Tiga Sub-Simulasi

**a) Tekanan Uap (Vapor Pressure) — Pendekatan Clausius-Clapeyron**

Semakin tinggi suhu suatu cairan/zat, semakin besar kecenderungannya
menguap menjadi gas — inilah tekanan uap. Persamaan Clausius-Clapeyron
menjelaskan hubungan non-linear antara suhu dan tekanan uap ini secara
formal.

> ⚠ **Catatan akurasi wajib:** simulasi ini memakai **pendekatan
> kualitatif/simplifikasi**, bukan kurva P–T literal dengan konstanta
> eksponensial yang presisi secara ilmiah. Tujuannya semata menunjukkan
> **tren** (semakin panas = semakin mudah menguap = semakin berbahaya
> untuk disimpan/dibakar sembarangan), bukan memberi angka tekanan uap
> yang bisa dipakai sebagai referensi teknik sungguhan. UI wajib melabeli
> ini sebagai model sederhana/kualitatif.

**b) Insinerator (Suhu Penghancuran Ikatan Kimia)**

Slider suhu 200–1200°C mensimulasikan ruang bakar insinerator B3. Pada
suhu tertentu, ikatan kimia molekul berbahaya (misalnya senyawa organik
persisten) mulai terurai secara termal. Ambang **1000°C** dipakai dalam
simulasi ini sebagai titik "penghancuran ikatan" — bukan berarti semua
bahan B3 hancur sempurna tepat di titik ini, tapi sebagai representasi
edukatif bahwa insinerasi bahan berbahaya membutuhkan suhu **jauh lebih
tinggi** dibanding pembakaran sampah biasa untuk benar-benar menetralisir
racunnya, bukan sekadar membakar permukaannya.

**c) Perisai Radiasi (Radiation Shielding)**

$$I = I_0 \cdot e^{-\mu x}$$

- **I₀** — intensitas radiasi awal, **I** — intensitas setelah menembus
  perisai, **μ** — koefisien atenuasi (seberapa efektif material menyerap
  radiasi), **x** — ketebalan perisai

Simulasi memakai tiga koefisien ilustratif: μ*α ≈ 5.0 (partikel alfa,
paling mudah diserap — cukup selembar kertas atau kulit), μ*β ≈ 1.5
(partikel beta, butuh lapisan aluminium tipis), μ_γ ≈ 0.3 (radiasi gamma,
paling sulit diserap — butuh timbal atau beton tebal).

> ⚠ **Catatan akurasi wajib:** koefisien atenuasi sungguhan **sangat
> bergantung pada energi partikel radiasi** (diukur dalam MeV) dan jenis
> material perisai spesifik — angka di atas adalah nilai ilustratif untuk
> menunjukkan **urutan relatif** (gamma paling sulit diserap, alfa paling
> mudah), bukan nilai rujukan teknik radiasi yang presisi.

**Kenapa B3 tidak bisa dipilah seperti organik/inorganik:** perbedaan
mendasarnya bukan pada jenis material fisiknya (B3 bisa berupa logam,
cairan, atau padatan apa saja), tapi pada **tingkat bahaya laten**-nya —
volatilitas kimia, radioaktivitas, atau reaktivitas termal yang bisa
mencederai manusia atau lingkungan kalau ditangani seperti sampah biasa.
Karena itu metode "pemilahan"-nya bukan soal memisahkan jenis material,
melainkan soal **penahanan dan penanganan aman** (containment) — perisai,
suhu kontrol, dan identifikasi dini sebelum bersentuhan langsung.

---

## Ringkasan Rumus (referensi cepat, sama dengan tabel di dokumen utama)

| Modul            | Rumus            | Konstanta tetap                                  |
| ---------------- | ---------------- | ------------------------------------------------ |
| A — Densitas     | ρ = m / V        | —                                                |
| B — Kalor        | Q = m·c·ΔT       | c = 4000 J/kg°C                                  |
| C — Torsi        | τ = r·F·sin(θ)   | batas aman = 8 N·m                               |
| D — Usaha/Energi | W = Ep = m·g·h   | g = 10 m/s²                                      |
| E — Kinematika   | v = s/t          | —                                                |
| F — PWM          | V_avg = D·V_max  | V_max = 12V                                      |
| G — Daya         | P = V·I, E = P·t | kamera 10W, drive 36W, arm 18W, baterai 50.000 J |
| Waste — Hooke    | F = k·x          | k = 50 N/m                                       |
| Waste — Radiasi  | I = I₀·e^(−μx)   | μ*α≈5.0, μ*β≈1.5, μ_γ≈0.3 (ilustratif)           |

## Catatan Implementasi

Semua teks di atas ditulis untuk ditempel langsung ke dalam
`DeepExplainCard` masing-masing modul (bagian bullet list + kotak contoh
yang disorot). Setiap tempat yang ditandai **"Catatan Akurasi"** di atas
wajib disertai komentar kode yang menandai angka tersebut sebagai (a)
nilai baku buku teks, atau (b) simplifikasi ilustratif — sesuai
requirement checklist Fase 11 pada dokumen integrasi utama. Jangan
menyajikan (b) sebagai fakta terukur di UI.
