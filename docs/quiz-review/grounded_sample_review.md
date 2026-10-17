# Grounded quiz sample: owner review (M3.4)

B v2 questions from the real model (450-word passages, final prompt), 10 objects x 3. Behind
`--dart-define=GROUNDED_QUIZ=true` (default off). I have not judged quality: please fill the last
three columns (y / n / note). Page = PDF page = printed page. Fallback rows show why the model's
reply was rejected; students would have seen a fixed fallback question there. The sample predates two
validator fixes, applied to it here: chunk credited to the passage the quote is really from, and
placeholder rubrics (e.g. ["1", "2"]) marked.

## Ponsel

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 1.4, 5.2, 2.1 sent | | | | |
| 2 | essay | (placeholder rubric: the current validator would reject this reply) Berdasarkan kutipan modul kuliah, jelaskan mengapa 'Ponsel' yang terbuat dari plastik, logam, dan kaca dikategorikan sebagai limbah B3 dan bagaimana prinsip penanganannya harus dilakukan! | essay | 1<br>2 | Jangan membuang B3 ke tempat sampah biasa, saluran air, toilet, atau tanah. | 2.8 | 14 |  |  |  |
| 3 | multipleChoice | Mengapa ponsel yang terbuat dari plastik, logam, dan kaca dikategorikan sebagai limbah B3, berdasarkan kutipan modul kuliah? | Mengandung logam dan bahan berbahaya sehingga dibahas sebagai sampah B3 di Bab 2. | Karena termasuk dalam kategori limbah non-organik biasa.<br>Karena merupakan contoh sampah plastik sekali pakai.<br>Karena mengandung bahan organik yang sulit diuraikan mikroorganisme. | Perangkat elektronik rusak (e-waste) mengandung logam, tetapi juga mengandung bahan berbahaya sehingga dibahas sebagai sampah B3 di Bab 2. | 1.4 | 7 |  |  |  |

## Laptop

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Laptop mengandung bahan dari kategori limbah apa menurut kutipan? | limbah B3 | sampah rumah tangga biasa<br>limbah organik biasa<br>sampah non-organik biasa | Perangkat elektronik rusak (e-waste) mengandung logam, tetapi juga mengandung bahan berbahaya sehingga dibahas sebagai sampah B3 di Bab 2. | 1.4 (model said 2.1) | 7 |  |  |  |
| 2 | essay | Berdasarkan kutipan modul kuliah yang diberikan, jelaskan mengapa laptop dikategorikan sebagai limbah B3 dan apa implikasi dari klasifikasi tersebut terhadap penanganan laptop! | essay | Penjelasan mengacu pada sifat bahan berbahaya dari laptop (plastik dan logam)<br>Menyebutkan kewajiban penanganan limbah B3 untuk laptop | Perangkat elektronik rusak (e-waste) mengandung logam, tetapi juga mengandung bahan berbahaya sehingga dibahas sebagai sampah B3 di Bab 2. | 1.4 (model said 2.1) | 7 |  |  |  |
| 3 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 1.4, 5.2, 2.1 sent | | | | |

## Baterai

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Apa kategori limbah yang termasuk dalam kategori B3 dari benda 'Baterai'? | limbah B3 rumah tangga | Limbah B3 kategori 2 dampak tunda<br>Limbah B3 kategori 1 dampak akut<br>Sampah non-organik biasa | Contoh B3 rumah tangga: baterai, lampu TL/CFL, aerosol, aki, elektronik rusak, pembersih kimia, pestisida, obat kedaluwarsa. | 2.summary | 16 |  |  |  |
| 2 | essay | Berdasarkan kutipan modul, jelaskan mengapa baterai bekas dikategorikan sebagai limbah B3 dan apa implikasinya bagi penanganannya. | essay | Menjelaskan karakteristik bahaya dari baterai sebagai limbah B3<br>Menjelaskan aturan penanganan yang benar untuk baterai | Sampah B3 adalah sampah yang mengandung bahan berbahaya dan beracun. Bahaya utamanya bukan pada volumenya, tetapi pada sifat zatnya: sedikit saja sudah dapat meracuni, membakar, meledak, atau mengikis. | 2.1 | 10 |  |  |  |
| 3 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 1.4, 4.qa, 2.1 sent | | | | |

## Botol plastik

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Apa kategori sampah plastik yang termasuk botol plastik minuman? | Sampah anorganik (dapat didaur ulang) | Sampah berbahaya yang harus dibuang khusus<br>Sampah logam yang perlu dipisahkan dari plastik<br>Sampah organik yang mudah diuraikan | Botol plastik minuman (PET), kantong kresek, sedotan dan peralatan makan sekali pakai. | 1.4 | 7 |  |  |  |
| 2 | essay | Berdasarkan kutipan modul kuliah, jelaskan mengapa botol plastik jenis PET berbeda perilakunya ketika dimasukkan ke dalam air dibandingkan dengan botol plastik jenis HDPE, kaitkan dengan konsep massa jenisnya. | essay | Mampu menyebutkan massa jenis PET dan HDPE berdasarkan kutipan.<br>Mampu menjelaskan perbedaan perilaku (mengapung atau tenggelam) berdasarkan perbandingan massa jenisnya dengan air. | PET Botol minuman bening sekitar 1,38 Tenggelam | 4.2 (model said 6.1) | 20 |  |  |  |
| 3 | multipleChoice | Berdasarkan kutipan modul kuliah, apa perbedaan utama dalam kategori atau sifat daur ulang antara botol plastik PET dan botol plastik HDPE jika dikaitkan dengan kode jenis resin? | 1 = PET, 2 = HDPE | PET adalah jenis sampah non-organik<br>Keduanya sama-sama termasuk anorganik<br>HDPE memiliki kerapatan berbeda | 1. Pengumpulan dan pemilahan berdasarkan kode jenis resin (1 = PET, 2 = HDPE, dan seterusnya). | 4.2 | 20 |  |  |  |

## Gelas plastik

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 4.2, 6.1, 1.4 sent | | | | |
| 2 | essay | (fallback: quote not verbatim in the passages) | | | | 6.1, 1.2, 1.4 sent | | | | |
| 3 | multipleChoice | Berdasarkan kutipan tersebut, bagaimana klasifikasi bahan dasar gelas plastik dikaitkan dengan kategori sampah yang lebih luas, mengingat gelas plastik termasuk dalam kelompok sampah non-organik yang dapat didaur ulang? | Plastik termasuk sampah non-organik yang dapat didaur ulang | Merupakan sampah yang hanya dapat bertahan dalam lingkungan puluhan tahun<br>Merupakan sampah organik yang mudah terurai secara alami<br>Merupakan sampah yang tidak dapat diuraikan oleh mikroorganisme | Sampah non-organik berasal dari bahan sintetis atau bahan anorganis yang tidak dapat atau sangat sulit diuraikan mikroorganisme. | 1.4 | 7 |  |  |  |

## Toples kaca

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Menurut kutipan, benda apa yang termasuk dalam kategori sampah kaca? | Botol kaca, pecahan kaca jendela dan cermin | Kaleng aluminium minuman dan makanan kaleng<br>Ban bekas untuk dijadikan bahan lantai<br>Kaleng baja dari pemilahan magnetik | c. Sampah kaca • Botol kaca, pecahan kaca jendela dan cermin. | 1.4 | 7 |  |  |  |
| 2 | essay | Jelaskan proses daur ulang yang dapat dilakukan terhadap toples kaca berdasarkan kutipan yang diberikan. | essay | Menjelaskan proses daur ulang kaca (dipilah menurut warna, dicuci, dihancurkan, dilebur, dan dibentuk ulang)<br>Menyebutkan potensi pemanfaatan kaca (botol utuh lebih baik dipakai ulang) | Kaca: dipilah menurut warna, dicuci, dihancurkan (cullet), dilebur, dan dibentuk ulang. Kaca dapat didaur ulang berkali-kali tanpa kehilangan mutu; botol utuh lebih baik dipakai ulang (reuse). | 4.5 | 21 |  |  |  |
| 3 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 6.8, 1.4 sent | | | | |

## Kaleng aluminium

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Bahan apa yang digunakan untuk kaleng aluminium? | aluminium | kaca<br>tembaga<br>besi | Kaleng aluminium minuman dan makanan kaleng, potongan besi, baja, tembaga, pipa dan kawat logam. | 1.4 | 7 |  |  |  |
| 2 | essay | (placeholder rubric: the current validator would reject this reply) Jelaskan mengapa kaleng aluminium dapat dipisahkan dari sampah logam lainnya menggunakan metode pemilahan magnetik, berdasarkan informasi dari kutipan modul kuliah. | essay | 1<br>2 | Pemilahan magnetik Logam feromagnetik (besi, baja) tertarik magnet, sedangkan aluminium, tembaga, kaca, dan plastik tidak. | 6.8 | 27 |  |  |  |
| 3 | multipleChoice | Berdasarkan kutipan modul, energi minimum yang dibutuhkan hanya untuk meleburkan 1 kg aluminium dari suhu 25°C hingga 660°C adalah sekitar berapa liter kWh? | 0,27 kWh | 968.500 J<br>571.500 J<br>397.000 J | Total Q = 968.500 J ≈ 0,97 MJ. Dalam kWh: 0,97 MJ ÷ 3,6 MJ/kWh ≈ 0,27 kWh. | 6.2 | 26 |  |  |  |

## Kardus

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | (fallback: unparseable) | | | | 1.2, 4.3, 1.3 sent | | | | |
| 2 | essay | Jelaskan mengapa kardus yang merupakan bahan dari kertas karton dikategorikan sebagai sampah anorganik yang dapat didaur ulang, berdasarkan informasi yang ada di modul! | essay | kertas berasal dari serat tumbuhan sehingga bersifat dapat terurai<br>dalam pemilahan sehari-hari sering dimasukkan ke anorganik daur ulang karena lebih bernilai didaur ulang menjadi kertas | Kertas berasal dari serat tumbuhan sehingga bersifat dapat terurai, namun dalam pemilahan sehari-hari sering dimasukkan ke anorganik daur ulang karena lebih bernilai didaur ulang menjadi kertas. | 9.qa (model said 1.3) | 34 |  |  |  |
| 3 | multipleChoice | (fallback: quote not verbatim in the passages) | | | | 1.2, 4.3, 1.3 sent | | | | |

## Kulit pisang

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Benda apa yang termasuk dalam kategori sampah organik yang bisa diuraikan secara alami oleh mikroorganisme? | Kulit pisang | Produk susu<br>Kertas berlapis plastik<br>Daging busuk yang tidak terpakai | Kulit buah: kulit pisang, kulit jeruk, kulit melon. | 1.3 | 6 |  |  |  |
| 2 | essay | Jelaskan mengapa kulit pisang diklasifikasikan sebagai sampah organik dalam konteks pemilahan sampah menurut kutipan modul! | essay | kulit pisang termasuk sisa makanan/bahan pangan<br>memiliki sifat biodegradable | Kulit buah: kulit pisang, kulit jeruk, kulit melon. | 1.3 | 6 |  |  |  |
| 3 | multipleChoice | Berdasarkan kutipan modul, jika kita menganalisis 'kulit pisang' sebagai sampah organik, manakah kesimpulan yang paling tepat mengenai proses pemrosesannya yang disarankan jika tujuannya adalah menghasilkan produk sampingan bernilai guna tinggi yang dipercepat dekomposisinya? | Vermikompos | Kotoran ternak<br>Sisa padat dan cair (slurry)<br>Biogas | Vermikompos memakai cacing tanah (umumnya Eisenia fetida atau Lumbricus rubellus) untuk mempercepat dekomposisi. | 3.4 | 18 |  |  |  |

## Kotak susu

| q | type | question | correct | other options / rubric | quote | chunk | p. | about the object? | correct per module? | keep |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | multipleChoice | Bahan utama dari kotak susu (kemasan karton minuman) yang berlapis adalah... | kertas karton | Plastik dan aluminium foil<br>Serat dari pulper<br>Kotoran ternak | Sebagian besar terdiri dari kertas karton, dilapisi plastik dan lapisan tipis aluminium foil. | 4.6 | 21 |  |  |  |
| 2 | essay | Jelaskan mengapa kotak susu (kemasan karton minuman berlapis) tidak termasuk sampah organik meskipun sebagian besar bahannya adalah kertas. | essay | Menjelaskan bahwa kemasan karton minuman berlapis tidak dapat dikomposkan.<br>Menyebutkan alasan utama mengapa ia termasuk sampah non-organik daur ulang. | Komposisi yang umum dikutip dari Tetra Pak adalah sekitar 75% karton, 20% plastik, dan 5% aluminium; angka ini perkiraan dan dapat berbeda menurut jenis kemasan. | 4.6 | 21 |  |  |  |
| 3 | multipleChoice | Mengapa 'Kotak susu' (kemasan karton minuman berlapis) dikategorikan sebagai sampah anorganik daur ulang meskipun sebagian besar bahannya adalah kertas, berdasarkan deskripsi komponennya? | Berlapis plastik dan aluminium sehingga tidak dapat dikomposkan | Karena tidak mengandung polutan<br>Karena bahannya kertas saja<br>Karena dapat terurai secara alami | Kemasan karton minuman bekas termasuk sampah non-organik yang dapat didaur ulang meskipun sebagian besar bahannya kertas, karena berlapis plastik dan aluminium sehingga tidak dapat dikomposkan. | 4.6 | 21 |  |  |  |
