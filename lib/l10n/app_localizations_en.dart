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
      'Put ELIOS and this phone on the same Wi-Fi or hotspot, then tap Connect now.';

  @override
  String get configSaveDefault => 'Save as default config';

  @override
  String get configUseAddressNextTime => 'Use this address next time';

  @override
  String get configDragToRotate => 'Drag to rotate';

  @override
  String get configLookingForElio => 'Looking for ELIOS…';

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
  String get shellConnectElio => 'Connect ELIOS';

  @override
  String get shellConnected => 'ELIOS connected';

  @override
  String get shellConnectedMsg => 'Robot connection is ready.';

  @override
  String get shellDisconnected => 'ELIOS disconnected';

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
  String get homeReady => 'Ready to learn with ELIOS?';

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
  String get medalRoboticsDesc => 'Start the Introduction to ELIOS module';

  @override
  String get medalRoboticsHint => 'Start Intro to ELIOS';

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
  String get notifSubtitle => 'Learning updates and reminders from ELIOS.';

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

  @override
  String get cfgIpHint => 'Enter an IP like 192.168.4.1';

  @override
  String get cfgPortRange => 'Port 1 to 65535';

  @override
  String cfgFoundAt(Object ip) {
    return 'Found ELIOS at $ip';
  }

  @override
  String get cfgNotFound => 'ELIOS not found on this Wi-Fi';

  @override
  String get cfgRetry => 'Retry';

  @override
  String get cfgCameraSource => 'Camera source';

  @override
  String get cfgCameraSourceSub => 'Which camera takes the scan photo';

  @override
  String get cfgMaixDesc => 'Robot camera over the ELIOS Wi-Fi';

  @override
  String get cfgPhoneCamera => 'Phone camera';

  @override
  String get cfgPhoneCameraDesc => 'Scan with this phone, no robot needed';

  @override
  String get cfgQuizQuestions => 'Quiz questions';

  @override
  String get cfgQuizQuestionsSub => 'Where the scan quiz gets its questions';

  @override
  String get cfgStartScan => 'Start scan';

  @override
  String get cfgConnectNow => 'Connect now';

  @override
  String get cfgDisconnect => 'Disconnect';

  @override
  String get cfgConnecting => 'Connecting…';

  @override
  String get cfgCancelConnecting => 'Cancel connecting';

  @override
  String get cfgConnected => 'Connected';

  @override
  String get cfgTryAgain => 'Try again';

  @override
  String get cfgConnection => 'Connection';

  @override
  String get cfgWsAddress => 'ELIOS WebSocket address';

  @override
  String get cfgPort => 'Port';

  @override
  String get cfgSearching => 'Searching…';

  @override
  String get cfgFindElio => 'Find ELIOS';

  @override
  String get cfgRobotNotUsed => 'Robot not used';

  @override
  String cfgConnectingTo(Object endpoint) {
    return 'Connecting to $endpoint';
  }

  @override
  String get cfgLastTryFailed => 'Last try failed';

  @override
  String get cfgNotConnectedYet => 'Not connected yet';

  @override
  String get cfgNotUsed => 'Not used';

  @override
  String get cfgOnline => 'Online';

  @override
  String get cfgConnectingShort => 'Connecting';

  @override
  String get cfgOffline => 'Offline';

  @override
  String get cfgStatus => 'Status';

  @override
  String get cfgBattery => 'Battery';

  @override
  String get cfgNotReported => 'not reported';

  @override
  String get cfgCamera => 'Camera';

  @override
  String get cfgPhone => 'Phone';

  @override
  String get cfgRobotModel => 'ELIOS robot 3D model, drag to rotate';

  @override
  String get cfgQuestionBankDesc => 'Checked questions, instant';

  @override
  String get cfgAiDesc => 'New questions each scan, needs internet';

  @override
  String get cfgAiUnreachable => 'ELIOS AI is not reachable';

  @override
  String get setConnection => 'Connection';

  @override
  String get setAutoReconnect => 'Auto-reconnect';

  @override
  String get setAutoReconnectSub => 'Reconnect when ELIOS is available again';

  @override
  String get setVideo => 'Video';

  @override
  String get setResolution => 'Resolution';

  @override
  String get setResolutionSub => 'Higher looks sharper but uses more Wi-Fi';

  @override
  String get setShowFps => 'Show FPS overlay';

  @override
  String get setShowFpsSub => 'Show stream speed while viewing';

  @override
  String get setSound => 'Sound';

  @override
  String get setSoundEffects => 'Sound effects';

  @override
  String get setSoundEffectsSub => 'UI and robot feedback sounds';

  @override
  String get setMasterVolume => 'Master volume';

  @override
  String setMasterVolumeValue(Object percent) {
    return 'Master volume $percent%';
  }

  @override
  String get setQuiz => 'Quiz';

  @override
  String get setDifficulty => 'Difficulty';

  @override
  String get setEasy => 'Easy';

  @override
  String get setMedium => 'Medium';

  @override
  String get setHard => 'Hard';

  @override
  String get setTimer => 'Timer';

  @override
  String get setTimerSub => 'Time for each question';

  @override
  String get setAllowSkip => 'Allow skipping';

  @override
  String get setAllowSkipSub => 'Learners can skip a question';

  @override
  String get qrIntro =>
      'Turn on this phone\'s hotspot (2.4 GHz) and type its name and password. On the robot screen tap Wi-Fi setup, then hold this QR in front of the camera.';

  @override
  String get qrSsid => 'Hotspot name (SSID)';

  @override
  String get qrPassword => 'Hotspot password';

  @override
  String get qrShowPassword => 'Show password';

  @override
  String get qrHidePassword => 'Hide password';

  @override
  String get qrShow => 'Show QR';

  @override
  String qrSemantics(Object ssid) {
    return 'Wi-Fi QR code for $ssid';
  }

  @override
  String get ctlWaiting => 'Waiting';

  @override
  String get ctlOffline => 'Offline';

  @override
  String get ctlStopped => 'Stopped';

  @override
  String get ctlForward => 'Forward';

  @override
  String get ctlBack => 'Back';

  @override
  String get ctlLeft => 'Left';

  @override
  String get ctlRight => 'Right';

  @override
  String get ctlReady => 'Ready';

  @override
  String get ctlHoming => 'Homing';

  @override
  String get ctlExit => 'Exit';

  @override
  String get ctlDebugScan => 'Debug Scan';

  @override
  String get ctlPushToDrive => 'Push to drive · let go to stop';

  @override
  String get ctlUnlocksOnConnect => 'Unlocks when the robot connects';

  @override
  String get ctlSpeedPwm => 'SPEED (PWM)';

  @override
  String get ctlSpeed => 'Speed';

  @override
  String get ctlPickUp => 'PICK UP';

  @override
  String get ctlRelease => 'RELEASE';

  @override
  String get ctlGripperCaps => 'GRIPPER';

  @override
  String get ctlGripper => 'Gripper';

  @override
  String get ctlHeight => 'HEIGHT';

  @override
  String get ctlUpDown => 'Up / Down';

  @override
  String get ctlReach => 'REACH';

  @override
  String get ctlFwdBack => 'Fwd / Back';

  @override
  String get ctlArmHint =>
      'Slide up to lift, slide forward to reach. The arm only moves when the robot is not STOPPED.';

  @override
  String get ctlArmLocked =>
      'Arm controls unlock when the robot is connected. STOP always works.';

  @override
  String get ctlAiBusy => 'ELIOS AI is busy. Try LOCK again in a moment.';

  @override
  String get ctlNoItem =>
      'No item found. Point the camera at one item and try again.';

  @override
  String get ctlBaseLeft => 'Base left';

  @override
  String get ctlBaseRight => 'Base right';

  @override
  String get ctlRobotControl => 'Robot Control';

  @override
  String get ctlDrive => 'DRIVE';

  @override
  String get ctlLiveScanPaused => 'LIVE · scan paused';

  @override
  String ctlLiveFps(Object fps) {
    return 'LIVE · $fps fps';
  }

  @override
  String get ctlNoVideo => 'No video';

  @override
  String get ctlNoVideoCaps => 'NO VIDEO';

  @override
  String get ctlConnecting => 'Connecting...';

  @override
  String get ctlScanQuiz => 'Scan quiz';

  @override
  String get ctlVoice => 'Voice';

  @override
  String get ctlWaitingFrames => 'Connected. Waiting for camera frames...';

  @override
  String get ctlArm => 'ARM';

  @override
  String get ctlUnlock => 'UNLOCK';

  @override
  String get ctlLock => 'LOCK';

  @override
  String get ctlScan => 'SCAN';

  @override
  String get ctlDisconnectRobot => 'Disconnect robot';

  @override
  String get ctlConnectRobot => 'Connect robot';

  @override
  String get ctlGuide => 'Guide';

  @override
  String get ctlStoppedPaused => 'Robot stopped · scanning paused';

  @override
  String get ctlRobotOffline => 'Robot offline';

  @override
  String get ctlTurnOnRobot => 'Turn on the robot and join the ELIOS Wi-Fi.';

  @override
  String get ctlConnect => 'Connect';

  @override
  String get ctlEmergencyStop => 'Emergency stop';

  @override
  String get ctlPower => 'Power';

  @override
  String get ctlMaixConnected => 'MaixCAM2 connected';

  @override
  String get ctlDisconnected => 'Disconnected';

  @override
  String get ctlPickZone => 'PICK ZONE';

  @override
  String get ctlKeepTabletOnWifi =>
      'Turn the robot on and keep this tablet on the ELIOS Wi-Fi.';

  @override
  String ctlRetryingIn(Object s, Object attempt, Object max) {
    return 'Retrying in $s s · attempt $attempt of $max';
  }

  @override
  String get ctlAutoReconnectOff => 'Auto-reconnect is off';

  @override
  String ctlStoppedRetrying(Object max) {
    return 'Stopped retrying after $max tries';
  }

  @override
  String ctlTryingAgain(Object attempt, Object max) {
    return 'Trying again · attempt $attempt of $max';
  }

  @override
  String get ctlLinkDropped =>
      'The robot link dropped, so the robot stopped for safety.';

  @override
  String get ctlOpenQuiz => 'Open quiz';

  @override
  String get ctlMission => 'MISSION';

  @override
  String ctlSortItems(Object count) {
    return 'Sort $count items this drive';
  }

  @override
  String get ctlThisDrive => 'THIS DRIVE';

  @override
  String get ctlElioSays => 'ELIOS SAYS';

  @override
  String ctlMissionOf(Object done, Object target) {
    return 'Mission $done of $target';
  }

  @override
  String get ctlSubtitle => 'Drive close, pick it up, sort it right!';

  @override
  String get ctlLinkLost => 'link lost';

  @override
  String get ctlStopButton => 'STOP button';

  @override
  String get ctlRobotError => 'robot error';

  @override
  String ctlRobotStoppedWhy(Object why) {
    return 'Robot STOPPED · $why';
  }

  @override
  String get ctlHoldForHome => 'Hold 1 second for HOME';

  @override
  String ctlRobotStoppedLong(Object why) {
    return 'ROBOT STOPPED ($why). Scanning stopped; an open quiz can still be answered.';
  }

  @override
  String get guideDriveTitle => 'Drive the robot';

  @override
  String get guideDriveBody =>
      'Push the green knob the way you want to go. Let go and the robot stops.';

  @override
  String get guideStopTitle => 'Big red STOP';

  @override
  String get guideStopBody =>
      'Tap it any time something looks unsafe. Space or Esc work too.';

  @override
  String get guideGrabTitle => 'Grab the item';

  @override
  String get guideGrabBody =>
      'When the item is close, press PICK UP. RELEASE drops it. HOME parks the arm.';

  @override
  String get guideQuizTitle => 'Answer the quiz';

  @override
  String get guideQuizBody =>
      'After each scan ELIOS AI asks a question. Tap here to open it and win trophies!';

  @override
  String guideStepOf(Object step, Object total) {
    return 'STEP $step OF $total';
  }

  @override
  String get guideSkip => 'Skip';

  @override
  String get guideNext => 'Next';

  @override
  String get guideIntro =>
      'Drive to an item, grab it, sort it, then answer ELIOS AI to earn trophies. Tap Guide any time to replay this.';

  @override
  String get r2JoystickHint => 'Joystick: slide to steer, let go to stop';

  @override
  String r2SpeedValue(Object value) {
    return 'Speed $value';
  }

  @override
  String get r2RobotPrefix => 'Robot ';

  @override
  String get dsAiOffline => 'ELIOS AI offline · question bank';

  @override
  String get dsAiReady => 'ELIOS AI ready';

  @override
  String get dsBack => 'Back';

  @override
  String get dsLive => 'LIVE';

  @override
  String get dsNoCamera => 'No camera';

  @override
  String get dsBankMode => 'Bank mode';

  @override
  String get dsPutItem => 'Put one item inside the white box, then tap Scan.';

  @override
  String get dsScanMakeQuiz => 'Scan and make quiz';

  @override
  String get dsScanMakeQuizShort => 'Scan & make quiz';

  @override
  String get dsTiming => 'About 2–4 s · needs internet';

  @override
  String get dsSwitchCamera => 'Switch camera';

  @override
  String get dsTestModeHint => 'Test mode: quiz without the camera';

  @override
  String get dsTestMode => 'Test mode';

  @override
  String get histSavedLocal => 'Saved locally';

  @override
  String get histTitle => 'Scan History';

  @override
  String get histSubtitleShort => 'Quiz results & trophies';

  @override
  String get histSubtitle =>
      'Every item you scanned, with its quiz results and trophies';

  @override
  String get histPickLeft => 'Pick a scan on the left to see the quiz details.';

  @override
  String get histRecent => 'Recent scans';

  @override
  String get histSeedDebug => 'Seed Sample Data (Debug)';

  @override
  String get histRecyclable => 'Recyclable';

  @override
  String get histOrganic => 'Organic';

  @override
  String histScannedAt(Object time, Object count) {
    return 'Scanned $time · Photo and $count questions saved locally';
  }

  @override
  String histDiffPill(Object level, Object count) {
    return '$level · ${count}Q';
  }

  @override
  String get hist10Trophies => '10 trophies per right answer';

  @override
  String get histQuestions => 'Questions';

  @override
  String get histPending => 'Pending';

  @override
  String get histCorrect => 'Correct';

  @override
  String get histWrong => 'Wrong';

  @override
  String get histYourAnswer => 'YOUR ANSWER';

  @override
  String get histRightAnswer => 'RIGHT ANSWER';

  @override
  String get histScore => 'SCORE';

  @override
  String get awaitingGrading => 'Awaiting grading';

  @override
  String histEssayScore(Object score, Object trophies) {
    return '$score / 10 · +$trophies trophies';
  }

  @override
  String get histHideExplanation => 'Hide Explanation';

  @override
  String get histShowExplanation => 'Show Explanation';

  @override
  String get histNoExplanation => 'No explanation was saved for this question.';

  @override
  String get histEmptyTitle => 'No Scan History Yet';

  @override
  String get histEmptyBody =>
      'Every item you scan and every quiz you finish will show up here.';

  @override
  String get authUserNotFound =>
      'No account found with this email or username.';

  @override
  String get authWrongPassword => 'Incorrect password.';

  @override
  String get authEmailInUse => 'This email is already registered.';

  @override
  String get authWeakPassword => 'Password must be at least 6 characters.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authTooMany => 'Too many attempts. Try again later.';

  @override
  String get authNoInternet => 'No internet connection.';

  @override
  String get authGoogleConfig =>
      'Google sign-in is not configured correctly. Check Android/iOS Firebase setup.';

  @override
  String get authOtherMethod =>
      'This email is already registered with another sign-in method.';

  @override
  String get authGoogleLinked =>
      'This Google account is already linked to another user.';

  @override
  String get authGoogleInvalid =>
      'Google credential is invalid. Check Firebase configuration.';

  @override
  String get authGoogleDisabled =>
      'Google sign-in is not enabled in Firebase Authentication.';

  @override
  String get authGeneric => 'Something went wrong. Please try again.';

  @override
  String get authWelcomeBack => 'Welcome back!';

  @override
  String get authSignInFailed => 'Sign in failed.';

  @override
  String get authAccountCreated => 'Account created!';

  @override
  String get authCreateFailed => 'Account creation failed.';

  @override
  String get authNoIdToken =>
      'Google Sign-In returned no idToken. Check Firebase platform config.';

  @override
  String authGoogleFailedCode(Object code) {
    return 'Google sign-in failed: $code';
  }

  @override
  String get authGoogleFailed => 'Google sign-in failed. Check debug logs.';

  @override
  String get authGuestEntered => 'Entered guest mode.';

  @override
  String get authGuestFailed => 'Guest mode failed.';

  @override
  String get authEmailFirst => 'Enter a valid email first.';

  @override
  String get authResetSent => 'Reset link sent to your email.';

  @override
  String get authResetFailed => 'Failed to send reset email.';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailOrUserRequired => 'Email or username is required';

  @override
  String get authValidEmail => 'Enter a valid email';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authMin6 => 'Min 6 characters';

  @override
  String get authNameRequired => 'Name is required';

  @override
  String get authMin2 => 'Min 2 characters';

  @override
  String get authForgot => 'Forgot password?';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authWelcomeTitle => 'Welcome Back';

  @override
  String get authJoin => 'Join ELIOS to start sorting';

  @override
  String get authSignInSub => 'Sign in to control ELIOS';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailOrUser => 'Email / Username';

  @override
  String get authEmailOrUserHint => 'you@example.com or username';

  @override
  String get authSendReset => 'Send reset link';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authFullName => 'Full Name';

  @override
  String get authFullNameHint => 'John Doe';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authGoogle => 'Continue with Google';

  @override
  String get authGuest => 'Continue as Guest';

  @override
  String get authGuestNote =>
      'Guest mode saves data locally only. Sign in to sync progress.';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authPleaseWait => 'Please wait';

  @override
  String get authOr => 'Or';

  @override
  String get quizSrcBank => 'MODULE QUESTION · QUESTION BANK';

  @override
  String get quizSrcAi => 'ELIOS AI QUESTION';

  @override
  String get quizSrcFallback => 'BACKUP QUESTION (ELIOS AI NOT CONNECTED)';

  @override
  String get quizSrcGeneric =>
      'GENERAL QUESTION (ITEM NOT IN THE QUESTION BANK YET)';

  @override
  String get quizPreparing => 'Quiz, preparing the question';

  @override
  String get quizReady => 'Quiz, question ready';

  @override
  String get quizWord => 'Quiz';

  @override
  String get scanFailed => 'Scan did not work';

  @override
  String get wasteGeneric => 'Waste';

  @override
  String trophiesEarned(Object count) {
    return '+$count trophies';
  }

  @override
  String trophiesTotal(Object count) {
    return '$count total trophies';
  }

  @override
  String get robotDropping => 'The robot is dropping it in the bin...';

  @override
  String get qzReadScan => 'Read the scan';

  @override
  String get qzAiLooking => 'ELIOS AI is looking';

  @override
  String get qzPickedTopic => 'Picked a topic';

  @override
  String get qzAfterScan => 'After the scan';

  @override
  String get qzAiTopic => 'ELIOS AI topic';

  @override
  String qzBankPool(Object pool) {
    return 'Bank pool · $pool';
  }

  @override
  String get qzWriting => 'Writing the question';

  @override
  String get qzEssay => 'essay';

  @override
  String get qzMultipleChoice => 'multiple choice';

  @override
  String qzQuestionOfLevel(Object n, Object total, Object level) {
    return 'Question $n of $total · $level';
  }

  @override
  String qzQuestionOf(Object n, Object total) {
    return 'Question $n of $total';
  }

  @override
  String qzScanned(Object name) {
    return 'Scanned: $name';
  }

  @override
  String get qzReading => 'reading…';

  @override
  String get qzAiReadingCaps => 'ELIOS AI · READING THE SCAN';

  @override
  String get qzAiWritingCaps => 'ELIOS AI · WRITING YOUR QUESTION';

  @override
  String get qzReadingScan => 'Reading the scan…';

  @override
  String get qzPreparingNext => 'Preparing the next question…';

  @override
  String get qzAiOnline =>
      'ELIOS AI is writing it online. This usually takes 2–4 seconds.';

  @override
  String get qzFromBank =>
      'From the reviewed question bank. This takes a moment.';

  @override
  String get qzKeepDriving => 'Keep driving. ';

  @override
  String get qzMinimiseHint =>
      'Minimise this and the Quiz button lights up when the question is ready.';

  @override
  String qzMcCaps(Object level) {
    return 'MULTIPLE CHOICE · $level';
  }

  @override
  String get qzSkipFinish => 'Skip and finish';

  @override
  String get qzSkip => 'Skip';

  @override
  String get qzUpTo10 => 'Up to +10 trophies for a full answer';

  @override
  String get qz10Right => '+10 trophies for a right answer';

  @override
  String qzEssayCaps(Object level, Object words) {
    return 'ESSAY · $level · MAX $words WORDS';
  }

  @override
  String get qzGrading => 'ELIOS AI is grading your answer…';

  @override
  String get qzTypeAnswer => 'Type your answer here…';

  @override
  String get qzSubmit => 'Submit';

  @override
  String get qzClear => 'Clear';

  @override
  String qzHazardTitle(Object name) {
    return 'Possibly hazardous (B3): $name';
  }

  @override
  String get qzHazardBody =>
      'Don\'t take it apart or put it in a normal bin. Ask staff to handle it. Continue the quiz about this item?';

  @override
  String get qzContinueQuiz => 'Continue quiz';

  @override
  String get qzWhichBin => 'Which bin is right?';

  @override
  String qzMismatchBody(
    Object detector,
    Object detectorCategory,
    Object name,
    Object aiCategory,
  ) {
    return 'The detector says $detector ($detectorCategory). ELIOS AI says $name ($aiCategory). Pick the right one.';
  }

  @override
  String qzUseAi(Object category) {
    return 'Use ELIOS AI ($category)';
  }

  @override
  String qzUseDetector(Object category) {
    return 'Use detector ($category)';
  }

  @override
  String get qzScanChip => 'Scan';

  @override
  String get qzComplete => 'Quiz complete';

  @override
  String get qzBack => 'Back';

  @override
  String get qzListenExplanation => 'Listen to explanation';

  @override
  String get qzFinish => 'Finish quiz';

  @override
  String get qzNextQuestion => 'Next question';

  @override
  String get qzEssayReview => 'Essay review';

  @override
  String get qzReview => 'Review';

  @override
  String get qzWaitingGrading => 'Waiting for grading';

  @override
  String get qzNotGradedYet =>
      'ELIOS AI has not graded this answer yet. It is saved and graded later.';

  @override
  String qzScoreOf10(Object score) {
    return 'Score $score / 10';
  }

  @override
  String get qzCorrect => 'Correct!';

  @override
  String qzYouChose(Object picked) {
    return 'You chose “$picked”.';
  }

  @override
  String get qzNotQuite => 'Not quite';

  @override
  String qzRightAnswerIs(Object answer) {
    return 'The right answer is “$answer”.';
  }

  @override
  String get qzAnswerReview => 'Answer review';

  @override
  String get qzDetailed => 'Detailed explanation';

  @override
  String qzQuestionOfCaps(Object n, Object total, Object kind) {
    return 'QUESTION $n OF $total · $kind';
  }

  @override
  String get qzEssayUpper => 'ESSAY';

  @override
  String get qzQuestionCaps => 'QUESTION';

  @override
  String get qzCorrectAnswerCaps => 'CORRECT ANSWER';

  @override
  String get qzLoadingExplanation => 'Loading the explanation…';

  @override
  String get qzSavedNoTrophies =>
      'Your answer is saved. ELIOS AI grades it when it is ready; no trophies until then.';

  @override
  String get qzFeedback => 'Feedback';

  @override
  String get qzWhyWrong => 'Why your answer is not right';

  @override
  String get qzWhyRight => 'Why the correct answer is right';

  @override
  String get qzElioModule => 'ELIOS module';

  @override
  String get qzScoringTable => 'Table 1. Scoring breakdown';

  @override
  String get qzCriteria => 'CRITERIA';

  @override
  String get qzFeedbackCaps => 'FEEDBACK';

  @override
  String qzWhereGoes(Object name) {
    return 'Table 1. Where $name goes';
  }

  @override
  String get qzThisItem => 'this item';

  @override
  String get qzBin => 'BIN';

  @override
  String get qzExamples => 'EXAMPLES';

  @override
  String get qzAccepts => 'ACCEPTS';

  @override
  String get qzOptionsTable => 'Table 1. The answer options';

  @override
  String get qzOption => 'OPTION';

  @override
  String get qzStatus => 'STATUS';

  @override
  String get qzCorrectAnswer => 'Correct answer';

  @override
  String get qzYourAnswer => 'Your answer';

  @override
  String get qzAiGraded => 'AI graded · check with your teacher';

  @override
  String get qzReviewedBank => 'Reviewed question bank';

  @override
  String get qzAiGenerated => 'AI generated · not reviewed';

  @override
  String get qzSugFullMark => 'Show a full-mark answer';

  @override
  String get qzSugKeyTerms => 'Explain key terms';

  @override
  String get qzSugHint => 'Give me a hint';

  @override
  String get qzSugSimpler => 'Say it simpler';

  @override
  String get qzCoach => 'ELIOS AI coach';

  @override
  String get qzSent => 'Sent';

  @override
  String get qzPlaying => 'Playing';

  @override
  String get qzAskScore => 'Ask ELIOS AI about your score…';

  @override
  String get qzAsk => 'Ask ELIOS AI…';

  @override
  String get qzSend => 'Send';

  @override
  String get qzListen => 'Listen';

  @override
  String get qzCopy => 'Copy';

  @override
  String get qzWhichItem => 'Which item is this?';

  @override
  String get qzNotThis => 'Not this?';

  @override
  String get qzMinimise => 'Minimise';

  @override
  String get qzMinimiseQuiz => 'Minimise quiz';

  @override
  String get qzCloseQuiz => 'Close quiz';

  @override
  String get qzReadToMe => 'Read it to me';

  @override
  String get qzExplanation => 'Explanation';

  @override
  String get ovEssayMax => 'Essay · max 150 words';

  @override
  String get ovPendingSub => 'Answer saved. No score yet.';

  @override
  String ovEssayScore(Object score) {
    return 'Score: $score/10 · +$score trophies';
  }

  @override
  String get ovGood => 'Good answer!';

  @override
  String get ovNeedsWork => 'A few points need work.';

  @override
  String get ovRight => 'Correct! +10 trophies';

  @override
  String get ovWrong => 'Not quite right';

  @override
  String ovRightAnswer(Object answer) {
    return 'Right answer: $answer';
  }

  @override
  String ovExplanationN(Object n) {
    return 'Explanation for question $n';
  }

  @override
  String get ovNoExplanation => 'No explanation for this question yet.';

  @override
  String get ovCompareTable => 'Waste category comparison';

  @override
  String ovReference(Object answer) {
    return 'Reference answer: $answer';
  }

  @override
  String get ovCategory => 'Category';

  @override
  String get ovMaterial => 'Material';

  @override
  String get ovAccepted => 'Accepted';

  @override
  String get ovCriteria => 'Criteria';

  @override
  String get ovMax => 'Max';

  @override
  String get ovAwarded => 'Awarded';

  @override
  String get ovComment => 'Comment';

  @override
  String get ovFinish => 'Finish quiz ✓';

  @override
  String get ovNext => 'Next question →';

  @override
  String get ovAssistant => 'AI Correction Assistant';

  @override
  String get ovAskAi => 'Ask AI...';

  @override
  String get ovVoice => 'Voice';

  @override
  String get lqTitle => 'Quiz';

  @override
  String lqCompletedBest(Object score) {
    return ' Completed with best score $score%.';
  }

  @override
  String lqBest(Object score) {
    return ' Best score $score%.';
  }

  @override
  String lqUsedAttempt(Object scoreText) {
    return 'You have already used your one quiz attempt.$scoreText';
  }

  @override
  String get lqOnceBody =>
      'This quiz can only be attempted once. Once you start, you must finish it before leaving.';

  @override
  String get lqFinishBody =>
      'This quiz has only one attempt. Please finish all questions before leaving.';

  @override
  String get lqLoading => 'Loading quiz questions';

  @override
  String get lqLoadFailed => 'Quiz questions could not be loaded.';

  @override
  String get lqCheckFirestore =>
      'Check the Firestore connection and try again.';

  @override
  String get lqBackToQuizzes => 'Back to Quizzes';

  @override
  String get lqNotAvailable => 'Quiz questions are not available yet.';

  @override
  String get lqIntro =>
      'Test your understanding of waste management and how ELIOS classifies materials. Each quiz has one attempt.';

  @override
  String get lqSetsFailed => 'Quiz sets could not be loaded.';

  @override
  String get lqNoPublished => 'No published quizzes are available.';

  @override
  String get lqCompleted => 'Completed';

  @override
  String get lqAttemptUsed => 'Attempt used';

  @override
  String lqBestScore(Object score) {
    return 'best score $score%';
  }

  @override
  String get lqReviewNew => 'review for new attempts only';

  @override
  String lqQuestions(Object count) {
    return '$count questions';
  }

  @override
  String get lqOneAttempt => 'one attempt';

  @override
  String get lqReview => 'Review';

  @override
  String get lqDone => 'Done';

  @override
  String get lqUsed => 'Used';

  @override
  String lqCounter(Object n, Object total) {
    return 'Question $n / $total';
  }

  @override
  String lqCorrectExpl(Object explanation) {
    return 'Correct: $explanation';
  }

  @override
  String lqNotQuiteExpl(Object explanation) {
    return 'Not quite: $explanation';
  }

  @override
  String get lqNotQuite => 'Not quite.';

  @override
  String get lqViewResults => 'View results';

  @override
  String get lqImageUnavailable => 'Image unavailable';

  @override
  String lqScored(Object score, Object total) {
    return 'You scored $score out of $total.';
  }

  @override
  String get lqBackLower => 'Back to quizzes';

  @override
  String get lqReviewAnswers => 'Review answers';

  @override
  String get rvTitle => 'Quiz review';

  @override
  String get rvScore => 'Score';

  @override
  String get rvPercent => 'Percent';

  @override
  String get rvPassed => 'Passed';

  @override
  String rvQuestionN(Object n) {
    return 'Question $n';
  }

  @override
  String get rvNotAnswered => 'Not answered';

  @override
  String get rvUnknown => 'Unknown answer';

  @override
  String get pqResultsTitle => 'Physics Quiz Results';

  @override
  String get pqTitle => 'Physics quiz';

  @override
  String pqCounter(Object n, Object total) {
    return 'Question $n / $total';
  }

  @override
  String get pqAdvanced => 'Advanced physics';

  @override
  String get pqWrong => 'Not quite.';

  @override
  String get pqSeeResults => 'See results';

  @override
  String get pqNext => 'Next question';

  @override
  String get pqDone => 'Physics Quiz Complete';

  @override
  String pqScore(Object score, Object total) {
    return 'Your score: $score / $total';
  }

  @override
  String get pqBackMenu => 'Back to Menu';

  @override
  String get tpNotUsed => 'Not used yet';

  @override
  String tpReady(Object model) {
    return 'Ready ($model)';
  }

  @override
  String get tpOffline => 'Not connected, bank mode';

  @override
  String get lnWelcome => 'Welcome to Learn';

  @override
  String lnWelcomeBody(Object bin, Object count) {
    return 'Start with $bin: $count short lessons, then try the quiz.';
  }

  @override
  String get lnStartModule1 => 'Start module 1';

  @override
  String get lnTestElio => 'Test how ELIOS sorts waste.';

  @override
  String lnQuizzesTest(Object count) {
    return '$count quizzes. Test how ELIOS sorts waste.';
  }

  @override
  String get lnTakeQuiz => 'Take quiz';

  @override
  String get lnYourProgress => 'Your learning progress';

  @override
  String get lnNoModulesStarted => 'No modules started yet';

  @override
  String lnModulesInProgress(Object started, Object total) {
    return '$started of $total modules in progress';
  }

  @override
  String lnOverall(Object percent) {
    return '$percent% overall completion';
  }

  @override
  String get lnCourseModules => 'Course modules';

  @override
  String get lnSeeAll => 'See all';

  @override
  String get lnContinueLearning => 'Continue learning';

  @override
  String get lnAllLessons => 'All lessons';

  @override
  String get lnNothingInProgress =>
      'Nothing in progress yet. Lessons you open will wait for you here.';

  @override
  String get lnWatchLearn => 'Watch and learn';

  @override
  String lnVideoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get lnVideos => 'Videos';

  @override
  String get lnNoVideos => 'No videos published yet.';

  @override
  String get lnPhysicsSims => 'Physics simulations';

  @override
  String lnModuleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modules',
      one: '1 module',
    );
    return '$_temp0';
  }

  @override
  String lnSimTag(Object tag) {
    return 'Simulation · $tag';
  }

  @override
  String get lnGuides => 'Guides';

  @override
  String get lnNoGuides => 'No guides published yet.';

  @override
  String lnModuleN(Object n) {
    return 'Module $n';
  }

  @override
  String get lnGuide => 'Guide';

  @override
  String get lnDone => 'Done';

  @override
  String get lnNew => 'New';

  @override
  String get lnLoadFailed => 'Learning modules could not be loaded.';

  @override
  String get lnLoadFailedBody =>
      'Check the connection to ELIOS or the internet, then try again. Lessons you already opened still work offline.';

  @override
  String get lnOpenOffline => 'Open offline lessons';

  @override
  String get lnNoModules => 'No learning modules available yet.';

  @override
  String get lnNoModulesBody =>
      'New lessons appear here as soon as they are published.';

  @override
  String get lnNothingHere => 'Nothing here yet.';

  @override
  String get lnVideo => 'Video';

  @override
  String get lnSimulations => 'Simulations';

  @override
  String get lnOfflineLessons => 'Offline lessons';

  @override
  String get lnLoadingOffline => 'Loading offline lessons';

  @override
  String get lnOfflineNote =>
      'Guides you opened before work offline. Videos need the internet.';

  @override
  String get lnNoSaved => 'No lessons saved on this device yet.';

  @override
  String get lnPlayVideo => 'Play video';

  @override
  String get lnOpenGuide => 'Open guide';

  @override
  String lnContinueVideo(Object pct) {
    return 'Continue video · $pct%';
  }

  @override
  String lnContinueGuide(Object pct) {
    return 'Continue guide · $pct%';
  }

  @override
  String get lnWatchAgain => 'Watch again';

  @override
  String get lnReadAgain => 'Read again';

  @override
  String get lnLesson => 'Lesson';

  @override
  String get lnDuration => 'Duration';

  @override
  String get lnReading => 'Reading';

  @override
  String lnPositionOf(Object n, Object total) {
    return '$n of $total';
  }

  @override
  String get lnWatched => 'Watched';

  @override
  String get lnRead => 'Read';

  @override
  String get lnAbout => 'About this lesson';

  @override
  String lnGuidesTab(Object count) {
    return '$count Guides';
  }

  @override
  String lnVideosTab(Object count) {
    return '$count Videos';
  }

  @override
  String lnQuizTab(Object count) {
    return '$count Quiz';
  }

  @override
  String get lnNoQuizModule => 'No quiz for this module yet.';

  @override
  String get lnNothingModule => 'Nothing here for this module yet.';

  @override
  String get lnThisLesson => 'this lesson';

  @override
  String get lnMyProgress => 'My progress';

  @override
  String get lnNoProgress => 'No progress yet.';

  @override
  String get lnNoProgressBody =>
      'Open a lesson, a simulation or a quiz and your progress shows up here.';

  @override
  String get lnInProgress => 'In progress';

  @override
  String get lnCompleted => 'Completed';

  @override
  String get lnSimProgress => 'Simulation progress';

  @override
  String lnSimsDone(Object done, Object total) {
    return '$done of $total modules done';
  }

  @override
  String lnPercentDone(Object percent) {
    return '$percent% done';
  }

  @override
  String get lnAllComplete => 'Every module is complete.';

  @override
  String get lnNoneComplete => 'No module completed yet.';

  @override
  String lnMinutes(Object count) {
    return '$count min';
  }

  @override
  String lnLessonCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String get lnQuizHistory => 'Quiz history';

  @override
  String get lnQuizHistoryHint =>
      'Quizzes you finish are listed here with your best score.';

  @override
  String lnBinQuiz(Object bin) {
    return '$bin quiz';
  }

  @override
  String lnBest(Object score) {
    return 'Best $score%';
  }

  @override
  String lnGuideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guides',
      one: '1 guide',
    );
    return '$_temp0';
  }

  @override
  String get lnNoVideosModule => 'No videos in this module yet.';

  @override
  String get lnNoGuidesModule => 'No guides in this module yet.';

  @override
  String get lnSimForModule => 'Simulation for this module';

  @override
  String get lnOpen => 'Open';

  @override
  String get lnNoQuizPublished => 'No quiz published for this module yet.';

  @override
  String get lnLoadingGuide => 'Loading guide';

  @override
  String get lnCheckOpenAgain =>
      'Check the connection and open the guide again.';

  @override
  String get lnPrevPage => 'Previous page';

  @override
  String lnPageOf(Object n, Object total) {
    return 'Page $n of $total';
  }

  @override
  String lnPage(Object n) {
    return 'Page $n';
  }

  @override
  String get lnNextPage => 'Next page';

  @override
  String lnVideoTag(Object tag) {
    return 'Video · $tag';
  }

  @override
  String lnGuidePart(Object n) {
    return 'Guide · Part $n';
  }

  @override
  String get lnStart => 'Start';

  @override
  String get lnContinue => 'Continue';

  @override
  String lnModuleLabel(Object label) {
    return 'Module $label';
  }

  @override
  String lnVideoLabel(Object title) {
    return 'Video $title';
  }

  @override
  String lnSimLabel(Object title) {
    return 'Simulation $title';
  }

  @override
  String get lnLoadingModules => 'Loading learning modules';

  @override
  String get lnLoadingLesson => 'Loading lesson';

  @override
  String lnAnswerLabel(Object letter, Object label) {
    return 'Answer $letter: $label';
  }

  @override
  String get lnCorrectSuffix => ', correct';

  @override
  String get lnWrongSuffix => ', wrong';

  @override
  String get lnTabTheory => 'Theory';

  @override
  String get lnTabFormula => 'Formula';

  @override
  String get lnStatus => 'Status';

  @override
  String get lnBackToHub => 'Back to learning hub';

  @override
  String get openProfileMenu => 'Open profile menu';

  @override
  String get closeMenu => 'Close menu';

  @override
  String get navigationMenu => 'Navigation menu';

  @override
  String get dismissNotification => 'Dismiss notification';

  @override
  String get wqCannotCrop =>
      'The item could not be cut out of the photo. Try scanning again.';

  @override
  String get wqNoCleanPhoto =>
      'The original photo without annotations is not available yet. Update the camera firmware, then scan again.';

  @override
  String get wqNotRecognised => 'The item in the photo was not recognised yet.';

  @override
  String get wqPickFirst =>
      'Pick one answer first. After that you can ask anything about this question.';

  @override
  String get wqWriteFirst =>
      'Write your answer and send it. After it is graded you can ask more.';

  @override
  String wqFallbackAi(Object reason) {
    return 'This is a backup question because the AI couldn\'t write one. $reason';
  }

  @override
  String get wqFallbackGeneric =>
      'This is a general question because this item is not in the question bank yet.';

  @override
  String get wqBankNotice =>
      'The AI is not connected, so this question is from the question bank. Check the internet.';

  @override
  String get wqRight => 'Correct!';

  @override
  String wqWrong(Object answer) {
    return 'Not quite. The right answer: $answer.';
  }

  @override
  String get wqEssayAnswer => 'Essay answer';

  @override
  String wqSavedNotGraded(Object reason) {
    return 'Answer saved, but the AI couldn\'t grade it yet. $reason';
  }

  @override
  String wqForFullMarks(Object tip) {
    return 'For full marks: $tip';
  }

  @override
  String wqScore(Object score) {
    return 'Score: $score/10.';
  }

  @override
  String get wqAnswerFirstMc =>
      'Answer the question first. Once you pick an answer, I\'ll explain it and answer your questions about it.';

  @override
  String get wqAnswerFirstEssay =>
      'Send your essay answer first. Then I\'ll grade it and we can talk about it.';

  @override
  String get wqScanFirst =>
      'Scan an item first to start the quiz, then we can talk.';

  @override
  String wqAiCannotAnswer(Object reason) {
    return 'The AI can\'t answer yet. $reason';
  }

  @override
  String get wqCheckInternet =>
      'Check the internet connection, then try again.';

  @override
  String get wqTryAgain => 'Try again.';

  @override
  String wqSkipped(Object n) {
    return 'Question $n skipped.';
  }

  @override
  String wqSkippedCount(Object count) {
    return ' $count questions skipped.';
  }

  @override
  String wqSessionDone(Object correct, Object total, Object skipped) {
    return 'Session done! Correct answers: $correct of $total.$skipped Scan another item for new questions.';
  }

  @override
  String get wqQuestionReady => 'Question ready';

  @override
  String get r1LinkLost => 'The robot connection dropped. The robot stopped.';

  @override
  String get r1NotConnected => 'robot not connected';

  @override
  String r1Stopped(Object reason) {
    return 'Robot stopped ($reason). Press \"Continue\" when it is safe.';
  }

  @override
  String get r1Stop => 'Stop';

  @override
  String get r1Picking => 'The robot is picking up the item';

  @override
  String get r1NotIdentified => 'The item could not be identified. Drive on.';

  @override
  String get r1NoConfirm =>
      'No confirmation. The robot did not pick up the item.';

  @override
  String get r1Timeout => 'Time is up. The robot did not pick up the item.';

  @override
  String get r1TooLong => 'The robot took too long. The robot stopped.';

  @override
  String get r1Resuming => 'The robot is carrying on';

  @override
  String get r1PickFailed => 'The item was not picked up. The robot stopped.';

  @override
  String get r1Done => 'Done! The robot can drive again.';

  @override
  String get r1ConfirmFirst => 'Confirm first';

  @override
  String get r1WhichBin => 'Which bin does it go in?';

  @override
  String r1RobotChose(Object bin) {
    return 'The robot chose: $bin';
  }

  @override
  String get r1PositionOk => 'Is the position right?';

  @override
  String get r1Forward => 'Forward a little';

  @override
  String get r1Back => 'Back up';

  @override
  String get r1PressPick => 'Press Pick up';

  @override
  String get r1Hand => 'A hand! The robot is pausing.';

  @override
  String r1NoReply(Object cmd, Object reason) {
    return 'The robot did not reply ($cmd: $reason). The robot stopped.';
  }

  @override
  String get h3Title => 'History';

  @override
  String get h3Subtitle => 'Scan results, quizzes & trophies';

  @override
  String get h3Back => 'Back';

  @override
  String get h3All => 'All';

  @override
  String get h3CatB3 => 'B3';

  @override
  String get h3CatB3Long => 'B3 · Hazardous';

  @override
  String get h3CatRecyclable => 'Recyclable';

  @override
  String get h3CatOrganic => 'Organic';

  @override
  String get h3CatResidu => 'Residual';

  @override
  String get h3Easy => 'Easy';

  @override
  String get h3Medium => 'Medium';

  @override
  String get h3Hard => 'Hard';

  @override
  String get h3Today => 'Today';

  @override
  String get h3Yesterday => 'Yesterday';

  @override
  String get h3LoadFailed => 'History couldn\'t be loaded';

  @override
  String get h3RecentScans => 'Recent scans';

  @override
  String h3ScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String get h3NoScansInCategory => 'No scans in this category yet.';

  @override
  String h3Trophies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trophies',
      one: '1 trophy',
    );
    return '$_temp0';
  }

  @override
  String h3ToNextLevel(Object count, Object level) {
    return '$count trophies to Level $level';
  }

  @override
  String get h3TopLevel => 'Top level';

  @override
  String get h3SavedLocally => 'Saved locally';

  @override
  String h3RowMeta(Object time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$time · $_temp0';
  }

  @override
  String get h3DetailTitle => 'Scan detail';

  @override
  String get h3ExportPdf => 'Export PDF';

  @override
  String get h3DetailLoadFailed => 'Scan detail couldn\'t be loaded';

  @override
  String h3ScannedMeta(Object time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return 'Scanned $time · photo and $_temp0 saved locally';
  }

  @override
  String h3DiffChip(Object level, Object count) {
    return '$level · ${count}Q';
  }

  @override
  String h3CorrectOf(Object correct, Object total) {
    return '$correct of $total correct';
  }

  @override
  String get h3TrophyRule => '10 trophies for every correct answer';

  @override
  String get h3Questions => 'Questions';

  @override
  String get h3PdfFailed => 'The PDF couldn\'t be exported. Try again.';

  @override
  String get h3Correct => 'Correct';

  @override
  String get h3Incorrect => 'Incorrect';

  @override
  String get h3AwaitingGrading => 'Awaiting grading';

  @override
  String h3EssayScore(Object score) {
    return 'Score $score/10';
  }

  @override
  String get h3YourAnswer => 'Your answer';

  @override
  String get h3CorrectAnswer => 'Correct answer';

  @override
  String get h3ReferenceAnswer => 'Reference answer';

  @override
  String get h3SeeExplanation => 'See explanation';

  @override
  String get h3Listen => 'Listen';

  @override
  String get h3Pause => 'Pause';

  @override
  String get h3ReadingNow => 'READING NOW';

  @override
  String get h3KeyIdea => 'KEY IDEA';

  @override
  String get h3TryAgain => 'Try again';

  @override
  String get h3Loading => 'Loading';

  @override
  String get h3EmptyTitle => 'No scans yet';

  @override
  String get h3EmptyBody =>
      'Scan an item with ELIOS and its quiz results and trophies will show up here.';

  @override
  String get h3StartScan => 'Start scanning';

  @override
  String get h3ExplanationTitle => 'Explanation';

  @override
  String h3ExplanationMeta(Object item, Object index, Object total) {
    return '$item · Q$index of $total';
  }

  @override
  String get h3WhyCorrect => 'Why this is the right answer';

  @override
  String get h3WhyWrong => 'Why your answer isn’t right';

  @override
  String get h3Feedback => 'Feedback';

  @override
  String get h3HowTo => 'How to do it';

  @override
  String get h3NextQuestion => 'Next question';

  @override
  String get h3ExplanationUnavailable =>
      'The full explanation isn\'t available yet';

  @override
  String h3PdfSaved(Object path) {
    return 'PDF saved: $path';
  }

  @override
  String get h3ExportQuestion => 'Export this question';

  @override
  String h3ExportOnly(Object index, Object item) {
    return 'Only Q$index of $item goes into the PDF.';
  }

  @override
  String get h3A4Pdf => 'A4 · PDF';

  @override
  String get h3Include => 'INCLUDE';

  @override
  String get h3IncAnswers => 'Question and both answers';

  @override
  String get h3IncExplanation => 'Full explanation and steps';

  @override
  String get h3IncPhoto => 'Scan photo';

  @override
  String get h3IncNotes => 'Space for my notes';

  @override
  String get h3Share => 'Share';

  @override
  String get h3SavePdf => 'Save PDF';

  @override
  String get h3Saving => 'Saving…';

  @override
  String h3ShownInOriginal(Object language) {
    return 'Shown in $language, connect to translate';
  }

  @override
  String get h3KeyIdeaTitle => 'Key idea';

  @override
  String pdfQuestionHeader(Object item, Object index) {
    return 'ELIOS | $item | Q$index';
  }

  @override
  String get pdfEssayScore => 'Essay score';

  @override
  String get pdfReportTitle => 'ELIOS - Waste Quiz Report';

  @override
  String pdfPageShort(Object page, Object total) {
    return 'Page $page / $total';
  }

  @override
  String pdfFooter(Object page, Object total, Object id) {
    return 'ELIOS Waste Sorting Education | Page $page of $total | Session ID: $id';
  }

  @override
  String get pdfSessionInfo => 'Session information';

  @override
  String get pdfPhoto => 'PHOTO';

  @override
  String get pdfItem => 'Item';

  @override
  String get pdfCategory => 'Category';

  @override
  String get pdfDateTime => 'Date / time';

  @override
  String get pdfDifficulty => 'Difficulty';

  @override
  String get pdfQuestionCount => 'Questions';

  @override
  String get pdfCorrect => 'Correct';

  @override
  String pdfCorrectOf(Object correct, Object total) {
    return '$correct of $total';
  }

  @override
  String get pdfTrophies => 'Trophies earned';

  @override
  String pdfTrophyCount(Object count) {
    return '$count trophies';
  }

  @override
  String get pdfGrade => 'Grade';

  @override
  String pdfQuestionLine(Object index, Object question) {
    return 'Q$index: $question';
  }

  @override
  String pdfEssayLine(Object score, Object trophies) {
    return '$score / 10 (+$trophies trophies)';
  }

  @override
  String get pdfNoExplanation => 'No explanation was saved for this question.';

  @override
  String pdfSource(Object title) {
    return 'Source: $title';
  }

  @override
  String get pdfBankTitle => 'ELIOS Question Bank';

  @override
  String pdfSection(Object section) {
    return 'section $section';
  }

  @override
  String pdfPage(Object page) {
    return 'p. $page';
  }

  @override
  String get pdfTableCategories => 'Table 1. Waste category comparison';

  @override
  String get pdfTableScoring => 'Table 1. Scoring breakdown';

  @override
  String get pdfColCategory => 'Category';

  @override
  String get pdfColMaterial => 'Material';

  @override
  String get pdfColAccepted => 'Accepted';

  @override
  String get pdfColCriterion => 'Criterion';

  @override
  String get pdfColMax => 'Max';

  @override
  String get pdfColAwarded => 'Awarded';

  @override
  String get pdfColComment => 'Comment';

  @override
  String a11yTrophies(Object count) {
    return '$count trophies';
  }

  @override
  String homeScanSubtitle(Object date, Object count) {
    return '$date · +$count trophies';
  }

  @override
  String a11yLabelValue(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String a11yBinStat(Object bin, Object count, Object percent) {
    return '$bin $count scans, $percent';
  }

  @override
  String get a11yTopBin => ', top bin';

  @override
  String get homeScansUnit => ' scans';

  @override
  String homeMedalsOf(Object unlocked, Object total) {
    return '$unlocked of $total';
  }

  @override
  String a11yMedal(Object name, Object state, Object description) {
    return '$name, $state. $description';
  }

  @override
  String get a11yUnlocked => 'unlocked';

  @override
  String get a11yLocked => 'locked';

  @override
  String a11ySearchItem(Object title, Object subtitle) {
    return '$title, $subtitle';
  }

  @override
  String learnQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String learnMinutes(Object count) {
    return '$count min';
  }

  @override
  String learnLessonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String a11yPercent(Object title, Object percent) {
    return '$title, $percent percent';
  }

  @override
  String get tipWaiting =>
      'Hang on, I\'m looking for the robot! If it takes long, check the ELIOS Wi-Fi.';

  @override
  String get tipDisconnected =>
      'Uh-oh, I can\'t hear the robot. Walk closer to it or check that it\'s switched on.';

  @override
  String get tipStopped =>
      'The robot is STOPPED. Check the way is clear, then tap Continue.';

  @override
  String get tipQuiz => 'Quiz time! Answer it, then we sort the item together.';

  @override
  String get tipDrive =>
      'Drive around slowly and point my camera at an item to sort.';

  @override
  String tipPickZone(Object item) {
    return 'Nice driving! The $item is in the pick zone. Press PICK UP to grab it.';
  }

  @override
  String tipLocked(Object item) {
    return 'Got it! I locked on the $item. Hold still while I look.';
  }

  @override
  String tipSeeItem(Object item) {
    return 'I see a $item. Drive closer, slowly.';
  }

  @override
  String ctlPlusTrophies(Object count) {
    return '+$count trophies';
  }

  @override
  String get guideReady => 'You\'re ready, Robot Pilot!';

  @override
  String get guideGo => 'Let\'s go!';

  @override
  String get qzElapsed => 'elapsed';

  @override
  String qzWordCount(Object words, Object limit) {
    return '$words / $limit words';
  }

  @override
  String wqCorrectOf(Object correct, Object total) {
    return '$correct of $total correct';
  }

  @override
  String get cfgCouldNotReach => 'Couldn\'t reach ELIOS';

  @override
  String get cfgIpAddress => 'IP address';

  @override
  String camMacFailed(Object error) {
    return 'The Mac camera couldn\'t be opened ($error).';
  }

  @override
  String get catExamplesOrganic =>
      'Food scraps; Leftover cooked food; Coffee grounds and tea bags; Grass clippings and leaves; Eggshells';

  @override
  String get catExamplesInorganic =>
      'Plastic bottles and containers; Glass jars and bottles; Aluminium cans and foil; Paper and cardboard; Metal scraps';

  @override
  String get catExamplesHazardous =>
      'Batteries; Electronic waste; Fluorescent light bulbs; Paint and solvents; Pesticides and herbicides';

  @override
  String get authNoUser => 'No account found for that username.';

  @override
  String get notifVideoDone => 'Video completed';

  @override
  String get notifVideoDoneMsg => 'You completed a video lesson.';

  @override
  String get notifGuideDone => 'Guide completed';

  @override
  String get notifGuideDoneMsg => 'You completed a guide.';

  @override
  String get notifQuizDone => 'Quiz completed';

  @override
  String get notifQuizDoneMsg => 'Your quiz result has been saved.';

  @override
  String get notifReview => 'Quiz review available';

  @override
  String get notifReviewMsg => 'You can now review your quiz answers.';

  @override
  String get notifSync => 'Progress sync issue';

  @override
  String get notifSyncMsg =>
      'Your progress could not be synced. Check your connection.';

  @override
  String get physDensityTag => 'Module A · Environment';

  @override
  String get physDensityTitle => 'Waste Density';

  @override
  String get physDensityDesc => 'ELIOS sorts inorganic waste by density.';

  @override
  String get physHeatTag => 'Module B · Environment';

  @override
  String get physHeatTitle => 'Compost Heat & Thermodynamics';

  @override
  String get physHeatDesc =>
      'Microbes decomposing waste release heat over time.';

  @override
  String get physTorqueTag => 'Module C · Mechanics';

  @override
  String get physTorqueTitle => 'Robot Shoulder Torque';

  @override
  String get physTorqueDesc =>
      'The ELIOS shoulder joint holds torque as the arm reaches out.';

  @override
  String get physWorkEnergyTag => 'Module D · Mechanics';

  @override
  String get physWorkEnergyTitle => 'Work & Potential Energy';

  @override
  String get physWorkEnergyDesc =>
      'Lifting a load takes a measurable amount of work.';

  @override
  String get physKinematicsTag => 'Module E · Kinematics';

  @override
  String get physKinematicsTitle => 'ELIOS Speed';

  @override
  String get physKinematicsDesc =>
      'Uniform straight-line motion towards the waste pile.';

  @override
  String get physPwmTag => 'Module F · Electronics';

  @override
  String get physPwmTitle => 'PWM & Motor Voltage';

  @override
  String get physPwmDesc =>
      'The duty cycle sets the average voltage of the wheel motors.';

  @override
  String get physPowerTag => 'Module G · Power';

  @override
  String get physPowerTitle => 'ELIOS Power & Battery';

  @override
  String get physPowerDesc => 'Managing how much power the robot parts use.';

  @override
  String get physDeepDiveTag => 'Deep-Dive · Waste Physics';

  @override
  String get physDeepDiveTitle => 'Waste Deep-Dive Cards';

  @override
  String get physDeepDiveDesc => 'A closer look: organic, inorganic and B3.';

  @override
  String get physQuizTag => 'Evaluation';

  @override
  String get physQuizTitle => 'Check Your Understanding (Quiz)';

  @override
  String get physQuizDesc =>
      'Test what you know about the physics behind the ELIOS robot.';

  @override
  String get physLevelBeginner => 'Beginner';

  @override
  String get physLevelIntermediate => 'Intermediate';

  @override
  String get physLevelAdvanced => 'Advanced';

  @override
  String get physLevelAllLevels => 'All levels';

  @override
  String get simDeepDive1 => 'Waste Deep-Dive';

  @override
  String get simDeepDive2 => 'The Physics of Sorting Waste';

  @override
  String get simDeepDive3 =>
      'Explore why each waste category is handled differently.';

  @override
  String get simDeepDive4 => 'Pile Porosity';

  @override
  String get simDeepDive5 =>
      'Low porosity (<25%). Air can hardly get in, which triggers anaerobic decomposition (methane).';

  @override
  String get simDeepDive6 =>
      'Good porosity. Oxygen flows freely and aerobic composting works best.';

  @override
  String get simDeepDive7 =>
      'Porosity is the percentage of empty space (filled with air) between the solid particles in a compost pile. High porosity = air can flow freely through the whole pile = the aerobic process (which needs oxygen) runs well. Low porosity = the pile is too dense = oxygen runs out quickly inside = anaerobic microbes take over.';

  @override
  String get simDeepDive8 =>
      'Organic waste has no electrical (conductivity), optical (NIR reflectance) or hazardous chemical (volatility/reactivity) property that could be used as an automatic sorting signal. The only relevant physical variable is its own pore structure and moisture, because the goal is not to separate materials but to manage the biological breakdown itself.';

  @override
  String get simDeepDive9 =>
      'ELIOS uses this principle in its spring-loaded gripper/pusher to test how hard or elastic an item is.';

  @override
  String get simDeepDive10 => 'Compression (x)';

  @override
  String get simDeepDive11 =>
      '⚠ Accuracy note: the peak wavelengths used in this simulation (e.g. PET ≈1660 nm, HDPE ≈1730 nm, PP ≈1410 nm) must be checked again against a valid industrial NIR sorting reference before release. Real NIR sensors measure absorbance peaks/valleys over ranges that can vary.';

  @override
  String get simDeepDive12 =>
      'When metal moves through a changing magnetic field, eddy currents are induced inside it. They create an opposing magnetic field that pushes non-magnetic metals such as aluminium away from the magnet.';

  @override
  String get simDeepDive13 =>
      'Inorganic materials (plastic, glass, metal) go through no biological process that needs managing (unlike organic waste), and most are not chemically reactive or hazardous (unlike B3). The most effective sorting signals are their stable physical properties: hardness (Hooke), optical identity (NIR) and magnetic/conductive behaviour (eddy currents).';

  @override
  String get simDeepDive14 =>
      'The hotter a liquid or substance is, the more it tends to evaporate into a gas: this is vapour pressure. The Clausius-Clapeyron equation describes this non-linear (exponential) relationship.';

  @override
  String get simDeepDive15 =>
      '⚠ Accuracy note: this simulation uses a qualitative, simplified approach, not a literal P–T curve with scientifically precise exponential constants. It only shows the trend (hotter = evaporates more easily = more dangerous).';

  @override
  String get simDeepDive16 => 'Substance temperature';

  @override
  String get simDeepDive17 => 'Incinerator temperature';

  @override
  String get simDeepDive18 => 'Status: hazardous chemical bonds broken (safe)';

  @override
  String get simDeepDive19 =>
      'Radiation intensity (I) drops exponentially as the shield thickness (x) increases.';

  @override
  String get simDeepDive20 =>
      '⚠ Accuracy note: real attenuation coefficients depend strongly on the energy of the radiation particles (MeV) and on the specific shield material. The numbers below are illustrative and only show the relative order (gamma hardest, alpha easiest).';

  @override
  String get simDeepDive21 => 'Alpha (α)';

  @override
  String get simDeepDive22 => 'Shield thickness (x)';

  @override
  String get simDeepDive23 =>
      'The key difference is not the physical material (B3 can be metal, liquid or any solid) but its hidden danger: chemical volatility, radioactivity or thermal reactivity that can harm people or the environment if it is handled like ordinary waste. So \"sorting\" here is not about separating materials but about safe containment and handling: shielding, controlled temperature and early identification before direct contact.';

  @override
  String get simDensity1 => 'Density & Classification';

  @override
  String get simDensity2 => 'MODULE A · LESSON';

  @override
  String get simDensity3 =>
      'Items with different densities are sorted into the matching category.';

  @override
  String get simDensity4 => 'DENSITY FORMULA';

  @override
  String get simDensity5 => 'm = mass · V = volume';

  @override
  String get simDensity6 => 'Move the sliders to see the item change';

  @override
  String get simDensity7 => 'Mass (m)';

  @override
  String get simDensity8 => 'CLASSIFICATION RESULT';

  @override
  String get simDensity9 => 'Unknown material';

  @override
  String get simDensity10 =>
      'Density outside the database range (not a known plastic, glass or metal).';

  @override
  String get simDensity11 => 'Choose a bin:';

  @override
  String get simDensity12 => 'Plastic';

  @override
  String get simDensity13 => 'Glass';

  @override
  String get simDensity14 => 'Metal';

  @override
  String get simDensity15 => 'Module A — Density & Waste Classification';

  @override
  String get simDensity16 =>
      'Density is a measure of how \"tightly packed\" matter is inside an object. Two objects can have the same size (volume) but very different weights, because their particles are packed differently. Iron feels heavy in your hand not because there is \"more\" iron, but because its atoms are packed more tightly per unit of space than, say, plastic.\n\nThis matters for ELIOS because density is one of the cheapest and fastest signals for guessing a material, far cheaper than, for example, analysing the infrared spectrum of every item.';

  @override
  String get simDensity17 =>
      'ρ = m / V (density = mass / volume). Pure water has ρ = 1.0 g/cm³ as the reference point.';

  @override
  String get simDensity18 =>
      'A common mistake swaps m and V into V/m, which changes the result drastically. Density is mass per volume.';

  @override
  String get simDensity19 => 'Plastic (0.9 - 1.4 g/cm³)';

  @override
  String get simDensity20 => 'Glass (2.4 - 2.6 g/cm³)';

  @override
  String get simDensity21 => 'Metal (≥ 2.7 g/cm³)';

  @override
  String get simDensity22 => 'Unknown';

  @override
  String get simHeat1 => 'Heat & Thermodynamics';

  @override
  String get simHeat2 => 'MODULE B · LESSON';

  @override
  String get simHeat3 => 'Heat & Composting Thermodynamics';

  @override
  String get simHeat4 => 'HEAT FORMULA (Q)';

  @override
  String get simHeat5 => 'm = mass · c = 4000 J/kg°C · ΔT = temperature change';

  @override
  String get simHeat6 => 'Particles represent microbial activity';

  @override
  String get simHeat7 => 'Temperature change (ΔT)';

  @override
  String get simHeat8 => 'Porosity (cross-module)';

  @override
  String get simHeat9 => 'PHASE RESULT';

  @override
  String get simHeat10 =>
      'Thermophilic phase: heat-loving bacteria work best and pathogens start to die.';

  @override
  String get simHeat11 => 'Module B — Heat & Composting Thermodynamics';

  @override
  String get simHeat12 =>
      'When microorganisms in a compost pile break down organic waste, they release energy as heat: a biological exothermic process. The pile warms up not because of fire or electricity, but because of the metabolism of millions of bacteria and fungi breaking organic molecules apart.\n\nThis module models how much heat a mass of compost has to absorb or release for a given temperature change, and links it to the real biological phases of composting.';

  @override
  String get simHeat13 => 'Mesophilic (< 55°C)';

  @override
  String get simHeat14 => 'Thermophilic (55 - 60°C)';

  @override
  String get simHeat15 => 'Too hot (> 60°C)';

  @override
  String get simKinematics1 => 'Kinematics';

  @override
  String get simKinematics2 => 'MODULE E · LESSON';

  @override
  String get simKinematics3 => 'Kinematics (uniform & accelerated motion)';

  @override
  String get simKinematics4 =>
      'How long does ELIOS take to reach the target? Link distance, speed and time.';

  @override
  String get simKinematics5 => 'TIME FORMULA (uniform motion)';

  @override
  String get simKinematics6 => 't = time · s = distance · v = constant speed';

  @override
  String get simKinematics7 => 'Target distance (s)';

  @override
  String get simKinematics8 => 'Speed (v)';

  @override
  String get simKinematics9 => 'PREDICTION';

  @override
  String get simKinematics10 => 'Estimated time of arrival (ETA)';

  @override
  String get simKinematics11 =>
      'Uniformly accelerated motion involves acceleration (a). In the real world ELIOS does not jump straight to full speed: the motor needs time (less than 1 second) to speed up from standstill to constant speed.\n\nFormula: s = v₀·t + ½·a·t²\n\nBecause ELIOS accelerates very quickly, the acceleration distance is tiny and is usually ignored for indoor navigation. But if an obstacle appears suddenly, the ELIOS emergency brake uses deceleration (negative acceleration) calculated with the same formula.';

  @override
  String get simKinematics12 => 'Module E — Kinematics';

  @override
  String get simKinematics13 =>
      'When ELIOS is sent to a waste collection point, its navigation system (Local Planner) has to know how far away it is and how long it will take to get there at a given speed. This is pure basic kinematics: the part of physics that studies motion without caring what causes it (force/mass).\n\nThis module models ELIOS moving in uniform straight-line motion.';

  @override
  String get simKinematics14 =>
      'Bonus, accelerated motion: in the real world the ELIOS motor needs time to accelerate (s = v₀·t + ½·a·t²). But because ELIOS accelerates very quickly, uniform motion is accurate enough to compute the ETA.';

  @override
  String get simKinematics15 =>
      'A common mistake when computing t is multiplying s and v (s·v) instead of dividing (s/v). The unit of s·v is m²/s, which makes no sense. Always check the final unit (m / (m/s) = s).';

  @override
  String get simDensityPainter1 => 'Reference';

  @override
  String get simDensityPainter2 => 'Object';

  @override
  String get simTorquePainter1 => 'TORQUE';

  @override
  String get simPowerBudget1 => 'Power & Battery Budget';

  @override
  String get simPowerBudget2 => 'MODULE G · LESSON';

  @override
  String get simPowerBudget3 => 'POWER & ENERGY FORMULA';

  @override
  String get simPowerBudget4 => 'Scenario presets:';

  @override
  String get simPowerBudget5 => 'Usage time (t)';

  @override
  String get simPowerBudget6 => 'BATTERY LIFE PREDICTION';

  @override
  String get simPowerBudget7 => 'Module G — Power & Battery Budget';

  @override
  String get simPowerBudget8 =>
      'Every ELIOS part that is switched on (camera, drive motors, arm motor) draws power from the same battery. This module shows how to work out how long the battery lasts depending on which parts are active, a decision the ELIOS control system really makes in real time to save power.\n\nThe real power-saving behaviour of ELIOS follows this logic directly: the drive motors are switched off while sorting (the robot stands still), and the camera is switched off while moving when it is not analysing an object. Every watt that does not need to be on means extra seconds of operation before the battery needs recharging.';

  @override
  String get simPowerBudget9 =>
      'P = V · I (power = voltage × current). Here the power (P) of each part is already given.';

  @override
  String get simPowerBudget10 => 'E = P · t (energy = total power × time).';

  @override
  String get simPowerBudget11 =>
      'Total capacity = 50,000 joules. t_estimate = 50,000 / P_total.';

  @override
  String get simPowerBudget12 =>
      'Camera 10 W, drive motors 36 W, arm motor 18 W.';

  @override
  String get simPwm1 => 'PWM & Motor';

  @override
  String get simPwm2 => 'MODULE F · LESSON';

  @override
  String get simPwm3 => 'PWM & Effective Voltage';

  @override
  String get simPwm4 => 'EFFECTIVE AVERAGE VOLTAGE';

  @override
  String get simPwm5 => 'Square wave (PWM signal)';

  @override
  String get simPwm6 => 'MOTOR VOLTAGE';

  @override
  String get simPwm7 => 'Module F — PWM & Effective Motor Voltage';

  @override
  String get simPwm8 =>
      'V_avg = D · V_max (effective average voltage = duty cycle × maximum voltage).';

  @override
  String get simPwm9 =>
      'D (duty cycle) is the percentage of time the signal is \"on\" in one period.';

  @override
  String get simPwm10 =>
      'Linear model limits (important): the RPM estimate in this simulation is a linear approximation. On a real motor, the link between duty cycle and actual RPM is not fully linear once the motor carries a torque load.';

  @override
  String get simPwm11 =>
      'The claim \"lower average voltage = proportionally lower average current\" is ONLY TRUE FOR A PURELY RESISTIVE LOAD. In a motor (inductive + mechanical load) the current does not follow the voltage in a simple linear way.';

  @override
  String get simTorque1 => 'Robot Shoulder Torque';

  @override
  String get simTorque2 => 'MODULE C · MECHANICS';

  @override
  String get simTorque3 => 'TORQUE FORMULA';

  @override
  String get simTorque4 => 'r = arm length · F = load · θ = angle';

  @override
  String get simTorque5 => 'Drag the arm handle to change r & θ';

  @override
  String get simTorque6 => 'Arm length (r)';

  @override
  String get simTorque7 => 'Load (F)';

  @override
  String get simTorque8 => 'Angle (θ)';

  @override
  String get simTorque9 => 'INSTANT TORQUE';

  @override
  String get simTorque10 => 'CHALLENGE';

  @override
  String get simTorque11 => 'Lesson: torque (moment of force)';

  @override
  String get simSimCanvasFrame1 => '⚠ TIP-OVER RISK';

  @override
  String get simSimulationPageScaffold1 => 'Lesson';

  @override
  String get simWorkEnergy1 => 'Work & Energy';

  @override
  String get simWorkEnergy2 => 'MODULE D · LESSON';

  @override
  String get simWorkEnergy3 => 'Work & Potential Energy';

  @override
  String get simWorkEnergy4 =>
      'Every lift turns battery energy into gravitational potential energy.';

  @override
  String get simWorkEnergy5 => 'WORK FORMULA (W)';

  @override
  String get simWorkEnergy6 => 'm = mass · g = 10 m/s² · h = height';

  @override
  String get simWorkEnergy7 => 'Change the height and load to see the effect';

  @override
  String get simWorkEnergy8 => 'Load mass (m)';

  @override
  String get simWorkEnergy9 => 'Height (h)';

  @override
  String get simWorkEnergy10 => 'RESULT';

  @override
  String get simWorkEnergy11 =>
      'Module D — Work & Gravitational Potential Energy';

  @override
  String get simWorkEnergy12 =>
      'Every time ELIOS lifts waste from the tray into a higher container, it does work against gravity. This work is stored as gravitational potential energy in the lifted item: energy that is \"ready to be released\" if the item is dropped again.\n\nThis is not just an abstract idea: every joule of work the ELIOS arm motor does comes from the battery, so this module directly explains why lifting heavy loads more often and higher = the ELIOS battery runs out faster.';

  @override
  String get simDeepDive24 =>
      '• Fick\'s law (diffusion): the rate at which oxygen moves into the pile is proportional to the area of the pore paths and inversely proportional to the distance travelled; a dense pile = longer, narrower diffusion paths = oxygen gets in much more slowly.\n';

  @override
  String get simDeepDive25 =>
      '• Heat conduction, Q/t = kAΔT/L: the heat microbes produce in the core of the pile travels outwards by conduction; a dense pile also slows this down, which raises the risk of overheating (see Module B).\n';

  @override
  String get simDeepDive26 =>
      '• Jurin\'s law (capillarity): explains how moisture rises or stays between small particles, which affects how \"wet\" the pores remain over time.';

  @override
  String get simDeepDive27 =>
      'Each type of plastic absorbs and reflects near-infrared light at its own characteristic wavelengths, forming a kind of \"optical fingerprint\".';

  @override
  String get simDeepDive28 =>
      'Incinerating hazardous materials needs much higher temperatures than burning ordinary waste, to break the chemical bonds of toxic molecules (for example persistent organic compounds). The 1000°C threshold here illustrates the thermal decomposition point.';

  @override
  String get simDeepDive29 => 'Status: bonds still intact (hazardous)';

  @override
  String get simDensity23 =>
      'Ranges: plastic (0.9–1.4), glass (2.4–2.6), metal (≥ 2.7).';

  @override
  String get simDensity24 =>
      'Plastics with ρ < 1.0 (HDPE, PP) float in water. Plastics with ρ > 1.0 (PET, PVC) sink. This is a real flotation sorting technique used in industry!';

  @override
  String get simHeat16 =>
      'Heat from microbial activity changes the temperature of the compost pile. Watch its phase.';

  @override
  String get simHeat17 =>
      'Warning: anaerobic, methane risk. Low porosity (<25%) and high temperature (>55°C).';

  @override
  String get simHeat18 => 'Overheated: too hot! Microbial activity slows down.';

  @override
  String get simHeat19 =>
      'Q = m · c · ΔT (heat = mass × specific heat × temperature change).';

  @override
  String get simHeat20 =>
      'Mesophilic phase (< 55°C): medium-temperature bacteria start breaking down simple sugars and proteins.';

  @override
  String get simHeat21 =>
      'Thermophilic phase (55–60°C): heat-loving bacteria dominate; this phase kills pathogens and weed seeds.';

  @override
  String get simHeat22 =>
      'Overheated (> 60°C): microbial activity slows or stops; turn the pile to release heat.';

  @override
  String get simHeat23 =>
      'Link with porosity: when porosity is < 25% AND the temperature is > 55°C, the pile can turn anaerobic (no oxygen left). Anaerobic microbes take over and produce methane (CH₄), a dangerous gas.';

  @override
  String get simKinematics16 => 'Uniform straight-line motion';

  @override
  String get simKinematics17 =>
      'Uniform motion: constant speed (v), no acceleration (a = 0).';

  @override
  String get simKinematics18 =>
      'v = s / t, so t = s / v (time = distance divided by speed).';

  @override
  String get simPowerBudget13 =>
      'How long does the battery last? It depends on which parts are switched on.';

  @override
  String get simPowerBudget14 =>
      'If P_total = 0, the runtime is mathematically infinite (∞).';

  @override
  String get simPwm12 =>
      'Control the ELIOS motor speed without wasting energy as heat in a resistor.';

  @override
  String get simPwm13 =>
      'The DC motors in ELIOS (for example the wheel or arm motors) are not always given full voltage all the time. To control motor speed without wasting energy as heat, ELIOS uses PWM (pulse width modulation): it switches the full voltage on and off very quickly (hundreds to thousands of times per second) and sets what share of each cycle the voltage is on.\n\nThe old way to control motor speed was a resistive voltage divider (resistor/potentiometer) that lowers the voltage directly. The problem is that the extra energy is wasted as heat in the resistor: energy is lost and parts get hot.\n\nPWM never really \"lowers\" the voltage: it only switches the full voltage on and off very fast. Because the motor has mechanical inertia and coil inductance that smooth this on/off \"twitching\" into steady motion, the result feels like a lower voltage, but without wasting energy as resistive heat; only much smaller switching losses.';

  @override
  String get simPwm14 =>
      'A 60% duty cycle means fully on 60% of the time and off for the other 40%. The average is 7.2 V of the 12 V maximum.';

  @override
  String get simTorque12 =>
      'When ELIOS reaches out its arm, the shoulder joint holds more torque.';

  @override
  String get simTorque13 => 'Torque above 8 N·m: the robot could tip over!';

  @override
  String get simTorque14 =>
      'θ = 90°: maximum torque, the arm is perpendicular to the force.';

  @override
  String get simTorque15 =>
      'θ = 0° or 180°: zero torque, the force is parallel to the arm.';

  @override
  String get simTorque16 =>
      'Large r: more torque, but the robot is harder to keep stable.';

  @override
  String get simWorkEnergy13 =>
      'W = E_p = m · g · h (work = potential energy = mass × gravity × height).';

  @override
  String get simWorkEnergy14 =>
      'g (gravity) is rounded to 10 m/s² to keep the maths simple.';

  @override
  String simPwmMotorGets(Object volts) {
    return 'The motor gets the equivalent of $volts V';
  }

  @override
  String simDensityMaterial(Object name) {
    return 'Material: $name';
  }

  @override
  String simPowerLegend(Object watts) {
    return 'P_total = $watts W · t = time (seconds)';
  }

  @override
  String simPowerEstimate(Object watts, Object runtime) {
    return 't_estimate = 50000 J / $watts W = $runtime';
  }

  @override
  String simPowerLasts(Object runtime) {
    return 'Lasts $runtime';
  }

  @override
  String simWorkBatteryLeft(Object percent) {
    return 'Battery left: $percent%';
  }

  @override
  String simTorqueMotorStatus(Object status) {
    return 'Motor: $status · safe limit 8 N·m';
  }

  @override
  String get simTorqueSafe => 'SAFE';

  @override
  String get simTorqueWarning => 'CAUTION';

  @override
  String get simTorqueCritical => 'CRITICAL';

  @override
  String simTorqueChallenge(Object r) {
    return 'Find the heaviest load ELIOS can lift when r = $r m and θ = 90° with a torque limit of 8 N·m.\nAnswer: F = τ/(r·sinθ) = 8 / $r = 16 N';
  }

  @override
  String get simTorqueBody =>
      'Torque (τ) measures how effectively a force turns an object around a pivot. Torque depends on the moment arm and on the angle between the arm and the direction of the force.';

  @override
  String simKinArrival(Object distance, Object speed, Object time) {
    return 'Arrival time = $distance / $speed = $time seconds';
  }

  @override
  String simHeatFinal(Object delta, Object result) {
    return 'Final temperature = 25°C + $delta°C = $result°C';
  }

  @override
  String physQDensity(Object m, Object v) {
    return 'A sample of inorganic waste has a mass of $m g and a volume of $v cm³. What is its density?';
  }

  @override
  String physQHeat(Object m, Object dt, Object c) {
    return 'A compost pile with a mass of $m kg warms up by $dt °C. If the specific heat (c) of compost is $c J/kg°C, how much heat (Q) did the microbes produce?';
  }

  @override
  String physQTorque(Object r, Object f, Object theta) {
    return 'The robot arm reaches out $r m and lifts a load with a force of $f N at an angle of $theta° to the arm. How large is the torque at the shoulder joint?';
  }

  @override
  String physQWork(Object m, Object h) {
    return 'ELIOS lifts a $m kg load to a height of $h m. How much work does it do against gravity (g = 10 m/s²)?';
  }

  @override
  String physQSpeed(Object s, Object t) {
    return 'ELIOS drives $s metres in a straight line in $t seconds towards the target. What is its average speed?';
  }

  @override
  String physQPwm(Object d, Object vmax) {
    return 'A PWM signal sets the motor voltage with a duty cycle (D) of $d%. If the maximum battery voltage is $vmax V, what is the average motor voltage?';
  }

  @override
  String physQPower(Object i, Object v) {
    return 'A subsystem draws $i A from a $v V battery. How much power does it use?';
  }
}
