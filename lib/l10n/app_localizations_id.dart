// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get languageName => 'Bahasa Indonesia';

  @override
  String get sidebarLanguage => 'Bahasa';

  @override
  String get sidebarGuestUser => 'Pengguna Tamu';

  @override
  String get sidebarLocalSession => 'Sesi lokal';

  @override
  String get sidebarClose => 'Tutup sidebar';

  @override
  String get sidebarNavigate => 'NAVIGASI';

  @override
  String get sidebarHome => 'Beranda';

  @override
  String get sidebarLearn => 'Belajar';

  @override
  String get sidebarLearnSubtitle => 'Jenis sampah & kuis';

  @override
  String get sidebarConfigure => 'Konfigurasi';

  @override
  String get sidebarConfigureSubtitle => 'Atur WebSocket ESP32';

  @override
  String get sidebarControl => 'Kontrol';

  @override
  String get sidebarControlSubtitle => 'Kendarai robot & Kamera';

  @override
  String get sidebarGuestBadge => 'TAMU';

  @override
  String get sidebarDarkMode => 'Mode gelap';

  @override
  String get signOut => 'Keluar';

  @override
  String get signIn => 'Masuk';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonContinue => 'Lanjutkan';

  @override
  String get leaveQuizTitle => 'Keluar dari kuis?';

  @override
  String get leaveQuiz => 'Keluar Kuis';

  @override
  String photoFailed(Object error) {
    return 'Gagal memotret: $error';
  }

  @override
  String get homeScanActivity => 'Aktivitas scan';

  @override
  String get homeFirstScanToday => 'Scan pertamamu menyala hari ini';

  @override
  String get homeScanItem => 'Scan sebuah benda';

  @override
  String homeTrophies(Object count) {
    return '$count trofi';
  }

  @override
  String get homeDailyQuests => 'Misi harian';

  @override
  String get homeBinBuddies => 'Teman tempat sampah';

  @override
  String get homeThisWeek => 'Minggu ini';

  @override
  String get homeQuizAccuracy => 'Akurasi kuis';

  @override
  String get homeMedals => 'Medali';

  @override
  String get homeDidYouKnow => 'TAHUKAH KAMU?';

  @override
  String get historyBackToList => 'Kembali ke daftar';

  @override
  String get historyPhoto => 'FOTO';

  @override
  String get historyAddSampleData => 'Tambah Contoh Data (Debug)';

  @override
  String get pdfExported => 'Laporan PDF berhasil diekspor';

  @override
  String pdfExportFailed(Object error) {
    return 'Gagal mengekspor PDF: $error';
  }

  @override
  String get exportPdf => 'Ekspor PDF';

  @override
  String get moduleProgress => 'Progres modul';

  @override
  String get controlGripOpen => 'Buka';

  @override
  String get controlGripClosed => 'Tertutup';

  @override
  String get controlBase => 'Basis';

  @override
  String get controlHome => 'POSISI AWAL';

  @override
  String controlR1Status(Object status) {
    return 'R1: $status';
  }

  @override
  String get controlCheckingRobot => 'memeriksa robot...';

  @override
  String get controlPhoneScan => 'Scan dengan kamera HP';

  @override
  String get configConnectionFailed => 'Koneksi gagal';

  @override
  String get configPhoneOnlyHint =>
      'Robot tidak dipakai. Arahkan HP ke satu benda lalu ketuk Start scan.';

  @override
  String get configSameWifiHint =>
      'Sambungkan ELIO dan HP ini ke Wi-Fi atau hotspot yang sama, lalu ketuk Connect now.';

  @override
  String get configSaveDefault => 'Simpan sebagai konfigurasi bawaan';

  @override
  String get configUseAddressNextTime => 'Pakai alamat ini lain kali';

  @override
  String get configDragToRotate => 'Geser untuk memutar';

  @override
  String get configLookingForElio => 'Mencari ELIO…';

  @override
  String get guidePdfUnavailable => 'PDF panduan belum tersedia.';

  @override
  String get videoUnavailable => 'Video belum tersedia.';

  @override
  String simulationComingSoon(Object title) {
    return '$title segera hadir.';
  }

  @override
  String get quizStartTitle => 'Mulai Kuis?';

  @override
  String get quizNotNow => 'Nanti Saja';

  @override
  String get quizStart => 'Mulai';

  @override
  String get quizFinishFirst => 'Selesaikan kuis dulu';

  @override
  String get quizContinue => 'Lanjutkan Kuis';

  @override
  String get quizKnowledgeChallenge => 'Tantangan pengetahuan';

  @override
  String get quizFinishToExit => 'Selesaikan kuis untuk keluar';

  @override
  String get simWork => 'Usaha (W)';

  @override
  String get simBattery => 'Baterai';

  @override
  String get simLiveTimer => 'Timer Langsung:';

  @override
  String get simRun => 'JALANKAN';

  @override
  String get simBonusUam => 'Bonus: Bagaimana dengan GLBB?';

  @override
  String get simSortMode => 'Mode Sortir';

  @override
  String get simExploreMode => 'Mode Jelajah';

  @override
  String get simIdle => 'Idle';

  @override
  String get simCamera => 'Kamera (10W)';

  @override
  String get simDriveMotor => 'Motor Penggerak (36W)';

  @override
  String get simArmMotor => 'Motor Lengan (18W)';

  @override
  String get simBatteryLeft => 'Sisa Baterai';

  @override
  String get simMotorSpeed => 'Kecepatan Motor (RPM)';

  @override
  String get simLinearEstimate => 'Perkiraan (aproksimasi linear)';

  @override
  String get deepOrganicCard => 'Kartu Organik — Porositas & Aliran Oksigen';

  @override
  String get deepInorganicCard =>
      'Kartu Inorganik — Hooke, NIR, & Eddy Current';

  @override
  String get deepB3Card => 'Kartu B3 — Tekanan Uap, Insinerator, Radiasi';

  @override
  String get deepCoreConcept => 'Konsep Inti';

  @override
  String get deepKeyPhysics => 'Fisika Kunci';

  @override
  String get deepWhyDifferent => 'Mengapa perlakuan berbeda?';

  @override
  String get deepHardnessTest => '1. Uji Kekerasan (Pegas Hooke)';

  @override
  String deepReactionForce(Object force) {
    return 'Gaya Reaksi (F = k·x): $force N (k=50 N/m)';
  }

  @override
  String get deepNir => '2. Reflektansi Near-Infrared (NIR)';

  @override
  String deepSpectrumPeak(Object nm) {
    return 'Puncak Spektrum: ≈$nm nm';
  }

  @override
  String get deepEddy => '3. Arus Eddy (Logam Non-Feromagnetik)';

  @override
  String get deepVaporPressure => '1. Tekanan Uap (Vapor Pressure)';

  @override
  String deepRelativeVapor(Object value) {
    return 'Tekanan Uap Relatif: $value (Arbiter)';
  }

  @override
  String get deepIncinerator => '2. Insinerator (Penghancuran Ikatan Kimia)';

  @override
  String get deepRadiationShield => '3. Perisai Radiasi (Radiation Shielding)';

  @override
  String get activityLess => 'Sedikit';

  @override
  String get activityMore => 'Banyak';

  @override
  String get activityOpenInHistory => 'Buka di Riwayat';

  @override
  String get activityNoScans => 'Tidak ada scan di hari ini.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsSubtitle => 'Koneksi, video, suara dan kuis';

  @override
  String get aiNeedsInternet => 'Gemini · perlu internet';

  @override
  String get aiOffHint =>
      'Mengenali hasil scan dan menulis soal kuis baru, sekitar 2 sampai 4 detik per soal.';

  @override
  String get aiActiveHint => 'Mengenali hasil scan dan menulis soal kuis.';

  @override
  String aiActive(Object model) {
    return 'Aktif · $model';
  }

  @override
  String get aiCloud => 'cloud';

  @override
  String get aiUnavailable =>
      'Tidak ada internet, atau semua model AI sedang sibuk. Kuis memakai bank soal dan mencoba AI lagi pada scan berikutnya.';

  @override
  String get robotWifiQr => 'QR Wi-Fi Robot';

  @override
  String get robotQrHint =>
      'Robot tidak bisa membacanya? Kurangi kecerahan layar atau miringkan HP sedikit.';

  @override
  String searchSeeAll(Object count) {
    return 'Lihat semua $count hasil';
  }

  @override
  String get waitingForStream => 'Menunggu stream MaixCAM2...';

  @override
  String get questionBank => 'Bank soal';

  @override
  String get backToQuestion => 'Kembali ke Soal';

  @override
  String get scanAgain => 'Scan lagi';

  @override
  String get testerMode => 'Mode penguji';

  @override
  String get testerQuestionSource => 'Sumber soal';

  @override
  String get testerBank => 'Bank';

  @override
  String get testerShareLog => 'Bagikan log';

  @override
  String get testerLogCopied => 'Log disalin';

  @override
  String get testerCopyLog => 'Salin log';

  @override
  String get testerLog => 'Log penguji';

  @override
  String get testerViewLog => 'Lihat log';

  @override
  String get testerClearLog => 'Hapus log';

  @override
  String get lookingForMaixcam => 'Mencari MaixCAM2...';

  @override
  String get lostConnection => 'Koneksi ke ELIOS terputus';

  @override
  String get reconnectNow => 'Sambungkan ulang';

  @override
  String get wifiSettings => 'Pengaturan Wi-Fi';

  @override
  String missionProgress(Object done, Object target) {
    return '$done dari $target selesai';
  }

  @override
  String get resetScanDebug => 'Reset scan (debug)';

  @override
  String get navMain => 'Utama';

  @override
  String get navHome => 'Beranda';

  @override
  String get navLearn => 'Belajar';

  @override
  String get navControl => 'Kontrol';

  @override
  String get navControlHint => 'Kontrol, membuka kontrol robot';

  @override
  String get navConfig => 'Atur';

  @override
  String get navHistory => 'Riwayat';

  @override
  String get shellConnectElio => 'Hubungkan ELIO';

  @override
  String get shellConnected => 'ELIO terhubung';

  @override
  String get shellConnectedMsg => 'Koneksi robot siap.';

  @override
  String get shellDisconnected => 'ELIO terputus';

  @override
  String get shellDisconnectedMsg =>
      'Koneksi robot terputus. Periksa perangkat atau jaringan.';

  @override
  String get leaveQuizBody =>
      'Kamu sedang mengerjakan kuis. Jika keluar sekarang, progres kuis ini akan hilang.';

  @override
  String homeHello(Object name) {
    return 'Halo, $name';
  }

  @override
  String get homeReady => 'Siap belajar bersama ELIO?';

  @override
  String get configTopSubtitle => 'Atur robot, kamera dan kuis';

  @override
  String comingSoon(Object title) {
    return '$title — segera hadir';
  }

  @override
  String get homeGuest => 'Tamu';

  @override
  String get homeOpenNotifications => 'Buka notifikasi';

  @override
  String get homeVideo => 'Video';

  @override
  String get homeGuide => 'Panduan';

  @override
  String get medalExplorer => 'Penjelajah Lingkungan';

  @override
  String get medalExplorerDesc => 'Selesaikan minimal 3 materi belajar';

  @override
  String get medalExplorerHint => '3 materi belajar';

  @override
  String get medalRobotics => 'Pemula Robotika';

  @override
  String get medalRoboticsDesc => 'Mulai modul Pengenalan ELIO';

  @override
  String get medalRoboticsHint => 'Mulai Pengenalan ELIO';

  @override
  String get medalAdvocate => 'Pejuang Keberlanjutan';

  @override
  String get medalAdvocateDesc => 'Selesaikan semua refleksi empati lingkungan';

  @override
  String get medalAdvocateHint => 'Semua refleksi';

  @override
  String get homeTapSquare =>
      'Ketuk kotak mana pun di tampilan Tahun untuk membuka hari itu di sini.';

  @override
  String scanCount(num count) {
    return '$count scan';
  }

  @override
  String scansInMonth(Object scans, Object month) {
    return '$scans di bulan $month';
  }

  @override
  String get noScans17Weeks => 'Belum ada scan dalam 17 minggu terakhir';

  @override
  String scansIn17Weeks(Object scans) {
    return '$scans dalam 17 minggu terakhir';
  }

  @override
  String get homeYear => 'Tahun';

  @override
  String get homeMonth => 'Bulan';

  @override
  String dayCount(num count) {
    return '$count hari';
  }

  @override
  String homeStreakLine(Object days, Object longest) {
    return 'Beruntun $days · terlama $longest';
  }

  @override
  String get homeGuestProgress =>
      'Progres tamu disimpan di perangkat ini. Masuk untuk menyinkronkannya ke perangkat lain.';

  @override
  String levelSemantics(Object level, Object title, Object trophies) {
    return 'Level $level, $title. $trophies trofi';
  }

  @override
  String get levelSemanticsTop => ', level tertinggi';

  @override
  String levelSemanticsNext(Object count, Object next) {
    return ', $count lagi ke level $next';
  }

  @override
  String homeLevel(Object level) {
    return 'Level $level';
  }

  @override
  String get homePlantFirst => 'Tanam trofi pertamamu: scan sebuah benda.';

  @override
  String get homeTreeGrows => 'Pohonmu tumbuh dengan setiap trofi.';

  @override
  String get homeTopLevel => 'Level tertinggi';

  @override
  String homeToNextLevel(Object count, Object next) {
    return '$count lagi ke Lv$next';
  }

  @override
  String get homeScans => 'Scan';

  @override
  String get homeDayStreak => 'Hari beruntun';

  @override
  String questsDoneLine(Object done) {
    return '$done dari 3 selesai · direset tengah malam';
  }

  @override
  String questsDoneSemantics(Object done) {
    return '$done dari 3 misi selesai';
  }

  @override
  String questSemantics(Object title, Object state, Object reward) {
    return '$title, $state. Hadiah $reward trofi';
  }

  @override
  String get questDone => 'selesai';

  @override
  String percentValue(Object value) {
    return '$value persen';
  }

  @override
  String get binsHungry => 'Tempat sampahmu lapar: scan sebuah benda';

  @override
  String binsFed(Object scans) {
    return '$scans masuk ke 3 tempat sampahmu';
  }

  @override
  String get binTop => 'Teratas';

  @override
  String get residuNote => 'Scan residu dihitung sebagai Anorganik.';

  @override
  String residuIncluded(Object count, Object scans) {
    return 'Anorganik termasuk $count $scans residu (robot memilah residu ke sana).';
  }

  @override
  String scanWord(num count) {
    return 'scan';
  }

  @override
  String weekSemantics(Object count, Object days) {
    return '$count scan minggu ini. $days';
  }

  @override
  String get quizAccNoData => 'Akurasi kuis: belum ada data';

  @override
  String quizAccSemantics(Object acc, Object count) {
    return 'Akurasi kuis $acc persen dari $count scan terakhir yang punya soal';
  }

  @override
  String quizAccDelta(Object dir, Object count) {
    return ', $dir $count poin';
  }

  @override
  String get deltaUp => 'naik';

  @override
  String get deltaDown => 'turun';

  @override
  String get noData => 'belum ada data';

  @override
  String get medalUnlocked => 'Terbuka';

  @override
  String get homeLoading => 'Memuat progresmu';

  @override
  String get homeGrowing => 'Menumbuhkan pohonmu…';

  @override
  String get fact1 =>
      'Plastik dengan massa jenis di bawah 1,0 g/cm³ mengapung di air. Pabrik daur ulang memakai itu untuk memisahkannya.';

  @override
  String get fact2 =>
      'Baterai termasuk sampah B3: logamnya bisa meresap ke tanah dan air, jadi perlu tempat buang khusus.';

  @override
  String get fact3 =>
      'Kulit buah dan sisa makanan bisa menjadi kompos dalam beberapa minggu.';

  @override
  String get fact4 =>
      'Membilas botol sebelum didaur ulang menjaga isi tempat sampah lain tetap bersih.';

  @override
  String get fact5 =>
      'Kaleng aluminium bisa didaur ulang berkali-kali tanpa turun kualitasnya.';

  @override
  String get heatmapDayLabels => 'Sen,Rab,Jum';

  @override
  String get calendarWeekdays => 'Mg,Sn,Sl,Rb,Km,Jm,Sb';

  @override
  String get activityScansHint => 'Pakai Bulan untuk melihat per hari';

  @override
  String get previousMonth => 'Bulan sebelumnya';

  @override
  String get nextMonth => 'Bulan berikutnya';

  @override
  String get searchAll => 'Semua';

  @override
  String get searchLessons => 'Materi';

  @override
  String get searchLessonsHeader => 'MATERI';

  @override
  String get searchSims => 'Simulasi';

  @override
  String get searchSimsHeader => 'SIMULASI';

  @override
  String get searchQuiz => 'Kuis';

  @override
  String get searchQuizHeader => 'KUIS';

  @override
  String get searchScans => 'Scan';

  @override
  String get searchScansHeader => 'SCAN KAMU';

  @override
  String get searchHint => 'Cari materi, simulasi, scan';

  @override
  String resultCount(num count) {
    return '$count hasil';
  }

  @override
  String get clearSearch => 'Hapus pencarian';

  @override
  String get searchIn => 'Cari di';

  @override
  String noResultsFor(Object query) {
    return 'Tidak ada hasil untuk “$query”.';
  }

  @override
  String get notifNone => 'Belum ada notifikasi.';

  @override
  String get notifEmptyHint =>
      'Pengingat belajar, kabar ulasan kuis, dan info progres akan muncul di sini.';

  @override
  String get notifDismiss => 'Tutup notifikasi';

  @override
  String get notifTitle => 'Notifikasi';

  @override
  String get notifClose => 'Tutup notifikasi';

  @override
  String get notifSubtitle => 'Kabar belajar dan pengingat dari ELIO.';

  @override
  String get notifMarkAllRead => 'Tandai semua dibaca';

  @override
  String get notifClearAll => 'Hapus semua';

  @override
  String get notifDone => 'Selesai';

  @override
  String get notifOpenLearning => 'Buka Belajar';

  @override
  String get notifOpenConfig => 'Buka Atur';

  @override
  String get timeJustNow => 'Baru saja';

  @override
  String timeMinutesAgo(Object n) {
    return '$n mnt lalu';
  }

  @override
  String timeHoursAgo(Object n) {
    return '$n jam lalu';
  }

  @override
  String timeDaysAgo(Object n) {
    return '$n hr lalu';
  }

  @override
  String timeWeeksAgo(Object n) {
    return '$n mgg lalu';
  }

  @override
  String timeMonthsAgo(Object n) {
    return '$n bln lalu';
  }

  @override
  String timeYearsAgo(Object n) {
    return '$n thn lalu';
  }

  @override
  String get questScan3 => 'Scan 3 benda hari ini';

  @override
  String get questFinishQuiz => 'Selesaikan satu kuis scan';

  @override
  String get questSortB3 => 'Pilah satu benda B3 dengan aman';

  @override
  String get levelEcoStarter => 'Pemula Eco';

  @override
  String get levelWasteSpotter => 'Pengamat Sampah';

  @override
  String get levelBinExpert => 'Ahli Tempat Sampah';

  @override
  String get levelEcoSorter => 'Pemilah Eco';

  @override
  String get levelPlanetGuardian => 'Penjaga Planet';

  @override
  String get gradePerfect => 'Sempurna';

  @override
  String get gradeGreat => 'Hebat';

  @override
  String get gradeGood => 'Bagus';

  @override
  String get gradeKeepLearning => 'Belajar Lagi';

  @override
  String get gradeTryAgain => 'Coba Lagi';

  @override
  String get cfgIpHint => 'Masukkan IP seperti 192.168.4.1';

  @override
  String get cfgPortRange => 'Port 1 sampai 65535';

  @override
  String cfgFoundAt(Object ip) {
    return 'ELIO ditemukan di $ip';
  }

  @override
  String get cfgNotFound => 'ELIO tidak ditemukan di Wi-Fi ini';

  @override
  String get cfgRetry => 'Coba lagi';

  @override
  String get cfgCameraSource => 'Sumber kamera';

  @override
  String get cfgCameraSourceSub => 'Kamera yang mengambil foto scan';

  @override
  String get cfgMaixDesc => 'Kamera robot lewat Wi-Fi ELIOS';

  @override
  String get cfgPhoneCamera => 'Kamera HP';

  @override
  String get cfgPhoneCameraDesc => 'Scan dengan HP ini, tanpa robot';

  @override
  String get cfgQuizQuestions => 'Soal kuis';

  @override
  String get cfgQuizQuestionsSub => 'Asal soal kuis scan';

  @override
  String get cfgStartScan => 'Mulai scan';

  @override
  String get cfgConnectNow => 'Hubungkan sekarang';

  @override
  String get cfgDisconnect => 'Putuskan';

  @override
  String get cfgConnecting => 'Menghubungkan…';

  @override
  String get cfgCancelConnecting => 'Batalkan koneksi';

  @override
  String get cfgConnected => 'Terhubung';

  @override
  String get cfgTryAgain => 'Coba lagi';

  @override
  String get cfgConnection => 'Koneksi';

  @override
  String get cfgWsAddress => 'Alamat WebSocket ELIO';

  @override
  String get cfgPort => 'Port';

  @override
  String get cfgSearching => 'Mencari…';

  @override
  String get cfgFindElio => 'Cari ELIO';

  @override
  String get cfgRobotNotUsed => 'Robot tidak dipakai';

  @override
  String cfgConnectingTo(Object endpoint) {
    return 'Menghubungkan ke $endpoint';
  }

  @override
  String get cfgLastTryFailed => 'Percobaan terakhir gagal';

  @override
  String get cfgNotConnectedYet => 'Belum terhubung';

  @override
  String get cfgNotUsed => 'Tidak dipakai';

  @override
  String get cfgOnline => 'Online';

  @override
  String get cfgConnectingShort => 'Menghubungkan';

  @override
  String get cfgOffline => 'Offline';

  @override
  String get cfgStatus => 'Status';

  @override
  String get cfgBattery => 'Baterai';

  @override
  String get cfgNotReported => 'tidak dilaporkan';

  @override
  String get cfgCamera => 'Kamera';

  @override
  String get cfgPhone => 'HP';

  @override
  String get cfgRobotModel => 'Model 3D robot ELIO, geser untuk memutar';

  @override
  String get cfgQuestionBankDesc => 'Soal yang sudah dicek, langsung';

  @override
  String get cfgAiDesc => 'Soal baru tiap scan, perlu internet';

  @override
  String get cfgAiUnreachable => 'ELIOS AI tidak bisa dihubungi';

  @override
  String get setConnection => 'Koneksi';

  @override
  String get setAutoReconnect => 'Sambung ulang otomatis';

  @override
  String get setAutoReconnectSub => 'Sambung lagi saat ELIO tersedia';

  @override
  String get setVideo => 'Video';

  @override
  String get setResolution => 'Resolusi';

  @override
  String get setResolutionSub =>
      'Lebih tinggi lebih tajam tapi memakai lebih banyak Wi-Fi';

  @override
  String get setShowFps => 'Tampilkan FPS';

  @override
  String get setShowFpsSub => 'Tampilkan kecepatan stream saat menonton';

  @override
  String get setSound => 'Suara';

  @override
  String get setSoundEffects => 'Efek suara';

  @override
  String get setSoundEffectsSub => 'Suara antarmuka dan robot';

  @override
  String get setMasterVolume => 'Volume utama';

  @override
  String setMasterVolumeValue(Object percent) {
    return 'Volume utama $percent%';
  }

  @override
  String get setQuiz => 'Kuis';

  @override
  String get setDifficulty => 'Tingkat kesulitan';

  @override
  String get setEasy => 'Mudah';

  @override
  String get setMedium => 'Sedang';

  @override
  String get setHard => 'Sulit';

  @override
  String get setTimer => 'Waktu';

  @override
  String get setTimerSub => 'Waktu untuk tiap soal';

  @override
  String get setAllowSkip => 'Boleh lewati soal';

  @override
  String get setAllowSkipSub => 'Siswa boleh melewati soal';

  @override
  String get qrIntro =>
      'Nyalakan hotspot HP ini (2.4 GHz) lalu ketik nama dan kata sandinya. Di layar robot ketuk Wi-Fi setup, lalu arahkan QR ini ke kamera.';

  @override
  String get qrSsid => 'Nama hotspot (SSID)';

  @override
  String get qrPassword => 'Kata sandi hotspot';

  @override
  String get qrShowPassword => 'Tampilkan kata sandi';

  @override
  String get qrHidePassword => 'Sembunyikan kata sandi';

  @override
  String get qrShow => 'Tampilkan QR';

  @override
  String qrSemantics(Object ssid) {
    return 'Kode QR Wi-Fi untuk $ssid';
  }

  @override
  String get ctlWaiting => 'Menunggu';

  @override
  String get ctlOffline => 'Offline';

  @override
  String get ctlStopped => 'Berhenti';

  @override
  String get ctlForward => 'Maju';

  @override
  String get ctlBack => 'Mundur';

  @override
  String get ctlLeft => 'Kiri';

  @override
  String get ctlRight => 'Kanan';

  @override
  String get ctlReady => 'Siap';

  @override
  String get ctlHoming => 'Kembali ke awal';

  @override
  String get ctlExit => 'Keluar';

  @override
  String get ctlDebugScan => 'Debug Scan';

  @override
  String get ctlPushToDrive => 'Dorong untuk jalan · lepas untuk berhenti';

  @override
  String get ctlUnlocksOnConnect => 'Aktif saat robot terhubung';

  @override
  String get ctlSpeedPwm => 'KECEPATAN (PWM)';

  @override
  String get ctlSpeed => 'Kecepatan';

  @override
  String get ctlPickUp => 'AMBIL';

  @override
  String get ctlRelease => 'LEPAS';

  @override
  String get ctlGripperCaps => 'PENJEPIT';

  @override
  String get ctlGripper => 'Penjepit';

  @override
  String get ctlHeight => 'TINGGI';

  @override
  String get ctlUpDown => 'Naik / Turun';

  @override
  String get ctlReach => 'JANGKAU';

  @override
  String get ctlFwdBack => 'Maju / Mundur';

  @override
  String get ctlArmHint =>
      'Geser ke atas untuk mengangkat, ke depan untuk menjangkau. Lengan hanya bergerak saat robot tidak BERHENTI.';

  @override
  String get ctlArmLocked =>
      'Kontrol lengan aktif saat robot terhubung. STOP selalu berfungsi.';

  @override
  String get ctlAiBusy =>
      'ELIOS AI sedang sibuk. Coba LOCK lagi sebentar lagi.';

  @override
  String get ctlNoItem =>
      'Tidak ada benda. Arahkan kamera ke satu benda lalu coba lagi.';

  @override
  String get ctlBaseLeft => 'Basis ke kiri';

  @override
  String get ctlBaseRight => 'Basis ke kanan';

  @override
  String get ctlRobotControl => 'Kontrol Robot';

  @override
  String get ctlDrive => 'KEMUDI';

  @override
  String get ctlLiveScanPaused => 'LIVE · scan dijeda';

  @override
  String ctlLiveFps(Object fps) {
    return 'LIVE · $fps fps';
  }

  @override
  String get ctlNoVideo => 'Tidak ada video';

  @override
  String get ctlNoVideoCaps => 'TIDAK ADA VIDEO';

  @override
  String get ctlConnecting => 'Menghubungkan...';

  @override
  String get ctlScanQuiz => 'Kuis scan';

  @override
  String get ctlVoice => 'Suara';

  @override
  String get ctlWaitingFrames => 'Terhubung. Menunggu gambar kamera...';

  @override
  String get ctlArm => 'LENGAN';

  @override
  String get ctlUnlock => 'LEPAS KUNCI';

  @override
  String get ctlLock => 'KUNCI';

  @override
  String get ctlScan => 'SCAN';

  @override
  String get ctlDisconnectRobot => 'Putuskan robot';

  @override
  String get ctlConnectRobot => 'Hubungkan robot';

  @override
  String get ctlGuide => 'Panduan';

  @override
  String get ctlStoppedPaused => 'Robot berhenti · scan dijeda';

  @override
  String get ctlRobotOffline => 'Robot offline';

  @override
  String get ctlTurnOnRobot => 'Nyalakan robot dan sambungkan ke Wi-Fi ELIOS.';

  @override
  String get ctlConnect => 'Hubungkan';

  @override
  String get ctlEmergencyStop => 'Berhenti darurat';

  @override
  String get ctlPower => 'Daya';

  @override
  String get ctlMaixConnected => 'MaixCAM2 terhubung';

  @override
  String get ctlDisconnected => 'Terputus';

  @override
  String get ctlPickZone => 'ZONA AMBIL';

  @override
  String get ctlKeepTabletOnWifi =>
      'Nyalakan robot dan tetap sambungkan tablet ini ke Wi-Fi ELIOS.';

  @override
  String ctlRetryingIn(Object s, Object attempt, Object max) {
    return 'Mencoba lagi dalam $s dtk · percobaan $attempt dari $max';
  }

  @override
  String get ctlAutoReconnectOff => 'Sambung ulang otomatis mati';

  @override
  String ctlStoppedRetrying(Object max) {
    return 'Berhenti mencoba setelah $max kali';
  }

  @override
  String ctlTryingAgain(Object attempt, Object max) {
    return 'Mencoba lagi · percobaan $attempt dari $max';
  }

  @override
  String get ctlLinkDropped =>
      'Koneksi robot terputus, jadi robot berhenti demi keamanan.';

  @override
  String get ctlOpenQuiz => 'Buka kuis';

  @override
  String get ctlMission => 'MISI';

  @override
  String ctlSortItems(Object count) {
    return 'Pilah $count benda di perjalanan ini';
  }

  @override
  String get ctlThisDrive => 'PERJALANAN INI';

  @override
  String get ctlElioSays => 'KATA ELIO';

  @override
  String ctlMissionOf(Object done, Object target) {
    return 'Misi $done dari $target';
  }

  @override
  String get ctlSubtitle => 'Dekati, ambil, pilah dengan benar!';

  @override
  String get ctlLinkLost => 'koneksi terputus';

  @override
  String get ctlStopButton => 'tombol STOP';

  @override
  String get ctlRobotError => 'robot error';

  @override
  String ctlRobotStoppedWhy(Object why) {
    return 'Robot BERHENTI · $why';
  }

  @override
  String get ctlHoldForHome => 'Tahan 1 detik untuk HOME';

  @override
  String ctlRobotStoppedLong(Object why) {
    return 'ROBOT DIHENTIKAN ($why). Pemindaian berhenti; kuis yang terbuka tetap bisa dijawab.';
  }

  @override
  String get guideDriveTitle => 'Kemudikan robot';

  @override
  String get guideDriveBody =>
      'Dorong tombol hijau ke arah tujuanmu. Lepas, robot berhenti.';

  @override
  String get guideStopTitle => 'STOP merah besar';

  @override
  String get guideStopBody =>
      'Ketuk kapan saja jika ada yang tidak aman. Space atau Esc juga bisa.';

  @override
  String get guideGrabTitle => 'Ambil bendanya';

  @override
  String get guideGrabBody =>
      'Saat benda sudah dekat, tekan AMBIL. LEPAS menjatuhkannya. HOME memarkir lengan.';

  @override
  String get guideQuizTitle => 'Jawab kuisnya';

  @override
  String get guideQuizBody =>
      'Setelah tiap scan ELIOS AI memberi pertanyaan. Ketuk di sini untuk membukanya dan menangkan trofi!';

  @override
  String guideStepOf(Object step, Object total) {
    return 'LANGKAH $step DARI $total';
  }

  @override
  String get guideSkip => 'Lewati';

  @override
  String get guideNext => 'Lanjut';

  @override
  String get guideIntro =>
      'Kemudikan ke sebuah benda, ambil, pilah, lalu jawab ELIOS AI untuk mendapat trofi. Ketuk Panduan kapan saja untuk mengulang ini.';

  @override
  String get r2JoystickHint =>
      'Joystick: geser untuk menyetir, lepas untuk berhenti';

  @override
  String r2SpeedValue(Object value) {
    return 'Kecepatan $value';
  }

  @override
  String get r2RobotPrefix => 'Robot ';

  @override
  String get dsAiOffline => 'ELIOS AI offline · bank soal';

  @override
  String get dsAiReady => 'ELIOS AI siap';

  @override
  String get dsBack => 'Kembali';

  @override
  String get dsLive => 'LIVE';

  @override
  String get dsNoCamera => 'Tidak ada kamera';

  @override
  String get dsBankMode => 'Mode bank';

  @override
  String get dsPutItem =>
      'Letakkan satu benda di dalam kotak putih, lalu ketuk Scan.';

  @override
  String get dsScanMakeQuiz => 'Scan dan buat kuis';

  @override
  String get dsScanMakeQuizShort => 'Scan & buat kuis';

  @override
  String get dsTiming => 'Sekitar 2–4 dtk · perlu internet';

  @override
  String get dsSwitchCamera => 'Ganti kamera';

  @override
  String get dsTestModeHint => 'Mode uji: kuis tanpa kamera';

  @override
  String get dsTestMode => 'Mode uji';
}
