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
}
