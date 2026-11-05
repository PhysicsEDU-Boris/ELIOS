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

  @override
  String get histSavedLocal => 'Tersimpan lokal';

  @override
  String get histTitle => 'Riwayat Scan';

  @override
  String get histSubtitleShort => 'Hasil kuis & trofi';

  @override
  String get histSubtitle =>
      'Semua benda yang kamu scan, dengan hasil kuis dan trofinya';

  @override
  String get histPickLeft =>
      'Pilih scan di sebelah kiri untuk melihat detail kuis.';

  @override
  String get histRecent => 'Scan terbaru';

  @override
  String get histSeedDebug => 'Isi Contoh Data (Debug)';

  @override
  String get histRecyclable => 'Daur ulang';

  @override
  String get histOrganic => 'Organik';

  @override
  String histScannedAt(Object time, Object count) {
    return 'Dipindai $time · Foto dan $count soal tersimpan lokal';
  }

  @override
  String histDiffPill(Object level, Object count) {
    return '$level · $count soal';
  }

  @override
  String get hist10Trophies => '10 trofi untuk tiap jawaban benar';

  @override
  String get histQuestions => 'Soal';

  @override
  String get histPending => 'Menunggu';

  @override
  String get histCorrect => 'Benar';

  @override
  String get histWrong => 'Salah';

  @override
  String get histYourAnswer => 'JAWABANMU';

  @override
  String get histRightAnswer => 'JAWABAN BENAR';

  @override
  String get histScore => 'SKOR';

  @override
  String get awaitingGrading => 'Menunggu penilaian';

  @override
  String histEssayScore(Object score, Object trophies) {
    return '$score / 10 · +$trophies Piala';
  }

  @override
  String get histHideExplanation => 'Tutup Penjelasan';

  @override
  String get histShowExplanation => 'Lihat Penjelasan';

  @override
  String get histNoExplanation => 'Penjelasan tidak tersimpan untuk soal ini.';

  @override
  String get histEmptyTitle => 'Belum Ada Riwayat Scan';

  @override
  String get histEmptyBody =>
      'Setiap sampah yang kamu scan dan kuis yang kamu selesaikan akan muncul di sini.';

  @override
  String get authUserNotFound =>
      'Akun dengan email atau username ini tidak ditemukan.';

  @override
  String get authWrongPassword => 'Kata sandi salah.';

  @override
  String get authEmailInUse => 'Email ini sudah terdaftar.';

  @override
  String get authWeakPassword => 'Kata sandi minimal 6 karakter.';

  @override
  String get authInvalidEmail => 'Masukkan alamat email yang valid.';

  @override
  String get authTooMany => 'Terlalu banyak percobaan. Coba lagi nanti.';

  @override
  String get authNoInternet => 'Tidak ada koneksi internet.';

  @override
  String get authGoogleConfig =>
      'Masuk dengan Google belum diatur dengan benar. Periksa pengaturan Firebase Android/iOS.';

  @override
  String get authOtherMethod =>
      'Email ini sudah terdaftar dengan cara masuk lain.';

  @override
  String get authGoogleLinked =>
      'Akun Google ini sudah tertaut ke pengguna lain.';

  @override
  String get authGoogleInvalid =>
      'Kredensial Google tidak valid. Periksa konfigurasi Firebase.';

  @override
  String get authGoogleDisabled =>
      'Masuk dengan Google belum diaktifkan di Firebase Authentication.';

  @override
  String get authGeneric => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get authWelcomeBack => 'Selamat datang kembali!';

  @override
  String get authSignInFailed => 'Gagal masuk.';

  @override
  String get authAccountCreated => 'Akun berhasil dibuat!';

  @override
  String get authCreateFailed => 'Gagal membuat akun.';

  @override
  String get authNoIdToken =>
      'Google Sign-In tidak mengembalikan idToken. Periksa konfigurasi platform Firebase.';

  @override
  String authGoogleFailedCode(Object code) {
    return 'Gagal masuk dengan Google: $code';
  }

  @override
  String get authGoogleFailed =>
      'Gagal masuk dengan Google. Periksa log debug.';

  @override
  String get authGuestEntered => 'Masuk sebagai tamu.';

  @override
  String get authGuestFailed => 'Gagal masuk sebagai tamu.';

  @override
  String get authEmailFirst => 'Masukkan email yang valid dulu.';

  @override
  String get authResetSent => 'Tautan reset dikirim ke emailmu.';

  @override
  String get authResetFailed => 'Gagal mengirim email reset.';

  @override
  String get authEmailRequired => 'Email wajib diisi';

  @override
  String get authEmailOrUserRequired => 'Email atau username wajib diisi';

  @override
  String get authValidEmail => 'Masukkan email yang valid';

  @override
  String get authPasswordRequired => 'Kata sandi wajib diisi';

  @override
  String get authMin6 => 'Minimal 6 karakter';

  @override
  String get authNameRequired => 'Nama wajib diisi';

  @override
  String get authMin2 => 'Minimal 2 karakter';

  @override
  String get authForgot => 'Lupa kata sandi?';

  @override
  String get authCreateAccount => 'Buat Akun';

  @override
  String get authWelcomeTitle => 'Selamat Datang Kembali';

  @override
  String get authJoin => 'Gabung ELIOS untuk mulai memilah';

  @override
  String get authSignInSub => 'Masuk untuk mengontrol ELIOS';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailOrUser => 'Email / Username';

  @override
  String get authEmailOrUserHint => 'kamu@contoh.com atau username';

  @override
  String get authSendReset => 'Kirim tautan reset';

  @override
  String get authSignIn => 'Masuk';

  @override
  String get authFullName => 'Nama Lengkap';

  @override
  String get authFullNameHint => 'Budi Santoso';

  @override
  String get authPassword => 'Kata sandi';

  @override
  String get authPasswordHint => 'Masukkan kata sandimu';

  @override
  String get authGoogle => 'Lanjut dengan Google';

  @override
  String get authGuest => 'Lanjut sebagai Tamu';

  @override
  String get authGuestNote =>
      'Mode tamu hanya menyimpan data di perangkat. Masuk untuk menyinkronkan progres.';

  @override
  String get authHaveAccount => 'Sudah punya akun? ';

  @override
  String get authNoAccount => 'Belum punya akun? ';

  @override
  String get authSignUp => 'Daftar';

  @override
  String get authPleaseWait => 'Mohon tunggu';

  @override
  String get authOr => 'Atau';

  @override
  String get quizSrcBank => 'SOAL DARI MODUL · BANK SOAL';

  @override
  String get quizSrcAi => 'SOAL ELIOS AI';

  @override
  String get quizSrcFallback => 'SOAL CADANGAN (ELIOS AI TIDAK TERSAMBUNG)';

  @override
  String get quizSrcGeneric => 'SOAL UMUM (BENDA BELUM ADA DI BANK SOAL)';

  @override
  String get quizPreparing => 'Kuis, menyiapkan soal';

  @override
  String get quizReady => 'Kuis, soal siap';

  @override
  String get quizWord => 'Kuis';

  @override
  String get scanFailed => 'Scan belum berhasil';

  @override
  String get wasteGeneric => 'Sampah';

  @override
  String trophiesEarned(Object count) {
    return '+$count Piala';
  }

  @override
  String trophiesTotal(Object count) {
    return '$count Total Piala';
  }

  @override
  String get robotDropping => 'Robot sedang membuang ke tempat sampah...';

  @override
  String get qzReadScan => 'Membaca scan';

  @override
  String get qzAiLooking => 'ELIOS AI sedang melihat';

  @override
  String get qzPickedTopic => 'Memilih topik';

  @override
  String get qzAfterScan => 'Setelah scan';

  @override
  String get qzAiTopic => 'Topik ELIOS AI';

  @override
  String qzBankPool(Object pool) {
    return 'Kumpulan bank · $pool';
  }

  @override
  String get qzWriting => 'Menulis soal';

  @override
  String get qzEssay => 'esai';

  @override
  String get qzMultipleChoice => 'pilihan ganda';

  @override
  String qzQuestionOfLevel(Object n, Object total, Object level) {
    return 'Soal $n dari $total · $level';
  }

  @override
  String qzQuestionOf(Object n, Object total) {
    return 'Soal $n dari $total';
  }

  @override
  String qzScanned(Object name) {
    return 'Hasil scan: $name';
  }

  @override
  String get qzReading => 'membaca…';

  @override
  String get qzAiReadingCaps => 'ELIOS AI · MEMBACA SCAN';

  @override
  String get qzAiWritingCaps => 'ELIOS AI · MENULIS SOALMU';

  @override
  String get qzReadingScan => 'Membaca scan…';

  @override
  String get qzPreparingNext => 'Menyiapkan soal berikutnya…';

  @override
  String get qzAiOnline =>
      'ELIOS AI menulisnya secara online. Biasanya 2–4 detik.';

  @override
  String get qzFromBank => 'Dari bank soal yang sudah dicek. Sebentar saja.';

  @override
  String get qzKeepDriving => 'Terus jalan. ';

  @override
  String get qzMinimiseHint =>
      'Kecilkan ini, tombol Kuis akan menyala saat soal siap.';

  @override
  String qzMcCaps(Object level) {
    return 'PILIHAN GANDA · $level';
  }

  @override
  String get qzSkipFinish => 'Lewati dan selesai';

  @override
  String get qzSkip => 'Lewati';

  @override
  String get qzUpTo10 => 'Sampai +10 trofi untuk jawaban lengkap';

  @override
  String get qz10Right => '+10 trofi untuk jawaban benar';

  @override
  String qzEssayCaps(Object level, Object words) {
    return 'ESAI · $level · MAKS $words KATA';
  }

  @override
  String get qzGrading => 'ELIOS AI sedang menilai jawabanmu…';

  @override
  String get qzTypeAnswer => 'Ketik jawabanmu di sini…';

  @override
  String get qzSubmit => 'Kirim';

  @override
  String get qzClear => 'Hapus';

  @override
  String qzHazardTitle(Object name) {
    return 'Mungkin berbahaya (B3): $name';
  }

  @override
  String get qzHazardBody =>
      'Jangan dibongkar atau dibuang ke tempat sampah biasa. Minta petugas menanganinya. Lanjutkan kuis tentang benda ini?';

  @override
  String get qzContinueQuiz => 'Lanjutkan kuis';

  @override
  String get qzWhichBin => 'Tempat sampah mana yang benar?';

  @override
  String qzMismatchBody(
    Object detector,
    Object detectorCategory,
    Object name,
    Object aiCategory,
  ) {
    return 'Detektor bilang $detector ($detectorCategory). ELIOS AI bilang $name ($aiCategory). Pilih yang benar.';
  }

  @override
  String qzUseAi(Object category) {
    return 'Pakai ELIOS AI ($category)';
  }

  @override
  String qzUseDetector(Object category) {
    return 'Pakai detektor ($category)';
  }

  @override
  String get qzScanChip => 'Scan';

  @override
  String get qzComplete => 'Kuis selesai';

  @override
  String get qzBack => 'Kembali';

  @override
  String get qzListenExplanation => 'Dengarkan penjelasan';

  @override
  String get qzFinish => 'Selesaikan kuis';

  @override
  String get qzNextQuestion => 'Soal berikutnya';

  @override
  String get qzEssayReview => 'Ulasan esai';

  @override
  String get qzReview => 'Ulasan';

  @override
  String get qzWaitingGrading => 'Menunggu penilaian';

  @override
  String get qzNotGradedYet =>
      'ELIOS AI belum menilai jawaban ini. Jawaban disimpan dan dinilai nanti.';

  @override
  String qzScoreOf10(Object score) {
    return 'Skor $score / 10';
  }

  @override
  String get qzCorrect => 'Benar!';

  @override
  String qzYouChose(Object picked) {
    return 'Kamu memilih “$picked”.';
  }

  @override
  String get qzNotQuite => 'Kurang tepat';

  @override
  String qzRightAnswerIs(Object answer) {
    return 'Jawaban yang benar adalah “$answer”.';
  }

  @override
  String get qzAnswerReview => 'Ulasan jawaban';

  @override
  String get qzDetailed => 'Penjelasan lengkap';

  @override
  String qzQuestionOfCaps(Object n, Object total, Object kind) {
    return 'SOAL $n DARI $total · $kind';
  }

  @override
  String get qzEssayUpper => 'ESAI';

  @override
  String get qzQuestionCaps => 'SOAL';

  @override
  String get qzCorrectAnswerCaps => 'JAWABAN BENAR';

  @override
  String get qzLoadingExplanation => 'Memuat penjelasan…';

  @override
  String get qzSavedNoTrophies =>
      'Jawabanmu disimpan. ELIOS AI menilainya saat siap; belum ada trofi sampai itu.';

  @override
  String get qzFeedback => 'Masukan';

  @override
  String get qzWhyWrong => 'Kenapa jawabanmu kurang tepat';

  @override
  String get qzWhyRight => 'Kenapa jawaban yang benar itu benar';

  @override
  String get qzElioModule => 'Modul ELIOS';

  @override
  String get qzScoringTable => 'Tabel 1. Rincian skor';

  @override
  String get qzCriteria => 'KRITERIA';

  @override
  String get qzFeedbackCaps => 'MASUKAN';

  @override
  String qzWhereGoes(Object name) {
    return 'Tabel 1. Ke mana $name dibuang';
  }

  @override
  String get qzThisItem => 'benda ini';

  @override
  String get qzBin => 'TEMPAT';

  @override
  String get qzExamples => 'CONTOH';

  @override
  String get qzAccepts => 'MENERIMA';

  @override
  String get qzOptionsTable => 'Tabel 1. Pilihan jawaban';

  @override
  String get qzOption => 'PILIHAN';

  @override
  String get qzStatus => 'STATUS';

  @override
  String get qzCorrectAnswer => 'Jawaban benar';

  @override
  String get qzYourAnswer => 'Jawabanmu';

  @override
  String get qzAiGraded => 'Dinilai AI · cek dengan gurumu';

  @override
  String get qzReviewedBank => 'Bank soal yang sudah dicek';

  @override
  String get qzAiGenerated => 'Dibuat AI · belum dicek';

  @override
  String get qzSugFullMark => 'Tunjukkan jawaban nilai penuh';

  @override
  String get qzSugKeyTerms => 'Jelaskan istilah penting';

  @override
  String get qzSugHint => 'Beri aku petunjuk';

  @override
  String get qzSugSimpler => 'Jelaskan lebih sederhana';

  @override
  String get qzCoach => 'Pelatih ELIOS AI';

  @override
  String get qzSent => 'Terkirim';

  @override
  String get qzPlaying => 'Diputar';

  @override
  String get qzAskScore => 'Tanya ELIOS AI tentang skormu…';

  @override
  String get qzAsk => 'Tanya ELIOS AI…';

  @override
  String get qzSend => 'Kirim';

  @override
  String get qzListen => 'Dengarkan';

  @override
  String get qzCopy => 'Salin';

  @override
  String get qzWhichItem => 'Benda apa ini?';

  @override
  String get qzNotThis => 'Bukan ini?';

  @override
  String get qzMinimise => 'Kecilkan';

  @override
  String get qzMinimiseQuiz => 'Kecilkan kuis';

  @override
  String get qzCloseQuiz => 'Tutup kuis';

  @override
  String get qzReadToMe => 'Bacakan untukku';

  @override
  String get qzExplanation => 'Penjelasan';

  @override
  String get ovEssayMax => 'Essay · maks 150 kata';

  @override
  String get ovPendingSub => 'Jawaban tersimpan. Nilai belum tersedia.';

  @override
  String ovEssayScore(Object score) {
    return 'Score: $score/10 · +$score Piala';
  }

  @override
  String get ovGood => 'Jawaban sudah baik!';

  @override
  String get ovNeedsWork => 'Perlu diperbaiki pada beberapa poin.';

  @override
  String get ovRight => 'Jawaban Benar! +10 Piala';

  @override
  String get ovWrong => 'Jawaban Kurang Tepat';

  @override
  String ovRightAnswer(Object answer) {
    return 'Jawaban benar: $answer';
  }

  @override
  String ovExplanationN(Object n) {
    return 'Penjelasan Soal $n';
  }

  @override
  String get ovNoExplanation => 'Penjelasan belum tersedia untuk soal ini.';

  @override
  String get ovCompareTable => 'Tabel Perbandingan Kategori Sampah';

  @override
  String ovReference(Object answer) {
    return 'Referensi jawaban: $answer';
  }

  @override
  String get ovCategory => 'Kategori';

  @override
  String get ovMaterial => 'Material';

  @override
  String get ovAccepted => 'Diterima';

  @override
  String get ovCriteria => 'Kriteria';

  @override
  String get ovMax => 'Maks';

  @override
  String get ovAwarded => 'Diperoleh';

  @override
  String get ovComment => 'Komentar';

  @override
  String get ovFinish => 'Selesai Quiz ✓';

  @override
  String get ovNext => 'Soal Berikutnya →';

  @override
  String get ovAssistant => 'Asisten Koreksi AI';

  @override
  String get ovAskAi => 'Tanya AI...';

  @override
  String get ovVoice => 'Suara';

  @override
  String get lqTitle => 'Kuis';

  @override
  String lqCompletedBest(Object score) {
    return ' Selesai dengan skor terbaik $score%.';
  }

  @override
  String lqBest(Object score) {
    return ' Skor terbaik $score%.';
  }

  @override
  String lqUsedAttempt(Object scoreText) {
    return 'Kamu sudah memakai satu-satunya kesempatan kuis ini.$scoreText';
  }

  @override
  String get lqOnceBody =>
      'Kuis ini hanya bisa dikerjakan sekali. Setelah mulai, kamu harus menyelesaikannya sebelum keluar.';

  @override
  String get lqFinishBody =>
      'Kuis ini hanya punya satu kesempatan. Selesaikan semua soal sebelum keluar.';

  @override
  String get lqLoading => 'Memuat soal kuis';

  @override
  String get lqLoadFailed => 'Soal kuis tidak bisa dimuat.';

  @override
  String get lqCheckFirestore => 'Periksa koneksi Firestore lalu coba lagi.';

  @override
  String get lqBackToQuizzes => 'Kembali ke Kuis';

  @override
  String get lqNotAvailable => 'Soal kuis belum tersedia.';

  @override
  String get lqIntro =>
      'Uji pemahamanmu tentang pengelolaan sampah dan cara ELIO mengelompokkan material. Tiap kuis punya satu kesempatan.';

  @override
  String get lqSetsFailed => 'Kumpulan kuis tidak bisa dimuat.';

  @override
  String get lqNoPublished => 'Belum ada kuis yang diterbitkan.';

  @override
  String get lqCompleted => 'Selesai';

  @override
  String get lqAttemptUsed => 'Kesempatan terpakai';

  @override
  String lqBestScore(Object score) {
    return 'skor terbaik $score%';
  }

  @override
  String get lqReviewNew => 'ulasan hanya untuk percobaan baru';

  @override
  String lqQuestions(Object count) {
    return '$count soal';
  }

  @override
  String get lqOneAttempt => 'satu kesempatan';

  @override
  String get lqReview => 'Ulas';

  @override
  String get lqDone => 'Selesai';

  @override
  String get lqUsed => 'Terpakai';

  @override
  String lqCounter(Object n, Object total) {
    return 'Soal $n / $total';
  }

  @override
  String lqCorrectExpl(Object explanation) {
    return 'Benar: $explanation';
  }

  @override
  String lqNotQuiteExpl(Object explanation) {
    return 'Kurang tepat: $explanation';
  }

  @override
  String get lqNotQuite => 'Kurang tepat.';

  @override
  String get lqViewResults => 'Lihat hasil';

  @override
  String get lqImageUnavailable => 'Gambar tidak tersedia';

  @override
  String lqScored(Object score, Object total) {
    return 'Skormu $score dari $total.';
  }

  @override
  String get lqBackLower => 'Kembali ke kuis';

  @override
  String get lqReviewAnswers => 'Ulas jawaban';

  @override
  String get rvTitle => 'Ulasan kuis';

  @override
  String get rvScore => 'Skor';

  @override
  String get rvPercent => 'Persen';

  @override
  String get rvPassed => 'Lulus';

  @override
  String rvQuestionN(Object n) {
    return 'Soal $n';
  }

  @override
  String get rvNotAnswered => 'Tidak dijawab';

  @override
  String get rvUnknown => 'Jawaban tidak diketahui';

  @override
  String get pqResultsTitle => 'Hasil Kuis Fisika';

  @override
  String get pqTitle => 'Kuis fisika';

  @override
  String pqCounter(Object n, Object total) {
    return 'Pertanyaan $n / $total';
  }

  @override
  String get pqAdvanced => 'Fisika lanjutan';

  @override
  String get pqWrong => 'Kurang Tepat.';

  @override
  String get pqSeeResults => 'Lihat Hasil';

  @override
  String get pqNext => 'Pertanyaan selanjutnya';

  @override
  String get pqDone => 'Kuis Fisika Selesai';

  @override
  String pqScore(Object score, Object total) {
    return 'Skor Anda: $score / $total';
  }

  @override
  String get pqBackMenu => 'Kembali ke Menu';

  @override
  String get tpNotUsed => 'Belum dipakai';

  @override
  String tpReady(Object model) {
    return 'Siap ($model)';
  }

  @override
  String get tpOffline => 'Tidak tersambung, mode bank';

  @override
  String get lnWelcome => 'Selamat datang di Belajar';

  @override
  String lnWelcomeBody(Object bin, Object count) {
    return 'Mulai dengan $bin: $count materi singkat, lalu coba kuisnya.';
  }

  @override
  String get lnStartModule1 => 'Mulai modul 1';

  @override
  String get lnTestElio => 'Uji cara ELIO memilah sampah.';

  @override
  String lnQuizzesTest(Object count) {
    return '$count kuis. Uji cara ELIO memilah sampah.';
  }

  @override
  String get lnTakeQuiz => 'Ikuti kuis';

  @override
  String get lnYourProgress => 'Progres belajarmu';

  @override
  String get lnNoModulesStarted => 'Belum ada modul yang dimulai';

  @override
  String lnModulesInProgress(Object started, Object total) {
    return '$started dari $total modul sedang berjalan';
  }

  @override
  String lnOverall(Object percent) {
    return '$percent% selesai secara keseluruhan';
  }

  @override
  String get lnCourseModules => 'Modul pelajaran';

  @override
  String get lnSeeAll => 'Lihat semua';

  @override
  String get lnContinueLearning => 'Lanjutkan belajar';

  @override
  String get lnAllLessons => 'Semua materi';

  @override
  String get lnNothingInProgress =>
      'Belum ada yang berjalan. Materi yang kamu buka akan menunggu di sini.';

  @override
  String get lnWatchLearn => 'Tonton dan belajar';

  @override
  String lnVideoCount(num count) {
    return '$count video';
  }

  @override
  String get lnVideos => 'Video';

  @override
  String get lnNoVideos => 'Belum ada video yang diterbitkan.';

  @override
  String get lnPhysicsSims => 'Simulasi fisika';

  @override
  String lnModuleCount(num count) {
    return '$count modul';
  }

  @override
  String lnSimTag(Object tag) {
    return 'Simulasi · $tag';
  }

  @override
  String get lnGuides => 'Panduan';

  @override
  String get lnNoGuides => 'Belum ada panduan yang diterbitkan.';

  @override
  String lnModuleN(Object n) {
    return 'Modul $n';
  }

  @override
  String get lnGuide => 'Panduan';

  @override
  String get lnDone => 'Selesai';

  @override
  String get lnNew => 'Baru';

  @override
  String get lnLoadFailed => 'Modul belajar tidak bisa dimuat.';

  @override
  String get lnLoadFailedBody =>
      'Periksa koneksi ke ELIO atau internet, lalu coba lagi. Materi yang sudah pernah dibuka tetap bisa dipakai offline.';

  @override
  String get lnOpenOffline => 'Buka materi offline';

  @override
  String get lnNoModules => 'Belum ada modul belajar.';

  @override
  String get lnNoModulesBody =>
      'Materi baru muncul di sini begitu diterbitkan.';

  @override
  String get lnNothingHere => 'Belum ada apa-apa di sini.';

  @override
  String get lnVideo => 'Video';

  @override
  String get lnSimulations => 'Simulasi';

  @override
  String get lnOfflineLessons => 'Materi offline';

  @override
  String get lnLoadingOffline => 'Memuat materi offline';

  @override
  String get lnOfflineNote =>
      'Panduan yang pernah dibuka bisa dipakai offline. Video perlu internet.';

  @override
  String get lnNoSaved => 'Belum ada materi yang tersimpan di perangkat ini.';

  @override
  String get lnPlayVideo => 'Putar video';

  @override
  String get lnOpenGuide => 'Buka panduan';

  @override
  String lnContinueVideo(Object pct) {
    return 'Lanjutkan video · $pct%';
  }

  @override
  String lnContinueGuide(Object pct) {
    return 'Lanjutkan panduan · $pct%';
  }

  @override
  String get lnWatchAgain => 'Tonton lagi';

  @override
  String get lnReadAgain => 'Baca lagi';

  @override
  String get lnLesson => 'Materi';

  @override
  String get lnDuration => 'Durasi';

  @override
  String get lnReading => 'Bacaan';

  @override
  String lnPositionOf(Object n, Object total) {
    return '$n dari $total';
  }

  @override
  String get lnWatched => 'Ditonton';

  @override
  String get lnRead => 'Dibaca';

  @override
  String get lnAbout => 'Tentang materi ini';

  @override
  String lnGuidesTab(Object count) {
    return '$count Panduan';
  }

  @override
  String lnVideosTab(Object count) {
    return '$count Video';
  }

  @override
  String lnQuizTab(Object count) {
    return '$count Kuis';
  }

  @override
  String get lnNoQuizModule => 'Belum ada kuis untuk modul ini.';

  @override
  String get lnNothingModule => 'Belum ada isi untuk modul ini.';

  @override
  String get lnThisLesson => 'materi ini';

  @override
  String get lnMyProgress => 'Progresku';

  @override
  String get lnNoProgress => 'Belum ada progres.';

  @override
  String get lnNoProgressBody =>
      'Buka materi, simulasi atau kuis dan progresmu akan muncul di sini.';

  @override
  String get lnInProgress => 'Sedang berjalan';

  @override
  String get lnCompleted => 'Selesai';

  @override
  String get lnSimProgress => 'Progres simulasi';

  @override
  String lnSimsDone(Object done, Object total) {
    return '$done dari $total modul selesai';
  }

  @override
  String lnPercentDone(Object percent) {
    return '$percent% selesai';
  }

  @override
  String get lnAllComplete => 'Semua modul sudah selesai.';

  @override
  String get lnNoneComplete => 'Belum ada modul yang selesai.';

  @override
  String lnMinutes(Object count) {
    return '$count mnt';
  }

  @override
  String lnLessonCount(num count) {
    return '$count materi';
  }

  @override
  String get lnQuizHistory => 'Riwayat kuis';

  @override
  String get lnQuizHistoryHint =>
      'Kuis yang kamu selesaikan tercantum di sini dengan skor terbaikmu.';

  @override
  String lnBinQuiz(Object bin) {
    return 'Kuis $bin';
  }

  @override
  String lnBest(Object score) {
    return 'Terbaik $score%';
  }

  @override
  String lnGuideCount(num count) {
    return '$count panduan';
  }

  @override
  String get lnNoVideosModule => 'Belum ada video di modul ini.';

  @override
  String get lnNoGuidesModule => 'Belum ada panduan di modul ini.';

  @override
  String get lnSimForModule => 'Simulasi untuk modul ini';

  @override
  String get lnOpen => 'Buka';

  @override
  String get lnNoQuizPublished =>
      'Belum ada kuis yang diterbitkan untuk modul ini.';

  @override
  String get lnLoadingGuide => 'Memuat panduan';

  @override
  String get lnCheckOpenAgain => 'Periksa koneksi lalu buka panduan lagi.';

  @override
  String get lnPrevPage => 'Halaman sebelumnya';

  @override
  String lnPageOf(Object n, Object total) {
    return 'Halaman $n dari $total';
  }

  @override
  String lnPage(Object n) {
    return 'Halaman $n';
  }

  @override
  String get lnNextPage => 'Halaman berikutnya';

  @override
  String lnVideoTag(Object tag) {
    return 'Video · $tag';
  }

  @override
  String lnGuidePart(Object n) {
    return 'Panduan · Bagian $n';
  }

  @override
  String get lnStart => 'Mulai';

  @override
  String get lnContinue => 'Lanjutkan';

  @override
  String lnModuleLabel(Object label) {
    return 'Modul $label';
  }

  @override
  String lnVideoLabel(Object title) {
    return 'Video $title';
  }

  @override
  String lnSimLabel(Object title) {
    return 'Simulasi $title';
  }

  @override
  String get lnLoadingModules => 'Memuat modul belajar';

  @override
  String get lnLoadingLesson => 'Memuat materi';

  @override
  String lnAnswerLabel(Object letter, Object label) {
    return 'Jawaban $letter: $label';
  }

  @override
  String get lnCorrectSuffix => ', benar';

  @override
  String get lnWrongSuffix => ', salah';

  @override
  String get lnTabTheory => 'Materi';

  @override
  String get lnTabFormula => 'Rumus';

  @override
  String get lnStatus => 'Status';

  @override
  String get lnBackToHub => 'Kembali ke pusat belajar';

  @override
  String get openProfileMenu => 'Buka menu profil';

  @override
  String get closeMenu => 'Tutup menu';

  @override
  String get navigationMenu => 'Menu navigasi';

  @override
  String get dismissNotification => 'Tutup notifikasi';

  @override
  String get wqCannotCrop =>
      'Benda belum bisa dipotong dari foto. Coba scan lagi.';

  @override
  String get wqNoCleanPhoto =>
      'Foto asli tanpa anotasi belum tersedia. Perbarui firmware kamera, lalu scan lagi.';

  @override
  String get wqNotRecognised => 'Benda di foto belum dikenali.';

  @override
  String get wqPickFirst =>
      'Pilih satu jawaban dulu. Setelah itu kamu bisa bertanya apa saja tentang soal ini.';

  @override
  String get wqWriteFirst =>
      'Tulis jawabanmu lalu kirim. Setelah dikoreksi, kamu bisa bertanya lebih lanjut.';

  @override
  String wqFallbackAi(Object reason) {
    return 'Ini soal cadangan karena AI belum bisa membuat soal. $reason';
  }

  @override
  String get wqFallbackGeneric =>
      'Ini soal umum karena benda ini belum ada di bank soal.';

  @override
  String get wqBankNotice =>
      'AI tidak tersambung, jadi soal ini dari bank soal. Periksa internet.';

  @override
  String get wqRight => 'Benar!';

  @override
  String wqWrong(Object answer) {
    return 'Kurang tepat. Jawaban yang benar: $answer.';
  }

  @override
  String get wqEssayAnswer => 'Jawaban Essay';

  @override
  String wqSavedNotGraded(Object reason) {
    return 'Jawaban tersimpan, tapi AI belum bisa mengoreksi. $reason';
  }

  @override
  String wqForFullMarks(Object tip) {
    return 'Untuk nilai penuh: $tip';
  }

  @override
  String wqScore(Object score) {
    return 'Skor: $score/10.';
  }

  @override
  String get wqAnswerFirstMc =>
      'Jawab soalnya dulu, ya. Setelah kamu memilih jawaban, aku akan menjelaskan dan menjawab pertanyaanmu tentang soal ini.';

  @override
  String get wqAnswerFirstEssay =>
      'Kirim jawaban essay-mu dulu, ya. Setelah itu aku koreksi dan kita bisa membahasnya.';

  @override
  String get wqScanFirst =>
      'Scan sampah dulu untuk memulai kuis, lalu kita bisa berdiskusi.';

  @override
  String wqAiCannotAnswer(Object reason) {
    return 'AI belum bisa menjawab. $reason';
  }

  @override
  String get wqCheckInternet => 'Periksa koneksi internet, lalu coba lagi.';

  @override
  String get wqTryAgain => 'Coba lagi.';

  @override
  String wqSkipped(Object n) {
    return 'Soal $n dilewati.';
  }

  @override
  String wqSkippedCount(Object count) {
    return ' $count soal dilewati.';
  }

  @override
  String wqSessionDone(Object correct, Object total, Object skipped) {
    return 'Sesi selesai! Jawaban benar: $correct dari $total.$skipped Scan sampah lain untuk soal baru.';
  }

  @override
  String get wqQuestionReady => 'Soal siap';

  @override
  String get r1LinkLost => 'Koneksi ke robot terputus. Robot berhenti.';

  @override
  String get r1NotConnected => 'robot tidak terhubung';

  @override
  String r1Stopped(Object reason) {
    return 'Robot dihentikan ($reason). Tekan \"Lanjutkan\" jika sudah aman.';
  }

  @override
  String get r1Stop => 'Berhenti';

  @override
  String get r1Picking => 'Robot mengambil benda';

  @override
  String get r1NotIdentified =>
      'Benda tidak bisa dikenali. Silakan jalan lagi.';

  @override
  String get r1NoConfirm =>
      'Tidak ada konfirmasi. Robot tidak mengambil benda.';

  @override
  String get r1Timeout => 'Waktu habis. Robot tidak mengambil benda.';

  @override
  String get r1TooLong => 'Robot terlalu lama. Robot berhenti.';

  @override
  String get r1Resuming => 'Robot melanjutkan';

  @override
  String get r1PickFailed => 'Benda tidak terambil. Robot berhenti.';

  @override
  String get r1Done => 'Selesai! Robot boleh jalan lagi.';

  @override
  String get r1ConfirmFirst => 'Konfirmasi dulu';

  @override
  String get r1WhichBin => 'Masuk tempat sampah mana?';

  @override
  String r1RobotChose(Object bin) {
    return 'Robot memilih: $bin';
  }

  @override
  String get r1PositionOk => 'Posisi sudah pas?';

  @override
  String get r1Forward => 'Maju sedikit';

  @override
  String get r1Back => 'Mundur';

  @override
  String get r1PressPick => 'Tekan Ambil';

  @override
  String get r1Hand => 'Ada tangan! Robot berhenti sebentar.';

  @override
  String r1NoReply(Object cmd, Object reason) {
    return 'Robot tidak menjawab ($cmd: $reason). Robot berhenti.';
  }

  @override
  String get h3Title => 'Riwayat';

  @override
  String get h3Subtitle => 'Hasil scan, kuis, dan piala';

  @override
  String get h3Back => 'Kembali';

  @override
  String get h3All => 'Semua';

  @override
  String get h3CatB3 => 'B3';

  @override
  String get h3CatB3Long => 'B3 · Berbahaya';

  @override
  String get h3CatRecyclable => 'Daur ulang';

  @override
  String get h3CatOrganic => 'Organik';

  @override
  String get h3CatResidu => 'Residu';

  @override
  String get h3Easy => 'Mudah';

  @override
  String get h3Medium => 'Sedang';

  @override
  String get h3Hard => 'Sulit';

  @override
  String get h3Today => 'Hari ini';

  @override
  String get h3Yesterday => 'Kemarin';

  @override
  String get h3LoadFailed => 'Riwayat belum dapat dimuat';

  @override
  String get h3RecentScans => 'Scan terbaru';

  @override
  String h3ScanCount(int count) {
    return '$count scan';
  }

  @override
  String get h3NoScansInCategory => 'Belum ada scan untuk kategori ini.';

  @override
  String h3Trophies(int count) {
    return '$count piala';
  }

  @override
  String h3ToNextLevel(Object count, Object level) {
    return '$count piala ke Level $level';
  }

  @override
  String get h3TopLevel => 'Level tertinggi';

  @override
  String get h3SavedLocally => 'Tersimpan lokal';

  @override
  String h3RowMeta(Object time, int count) {
    return '$time · $count soal';
  }

  @override
  String get h3DetailTitle => 'Detail scan';

  @override
  String get h3ExportPdf => 'Ekspor PDF';

  @override
  String get h3DetailLoadFailed => 'Detail scan belum dapat dimuat';

  @override
  String h3ScannedMeta(Object time, int count) {
    return 'Scan $time · foto dan $count soal tersimpan lokal';
  }

  @override
  String h3DiffChip(Object level, Object count) {
    return '$level · ${count}Q';
  }

  @override
  String h3CorrectOf(Object correct, Object total) {
    return '$correct dari $total benar';
  }

  @override
  String get h3TrophyRule => '10 piala untuk setiap jawaban benar';

  @override
  String get h3Questions => 'Soal';

  @override
  String get h3PdfFailed => 'PDF belum dapat diekspor. Coba lagi.';

  @override
  String get h3Correct => 'Benar';

  @override
  String get h3Incorrect => 'Salah';

  @override
  String get h3AwaitingGrading => 'Menunggu penilaian';

  @override
  String h3EssayScore(Object score) {
    return 'Skor $score/10';
  }

  @override
  String get h3YourAnswer => 'Jawabanmu';

  @override
  String get h3CorrectAnswer => 'Jawaban benar';

  @override
  String get h3ReferenceAnswer => 'Jawaban acuan';

  @override
  String get h3SeeExplanation => 'Lihat penjelasan';

  @override
  String get h3Listen => 'Dengarkan';

  @override
  String get h3Pause => 'Jeda';

  @override
  String get h3ReadingNow => 'SEDANG DIBACAKAN';

  @override
  String get h3KeyIdea => 'IDE UTAMA';

  @override
  String get h3TryAgain => 'Coba lagi';

  @override
  String get h3Loading => 'Sedang memuat';

  @override
  String get h3EmptyTitle => 'Belum ada scan';

  @override
  String get h3EmptyBody =>
      'Scan benda dengan ELIOS. Hasil kuis dan pialamu akan muncul di sini.';

  @override
  String get h3StartScan => 'Mulai scan';

  @override
  String get h3ExplanationTitle => 'Penjelasan';

  @override
  String h3ExplanationMeta(Object item, Object index, Object total) {
    return '$item · Soal $index dari $total';
  }

  @override
  String get h3WhyCorrect => 'Kenapa ini jawaban yang benar';

  @override
  String get h3WhyWrong => 'Kenapa jawabanmu kurang tepat';

  @override
  String get h3Feedback => 'Umpan balik';

  @override
  String get h3HowTo => 'Cara melakukannya';

  @override
  String get h3NextQuestion => 'Soal berikutnya';

  @override
  String get h3ExplanationUnavailable => 'Penjelasan lengkap belum tersedia';

  @override
  String h3PdfSaved(Object path) {
    return 'PDF tersimpan: $path';
  }

  @override
  String get h3ExportQuestion => 'Ekspor soal ini';

  @override
  String h3ExportOnly(Object index, Object item) {
    return 'Hanya soal $index dari $item masuk ke PDF.';
  }

  @override
  String get h3A4Pdf => 'A4 · PDF';

  @override
  String get h3Include => 'SERTAKAN';

  @override
  String get h3IncAnswers => 'Soal dan kedua jawaban';

  @override
  String get h3IncExplanation => 'Penjelasan dan langkah';

  @override
  String get h3IncPhoto => 'Foto scan';

  @override
  String get h3IncNotes => 'Ruang catatan';

  @override
  String get h3Share => 'Bagikan';

  @override
  String get h3SavePdf => 'Simpan PDF';

  @override
  String get h3Saving => 'Menyimpan…';

  @override
  String h3ShownInOriginal(Object language) {
    return 'Ditampilkan dalam $language, sambungkan internet untuk menerjemahkan';
  }

  @override
  String get h3KeyIdeaTitle => 'Ide utama';

  @override
  String pdfQuestionHeader(Object item, Object index) {
    return 'ELIOS | $item | Soal $index';
  }

  @override
  String get pdfEssayScore => 'Skor esai';

  @override
  String get pdfReportTitle => 'ELIOS - Laporan Kuis Sampah';

  @override
  String pdfPageShort(Object page, Object total) {
    return 'Hal. $page / $total';
  }

  @override
  String pdfFooter(Object page, Object total, Object id) {
    return 'ELIOS Edukasi Pemilahan Sampah | Halaman $page dari $total | ID sesi: $id';
  }

  @override
  String get pdfSessionInfo => 'Informasi Sesi';

  @override
  String get pdfPhoto => 'FOTO';

  @override
  String get pdfItem => 'Benda';

  @override
  String get pdfCategory => 'Kategori';

  @override
  String get pdfDateTime => 'Tanggal / Waktu';

  @override
  String get pdfDifficulty => 'Tingkat Kesulitan';

  @override
  String get pdfQuestionCount => 'Jumlah Soal';

  @override
  String get pdfCorrect => 'Benar';

  @override
  String pdfCorrectOf(Object correct, Object total) {
    return '$correct dari $total';
  }

  @override
  String get pdfTrophies => 'Piala Diperoleh';

  @override
  String pdfTrophyCount(Object count) {
    return '$count Piala';
  }

  @override
  String get pdfGrade => 'Nilai';

  @override
  String pdfQuestionLine(Object index, Object question) {
    return 'Soal $index: $question';
  }

  @override
  String pdfEssayLine(Object score, Object trophies) {
    return '$score / 10 (+$trophies Piala)';
  }

  @override
  String get pdfNoExplanation => 'Penjelasan tidak tersimpan untuk soal ini.';

  @override
  String pdfSource(Object title) {
    return 'Sumber: $title';
  }

  @override
  String get pdfBankTitle => 'Bank Soal ELIOS';

  @override
  String pdfSection(Object section) {
    return 'bagian $section';
  }

  @override
  String pdfPage(Object page) {
    return 'hal. $page';
  }

  @override
  String get pdfTableCategories => 'Tabel 1. Perbandingan Kategori Sampah';

  @override
  String get pdfTableScoring => 'Tabel 1. Rincian penilaian';

  @override
  String get pdfColCategory => 'Kategori';

  @override
  String get pdfColMaterial => 'Material';

  @override
  String get pdfColAccepted => 'Diterima';

  @override
  String get pdfColCriterion => 'Kriteria';

  @override
  String get pdfColMax => 'Maks';

  @override
  String get pdfColAwarded => 'Diperoleh';

  @override
  String get pdfColComment => 'Komentar';
}
