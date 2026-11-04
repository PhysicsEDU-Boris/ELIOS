// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get sidebarLanguage => 'Language';

  @override
  String get sidebarGuestUser => 'Guest User';

  @override
  String get sidebarLocalSession => 'Local session';

  @override
  String get sidebarClose => 'Close sidebar';

  @override
  String get sidebarNavigate => 'NAVIGATE';

  @override
  String get sidebarHome => 'Home';

  @override
  String get sidebarLearn => 'Learn';

  @override
  String get sidebarLearnSubtitle => 'Waste types & quizzes';

  @override
  String get sidebarConfigure => 'Configure';

  @override
  String get sidebarConfigureSubtitle => 'Setup ESP32 WebSocket';

  @override
  String get sidebarControl => 'Control';

  @override
  String get sidebarControlSubtitle => 'Drive robot & Camera';

  @override
  String get sidebarGuestBadge => 'GUEST';

  @override
  String get sidebarDarkMode => 'Dark mode';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signIn => 'Sign in';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get leaveQuizTitle => 'Leave quiz?';

  @override
  String get leaveQuiz => 'Leave Quiz';

  @override
  String photoFailed(Object error) {
    return 'Could not take the photo: $error';
  }

  @override
  String get homeScanActivity => 'Scan activity';

  @override
  String get homeFirstScanToday => 'Your first scan lights up today';

  @override
  String get homeScanItem => 'Scan an item';

  @override
  String homeTrophies(Object count) {
    return '$count trophies';
  }

  @override
  String get homeDailyQuests => 'Daily quests';

  @override
  String get homeBinBuddies => 'Bin buddies';

  @override
  String get homeThisWeek => 'This week';

  @override
  String get homeQuizAccuracy => 'Quiz accuracy';

  @override
  String get homeMedals => 'Medals';

  @override
  String get homeDidYouKnow => 'DID YOU KNOW?';

  @override
  String get historyBackToList => 'Back to list';

  @override
  String get historyPhoto => 'PHOTO';

  @override
  String get historyAddSampleData => 'Add Sample Data (Debug)';

  @override
  String get pdfExported => 'PDF report exported';

  @override
  String pdfExportFailed(Object error) {
    return 'Could not export PDF: $error';
  }

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get moduleProgress => 'Module progress';

  @override
  String get controlGripOpen => 'Open';

  @override
  String get controlGripClosed => 'Closed';

  @override
  String get controlBase => 'Base';

  @override
  String get controlHome => 'HOME';

  @override
  String controlR1Status(Object status) {
    return 'R1: $status';
  }

  @override
  String get controlCheckingRobot => 'checking robot...';

  @override
  String get controlPhoneScan => 'Scan with phone camera';

  @override
  String get configConnectionFailed => 'Connection failed';

  @override
  String get configPhoneOnlyHint =>
      'The robot is not used. Point the phone at one item and tap Start scan.';

  @override
  String get configSameWifiHint =>
      'Put ELIO and this phone on the same Wi-Fi or hotspot, then tap Connect now.';

  @override
  String get configSaveDefault => 'Save as default config';

  @override
  String get configUseAddressNextTime => 'Use this address next time';

  @override
  String get configDragToRotate => 'Drag to rotate';

  @override
  String get configLookingForElio => 'Looking for ELIO…';

  @override
  String get guidePdfUnavailable => 'Guide PDF is not available yet.';

  @override
  String get videoUnavailable => 'Video is not available yet.';

  @override
  String simulationComingSoon(Object title) {
    return '$title is coming soon.';
  }

  @override
  String get quizStartTitle => 'Start Quiz?';

  @override
  String get quizNotNow => 'Not Now';

  @override
  String get quizStart => 'Start';

  @override
  String get quizFinishFirst => 'Finish quiz first';

  @override
  String get quizContinue => 'Continue Quiz';

  @override
  String get quizKnowledgeChallenge => 'Knowledge challenge';

  @override
  String get quizFinishToExit => 'Finish quiz to exit';

  @override
  String get simWork => 'Work (W)';

  @override
  String get simBattery => 'Battery';

  @override
  String get simLiveTimer => 'Live Timer:';

  @override
  String get simRun => 'RUN';

  @override
  String get simBonusUam => 'Bonus: What about uniformly accelerated motion?';

  @override
  String get simSortMode => 'Sort Mode';

  @override
  String get simExploreMode => 'Explore Mode';

  @override
  String get simIdle => 'Idle';

  @override
  String get simCamera => 'Camera (10W)';

  @override
  String get simDriveMotor => 'Drive Motor (36W)';

  @override
  String get simArmMotor => 'Arm Motor (18W)';

  @override
  String get simBatteryLeft => 'Battery Left';

  @override
  String get simMotorSpeed => 'Motor Speed (RPM)';

  @override
  String get simLinearEstimate => 'Estimate (linear approximation)';

  @override
  String get deepOrganicCard => 'Organic Card — Porosity & Oxygen Flow';

  @override
  String get deepInorganicCard => 'Inorganic Card — Hooke, NIR, & Eddy Current';

  @override
  String get deepB3Card => 'B3 Card — Vapor Pressure, Incinerator, Radiation';

  @override
  String get deepCoreConcept => 'Core Concept';

  @override
  String get deepKeyPhysics => 'Key Physics';

  @override
  String get deepWhyDifferent => 'Why is the treatment different?';

  @override
  String get deepHardnessTest => '1. Hardness Test (Hooke Spring)';

  @override
  String deepReactionForce(Object force) {
    return 'Reaction Force (F = k·x): $force N (k=50 N/m)';
  }

  @override
  String get deepNir => '2. Near-Infrared (NIR) Reflectance';

  @override
  String deepSpectrumPeak(Object nm) {
    return 'Spectrum Peak: ≈$nm nm';
  }

  @override
  String get deepEddy => '3. Eddy Current (Non-Ferromagnetic Metal)';

  @override
  String get deepVaporPressure => '1. Vapor Pressure';

  @override
  String deepRelativeVapor(Object value) {
    return 'Relative Vapor Pressure: $value (Arbiter)';
  }

  @override
  String get deepIncinerator => '2. Incinerator (Breaking Chemical Bonds)';

  @override
  String get deepRadiationShield => '3. Radiation Shielding';

  @override
  String get activityLess => 'Less';

  @override
  String get activityMore => 'More';

  @override
  String get activityOpenInHistory => 'Open in History';

  @override
  String get activityNoScans => 'No scans on this day.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Connection, video, sound and quiz';

  @override
  String get aiNeedsInternet => 'Gemini · needs internet';

  @override
  String get aiOffHint =>
      'Identifies scans and writes new quiz questions, about 2 to 4 s each.';

  @override
  String get aiActiveHint => 'Identifying scans and writing quiz questions.';

  @override
  String aiActive(Object model) {
    return 'Active · $model';
  }

  @override
  String get aiCloud => 'cloud';

  @override
  String get aiUnavailable =>
      'No internet, or every AI model is busy. The quiz uses the question bank and tries the AI again on the next scan.';

  @override
  String get robotWifiQr => 'Robot Wi-Fi QR';

  @override
  String get robotQrHint =>
      'Robot not reading it? Lower the screen brightness or tilt the phone a little.';

  @override
  String searchSeeAll(Object count) {
    return 'See all $count results';
  }

  @override
  String get waitingForStream => 'Waiting for MaixCAM2 stream...';

  @override
  String get questionBank => 'Question bank';

  @override
  String get backToQuestion => 'Back to Question';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get testerMode => 'Tester mode';

  @override
  String get testerQuestionSource => 'Question source';

  @override
  String get testerBank => 'Bank';

  @override
  String get testerShareLog => 'Share log';

  @override
  String get testerLogCopied => 'Log copied';

  @override
  String get testerCopyLog => 'Copy log';

  @override
  String get testerLog => 'Tester log';

  @override
  String get testerViewLog => 'View log';

  @override
  String get testerClearLog => 'Clear log';

  @override
  String get lookingForMaixcam => 'Looking for MaixCAM2...';

  @override
  String get lostConnection => 'Lost connection to ELIOS';

  @override
  String get reconnectNow => 'Reconnect now';

  @override
  String get wifiSettings => 'Wi-Fi settings';

  @override
  String missionProgress(Object done, Object target) {
    return '$done of $target done';
  }

  @override
  String get resetScanDebug => 'Reset scan (debug)';
}
