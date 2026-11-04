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

  @override
  String get navMain => 'Main';

  @override
  String get navHome => 'Home';

  @override
  String get navLearn => 'Learn';

  @override
  String get navControl => 'Control';

  @override
  String get navControlHint => 'Control, opens robot control';

  @override
  String get navConfig => 'Config';

  @override
  String get navHistory => 'History';

  @override
  String get shellConnectElio => 'Connect ELIO';

  @override
  String get shellConnected => 'ELIO connected';

  @override
  String get shellConnectedMsg => 'Robot connection is ready.';

  @override
  String get shellDisconnected => 'ELIO disconnected';

  @override
  String get shellDisconnectedMsg =>
      'Robot connection was lost. Check the device or network.';

  @override
  String get leaveQuizBody =>
      'You have an active quiz. If you leave now, your current quiz progress will be lost.';

  @override
  String homeHello(Object name) {
    return 'Hello, $name';
  }

  @override
  String get homeReady => 'Ready to learn with ELIO?';

  @override
  String get configTopSubtitle => 'Robot, camera and quiz setup';

  @override
  String comingSoon(Object title) {
    return '$title — coming soon';
  }

  @override
  String get homeGuest => 'Guest';

  @override
  String get homeOpenNotifications => 'Open notifications';

  @override
  String get homeVideo => 'Video';

  @override
  String get homeGuide => 'Guide';

  @override
  String get medalExplorer => 'Environmental Explorer';

  @override
  String get medalExplorerDesc => 'Complete at least 3 learning items';

  @override
  String get medalExplorerHint => '3 learning items';

  @override
  String get medalRobotics => 'Robotics Beginner';

  @override
  String get medalRoboticsDesc => 'Start the Introduction to ELIO module';

  @override
  String get medalRoboticsHint => 'Start Intro to ELIO';

  @override
  String get medalAdvocate => 'Sustainability Advocate';

  @override
  String get medalAdvocateDesc =>
      'Complete all environmental empathy reflections';

  @override
  String get medalAdvocateHint => 'All reflections';

  @override
  String get homeTapSquare =>
      'Tap any square in the Year view to open that day here.';

  @override
  String scanCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String scansInMonth(Object scans, Object month) {
    return '$scans in $month';
  }

  @override
  String get noScans17Weeks => 'No scans in the last 17 weeks';

  @override
  String scansIn17Weeks(Object scans) {
    return '$scans in the last 17 weeks';
  }

  @override
  String get homeYear => 'Year';

  @override
  String get homeMonth => 'Month';

  @override
  String dayCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String homeStreakLine(Object days, Object longest) {
    return 'Streak $days · longest $longest';
  }

  @override
  String get homeGuestProgress =>
      'Guest progress is stored on this device. Sign in to sync it across devices.';

  @override
  String levelSemantics(Object level, Object title, Object trophies) {
    return 'Level $level, $title. $trophies trophies';
  }

  @override
  String get levelSemanticsTop => ', top level';

  @override
  String levelSemanticsNext(Object count, Object next) {
    return ', $count to level $next';
  }

  @override
  String homeLevel(Object level) {
    return 'Level $level';
  }

  @override
  String get homePlantFirst => 'Plant your first trophy: scan an item.';

  @override
  String get homeTreeGrows => 'Your tree grows with every trophy.';

  @override
  String get homeTopLevel => 'Top level';

  @override
  String homeToNextLevel(Object count, Object next) {
    return '$count to Lv$next';
  }

  @override
  String get homeScans => 'Scans';

  @override
  String get homeDayStreak => 'Day streak';

  @override
  String questsDoneLine(Object done) {
    return '$done of 3 done · resets at midnight';
  }

  @override
  String questsDoneSemantics(Object done) {
    return '$done of 3 quests done';
  }

  @override
  String questSemantics(Object title, Object state, Object reward) {
    return '$title, $state. Reward $reward trophies';
  }

  @override
  String get questDone => 'done';

  @override
  String percentValue(Object value) {
    return '$value percent';
  }

  @override
  String get binsHungry => 'Your bins are hungry: scan an item';

  @override
  String binsFed(Object scans) {
    return '$scans fed to your 3 bins';
  }

  @override
  String get binTop => 'Top';

  @override
  String get residuNote => 'Residu scans count toward Anorganik.';

  @override
  String residuIncluded(Object count, Object scans) {
    return 'Anorganik includes $count residu $scans (the robot sorts residu there).';
  }

  @override
  String scanWord(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'scans',
      one: 'scan',
    );
    return '$_temp0';
  }

  @override
  String weekSemantics(Object count, Object days) {
    return '$count scans this week. $days';
  }

  @override
  String get quizAccNoData => 'Quiz accuracy: no data';

  @override
  String quizAccSemantics(Object acc, Object count) {
    return 'Quiz accuracy $acc percent over the last $count scans with questions';
  }

  @override
  String quizAccDelta(Object dir, Object count) {
    return ', $dir $count points';
  }

  @override
  String get deltaUp => 'up';

  @override
  String get deltaDown => 'down';

  @override
  String get noData => 'no data';

  @override
  String get medalUnlocked => 'Unlocked';

  @override
  String get homeLoading => 'Loading your progress';

  @override
  String get homeGrowing => 'Growing your tree…';

  @override
  String get fact1 =>
      'Plastics under 1,0 g/cm³ float in water. Recycling plants use that to separate them.';

  @override
  String get fact2 =>
      'Batteries are B3 waste: their metals can leak into soil and water, so they need a special drop-off.';

  @override
  String get fact3 =>
      'Fruit peels and food scraps can turn into compost in a few weeks.';

  @override
  String get fact4 =>
      'Rinsing a bottle before recycling keeps the rest of the bin clean.';

  @override
  String get fact5 =>
      'Aluminium cans can be recycled again and again without losing quality.';

  @override
  String get heatmapDayLabels => 'Mon,Wed,Fri';

  @override
  String get calendarWeekdays => 'Su,Mo,Tu,We,Th,Fr,Sa';

  @override
  String get activityScansHint => 'Use Month to browse days';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get searchAll => 'All';

  @override
  String get searchLessons => 'Lessons';

  @override
  String get searchLessonsHeader => 'LESSONS';

  @override
  String get searchSims => 'Simulations';

  @override
  String get searchSimsHeader => 'SIMULATIONS';

  @override
  String get searchQuiz => 'Quiz';

  @override
  String get searchQuizHeader => 'QUIZ';

  @override
  String get searchScans => 'Scans';

  @override
  String get searchScansHeader => 'YOUR SCANS';

  @override
  String get searchHint => 'Search lessons, simulations, scans';

  @override
  String resultCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get searchIn => 'Search in';

  @override
  String noResultsFor(Object query) {
    return 'No results for “$query”.';
  }

  @override
  String get notifNone => 'No notifications right now.';

  @override
  String get notifEmptyHint =>
      'Learning reminders, quiz review updates, and progress alerts will appear here.';

  @override
  String get notifDismiss => 'Dismiss notifications';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifClose => 'Close notifications';

  @override
  String get notifSubtitle => 'Learning updates and reminders from ELIO.';

  @override
  String get notifMarkAllRead => 'Mark all read';

  @override
  String get notifClearAll => 'Clear all';

  @override
  String get notifDone => 'Done';

  @override
  String get notifOpenLearning => 'Open Learning';

  @override
  String get notifOpenConfig => 'Open Config';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(Object n) {
    return '${n}m ago';
  }

  @override
  String timeHoursAgo(Object n) {
    return '${n}h ago';
  }

  @override
  String timeDaysAgo(Object n) {
    return '${n}d ago';
  }

  @override
  String timeWeeksAgo(Object n) {
    return '${n}w ago';
  }

  @override
  String timeMonthsAgo(Object n) {
    return '${n}mo ago';
  }

  @override
  String timeYearsAgo(Object n) {
    return '${n}y ago';
  }

  @override
  String get questScan3 => 'Scan 3 items today';

  @override
  String get questFinishQuiz => 'Finish a scan quiz';

  @override
  String get questSortB3 => 'Sort one B3 item safely';

  @override
  String get levelEcoStarter => 'Eco Starter';

  @override
  String get levelWasteSpotter => 'Waste Spotter';

  @override
  String get levelBinExpert => 'Bin Expert';

  @override
  String get levelEcoSorter => 'Eco Sorter';

  @override
  String get levelPlanetGuardian => 'Planet Guardian';

  @override
  String get gradePerfect => 'Perfect';

  @override
  String get gradeGreat => 'Great';

  @override
  String get gradeGood => 'Good';

  @override
  String get gradeKeepLearning => 'Keep Learning';

  @override
  String get gradeTryAgain => 'Try Again';
}
