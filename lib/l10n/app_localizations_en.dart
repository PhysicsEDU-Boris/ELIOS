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

  @override
  String get cfgIpHint => 'Enter an IP like 192.168.4.1';

  @override
  String get cfgPortRange => 'Port 1 to 65535';

  @override
  String cfgFoundAt(Object ip) {
    return 'Found ELIO at $ip';
  }

  @override
  String get cfgNotFound => 'ELIO not found on this Wi-Fi';

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
  String get cfgWsAddress => 'ELIO WebSocket address';

  @override
  String get cfgPort => 'Port';

  @override
  String get cfgSearching => 'Searching…';

  @override
  String get cfgFindElio => 'Find ELIO';

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
  String get cfgRobotModel => 'ELIO robot 3D model, drag to rotate';

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
  String get setAutoReconnectSub => 'Reconnect when ELIO is available again';

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
  String get ctlElioSays => 'ELIO SAYS';

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
      'Test your understanding of waste management and how ELIO classifies materials. Each quiz has one attempt.';

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
}
