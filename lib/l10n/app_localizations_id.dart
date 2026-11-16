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
    return '$count XP';
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
      'Sambungkan ELIOS dan HP ini ke Wi-Fi atau hotspot yang sama, lalu ketuk Connect now.';

  @override
  String get configSaveDefault => 'Simpan sebagai konfigurasi bawaan';

  @override
  String get configUseAddressNextTime => 'Pakai alamat ini lain kali';

  @override
  String get configDragToRotate => 'Geser untuk memutar';

  @override
  String get configLookingForElio => 'Mencari ELIOS…';

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
  String get settingsSubtitle => 'Koneksi dan video';

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
  String get robotWifiQrSubtitle => 'Hubungkan ELIOS ke hotspot atau Wi-Fi';

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
  String get shellConnectElio => 'Hubungkan ELIOS';

  @override
  String get shellConnected => 'ELIOS terhubung';

  @override
  String get shellConnectedMsg => 'Koneksi robot siap.';

  @override
  String get shellDisconnected => 'ELIOS terputus';

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
  String get homeReady => 'Siap belajar bersama ELIOS?';

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
  String get medalRoboticsDesc => 'Mulai modul Pengenalan ELIOS';

  @override
  String get medalRoboticsHint => 'Mulai Pengenalan ELIOS';

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
    return 'Level $level, $title. $trophies XP';
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
  String get homePlantFirst => 'Raih XP pertamamu: scan sebuah benda.';

  @override
  String get homeTreeGrows => 'Pohonmu tumbuh setiap kamu dapat XP.';

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
    return '$title, $state. Hadiah $reward XP';
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
  String get residuNote =>
      'Scan residu dihitung sebagai Anorganik (robot memilah residu ke sana).';

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
  String get notifSubtitle => 'Kabar belajar dan pengingat dari ELIOS.';

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
    return 'ELIOS ditemukan di $ip';
  }

  @override
  String get cfgNotFound => 'ELIOS tidak ditemukan di Wi-Fi ini';

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
  String get cfgWsAddress => 'Alamat WebSocket ELIOS';

  @override
  String get cfgPort => 'Port';

  @override
  String get cfgSearching => 'Mencari…';

  @override
  String get cfgFindElio => 'Cari ELIOS';

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
  String get cfgRobotModel => 'Model 3D robot ELIOS, geser untuk memutar';

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
  String get setAutoReconnectSub => 'Sambung lagi saat ELIOS tersedia';

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
      'Nyalakan hotspot HP ini (2.4 GHz), atau pakai Wi-Fi rumah, lalu ketik nama dan kata sandinya. Di layar robot ketuk Wi-Fi setup, lalu arahkan QR ini ke kamera.';

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
  String get ctlElioSays => 'KATA ELIOS';

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
      'Setelah tiap scan ELIOS AI memberi pertanyaan. Ketuk di sini untuk membukanya dan dapatkan XP!';

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
      'Kemudikan ke sebuah benda, ambil, pilah, lalu jawab ELIOS AI untuk mendapat XP. Ketuk Panduan kapan saja untuk mengulang ini.';

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
  String get histSubtitleShort => 'Hasil kuis & XP';

  @override
  String get histSubtitle =>
      'Semua benda yang kamu scan, dengan hasil kuis dan XP-nya';

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
  String get hist10Trophies => '10 XP untuk tiap jawaban benar';

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
    return '$score / 10 · +$trophies XP';
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
    return '+$count XP';
  }

  @override
  String trophiesTotal(Object count) {
    return 'Total $count XP';
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
  String get qzUpTo10 => 'Sampai +10 XP untuk jawaban lengkap';

  @override
  String get qz10Right => '+10 XP untuk jawaban benar';

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
      'Jawabanmu disimpan. ELIOS AI menilainya saat siap; belum ada XP sampai itu.';

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
    return 'Skor: $score/10 · +$score XP';
  }

  @override
  String get ovGood => 'Jawaban sudah baik!';

  @override
  String get ovNeedsWork => 'Perlu diperbaiki pada beberapa poin.';

  @override
  String get ovRight => 'Jawaban Benar! +10 XP';

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
      'Uji pemahamanmu tentang pengelolaan sampah dan cara ELIOS mengelompokkan material. Tiap kuis punya satu kesempatan.';

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
  String get lnTestElio => 'Uji cara ELIOS memilah sampah.';

  @override
  String lnQuizzesTest(Object count) {
    return '$count kuis. Uji cara ELIOS memilah sampah.';
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
      'Periksa koneksi ke ELIOS atau internet, lalu coba lagi. Materi yang sudah pernah dibuka tetap bisa dipakai offline.';

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
  String get h3Subtitle => 'Hasil scan, kuis, dan XP';

  @override
  String get h3Back => 'Kembali';

  @override
  String get h3All => 'Semua scan';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count XP',
    );
    return '$_temp0';
  }

  @override
  String h3ToNextLevel(Object count, Object level) {
    return '$count XP lagi ke Level $level';
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
  String h3DiffChip(Object level, Object count) {
    return '$level · ${count}Q';
  }

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
  String get h3Translating => 'Menerjemahkan…';

  @override
  String get h3Loading => 'Sedang memuat';

  @override
  String get h3EmptyTitle => 'Belum ada scan';

  @override
  String get h3EmptyBody =>
      'Scan benda dengan ELIOS. Hasil kuis dan XP-mu akan muncul di sini.';

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
  String get pdfTrophies => 'XP Diperoleh';

  @override
  String pdfTrophyCount(Object count) {
    return '$count XP';
  }

  @override
  String get pdfGrade => 'Nilai';

  @override
  String pdfQuestionLine(Object index, Object question) {
    return 'Soal $index: $question';
  }

  @override
  String pdfEssayLine(Object score, Object trophies) {
    return '$score / 10 (+$trophies XP)';
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

  @override
  String a11yTrophies(Object count) {
    return '$count XP';
  }

  @override
  String homeScanSubtitle(Object date, Object count) {
    return '$date · +$count XP';
  }

  @override
  String a11yLabelValue(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String a11yBinStat(Object bin, Object count, Object percent) {
    return '$bin $count scan, $percent';
  }

  @override
  String get a11yTopBin => ', tempat sampah teratas';

  @override
  String get homeScansUnit => ' scan';

  @override
  String get homeOpenHistory => 'Buka Riwayat';

  @override
  String homeLatestScan(String item, String when) {
    return 'Terbaru: $item · $when';
  }

  @override
  String homeMedalsOf(Object unlocked, Object total) {
    return '$unlocked dari $total';
  }

  @override
  String a11yMedal(Object name, Object state, Object description) {
    return '$name, $state. $description';
  }

  @override
  String get a11yUnlocked => 'terbuka';

  @override
  String get a11yLocked => 'terkunci';

  @override
  String a11ySearchItem(Object title, Object subtitle) {
    return '$title, $subtitle';
  }

  @override
  String learnQuestionCount(int count) {
    return '$count soal';
  }

  @override
  String learnMinutes(Object count) {
    return '$count menit';
  }

  @override
  String learnLessonCount(int count) {
    return '$count pelajaran';
  }

  @override
  String a11yPercent(Object title, Object percent) {
    return '$title, $percent persen';
  }

  @override
  String get tipWaiting =>
      'Tunggu ya, aku sedang mencari robotnya! Kalau lama, periksa Wi-Fi ELIOS.';

  @override
  String get tipDisconnected =>
      'Aduh, aku tidak bisa mendengar robotnya. Dekati robot atau periksa apakah sudah menyala.';

  @override
  String get tipStopped =>
      'Robot BERHENTI. Pastikan jalannya aman, lalu ketuk Lanjutkan.';

  @override
  String get tipQuiz =>
      'Waktunya kuis! Jawab dulu, lalu kita pilah bendanya bersama.';

  @override
  String get tipDrive =>
      'Jalan pelan-pelan dan arahkan kameraku ke benda yang mau dipilah.';

  @override
  String tipPickZone(Object item) {
    return 'Hebat! $item ada di zona ambil. Tekan PICK UP untuk mengambilnya.';
  }

  @override
  String tipLocked(Object item) {
    return 'Dapat! Aku mengunci $item. Tahan sebentar, aku sedang melihat.';
  }

  @override
  String tipSeeItem(Object item) {
    return 'Aku melihat $item. Mendekat pelan-pelan, ya.';
  }

  @override
  String ctlPlusTrophies(Object count) {
    return '+$count XP';
  }

  @override
  String get guideReady => 'Kamu siap, Pilot Robot!';

  @override
  String get guideGo => 'Ayo mulai!';

  @override
  String get qzElapsed => 'berlalu';

  @override
  String qzWordCount(Object words, Object limit) {
    return '$words / $limit kata';
  }

  @override
  String wqCorrectOf(Object correct, Object total) {
    return '$correct dari $total benar';
  }

  @override
  String get cfgCouldNotReach => 'Tidak dapat menghubungi ELIOS';

  @override
  String get cfgIpAddress => 'Alamat IP';

  @override
  String camMacFailed(Object error) {
    return 'Kamera Mac tidak bisa dibuka ($error).';
  }

  @override
  String get catExamplesOrganic =>
      'Sisa makanan; Sisa masakan; Ampas kopi dan kantong teh; Potongan rumput dan daun; Cangkang telur';

  @override
  String get catExamplesInorganic =>
      'Botol dan wadah plastik; Toples dan botol kaca; Kaleng dan foil aluminium; Kertas dan kardus; Potongan logam';

  @override
  String get catExamplesHazardous =>
      'Baterai; Sampah elektronik; Lampu neon; Cat dan pelarut; Pestisida dan herbisida';

  @override
  String get authNoUser => 'Tidak ada akun dengan nama pengguna itu.';

  @override
  String get notifVideoDone => 'Video selesai';

  @override
  String get notifVideoDoneMsg => 'Kamu menyelesaikan satu video pelajaran.';

  @override
  String get notifGuideDone => 'Panduan selesai';

  @override
  String get notifGuideDoneMsg => 'Kamu menyelesaikan satu panduan.';

  @override
  String get notifQuizDone => 'Kuis selesai';

  @override
  String get notifQuizDoneMsg => 'Hasil kuismu sudah disimpan.';

  @override
  String get notifReview => 'Ulasan kuis tersedia';

  @override
  String get notifReviewMsg => 'Sekarang kamu bisa mengulas jawaban kuismu.';

  @override
  String get notifSync => 'Masalah sinkronisasi progres';

  @override
  String get notifSyncMsg =>
      'Progresmu belum dapat disinkronkan. Periksa koneksimu.';

  @override
  String get physDensityTag => 'Modul A · Lingkungan';

  @override
  String get physDensityTitle => 'Massa Jenis Sampah';

  @override
  String get physDensityDesc =>
      'ELIOS mengklasifikasi sampah anorganik berdasarkan densitas.';

  @override
  String get physHeatTag => 'Modul B · Lingkungan';

  @override
  String get physHeatTitle => 'Panas & Termodinamika Kompos';

  @override
  String get physHeatDesc =>
      'Dekomposisi mikroba menghasilkan panas seiring waktu.';

  @override
  String get physTorqueTag => 'Modul C · Mekanika';

  @override
  String get physTorqueTitle => 'Torsi Bahu Robot';

  @override
  String get physTorqueDesc =>
      'Sendi bahu ELIOS menahan torsi saat lengan menjulur.';

  @override
  String get physWorkEnergyTag => 'Modul D · Mekanika';

  @override
  String get physWorkEnergyTitle => 'Usaha & Energi Potensial';

  @override
  String get physWorkEnergyDesc =>
      'Mengangkat beban membutuhkan usaha yang terukur.';

  @override
  String get physKinematicsTag => 'Modul E · Kinematika';

  @override
  String get physKinematicsTitle => 'Kecepatan Gerak ELIOS';

  @override
  String get physKinematicsDesc =>
      'Gerak lurus beraturan menuju tumpukan sampah.';

  @override
  String get physPwmTag => 'Modul F · Elektronika';

  @override
  String get physPwmTitle => 'PWM & Tegangan Motor';

  @override
  String get physPwmDesc =>
      'Duty cycle mengatur tegangan rata-rata motor roda.';

  @override
  String get physPowerTag => 'Modul G · Daya';

  @override
  String get physPowerTitle => 'Daya & Baterai ELIOS';

  @override
  String get physPowerDesc => 'Manajemen konsumsi daya komponen robot.';

  @override
  String get physDeepDiveTag => 'Deep-Dive · Waste Physics';

  @override
  String get physDeepDiveTitle => 'Kartu Deep-Dive Sampah';

  @override
  String get physDeepDiveDesc =>
      'Eksplorasi mendalam: Organik, Inorganik, dan B3.';

  @override
  String get physQuizTag => 'Evaluasi';

  @override
  String get physQuizTitle => 'Uji Pemahaman (Kuis)';

  @override
  String get physQuizDesc =>
      'Uji pengetahuan Anda tentang fisika di balik robot ELIOS.';

  @override
  String get physLevelBeginner => 'Pemula';

  @override
  String get physLevelIntermediate => 'Menengah';

  @override
  String get physLevelAdvanced => 'Lanjutan';

  @override
  String get physLevelAllLevels => 'Semua Level';

  @override
  String get simDeepDive1 => 'Deep-Dive Sampah';

  @override
  String get simDeepDive2 => 'Fisika Pemilahan Sampah';

  @override
  String get simDeepDive3 =>
      'Eksplorasi alasan di balik perbedaan penanganan tiap kategori sampah.';

  @override
  String get simDeepDive4 => 'Porositas Tumpukan';

  @override
  String get simDeepDive5 =>
      'Porositas rendah (<25%). Udara sulit masuk, memicu dekomposisi anaerobik (metana).';

  @override
  String get simDeepDive6 =>
      'Porositas baik. Oksigen mengalir bebas, proses aerobik optimal.';

  @override
  String get simDeepDive7 =>
      'Porositas adalah persentase ruang kosong (berisi udara) di antara partikel padat dalam tumpukan kompos. Porositas tinggi = udara bisa mengalir bebas ke seluruh tumpukan = proses aerobik (butuh oksigen) berjalan sehat. Porositas rendah = tumpukan terlalu padat = oksigen cepat habis di bagian dalam = mikroba anaerobik mengambil alih.';

  @override
  String get simDeepDive8 =>
      'Sampah organik tidak punya sifat listrik (konduktivitas), optik (reflektansi NIR), atau kimia berbahaya (volatilitas/reaktivitas) yang bisa dijadikan sinyal pemilahan otomatis — satu-satunya variabel fisik yang relevan justru adalah struktur pori dan kelembapannya sendiri, karena tujuan pemrosesannya bukan memisahkan jenis material, tapi mengelola proses biologis penguraian itu sendiri.';

  @override
  String get simDeepDive9 =>
      'Prinsip ini dipakai ELIOS pada mekanisme penjepit/pendorong berpegas untuk menguji kekerasan/elastisitas benda.';

  @override
  String get simDeepDive10 => 'Pemampatan (x)';

  @override
  String get simDeepDive11 =>
      '⚠ Catatan Akurasi: Angka panjang gelombang puncak (mis. PET ≈1660nm, HDPE ≈1730nm, PP ≈1410nm) yang dipakai dalam simulasi ini harus diverifikasi ulang terhadap referensi sorting NIR industri yang valid sebelum dirilis ke pengguna. Sensor NIR sungguhan mengukur puncak/lembah absorbansi pada rentang tertentu yang bisa bervariasi.';

  @override
  String get simDeepDive12 =>
      'Ketika logam bergerak melalui medan magnet yang berubah, arus pusar (eddy current) terinduksi di dalam logam tersebut, menciptakan medan magnet lawan yang menolak logam non-magnetik seperti aluminium menjauh dari sumber magnet.';

  @override
  String get simDeepDive13 =>
      'Material inorganik (plastik, kaca, logam) tidak mengalami proses biologis apa pun yang perlu dikelola (beda dengan organik), dan sebagian besar tidak reaktif secara kimiawi/berbahaya (beda dengan B3) — sinyal pemilahan yang paling efektif justru sifat fisiknya yang stabil: kekerasan (Hooke), identitas optik (NIR), dan sifat magnetik/konduktif (arus eddy).';

  @override
  String get simDeepDive14 =>
      'Semakin tinggi suhu suatu cairan/zat, semakin besar kecenderungannya menguap menjadi gas — inilah tekanan uap. Persamaan Clausius-Clapeyron menjelaskan hubungan non-linear (eksponensial) ini.';

  @override
  String get simDeepDive15 =>
      '⚠ Catatan Akurasi: Simulasi ini memakai pendekatan kualitatif/simplifikasi, bukan kurva P–T literal dengan konstanta eksponensial yang presisi secara ilmiah. Tujuannya semata menunjukkan tren (semakin panas = semakin mudah menguap = semakin berbahaya).';

  @override
  String get simDeepDive16 => 'Suhu Zat';

  @override
  String get simDeepDive17 => 'Suhu Insinerator';

  @override
  String get simDeepDive18 => 'Status: Ikatan Kimia Berbahaya Terurai (Aman)';

  @override
  String get simDeepDive19 =>
      'Intensitas radiasi (I) berkurang secara eksponensial seiring bertambahnya ketebalan perisai (x).';

  @override
  String get simDeepDive20 =>
      '⚠ Catatan Akurasi: Koefisien atenuasi sungguhan sangat bergantung pada energi partikel radiasi (MeV) dan jenis material perisai spesifik. Angka di bawah adalah nilai ilustratif untuk menunjukkan urutan relatif (gamma paling sulit, alfa paling mudah).';

  @override
  String get simDeepDive21 => 'Alfa (α)';

  @override
  String get simDeepDive22 => 'Ketebalan Perisai (x)';

  @override
  String get simDeepDive23 =>
      'Perbedaan mendasarnya bukan pada jenis material fisiknya (B3 bisa berupa logam, cairan, atau padatan apa saja), tapi pada tingkat bahaya laten-nya — volatilitas kimia, radioaktivitas, atau reaktivitas termal yang bisa mencederai manusia atau lingkungan kalau ditangani seperti sampah biasa. Karena itu metode \"pemilahan\"-nya bukan soal memisahkan jenis material, melainkan soal penahanan dan penanganan aman (containment) — perisai, suhu kontrol, dan identifikasi dini sebelum bersentuhan langsung.';

  @override
  String get simDensity1 => 'Densitas & Klasifikasi';

  @override
  String get simDensity2 => 'MODUL A · MATERI';

  @override
  String get simDensity3 =>
      'Benda dengan massa jenis berbeda diklasifikasikan ke kategori yang sesuai.';

  @override
  String get simDensity4 => 'RUMUS DENSITAS';

  @override
  String get simDensity5 => 'm = massa · V = volume';

  @override
  String get simDensity6 => 'Ubah slider untuk melihat benda berubah';

  @override
  String get simDensity7 => 'Massa (m)';

  @override
  String get simDensity8 => 'HASIL KLASIFIKASI';

  @override
  String get simDensity9 => 'Material tidak dikenal';

  @override
  String get simDensity10 =>
      'Densitas di luar rentang database (bukan plastik, kaca, atau logam yang dikenal).';

  @override
  String get simDensity11 => 'Pilih Tong Sampah:';

  @override
  String get simDensity12 => 'Plastik';

  @override
  String get simDensity13 => 'Kaca';

  @override
  String get simDensity14 => 'Logam';

  @override
  String get simDensity15 => 'Modul A — Densitas & Klasifikasi Sampah';

  @override
  String get simDensity16 =>
      'Densitas (massa jenis) adalah ukuran seberapa \"padat\" materi tersusun di dalam suatu benda. Dua benda bisa punya ukuran (volume) yang sama tapi berat yang jauh berbeda — itu karena partikel penyusunnya dikemas dengan kerapatan berbeda. Besi terasa berat digenggam bukan karena besi \"lebih banyak,\" tapi karena atom-atomnya lebih rapat per satuan ruang dibanding, katakanlah, plastik.\n\nKonsep ini penting untuk ELIOS karena densitas adalah salah satu sinyal paling murah dan paling cepat untuk menebak jenis material — jauh lebih murah dibanding, misalnya, menganalisis spektrum inframerah tiap benda.';

  @override
  String get simDensity17 =>
      'ρ = m / V (Densitas = massa / volume). Air murni punya ρ = 1.0 g/cm³ sebagai titik referensi.';

  @override
  String get simDensity18 =>
      'Miskonsepsi sering menukar posisi m dan V menjadi V/m, mengubah hasil drastis. Densitas adalah massa per volume.';

  @override
  String get simDensity19 => 'Plastik (0.9 - 1.4 g/cm³)';

  @override
  String get simDensity20 => 'Kaca (2.4 - 2.6 g/cm³)';

  @override
  String get simDensity21 => 'Logam (≥ 2.7 g/cm³)';

  @override
  String get simDensity22 => 'Tidak diketahui';

  @override
  String get simHeat1 => 'Kalor & Termodinamika';

  @override
  String get simHeat2 => 'MODUL B · MATERI';

  @override
  String get simHeat3 => 'Kalor & Termodinamika Pengomposan';

  @override
  String get simHeat4 => 'RUMUS KALOR (Q)';

  @override
  String get simHeat5 => 'm = massa · c = 4000 J/kg°C · ΔT = perubahan suhu';

  @override
  String get simHeat6 => 'Partikel mewakili aktivitas mikroba';

  @override
  String get simHeat7 => 'Perubahan Suhu (ΔT)';

  @override
  String get simHeat8 => 'Porositas (Lintas Modul)';

  @override
  String get simHeat9 => 'HASIL FASE';

  @override
  String get simHeat10 =>
      'Fase Termofilik: Bakteri tahan panas bekerja optimal, patogen mulai mati.';

  @override
  String get simHeat11 => 'Modul B — Kalor & Termodinamika Pengomposan';

  @override
  String get simHeat12 =>
      'Saat mikroorganisme di tumpukan kompos memecah sampah organik, mereka melepaskan energi dalam bentuk kalor (heat) — ini disebut proses eksotermik biologis. Suhu tumpukan kompos naik bukan karena api atau listrik, tapi karena aktivitas metabolisme jutaan bakteri dan jamur yang bekerja memecah rantai molekul organik.\n\nModul ini memodelkan berapa banyak kalor yang perlu diserap atau dilepas suatu massa kompos untuk mengalami perubahan suhu tertentu, dan menghubungkannya ke fase biologis nyata dari proses pengomposan.';

  @override
  String get simHeat13 => 'Mesofilik (< 55°C)';

  @override
  String get simHeat14 => 'Termofilik (55 - 60°C)';

  @override
  String get simHeat15 => 'Terlalu Panas (> 60°C)';

  @override
  String get simKinematics1 => 'Kinematika';

  @override
  String get simKinematics2 => 'MODUL E · MATERI';

  @override
  String get simKinematics3 => 'Kinematika (GLB & GLBB)';

  @override
  String get simKinematics4 =>
      'Berapa lama ELIOS mencapai target? Hubungkan jarak, kecepatan, dan waktu.';

  @override
  String get simKinematics5 => 'RUMUS WAKTU (GLB)';

  @override
  String get simKinematics6 =>
      't = waktu · s = jarak tempuh · v = kecepatan konstan';

  @override
  String get simKinematics7 => 'Jarak Target (s)';

  @override
  String get simKinematics8 => 'Kecepatan (v)';

  @override
  String get simKinematics9 => 'HASIL PREDIKSI';

  @override
  String get simKinematics10 => 'Estimasi Waktu Sampai (ETA)';

  @override
  String get simKinematics11 =>
      'GLBB (Gerak Lurus Berubah Beraturan) melibatkan akselerasi (a). Di dunia nyata, ELIOS tidak langsung melesat ke kecepatan penuh — motor butuh waktu (meski kurang dari 1 detik) untuk berakselerasi dari diam hingga kecepatan konstan.\n\nRumus GLBB: s = v₀·t + ½·a·t²\n\nKarena akselerasi ELIOS sangat cepat, jarak berakselerasi sangat kecil dan sering diabaikan dalam navigasi ruangan biasa. Namun, jika ada halangan dadakan, modul rem darurat ELIOS akan menggunakan deselerasi (akselerasi negatif) yang dihitung dengan rumus GLBB yang sama.';

  @override
  String get simKinematics12 => 'Modul E — Kinematika';

  @override
  String get simKinematics13 =>
      'Saat ELIOS disuruh menuju titik kumpul sampah, sistem navigasinya (Local Planner) harus tahu seberapa jauh jaraknya dan berapa lama waktu yang dibutuhkan untuk tiba di sana dengan kecepatan tertentu. Ini adalah implementasi murni dari Kinematika Dasar — ilmu fisika yang mempelajari gerak benda tanpa peduli apa penyebab geraknya (gaya/massa).\n\nModul ini memodelkan pergerakan ELIOS sebagai Gerak Lurus Beraturan (GLB).';

  @override
  String get simKinematics14 =>
      'Bonus GLBB: Di dunia nyata motor ELIOS butuh waktu berakselerasi (s = v₀·t + ½·a·t²). Namun karena akselerasi ELIOS sangat singkat, GLB cukup akurat untuk menghitung ETA.';

  @override
  String get simKinematics15 =>
      'Miskonsepsi sering terjadi saat menghitung t: mengalikan s dan v (s·v) alih-alih membaginya (s/v). Satuan s·v adalah m²/s, yang tidak punya makna logis. Cek selalu satuan akhir (m / (m/s) = s).';

  @override
  String get simDensityPainter1 => 'Referensi';

  @override
  String get simDensityPainter2 => 'Objek';

  @override
  String get simTorquePainter1 => 'TORSI';

  @override
  String get simPowerBudget1 => 'Daya & Anggaran Baterai';

  @override
  String get simPowerBudget2 => 'MODUL G · MATERI';

  @override
  String get simPowerBudget3 => 'RUMUS DAYA & ENERGI';

  @override
  String get simPowerBudget4 => 'Preset Skenario:';

  @override
  String get simPowerBudget5 => 'Waktu Penggunaan (t)';

  @override
  String get simPowerBudget6 => 'PREDIKSI KETAHANAN BATERAI';

  @override
  String get simPowerBudget7 => 'Modul G — Daya & Anggaran Baterai';

  @override
  String get simPowerBudget8 =>
      'Setiap komponen ELIOS yang menyala — kamera, motor penggerak, motor lengan — menarik daya listrik dari baterai yang sama. Modul ini mengajarkan cara menghitung berapa lama baterai akan bertahan tergantung kombinasi komponen mana saja yang sedang aktif, sebuah keputusan yang benar-benar diambil oleh sistem kendali ELIOS secara real-time untuk menghemat daya.\n\nPerilaku hemat daya nyata ELIOS meniru logika ini secara langsung: motor penggerak dimatikan saat sedang menyortir (karena robot diam di tempat), dan kamera dimatikan saat sedang berpindah tempat jika tidak sedang menganalisis objek — setiap watt yang tidak perlu menyala berarti detik operasi tambahan sebelum baterai perlu diisi ulang.';

  @override
  String get simPowerBudget9 =>
      'P = V · I (Daya = Tegangan × Arus). Disini daya (P) sudah ditentukan per komponen.';

  @override
  String get simPowerBudget10 => 'E = P · t (Energi = Daya total × waktu).';

  @override
  String get simPowerBudget11 =>
      'Total Kapasitas = 50.000 Joule. t_estimasi = 50.000 / P_total.';

  @override
  String get simPowerBudget12 =>
      'Kamera 10W, Motor Penggerak 36W, Motor Lengan 18W.';

  @override
  String get simPwm1 => 'PWM & Motor';

  @override
  String get simPwm2 => 'MODUL F · MATERI';

  @override
  String get simPwm3 => 'PWM & Tegangan Efektif';

  @override
  String get simPwm4 => 'TEGANGAN RATA-RATA EFEKTIF';

  @override
  String get simPwm5 => 'Gelombang Kotak (Sinyal PWM)';

  @override
  String get simPwm6 => 'TEGANGAN MOTOR';

  @override
  String get simPwm7 => 'Modul F — PWM & Tegangan Efektif Motor';

  @override
  String get simPwm8 =>
      'V_avg = D · V_max (Tegangan efektif rata-rata = Duty Cycle × Tegangan Maksimum).';

  @override
  String get simPwm9 =>
      'D (Duty Cycle) adalah persentase waktu sinyal dalam kondisi \"menyala\" dalam satu periode.';

  @override
  String get simPwm10 =>
      'Batasan Model Linear (Penting): Perkiraan RPM pada simulasi ini adalah pendekatan linear. Pada motor nyata, hubungan duty cycle dan RPM aktual tidak sepenuhnya linear begitu motor dibebani torsi.';

  @override
  String get simPwm11 =>
      'Klaim \"penurunan tegangan rata-rata = penurunan arus rata-rata secara proporsional\" HANYA BENAR KALAU BEBAN MURNI RESISTIF. Pada motor (beban induktif + mekanis), penurunan arus tidak mengikuti penurunan tegangan secara linear sederhana.';

  @override
  String get simTorque1 => 'Torsi Bahu Robot';

  @override
  String get simTorque2 => 'MODUL C · MEKANIKA';

  @override
  String get simTorque3 => 'RUMUS TORSI';

  @override
  String get simTorque4 => 'r = panjang lengan · F = beban · θ = sudut';

  @override
  String get simTorque5 => 'Seret gagang lengan untuk mengubah r & θ';

  @override
  String get simTorque6 => 'Panjang lengan (r)';

  @override
  String get simTorque7 => 'Beban (F)';

  @override
  String get simTorque8 => 'Sudut (θ)';

  @override
  String get simTorque9 => 'TORSI INSTAN';

  @override
  String get simTorque10 => 'TANTANGAN';

  @override
  String get simTorque11 => 'Penjelasan Materi: Torsi (Momen Gaya)';

  @override
  String get simSimCanvasFrame1 => '⚠ RISIKO TERGULING';

  @override
  String get simSimulationPageScaffold1 => 'Materi';

  @override
  String get simWorkEnergy1 => 'Usaha & Energi';

  @override
  String get simWorkEnergy2 => 'MODUL D · MATERI';

  @override
  String get simWorkEnergy3 => 'Usaha & Energi Potensial';

  @override
  String get simWorkEnergy4 =>
      'Setiap gerakan mengangkat beban mengubah energi baterai menjadi energi potensial gravitasi.';

  @override
  String get simWorkEnergy5 => 'RUMUS USAHA (W)';

  @override
  String get simWorkEnergy6 => 'm = massa · g = 10 m/s² · h = ketinggian';

  @override
  String get simWorkEnergy7 => 'Ubah tinggi dan beban untuk melihat dampaknya';

  @override
  String get simWorkEnergy8 => 'Massa Beban (m)';

  @override
  String get simWorkEnergy9 => 'Ketinggian (h)';

  @override
  String get simWorkEnergy10 => 'HASIL PERHITUNGAN';

  @override
  String get simWorkEnergy11 => 'Modul D — Usaha & Energi Potensial Gravitasi';

  @override
  String get simWorkEnergy12 =>
      'Setiap kali ELIOS mengangkat sampah dari nampan ke tempat penampungan yang lebih tinggi, ia melakukan usaha (work) melawan gravitasi. Usaha ini tersimpan sebagai energi potensial gravitasi pada benda yang diangkat — energi yang \"siap dilepas\" kalau benda itu dijatuhkan kembali.\n\nIni bukan sekadar konsep abstrak: setiap Joule usaha yang dilakukan motor lengan ELIOS untuk mengangkat sesuatu berasal dari baterai, sehingga modul ini secara langsung menjelaskan kenapa mengangkat beban berat lebih sering ke ketinggian lebih tinggi = baterai ELIOS lebih cepat habis.';

  @override
  String get simDeepDive24 =>
      '• Hukum Fick (difusi) — laju perpindahan oksigen ke dalam tumpukan sebanding dengan luas jalur pori dan berbanding terbalik dengan jarak tempuh; tumpukan padat = jalur difusi lebih panjang dan sempit = laju oksigen masuk melambat drastis.\n';

  @override
  String get simDeepDive25 =>
      '• Konduksi kalor, Q/t = kAΔT/L — panas yang dihasilkan mikroba di inti tumpukan merambat keluar lewat konduksi; tumpukan padat menghambat pelepasan ini juga, memperparah risiko overheating (lihat Modul B).\n';

  @override
  String get simDeepDive26 =>
      '• Hukum Jurin (kapilaritas) — menjelaskan bagaimana kelembapan naik atau tertahan di antara partikel kecil, memengaruhi seberapa \"basah\" pori-pori tetap dari waktu ke waktu.';

  @override
  String get simDeepDive27 =>
      'Setiap jenis plastik menyerap dan memantulkan cahaya inframerah-dekat pada panjang gelombang karakteristik yang berbeda, membentuk semacam \"sidik jari optik.\"';

  @override
  String get simDeepDive28 =>
      'Insinerasi bahan berbahaya membutuhkan suhu jauh lebih tinggi dibanding pembakaran sampah biasa untuk memutus ikatan kimia molekul beracun (misalnya senyawa organik persisten). Ambang 1000°C di sini adalah ilustrasi titik dekomposisi termal.';

  @override
  String get simDeepDive29 => 'Status: Ikatan Masih Utuh (Berbahaya)';

  @override
  String get simDensity23 =>
      'Rentang: Plastik (0.9–1.4), Kaca (2.4–2.6), Logam (≥ 2.7).';

  @override
  String get simDensity24 =>
      'Plastik dengan ρ < 1.0 (HDPE, PP) mengapung di air. Plastik dengan ρ > 1.0 (PET, PVC) tenggelam. Ini teknik pemilahan flotasi sungguhan di industri!';

  @override
  String get simHeat16 =>
      'Kalor dari aktivitas mikroba mengubah suhu tumpukan kompos. Pantau fasenya.';

  @override
  String get simHeat17 =>
      'Peringatan: anaerob — risiko metana. Porositas rendah (<25%) dan suhu tinggi (>55°C).';

  @override
  String get simHeat18 =>
      'Overheated: Terlalu panas! Aktivitas mikroba terhambat.';

  @override
  String get simHeat19 =>
      'Q = m · c · ΔT (Kalor = massa × kalor jenis × perubahan suhu).';

  @override
  String get simHeat20 =>
      'Fase Mesofilik (< 55°C): Bakteri suhu-sedang mulai memecah gula & protein sederhana.';

  @override
  String get simHeat21 =>
      'Fase Termofilik (55–60°C): Bakteri tahan-panas mendominasi, fase membunuh patogen & biji gulma.';

  @override
  String get simHeat22 =>
      'Overheated (> 60°C): Aktivitas mikroba mulai terhambat/mati; perlu diaduk untuk melepas panas.';

  @override
  String get simHeat23 =>
      'Hubungan dengan Porositas: Ketika porositas < 25% DAN suhu > 55°C, tumpukan berisiko masuk kondisi anaerobik (oksigen habis). Mikroba anaerob mengambil alih dan menghasilkan gas metana (CH₄) yang berbahaya.';

  @override
  String get simKinematics16 =>
      'Visualisasi pergerakan GLB (Gerak Lurus Beraturan)';

  @override
  String get simKinematics17 =>
      'GLB: Kecepatan tetap (v), tidak ada akselerasi (a = 0).';

  @override
  String get simKinematics18 =>
      'v = s / t, sehingga t = s / v (waktu = jarak dibagi kecepatan).';

  @override
  String get simPowerBudget13 =>
      'Berapa lama baterai bertahan? Bergantung pada komponen yang dihidupkan.';

  @override
  String get simPowerBudget14 =>
      'Jika P_total = 0, waktu bertahan secara matematis tak hingga (∞).';

  @override
  String get simPwm12 =>
      'Atur kecepatan motor ELIOS tanpa membuang energi panas lewat resistor.';

  @override
  String get simPwm13 =>
      'Motor DC pada ELIOS (misalnya motor roda atau motor lengan) tidak selalu diberi tegangan penuh terus-menerus. Untuk mengatur kecepatan motor tanpa membuang energi sebagai panas, ELIOS memakai teknik PWM (Pulse Width Modulation) — menyalakan dan mematikan tegangan penuh secara sangat cepat (ratusan hingga ribuan kali per detik), dan mengatur berapa lama proporsi waktu tegangan itu menyala dalam satu siklus.\n\nCara lama mengatur kecepatan motor adalah memakai pembagi tegangan resistif (resistor/potensiometer) untuk menurunkan tegangan secara langsung. Masalahnya, kelebihan energi pada metode ini dibuang sebagai panas di resistor — energi terbuang percuma dan komponen jadi panas.\n\nPWM tidak pernah benar-benar \"menurunkan\" tegangan — ia hanya menyalakan-mematikan tegangan penuh dengan sangat cepat. Karena motor punya inersia mekanis dan induktansi kumparan yang meredam \"kedutan\" on/off ini menjadi gerakan halus, hasil akhirnya terasa seperti tegangan lebih rendah, tapi tanpa membuang energi sebagai panas resistif — hanya rugi-rugi sambungan (switching loss) yang jauh lebih kecil.';

  @override
  String get simPwm14 =>
      'Duty cycle 60% berarti menyala penuh 60% waktu dan mati 40% sisanya. Rata-ratanya 7.2V dari 12V maksimal.';

  @override
  String get simTorque12 =>
      'Saat ELIOS menjulurkan lengan, sendi bahu menahan torsi yang lebih besar.';

  @override
  String get simTorque13 => 'Torsi melebihi 8 N·m — Robot bisa terguling!';

  @override
  String get simTorque14 =>
      'θ = 90°: torsi maksimum — lengan tegak lurus dengan gaya.';

  @override
  String get simTorque15 =>
      'θ = 0° atau 180°: torsi nol — gaya sejajar lengan.';

  @override
  String get simTorque16 =>
      'r besar: torsi lebih besar, tapi robot lebih sulit stabil.';

  @override
  String get simWorkEnergy13 =>
      'W = E_p = m · g · h (Usaha = Energi Potensial = massa × gravitasi × ketinggian).';

  @override
  String get simWorkEnergy14 =>
      'g (gravitasi) dibulatkan menjadi 10 m/s² untuk kemudahan hitung.';

  @override
  String simPwmMotorGets(Object volts) {
    return 'Motor menerima setara $volts V';
  }

  @override
  String simDensityMaterial(Object name) {
    return 'Material: $name';
  }

  @override
  String simPowerLegend(Object watts) {
    return 'P_total = $watts W · t = waktu (detik)';
  }

  @override
  String simPowerEstimate(Object watts, Object runtime) {
    return 't_estimasi = 50000 J / $watts W = $runtime';
  }

  @override
  String simPowerLasts(Object runtime) {
    return 'Bertahan selama $runtime';
  }

  @override
  String simWorkBatteryLeft(Object percent) {
    return 'Baterai Tersisa: $percent%';
  }

  @override
  String simTorqueMotorStatus(Object status) {
    return 'Motor: $status · batas aman 8 N·m';
  }

  @override
  String get simTorqueSafe => 'AMAN';

  @override
  String get simTorqueWarning => 'PERHATIAN';

  @override
  String get simTorqueCritical => 'KRITIS';

  @override
  String simTorqueChallenge(Object r) {
    return 'Cari berat maksimum yang dapat diangkat ELIOS saat r = $r m dan θ = 90° dengan batas torsi 8 N·m.\nJawaban: F = τ/(r·sinθ) = 8 / $r = 16 N';
  }

  @override
  String get simTorqueBody =>
      'Torsi (τ) adalah ukuran efektivitas gaya dalam memutar benda terhadap suatu titik poros. Torsi bergantung pada lengan momen dan sudut antara lengan dengan arah gaya.';

  @override
  String simKinArrival(Object distance, Object speed, Object time) {
    return 'Waktu Tiba = $distance / $speed = $time detik';
  }

  @override
  String simHeatFinal(Object delta, Object result) {
    return 'Suhu Akhir = 25°C + $delta°C = $result°C';
  }

  @override
  String physQDensity(Object m, Object v) {
    return 'Sebuah sampel sampah inorganik memiliki massa $m g dan volume $v cm³. Berapa massa jenis (densitas) sampah tersebut?';
  }

  @override
  String physQHeat(Object m, Object dt, Object c) {
    return 'Tumpukan kompos bermassa $m kg mengalami kenaikan suhu sebesar $dt °C. Jika kalor jenis (c) kompos adalah $c J/kg°C, berapa total kalor (Q) yang dihasilkan mikroba?';
  }

  @override
  String physQTorque(Object r, Object f, Object theta) {
    return 'Lengan robot memanjang sejauh $r m dan mengangkat beban dengan gaya $f N pada sudut $theta° terhadap lengan. Berapa besar torsi pada sendi bahu?';
  }

  @override
  String physQWork(Object m, Object h) {
    return 'ELIOS mengangkat beban $m kg setinggi $h m. Berapa usaha yang dilakukan melawan gravitasi (g = 10 m/s²)?';
  }

  @override
  String physQSpeed(Object s, Object t) {
    return 'ELIOS bergerak lurus sejauh $s meter dalam waktu $t detik menuju target. Berapa kecepatan rata-ratanya?';
  }

  @override
  String physQPwm(Object d, Object vmax) {
    return 'Sinyal PWM mengatur tegangan motor dengan Duty Cycle (D) sebesar $d%. Jika tegangan maksimal baterai adalah $vmax V, berapa tegangan rata-rata motor?';
  }

  @override
  String physQPower(Object i, Object v) {
    return 'Sebuah subsistem menarik arus sebesar $i A dari baterai $v V. Berapa daya yang dikonsumsi?';
  }

  @override
  String simDensityLoad(Object kg) {
    return 'Beban tipikal organik ELIOS adalah $kg kg. Karena organik jauh lebih padat dari plastik, mengangkat volume organik yang sama membutuhkan usaha energi lebih besar (Lihat Modul D).';
  }

  @override
  String simWorkOrganic(Object kg) {
    return 'Sampah organik cenderung memiliki massa lebih besar per volume dibanding plastik. Untuk beban tipikal organik seberat $kg kg, mengangkatnya ke ketinggian yang sama dengan plastik ringan membutuhkan usaha jauh lebih besar.';
  }

  @override
  String simWorkBattery(Object joules) {
    return 'Kapasitas baterai ELIOS yang dipakai dalam simulasi ini adalah $joules Joule. %tersisa = 100 - (W / $joules) × 100.';
  }

  @override
  String get aiNotReady =>
      'AI belum bisa membaca foto. Periksa internet, lalu coba lagi.';

  @override
  String get aiNotRecognised =>
      'Benda di foto belum dikenali. Dekatkan kamera, pastikan terang, lalu scan lagi.';

  @override
  String get essaySavedPending =>
      'Jawaban tersimpan. Menunggu penilaian karena AI belum tersedia.';

  @override
  String essayScoreLine(Object score) {
    return 'Skor: $score/10.';
  }

  @override
  String get quizSkippedAnswer => '(dilewati)';

  @override
  String get quizTimeUpAnswer => '(waktu habis)';

  @override
  String wqTimeUp(int n) {
    return 'Waktu soal $n habis.';
  }

  @override
  String qzTimeLeft(int n) {
    return 'Sisa $n detik';
  }

  @override
  String get h3YourTrophies => 'XP kamu';

  @override
  String h3TrophyUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'XP',
    );
    return '$_temp0';
  }

  @override
  String get h3StatTrophies => 'XP';

  @override
  String get h3StatScanned => 'Dipindai';

  @override
  String h3QuestionOf(int index, int total) {
    return 'Soal $index dari $total';
  }

  @override
  String get h3HeroRight => 'Mantap!';

  @override
  String get h3HeroRightBody => 'Jawabanmu benar. Ini alasannya.';

  @override
  String get h3HeroWrong => 'Belum tepat!';

  @override
  String get h3HeroWrongBody => 'Coba lagi, yuk cari tahu alasannya.';

  @override
  String h3PlusTrophies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count XP',
    );
    return '$_temp0';
  }

  @override
  String get h3TheQuestion => 'Pertanyaan';

  @override
  String get h3LearnWhy => 'Yuk pelajari alasannya';

  @override
  String get h3Mission => 'Misimu';

  @override
  String h3MissionSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count langkah agar benar',
    );
    return '$_temp0';
  }

  @override
  String get h3MissionDone =>
      'Misi selesai: kamu tahu cara memilahnya dengan benar.';

  @override
  String get h3SeeResults => 'Lihat hasil';

  @override
  String h3CardSemantics(
    String item,
    String category,
    int correct,
    int total,
    int trophies,
  ) {
    return '$item, $category, $correct dari $total benar, +$trophies XP';
  }

  @override
  String get h3OpenPhoto => 'Lihat foto layar penuh';

  @override
  String get h3Close => 'Tutup';

  @override
  String get h3SharePhoto => 'Bagikan foto';

  @override
  String get h3PinchHint => 'Cubit untuk zoom · ketuk dua kali untuk reset';

  @override
  String h3ViewerMeta(String when, String category) {
    return 'Dipindai $when · $category';
  }

  @override
  String h3ScanPhoto(String item) {
    return 'Foto scan $item';
  }

  @override
  String get historySyncing => 'Menyinkronkan riwayat…';

  @override
  String get historySynced => 'Riwayat tersinkron';

  @override
  String get historyLocalOnly =>
      'Tersimpan di perangkat · menunggu sinkronisasi';

  @override
  String get historySyncRetry => 'Sinkronkan sekarang';

  @override
  String get historyImport => 'Impor riwayat lama perangkat';

  @override
  String get historyImportBody =>
      'Scan lama ini belum memiliki pemilik akun. Impor ke akun yang sedang dipakai? Riwayat asli perangkat tetap disimpan.';

  @override
  String get historyImportFailed =>
      'Riwayat lama gagal diimpor. File asli tetap disimpan.';

  @override
  String get dailyGuidesTitle => 'Panduan Harian';

  @override
  String get dailyGuidesDescription =>
      'Pelajari fisika di balik berita lingkungan.';

  @override
  String get dailyGuidesRefresh => 'Muat ulang panduan';

  @override
  String get dailyGuidesOffline =>
      'Menampilkan panduan tersimpan. Hubungkan internet untuk memeriksa edisi baru.';

  @override
  String get dailyGuidesEmpty => 'Panduan harian pertama akan segera hadir.';

  @override
  String get dailyGuidesLatest => 'Edisi terbaru';

  @override
  String get dailyGuidesArchive => 'Edisi sebelumnya';

  @override
  String get g4AiLooksFor => 'Yang dicari ELIOS AI';

  @override
  String get g4All => 'Semua';

  @override
  String get g4AllStopsDone => 'Ketiga perhentian selesai';

  @override
  String get g4AlmostBody =>
      'Belum ada XP. Kamu boleh mencoba sesering yang kamu mau.';

  @override
  String get g4AlmostTitle => 'Hampir! Coba sekali lagi';

  @override
  String get g4Archive => 'Arsip';

  @override
  String g4ArchiveLabel(Object title, Object date, Object stops, Object xp) {
    return '$title, $date, $stops dari 3 perhentian, $xp XP';
  }

  @override
  String get g4AskTeacher => 'Minta guru memeriksa';

  @override
  String get g4AskTeacherHint =>
      'Merasa hasilnya salah? Minta gurumu memeriksanya. Guru melihat alasan AI, bukan fotomu.';

  @override
  String get g4BackToResult => 'Kembali ke hasil';

  @override
  String get g4BadgeUnlocked => 'Lencana terbuka';

  @override
  String get g4Cancel => 'Batal';

  @override
  String get g4Check => 'Periksa';

  @override
  String get g4CheckAgain => 'Periksa lagi';

  @override
  String get g4ContinueGuide => 'Lanjutkan panduan';

  @override
  String g4ContinueStop(Object n) {
    return 'Lanjut · Perhentian $n';
  }

  @override
  String get g4CopyLink => 'Salin tautan';

  @override
  String get g4DayFuture => 'belum tiba';

  @override
  String get g4DayMissed => 'terlewat';

  @override
  String get g4DayRead => 'dibaca';

  @override
  String get g4DayToday => 'hari ini, belum dibaca';

  @override
  String get g4DidYouKnow => 'Tahukah kamu?';

  @override
  String get g4EmptyBody =>
      'Cerita fisika baru datang setiap pagi sekitar pukul 06.00. Tarik ke bawah untuk memeriksa lagi.';

  @override
  String get g4EmptyTitle => 'Panduan pertama sedang dalam perjalanan';

  @override
  String get g4FeedError => 'Panduan gagal dimuat';

  @override
  String get g4FeedSubtitle => 'Fisika di balik berita nyata';

  @override
  String get g4FinishStop2 => 'Selesaikan Perhentian 2 untuk membuka';

  @override
  String get g4FollowApp => 'Sama dengan aplikasi';

  @override
  String g4FrameN(Object n) {
    return 'Bingkai $n';
  }

  @override
  String get g4GuideArchive => 'Arsip panduan';

  @override
  String get g4GuideLanguage => 'Bahasa panduan';

  @override
  String get g4GuideXp => 'XP panduan';

  @override
  String get g4Import => 'Impor';

  @override
  String g4ImportBody(Object xp) {
    return 'HP ini punya $xp XP panduan dari sesi tamu.';
  }

  @override
  String g4ImportConfirm(Object xp) {
    return 'Tambahkan progres panduan tamu ($xp XP, perhentian, dan hari beruntun) ke akun ini? Tidak ada yang digabung tanpa persetujuanmu.';
  }

  @override
  String get g4ImportFailed => 'Belum bisa mengimpor. Coba lagi saat online.';

  @override
  String get g4ImportTitle => 'Impor progres panduan tamu';

  @override
  String g4IssueCount(int count) {
    return '$count edisi';
  }

  @override
  String g4IssueN(Object n) {
    return 'Edisi #$n';
  }

  @override
  String get g4LabApproved => 'Lab disetujui';

  @override
  String get g4LabApprovedBy => 'Lab disetujui ELIOS AI';

  @override
  String get g4LabBusy =>
      'Pemeriksaan lab sedang sibuk. Fotomu tetap di HP; coba lagi sebentar lagi.';

  @override
  String get g4LabChecking => 'ELIOS AI sedang memeriksa fotomu…';

  @override
  String get g4LabLimit =>
      'Sudah 5 kali pemeriksaan lab untuk panduan ini hari ini. Coba lagi besok.';

  @override
  String g4LabMeta(Object xp) {
    return 'Sekitar 10 menit · +$xp XP · lencana';
  }

  @override
  String get g4LabOffline =>
      'Pemeriksaan lab perlu internet. Sambungkan lalu coba lagi; belum ada yang terkirim.';

  @override
  String get g4LabResult => 'Hasil lab mini';

  @override
  String get g4LangEn => 'Bahasa Inggris';

  @override
  String get g4LangId => 'Bahasa Indonesia';

  @override
  String get g4LangMissing =>
      'Edisi ini belum ada dalam bahasamu, jadi ditampilkan dalam bahasa lain.';

  @override
  String get g4LangPill => 'EN · ID';

  @override
  String get g4Listen => 'Dengarkan';

  @override
  String get g4MiniLab => 'Lab mini';

  @override
  String get g4Missing => 'belum terlihat';

  @override
  String get g4New => 'BARU';

  @override
  String get g4NewGuide => 'Panduan baru';

  @override
  String get g4NextCard => 'Kartu berikutnya';

  @override
  String get g4NotNow => 'Nanti saja';

  @override
  String get g4NotQuite => 'Belum tepat.';

  @override
  String get g4OfflineBanner =>
      'Offline. Menampilkan panduan tersimpan. Sambungkan untuk memeriksa edisi baru.';

  @override
  String get g4Ok => 'OK';

  @override
  String get g4Pass => 'terlihat';

  @override
  String get g4Pdf => 'PDF';

  @override
  String g4PdfMeta(Object pages, Object language) {
    return 'PDF $pages halaman · $language · tersimpan untuk offline';
  }

  @override
  String get g4PhotoCredit => 'Kredit foto';

  @override
  String get g4PhotoHint =>
      'Ambil 3 foto: awal, tengah, dan akhir percobaanmu.';

  @override
  String g4PhotosTaken(Object n) {
    return '$n dari 3 foto';
  }

  @override
  String g4PlusXp(Object xp) {
    return '+$xp XP';
  }

  @override
  String get g4PrivacyNote =>
      'ELIOS memeriksa 8 foto diam dari klipmu, lalu menghapusnya. Hanya hasilnya yang disimpan.';

  @override
  String get g4QuestMap => 'Peta misimu';

  @override
  String get g4QuickQuiz => 'Kuis cepat';

  @override
  String get g4QuizAlmost =>
      '2 jawaban benar sudah lulus. Coba lagi kuisnya dengan soal baru.';

  @override
  String get g4QuizNice => 'Kerja bagus!';

  @override
  String get g4QuizParkedHint =>
      'Kartu yang sudah dijawab ada di kiri. Ketuk Q1–Q3 di hasil untuk melihat lagi.';

  @override
  String get g4QuizPassed => 'Kuis lulus';

  @override
  String get g4QuizResultHint => 'Ketuk Q1–Q3 untuk melihat lagi jawabanmu.';

  @override
  String get g4QuizUnavailable => 'Kuis gagal dimuat';

  @override
  String get g4ReadAgain => 'Baca panduan lagi';

  @override
  String get g4ReadFullGuide => 'Baca panduan lengkap';

  @override
  String g4ReadPage(Object page) {
    return 'Baca halaman $page';
  }

  @override
  String get g4Record => 'Rekam 15–30 dtk';

  @override
  String g4RecordHint(Object min) {
    return 'Rekam hanya tangan dan percobaanmu. Berhenti setelah $min dtk; rekaman berakhir di 30 dtk.';
  }

  @override
  String g4RecordingSeconds(Object s, Object max) {
    return 'Merekam $s / $max dtk';
  }

  @override
  String get g4Retake => 'Rekam ulang';

  @override
  String get g4Retry => 'Coba lagi';

  @override
  String get g4ReviewBody =>
      'Hanya gambar ini yang akan dikirim. Tidak ada yang keluar dari HP sampai kamu mengetuk Kirim.';

  @override
  String g4ReviewQuestion(Object n) {
    return 'Lihat lagi soal $n';
  }

  @override
  String get g4ReviewSent => 'Terkirim ke gurumu.';

  @override
  String g4ReviewTitle(Object n) {
    return '$n foto siap';
  }

  @override
  String get g4SafetyTitle => 'Rekam hanya tangan dan percobaanmu';

  @override
  String get g4SavedAccount => 'Tersimpan di akunmu';

  @override
  String get g4SavedPhone =>
      'Tersimpan di HP ini. Akan tersinkron saat online.';

  @override
  String get g4Saving => 'Menyimpan…';

  @override
  String g4ScoreOf(Object score, Object total) {
    return '$score dari $total benar';
  }

  @override
  String get g4SeeResult => 'Lihat hasil';

  @override
  String get g4Send => 'Kirim ke ELIOS AI';

  @override
  String get g4Sources => 'Sumber';

  @override
  String g4SourcesCount(int count) {
    return '$count sumber';
  }

  @override
  String get g4StartGuide => 'Mulai panduan';

  @override
  String get g4StartLab => 'Mulai lab mini';

  @override
  String get g4StopDone => 'selesai';

  @override
  String get g4StopLocked => 'terkunci';

  @override
  String get g4StopMission => 'Misimu';

  @override
  String get g4StopMissionSub => 'Perhentian 3 · Misimu';

  @override
  String g4StopN(Object n) {
    return 'Perhentian $n';
  }

  @override
  String get g4StopOpen => 'terbuka';

  @override
  String g4StopPage(Object n, Object page) {
    return 'PERHENTIAN $n · HLM.$page';
  }

  @override
  String get g4StopPhysics => 'Fisikanya';

  @override
  String get g4StopRecording => 'Berhenti merekam';

  @override
  String get g4StopStory => 'Ceritanya';

  @override
  String g4StopsDoneNext(Object done, Object next) {
    return '$done dari 3 perhentian selesai · Berikutnya: $next';
  }

  @override
  String g4StopsOf(Object done) {
    return '$done/3 perhentian';
  }

  @override
  String get g4StreakHint =>
      'Baca panduan hari ini untuk dapat XP dan semanggi';

  @override
  String get g4WeekReading => 'Bacaanmu minggu ini';

  @override
  String get g4TakePhoto => 'Ambil foto';

  @override
  String get g4TeacherBody =>
      'ELIOS AI belum yakin, jadi gurumu akan melihat hasilnya. Tidak ada foto yang disimpan.';

  @override
  String get g4TeacherNote =>
      'Gurumu bisa melihat dan mengubah hasil ini. Foto sudah dihapus setelah pemeriksaan.';

  @override
  String get g4TeacherTitle => 'Gurumu akan memeriksanya';

  @override
  String get g4ThreePhotos => 'Ambil 3 foto saja';

  @override
  String g4TodayDate(Object date) {
    return 'HARI INI · $date';
  }

  @override
  String g4TodayLabel(Object title, Object done) {
    return 'Panduan hari ini: $title, $done dari 3 perhentian selesai';
  }

  @override
  String get g4TodaysGuide => 'PANDUAN HARI INI';

  @override
  String g4TodaysGuideIssue(Object n) {
    return 'PANDUAN HARI INI · #$n';
  }

  @override
  String get g4TopicAir => 'Udara';

  @override
  String get g4TopicEnergy => 'Energi';

  @override
  String get g4TopicHeat => 'Panas';

  @override
  String get g4TopicOther => 'Sains';

  @override
  String get g4TopicStorm => 'Badai';

  @override
  String get g4TopicWaste => 'Sampah';

  @override
  String get g4TopicWater => 'Air';

  @override
  String get g4TryAgain => 'Coba lagi';

  @override
  String get g4TryQuizAgain => 'Coba kuis lagi';

  @override
  String get g4WeekLetters => 'S,S,R,K,J,S,M';

  @override
  String get g4WhatAiSaw => 'Yang dilihat ELIOS AI';

  @override
  String get g4WhatToDo => 'Yang dilakukan';

  @override
  String g4XpDone(Object xp) {
    return '✓ $xp XP';
  }

  @override
  String g4XpOf(Object xp, Object total) {
    return '$xp / $total XP';
  }

  @override
  String g4YourQuestion(Object q) {
    return 'Pertanyaanmu: $q';
  }

  @override
  String get g4FeedTitle => 'Panduan ELIOS';

  @override
  String get lnShortcuts => 'Pintasan belajar';

  @override
  String get lnJumpBackIn => 'Lanjut belajar';

  @override
  String get lnExplore => 'Jelajahi';

  @override
  String lnExploreSub(int lessons, int modules) {
    return '$lessons pelajaran di $modules modul';
  }

  @override
  String get lnModules => 'Modul';

  @override
  String get lnPdfGuides => 'Panduan PDF';

  @override
  String get lnPractice => 'Latihan';

  @override
  String get lnYou => 'Kamu';

  @override
  String get lnQuizShort => 'Kuis';

  @override
  String get lnMiniLab => 'Lab mini';

  @override
  String get lnTodaysLab => 'Eksperimen hari ini';

  @override
  String get lnArchive => 'Arsip';

  @override
  String get lnProgressShort => 'Progres';

  @override
  String get lnStartHere => 'Mulai di sini';

  @override
  String lnQuizCount(num count) {
    return '$count kuis';
  }

  @override
  String lnTotalXp(int xp) {
    return 'Total $xp XP';
  }

  @override
  String lnGuideStops(String issue, int done) {
    return '#$issue · $done dari 3 tahap';
  }

  @override
  String lnPctDone(int pct) {
    return '$pct%';
  }

  @override
  String get lnTodaysGuide => 'Panduan hari ini';

  @override
  String get navScan => 'Pindai';

  @override
  String get navScanHint => 'Pindai, membuka pilihan pindai';

  @override
  String get navProfile => 'Profil';

  @override
  String get scanHubSubtitle => 'Pilih cara memindai hari ini';

  @override
  String get scanPhoneOverline => 'Dengan ponselmu';

  @override
  String get scanPhoneTitle => 'Pindai & kuis';

  @override
  String get scanPhoneBody =>
      'Arahkan kamera ke satu benda. ELIOS menamainya dan membuat kuis untukmu.';

  @override
  String get scanOpenCamera => 'Buka kamera';

  @override
  String get scanRobotOverline => 'Dengan robot';

  @override
  String get scanRobotTitle => 'Pindai dengan robot';

  @override
  String get scanRobotBody =>
      'Pilih kendaraan. ELIOS siap; drone segera hadir.';

  @override
  String get scanSelectVehicle => 'Pilih kendaraan';

  @override
  String get vehicleEliosDesc => 'Robot darat · kamera MaixCAM2';

  @override
  String get vehicleDrone => 'Drone';

  @override
  String get vehicleComingSoon => 'Segera hadir';

  @override
  String get vehicleReady => 'Siap';

  @override
  String get vehicleMaixNote => 'Robot memakai kamera MaixCAM2 secara otomatis';

  @override
  String get setupTitle => 'Pengaturan ELIOS';

  @override
  String get profileTapPicture => 'Ketuk fotomu untuk opsi akun';

  @override
  String get profileSynced => 'Akun Google · riwayat tersinkron';

  @override
  String get profileGuestChip => 'Tamu · riwayat tersimpan di ponsel ini saja';

  @override
  String get profileAppearance => 'Tampilan';

  @override
  String get profileDarkModeSub => 'Ubah seluruh aplikasi ke tema gelap';

  @override
  String get profileLanguageSub => 'Teks dan suara aplikasi';

  @override
  String get profileQuestionSource => 'Sumber soal';

  @override
  String get profileQuestionSourceSub => 'Asal soal untuk kuis pindai';

  @override
  String get profileAccountMenu => 'Opsi akun';

  @override
  String get profileSwitchAccount => 'Ganti akun';

  @override
  String vehicleUse(String name) {
    return 'Pakai $name';
  }

  @override
  String get profileNotSignedIn => 'Belum masuk';

  @override
  String get profileGuestTap => 'Ketuk gambar untuk masuk atau ganti akun';

  @override
  String homeLvShort(int n) {
    return 'Lv $n';
  }

  @override
  String homeToNextLong(int count, int level) {
    return '$count XP lagi ke Level $level · pohonmu tumbuh setiap kamu dapat XP';
  }

  @override
  String get homeRobotOverline => 'Robot ELIOS';

  @override
  String get homeStillConnected => 'Masih terhubung';

  @override
  String get homeResumeControl => 'Lanjutkan kontrol robot';

  @override
  String lnClovers(int count) {
    return '$count semanggi';
  }

  @override
  String lnGuideRewards(int xp, String clovers) {
    return '$clovers · $xp XP dari Panduan Harian';
  }

  @override
  String lnCloversOf(int earned, int possible) {
    return '$earned dari $possible semanggi';
  }

  @override
  String get wqSavedNoQuiz =>
      'Tersimpan di Riwayat. Kuis dimatikan untuk pindai robot.';

  @override
  String get setupQuizAfterScan => 'Kuis setelah tiap pindai';

  @override
  String get setupCameraAuto => 'Kamera: MaixCAM2';

  @override
  String get setupAutomatic => 'Otomatis';

  @override
  String get setupOpenControl => 'Buka kontrol';

  @override
  String get setupVideoStream => 'Aliran video';

  @override
  String get vehicleChange => 'Ganti';

  @override
  String get scanHoldSteady => 'Tahan · satu benda di dalam bingkai';

  @override
  String get scanTakePhoto => 'Ambil foto dan kenali';

  @override
  String get scanAiQuiz => 'Kuis AI';

  @override
  String get contributeTitle => 'Pindai untuk berkontribusi';

  @override
  String get contributePickBin => 'Tempat sampah mana yang kamu pakai?';

  @override
  String get contributeDrop =>
      'Masukkan benda ke tempat sampah selagi merekam.';

  @override
  String get contributeKeepLabel =>
      'Jaga label tempat sampah tetap terlihat agar bisa dicek.';

  @override
  String get contributeChecking => 'ELIOS AI sedang mengecek videomu…';

  @override
  String get contributeStart => 'Mulai merekam';

  @override
  String get contributeStop => 'Berhenti merekam';

  @override
  String get contributeNice => 'Pemilahan yang bagus!';

  @override
  String get contributeNotQuite => 'Belum tepat';

  @override
  String get contributeNotChecked => 'Tidak bisa dicek';

  @override
  String get contributeNoItem =>
      'ELIOS AI tidak melihat benda. Coba lagi lebih dekat, dengan cahaya yang cukup.';

  @override
  String contributeWentInto(String item, String bin) {
    return '$item masuk ke tempat sampah $bin.';
  }

  @override
  String contributeBelongs(String item, String bin) {
    return '$item seharusnya masuk tempat sampah $bin. Coba lagi!';
  }

  @override
  String contributeTrophies(int count) {
    return '+$count XP';
  }

  @override
  String get contributeSaved => 'Tersimpan di Riwayat sebagai kontribusi';

  @override
  String get contributeAgain => 'Kontribusi lagi';

  @override
  String get scanContributeOverline => 'Dapatkan XP';

  @override
  String get scanContributeBody =>
      'Rekam dirimu memasukkan sampah ke tempat yang benar. Jaga label tempat sampah tetap terlihat.';

  @override
  String contributeRec(String time) {
    return 'REK $time';
  }

  @override
  String get histSubtitle3 => 'Pindaian, kuis, dan kontribusi';

  @override
  String get histSeeTimeline => 'Lihat linimasa';

  @override
  String get histByDevice => 'Per perangkat';

  @override
  String get histByDeviceSub => 'Buka perangkat untuk melihat linimasanya';

  @override
  String get histToReview => 'Soal untuk diulas';

  @override
  String get histReview => 'Ulas';

  @override
  String histQuiz(int correct, int total) {
    return 'Kuis $correct/$total';
  }

  @override
  String get histScanOnly => 'Pindai saja';

  @override
  String get histContribution => 'Kontribusi';

  @override
  String get histPhone => 'Ponsel';

  @override
  String get histNoScansYet => 'Belum ada pindaian';

  @override
  String get histTimeline => 'Linimasa pindai';

  @override
  String get histTimelineSub => 'Pindaian terbaru per perangkat';

  @override
  String get histPhoneTitle => 'Ponsel ini';

  @override
  String get histEliosTitle => 'Robot ELIOS';

  @override
  String histDeviceScans(int count, String camera) {
    return '$count pindaian · kamera $camera';
  }

  @override
  String get histPhoneCamera => 'ponsel';

  @override
  String get histNoDevice =>
      'Pindaian sebelum pembaruan ini tidak punya perangkat; lihat di Semua.';

  @override
  String get histAllScans => 'Semua';

  @override
  String get h3TrophiesWord => 'XP';

  @override
  String get celebrateTap => 'Ketuk untuk lanjut';

  @override
  String celebrateLevelUp(int level) {
    return 'Level $level!';
  }

  @override
  String get celebrateMedal => 'Medali terbuka';

  @override
  String get lnArchiveTitle => 'Dari arsip';

  @override
  String lnArchiveSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panduan terakhirmu · geser fotonya',
      one: 'Panduan terakhirmu · geser fotonya',
    );
    return '$_temp0';
  }

  @override
  String get lnArchivePulled => 'Lanjutkan dari terakhir kali';

  @override
  String lnArchivePhotoLabel(String title) {
    return '$title. Ketuk untuk menarik keluar, geser untuk panduan berikutnya';
  }

  @override
  String lnArchiveXp(int xp, int total) {
    return '$xp/$total XP';
  }

  @override
  String lnArchiveXpDone(int total) {
    return '✓ $total XP';
  }

  @override
  String lnArchiveStops(int done) {
    return '$done/3 tahap';
  }

  @override
  String lnRailSub(String lead, int count, String module) {
    return '$lead · $count di $module';
  }

  @override
  String get lnRailVideosLead => 'Tonton dan pelajari';

  @override
  String get lnRailGuidesLead => 'Baca dalam semenit';

  @override
  String get lnRailQuizLead => 'Uji pemahamanmu';

  @override
  String lnRailSims(int count) {
    return 'Coba sendiri · $count lab';
  }

  @override
  String get lnSimulation => 'Simulasi';

  @override
  String get lnQuizzes => 'Kuis';

  @override
  String lnBestShort(int score) {
    return 'terbaik $score%';
  }

  @override
  String lnContinueLessonN(int n) {
    return 'Lanjutkan pelajaran $n';
  }

  @override
  String lnStartLessonN(int n) {
    return 'Mulai pelajaran $n';
  }

  @override
  String lnWhatGoesIn(String module) {
    String _temp0 = intl.Intl.selectLogic(module, {
      'organic': 'Yang masuk tong hijau',
      'inorganic': 'Yang masuk tong kuning',
      'hazardous': 'Yang masuk tong merah',
      'other': 'Yang masuk tong ini',
    });
    return '$_temp0';
  }

  @override
  String get lnLessons => 'Pelajaran';

  @override
  String lnModuleProgressDone(int done, int total) {
    return 'Progres modul · $done dari $total selesai';
  }

  @override
  String lnPartN(int n) {
    return 'Bagian $n';
  }

  @override
  String lnPctWatched(int pct) {
    return '$pct% ditonton';
  }

  @override
  String lnLessonNofM(int n, int total) {
    return 'Pelajaran $n dari $total';
  }

  @override
  String get lnPlaying => 'diputar';

  @override
  String get lnCheckAnswer => 'Periksa jawaban';

  @override
  String get lnPickToContinue => 'Pilih jawaban untuk lanjut.';

  @override
  String get setupWsOverWifi => 'Alamat WebSocket ELIOS lewat Wi-Fi robot';

  @override
  String get setupJoinWifi => 'Sambung ke Wi-Fi ELIOS';

  @override
  String get setupJoinWifiBody =>
      'Pindai QR Wi-Fi di robot agar ponsel ini masuk ke jaringannya.';

  @override
  String get setupShowWifiQr => 'Tampilkan QR Wi-Fi robot';

  @override
  String setupFoundAt(String ip) {
    return 'Ditemukan di $ip';
  }

  @override
  String get setupSearch => 'Cari ELIOS';

  @override
  String get setupSearchAgain => 'Cari lagi';

  @override
  String get setupConnectStep => 'Hubungkan';

  @override
  String get setupSaveDefault => 'Simpan sebagai alamat bawaan';

  @override
  String get setupSavedDefault => 'Disimpan sebagai alamat bawaan';

  @override
  String setupStepState(int n, String state) {
    return 'Langkah $n, $state';
  }

  @override
  String get setupStepDone => 'selesai';

  @override
  String get setupStepNow => 'langkah sekarang';

  @override
  String get setupStepTodo => 'belum';

  @override
  String get setupStepProblem => 'perlu dicek';

  @override
  String get histEcoLevel => 'LEVEL EKO KAMU';

  @override
  String get histSyncedShort => 'Tersinkron';

  @override
  String get histSyncingShort => 'Menyinkron';

  @override
  String get histNotSyncedShort => 'Belum sinkron';

  @override
  String get scanResultTitle => 'Hasil scan';

  @override
  String get scanIdentified => 'Teridentifikasi';

  @override
  String get scanIdentifying => 'Mengenali…';

  @override
  String get scanBinRecyclable => 'Tempat sampah Anorganik';

  @override
  String get scanBinOrganic => 'Tempat sampah Organik';

  @override
  String get scanBinB3 => 'Tempat sampah B3';

  @override
  String get scanBinResidu => 'Tempat sampah Residu';

  @override
  String get scanQuizReady => 'Kuismu sudah siap';

  @override
  String get scanQuizWriting => 'Menulis kuismu…';

  @override
  String scanQuizQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soal',
    );
    return '$_temp0';
  }

  @override
  String get scanRetake => 'Foto ulang';

  @override
  String get scanStartQuiz => 'Mulai kuis';

  @override
  String get scanSkipQuestion => 'Lewati soal';

  @override
  String get scanJustNowPhone => 'Baru saja · Ponsel';

  @override
  String get scanGallery => 'Pilih dari galeri';

  @override
  String scanZoom(Object zoom) {
    return 'Zoom $zoom';
  }

  @override
  String get scanFlash => 'Lampu kilat';

  @override
  String get scanWhyWorks => 'Mengapa begitu';

  @override
  String get scanBinFits => 'Tempat sampah mana yang cocok untuk benda ini';

  @override
  String get scanAskCoach => 'Tanya pelatih ELIOS AI';

  @override
  String get scanAskCoachSub => 'Tanya alasannya, minta petunjuk, dengarkan';

  @override
  String get scanBinYes => 'Ya';

  @override
  String get scanBinNo => 'Bukan';
}
