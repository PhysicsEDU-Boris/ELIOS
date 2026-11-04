import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// The name of this language, written in this language itself (e.g. "Français" for French).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// Sidebar label for the app language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sidebarLanguage;

  /// No description provided for @sidebarGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get sidebarGuestUser;

  /// No description provided for @sidebarLocalSession.
  ///
  /// In en, this message translates to:
  /// **'Local session'**
  String get sidebarLocalSession;

  /// No description provided for @sidebarClose.
  ///
  /// In en, this message translates to:
  /// **'Close sidebar'**
  String get sidebarClose;

  /// No description provided for @sidebarNavigate.
  ///
  /// In en, this message translates to:
  /// **'NAVIGATE'**
  String get sidebarNavigate;

  /// No description provided for @sidebarHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get sidebarHome;

  /// No description provided for @sidebarLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get sidebarLearn;

  /// No description provided for @sidebarLearnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Waste types & quizzes'**
  String get sidebarLearnSubtitle;

  /// No description provided for @sidebarConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get sidebarConfigure;

  /// No description provided for @sidebarConfigureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Setup ESP32 WebSocket'**
  String get sidebarConfigureSubtitle;

  /// No description provided for @sidebarControl.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get sidebarControl;

  /// No description provided for @sidebarControlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drive robot & Camera'**
  String get sidebarControlSubtitle;

  /// No description provided for @sidebarGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'GUEST'**
  String get sidebarGuestBadge;

  /// No description provided for @sidebarDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get sidebarDarkMode;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @leaveQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave quiz?'**
  String get leaveQuizTitle;

  /// No description provided for @leaveQuiz.
  ///
  /// In en, this message translates to:
  /// **'Leave Quiz'**
  String get leaveQuiz;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not take the photo: {error}'**
  String photoFailed(Object error);

  /// No description provided for @homeScanActivity.
  ///
  /// In en, this message translates to:
  /// **'Scan activity'**
  String get homeScanActivity;

  /// No description provided for @homeFirstScanToday.
  ///
  /// In en, this message translates to:
  /// **'Your first scan lights up today'**
  String get homeFirstScanToday;

  /// No description provided for @homeScanItem.
  ///
  /// In en, this message translates to:
  /// **'Scan an item'**
  String get homeScanItem;

  /// No description provided for @homeTrophies.
  ///
  /// In en, this message translates to:
  /// **'{count} trophies'**
  String homeTrophies(Object count);

  /// No description provided for @homeDailyQuests.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get homeDailyQuests;

  /// No description provided for @homeBinBuddies.
  ///
  /// In en, this message translates to:
  /// **'Bin buddies'**
  String get homeBinBuddies;

  /// No description provided for @homeThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get homeThisWeek;

  /// No description provided for @homeQuizAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Quiz accuracy'**
  String get homeQuizAccuracy;

  /// No description provided for @homeMedals.
  ///
  /// In en, this message translates to:
  /// **'Medals'**
  String get homeMedals;

  /// No description provided for @homeDidYouKnow.
  ///
  /// In en, this message translates to:
  /// **'DID YOU KNOW?'**
  String get homeDidYouKnow;

  /// No description provided for @historyBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back to list'**
  String get historyBackToList;

  /// No description provided for @historyPhoto.
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get historyPhoto;

  /// No description provided for @historyAddSampleData.
  ///
  /// In en, this message translates to:
  /// **'Add Sample Data (Debug)'**
  String get historyAddSampleData;

  /// No description provided for @pdfExported.
  ///
  /// In en, this message translates to:
  /// **'PDF report exported'**
  String get pdfExported;

  /// No description provided for @pdfExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export PDF: {error}'**
  String pdfExportFailed(Object error);

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @moduleProgress.
  ///
  /// In en, this message translates to:
  /// **'Module progress'**
  String get moduleProgress;

  /// Gripper fully open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get controlGripOpen;

  /// Gripper fully closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get controlGripClosed;

  /// Robot arm base joint.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get controlBase;

  /// Button that moves the robot arm to its home position.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get controlHome;

  /// No description provided for @controlR1Status.
  ///
  /// In en, this message translates to:
  /// **'R1: {status}'**
  String controlR1Status(Object status);

  /// No description provided for @controlCheckingRobot.
  ///
  /// In en, this message translates to:
  /// **'checking robot...'**
  String get controlCheckingRobot;

  /// No description provided for @controlPhoneScan.
  ///
  /// In en, this message translates to:
  /// **'Scan with phone camera'**
  String get controlPhoneScan;

  /// No description provided for @configConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get configConnectionFailed;

  /// No description provided for @configPhoneOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'The robot is not used. Point the phone at one item and tap Start scan.'**
  String get configPhoneOnlyHint;

  /// No description provided for @configSameWifiHint.
  ///
  /// In en, this message translates to:
  /// **'Put ELIO and this phone on the same Wi-Fi or hotspot, then tap Connect now.'**
  String get configSameWifiHint;

  /// No description provided for @configSaveDefault.
  ///
  /// In en, this message translates to:
  /// **'Save as default config'**
  String get configSaveDefault;

  /// No description provided for @configUseAddressNextTime.
  ///
  /// In en, this message translates to:
  /// **'Use this address next time'**
  String get configUseAddressNextTime;

  /// No description provided for @configDragToRotate.
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate'**
  String get configDragToRotate;

  /// No description provided for @configLookingForElio.
  ///
  /// In en, this message translates to:
  /// **'Looking for ELIO…'**
  String get configLookingForElio;

  /// No description provided for @guidePdfUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Guide PDF is not available yet.'**
  String get guidePdfUnavailable;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video is not available yet.'**
  String get videoUnavailable;

  /// No description provided for @simulationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} is coming soon.'**
  String simulationComingSoon(Object title);

  /// No description provided for @quizStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz?'**
  String get quizStartTitle;

  /// No description provided for @quizNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get quizNotNow;

  /// No description provided for @quizStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get quizStart;

  /// No description provided for @quizFinishFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish quiz first'**
  String get quizFinishFirst;

  /// No description provided for @quizContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Quiz'**
  String get quizContinue;

  /// No description provided for @quizKnowledgeChallenge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge challenge'**
  String get quizKnowledgeChallenge;

  /// No description provided for @quizFinishToExit.
  ///
  /// In en, this message translates to:
  /// **'Finish quiz to exit'**
  String get quizFinishToExit;

  /// Physics: work, symbol W.
  ///
  /// In en, this message translates to:
  /// **'Work (W)'**
  String get simWork;

  /// No description provided for @simBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get simBattery;

  /// No description provided for @simLiveTimer.
  ///
  /// In en, this message translates to:
  /// **'Live Timer:'**
  String get simLiveTimer;

  /// No description provided for @simRun.
  ///
  /// In en, this message translates to:
  /// **'RUN'**
  String get simRun;

  /// No description provided for @simBonusUam.
  ///
  /// In en, this message translates to:
  /// **'Bonus: What about uniformly accelerated motion?'**
  String get simBonusUam;

  /// No description provided for @simSortMode.
  ///
  /// In en, this message translates to:
  /// **'Sort Mode'**
  String get simSortMode;

  /// No description provided for @simExploreMode.
  ///
  /// In en, this message translates to:
  /// **'Explore Mode'**
  String get simExploreMode;

  /// No description provided for @simIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get simIdle;

  /// No description provided for @simCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera (10W)'**
  String get simCamera;

  /// No description provided for @simDriveMotor.
  ///
  /// In en, this message translates to:
  /// **'Drive Motor (36W)'**
  String get simDriveMotor;

  /// No description provided for @simArmMotor.
  ///
  /// In en, this message translates to:
  /// **'Arm Motor (18W)'**
  String get simArmMotor;

  /// No description provided for @simBatteryLeft.
  ///
  /// In en, this message translates to:
  /// **'Battery Left'**
  String get simBatteryLeft;

  /// No description provided for @simMotorSpeed.
  ///
  /// In en, this message translates to:
  /// **'Motor Speed (RPM)'**
  String get simMotorSpeed;

  /// No description provided for @simLinearEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate (linear approximation)'**
  String get simLinearEstimate;

  /// No description provided for @deepOrganicCard.
  ///
  /// In en, this message translates to:
  /// **'Organic Card — Porosity & Oxygen Flow'**
  String get deepOrganicCard;

  /// No description provided for @deepInorganicCard.
  ///
  /// In en, this message translates to:
  /// **'Inorganic Card — Hooke, NIR, & Eddy Current'**
  String get deepInorganicCard;

  /// B3 = Indonesian hazardous-waste category; keep "B3".
  ///
  /// In en, this message translates to:
  /// **'B3 Card — Vapor Pressure, Incinerator, Radiation'**
  String get deepB3Card;

  /// No description provided for @deepCoreConcept.
  ///
  /// In en, this message translates to:
  /// **'Core Concept'**
  String get deepCoreConcept;

  /// No description provided for @deepKeyPhysics.
  ///
  /// In en, this message translates to:
  /// **'Key Physics'**
  String get deepKeyPhysics;

  /// No description provided for @deepWhyDifferent.
  ///
  /// In en, this message translates to:
  /// **'Why is the treatment different?'**
  String get deepWhyDifferent;

  /// No description provided for @deepHardnessTest.
  ///
  /// In en, this message translates to:
  /// **'1. Hardness Test (Hooke Spring)'**
  String get deepHardnessTest;

  /// No description provided for @deepReactionForce.
  ///
  /// In en, this message translates to:
  /// **'Reaction Force (F = k·x): {force} N (k=50 N/m)'**
  String deepReactionForce(Object force);

  /// No description provided for @deepNir.
  ///
  /// In en, this message translates to:
  /// **'2. Near-Infrared (NIR) Reflectance'**
  String get deepNir;

  /// No description provided for @deepSpectrumPeak.
  ///
  /// In en, this message translates to:
  /// **'Spectrum Peak: ≈{nm} nm'**
  String deepSpectrumPeak(Object nm);

  /// No description provided for @deepEddy.
  ///
  /// In en, this message translates to:
  /// **'3. Eddy Current (Non-Ferromagnetic Metal)'**
  String get deepEddy;

  /// No description provided for @deepVaporPressure.
  ///
  /// In en, this message translates to:
  /// **'1. Vapor Pressure'**
  String get deepVaporPressure;

  /// No description provided for @deepRelativeVapor.
  ///
  /// In en, this message translates to:
  /// **'Relative Vapor Pressure: {value} (Arbiter)'**
  String deepRelativeVapor(Object value);

  /// No description provided for @deepIncinerator.
  ///
  /// In en, this message translates to:
  /// **'2. Incinerator (Breaking Chemical Bonds)'**
  String get deepIncinerator;

  /// No description provided for @deepRadiationShield.
  ///
  /// In en, this message translates to:
  /// **'3. Radiation Shielding'**
  String get deepRadiationShield;

  /// Heatmap legend: fewer scans.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get activityLess;

  /// Heatmap legend: more scans.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get activityMore;

  /// No description provided for @activityOpenInHistory.
  ///
  /// In en, this message translates to:
  /// **'Open in History'**
  String get activityOpenInHistory;

  /// No description provided for @activityNoScans.
  ///
  /// In en, this message translates to:
  /// **'No scans on this day.'**
  String get activityNoScans;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connection, video, sound and quiz'**
  String get settingsSubtitle;

  /// No description provided for @aiNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Gemini · needs internet'**
  String get aiNeedsInternet;

  /// No description provided for @aiOffHint.
  ///
  /// In en, this message translates to:
  /// **'Identifies scans and writes new quiz questions, about 2 to 4 s each.'**
  String get aiOffHint;

  /// No description provided for @aiActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Identifying scans and writing quiz questions.'**
  String get aiActiveHint;

  /// No description provided for @aiActive.
  ///
  /// In en, this message translates to:
  /// **'Active · {model}'**
  String aiActive(Object model);

  /// No description provided for @aiCloud.
  ///
  /// In en, this message translates to:
  /// **'cloud'**
  String get aiCloud;

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No internet, or every AI model is busy. The quiz uses the question bank and tries the AI again on the next scan.'**
  String get aiUnavailable;

  /// No description provided for @robotWifiQr.
  ///
  /// In en, this message translates to:
  /// **'Robot Wi-Fi QR'**
  String get robotWifiQr;

  /// No description provided for @robotQrHint.
  ///
  /// In en, this message translates to:
  /// **'Robot not reading it? Lower the screen brightness or tilt the phone a little.'**
  String get robotQrHint;

  /// No description provided for @searchSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all {count} results'**
  String searchSeeAll(Object count);

  /// No description provided for @waitingForStream.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MaixCAM2 stream...'**
  String get waitingForStream;

  /// No description provided for @questionBank.
  ///
  /// In en, this message translates to:
  /// **'Question bank'**
  String get questionBank;

  /// No description provided for @backToQuestion.
  ///
  /// In en, this message translates to:
  /// **'Back to Question'**
  String get backToQuestion;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @testerMode.
  ///
  /// In en, this message translates to:
  /// **'Tester mode'**
  String get testerMode;

  /// No description provided for @testerQuestionSource.
  ///
  /// In en, this message translates to:
  /// **'Question source'**
  String get testerQuestionSource;

  /// No description provided for @testerBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get testerBank;

  /// No description provided for @testerShareLog.
  ///
  /// In en, this message translates to:
  /// **'Share log'**
  String get testerShareLog;

  /// No description provided for @testerLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get testerLogCopied;

  /// No description provided for @testerCopyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get testerCopyLog;

  /// No description provided for @testerLog.
  ///
  /// In en, this message translates to:
  /// **'Tester log'**
  String get testerLog;

  /// No description provided for @testerViewLog.
  ///
  /// In en, this message translates to:
  /// **'View log'**
  String get testerViewLog;

  /// No description provided for @testerClearLog.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get testerClearLog;

  /// No description provided for @lookingForMaixcam.
  ///
  /// In en, this message translates to:
  /// **'Looking for MaixCAM2...'**
  String get lookingForMaixcam;

  /// No description provided for @lostConnection.
  ///
  /// In en, this message translates to:
  /// **'Lost connection to ELIOS'**
  String get lostConnection;

  /// No description provided for @reconnectNow.
  ///
  /// In en, this message translates to:
  /// **'Reconnect now'**
  String get reconnectNow;

  /// No description provided for @wifiSettings.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi settings'**
  String get wifiSettings;

  /// No description provided for @missionProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {target} done'**
  String missionProgress(Object done, Object target);

  /// No description provided for @resetScanDebug.
  ///
  /// In en, this message translates to:
  /// **'Reset scan (debug)'**
  String get resetScanDebug;

  /// Screen-reader name of the bottom navigation bar.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get navMain;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navControl.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get navControl;

  /// No description provided for @navControlHint.
  ///
  /// In en, this message translates to:
  /// **'Control, opens robot control'**
  String get navControlHint;

  /// No description provided for @navConfig.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get navConfig;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @shellConnectElio.
  ///
  /// In en, this message translates to:
  /// **'Connect ELIO'**
  String get shellConnectElio;

  /// No description provided for @shellConnected.
  ///
  /// In en, this message translates to:
  /// **'ELIO connected'**
  String get shellConnected;

  /// No description provided for @shellConnectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Robot connection is ready.'**
  String get shellConnectedMsg;

  /// No description provided for @shellDisconnected.
  ///
  /// In en, this message translates to:
  /// **'ELIO disconnected'**
  String get shellDisconnected;

  /// No description provided for @shellDisconnectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Robot connection was lost. Check the device or network.'**
  String get shellDisconnectedMsg;

  /// No description provided for @leaveQuizBody.
  ///
  /// In en, this message translates to:
  /// **'You have an active quiz. If you leave now, your current quiz progress will be lost.'**
  String get leaveQuizBody;

  /// No description provided for @homeHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeHello(Object name);

  /// No description provided for @homeReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to learn with ELIO?'**
  String get homeReady;

  /// No description provided for @configTopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Robot, camera and quiz setup'**
  String get configTopSubtitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} — coming soon'**
  String comingSoon(Object title);

  /// No description provided for @homeGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get homeGuest;

  /// No description provided for @homeOpenNotifications.
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get homeOpenNotifications;

  /// No description provided for @homeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get homeVideo;

  /// No description provided for @homeGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get homeGuide;

  /// No description provided for @medalExplorer.
  ///
  /// In en, this message translates to:
  /// **'Environmental Explorer'**
  String get medalExplorer;

  /// No description provided for @medalExplorerDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete at least 3 learning items'**
  String get medalExplorerDesc;

  /// No description provided for @medalExplorerHint.
  ///
  /// In en, this message translates to:
  /// **'3 learning items'**
  String get medalExplorerHint;

  /// No description provided for @medalRobotics.
  ///
  /// In en, this message translates to:
  /// **'Robotics Beginner'**
  String get medalRobotics;

  /// No description provided for @medalRoboticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Start the Introduction to ELIO module'**
  String get medalRoboticsDesc;

  /// No description provided for @medalRoboticsHint.
  ///
  /// In en, this message translates to:
  /// **'Start Intro to ELIO'**
  String get medalRoboticsHint;

  /// No description provided for @medalAdvocate.
  ///
  /// In en, this message translates to:
  /// **'Sustainability Advocate'**
  String get medalAdvocate;

  /// No description provided for @medalAdvocateDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete all environmental empathy reflections'**
  String get medalAdvocateDesc;

  /// No description provided for @medalAdvocateHint.
  ///
  /// In en, this message translates to:
  /// **'All reflections'**
  String get medalAdvocateHint;

  /// No description provided for @homeTapSquare.
  ///
  /// In en, this message translates to:
  /// **'Tap any square in the Year view to open that day here.'**
  String get homeTapSquare;

  /// No description provided for @scanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scan} other{{count} scans}}'**
  String scanCount(num count);

  /// No description provided for @scansInMonth.
  ///
  /// In en, this message translates to:
  /// **'{scans} in {month}'**
  String scansInMonth(Object scans, Object month);

  /// No description provided for @noScans17Weeks.
  ///
  /// In en, this message translates to:
  /// **'No scans in the last 17 weeks'**
  String get noScans17Weeks;

  /// No description provided for @scansIn17Weeks.
  ///
  /// In en, this message translates to:
  /// **'{scans} in the last 17 weeks'**
  String scansIn17Weeks(Object scans);

  /// No description provided for @homeYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get homeYear;

  /// No description provided for @homeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get homeMonth;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String dayCount(num count);

  /// No description provided for @homeStreakLine.
  ///
  /// In en, this message translates to:
  /// **'Streak {days} · longest {longest}'**
  String homeStreakLine(Object days, Object longest);

  /// No description provided for @homeGuestProgress.
  ///
  /// In en, this message translates to:
  /// **'Guest progress is stored on this device. Sign in to sync it across devices.'**
  String get homeGuestProgress;

  /// No description provided for @levelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Level {level}, {title}. {trophies} trophies'**
  String levelSemantics(Object level, Object title, Object trophies);

  /// No description provided for @levelSemanticsTop.
  ///
  /// In en, this message translates to:
  /// **', top level'**
  String get levelSemanticsTop;

  /// No description provided for @levelSemanticsNext.
  ///
  /// In en, this message translates to:
  /// **', {count} to level {next}'**
  String levelSemanticsNext(Object count, Object next);

  /// No description provided for @homeLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String homeLevel(Object level);

  /// No description provided for @homePlantFirst.
  ///
  /// In en, this message translates to:
  /// **'Plant your first trophy: scan an item.'**
  String get homePlantFirst;

  /// No description provided for @homeTreeGrows.
  ///
  /// In en, this message translates to:
  /// **'Your tree grows with every trophy.'**
  String get homeTreeGrows;

  /// No description provided for @homeTopLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get homeTopLevel;

  /// No description provided for @homeToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{count} to Lv{next}'**
  String homeToNextLevel(Object count, Object next);

  /// No description provided for @homeScans.
  ///
  /// In en, this message translates to:
  /// **'Scans'**
  String get homeScans;

  /// No description provided for @homeDayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get homeDayStreak;

  /// No description provided for @questsDoneLine.
  ///
  /// In en, this message translates to:
  /// **'{done} of 3 done · resets at midnight'**
  String questsDoneLine(Object done);

  /// No description provided for @questsDoneSemantics.
  ///
  /// In en, this message translates to:
  /// **'{done} of 3 quests done'**
  String questsDoneSemantics(Object done);

  /// No description provided for @questSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}, {state}. Reward {reward} trophies'**
  String questSemantics(Object title, Object state, Object reward);

  /// No description provided for @questDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get questDone;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value} percent'**
  String percentValue(Object value);

  /// No description provided for @binsHungry.
  ///
  /// In en, this message translates to:
  /// **'Your bins are hungry: scan an item'**
  String get binsHungry;

  /// No description provided for @binsFed.
  ///
  /// In en, this message translates to:
  /// **'{scans} fed to your 3 bins'**
  String binsFed(Object scans);

  /// No description provided for @binTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get binTop;

  /// No description provided for @residuNote.
  ///
  /// In en, this message translates to:
  /// **'Residu scans count toward Anorganik.'**
  String get residuNote;

  /// No description provided for @residuIncluded.
  ///
  /// In en, this message translates to:
  /// **'Anorganik includes {count} residu {scans} (the robot sorts residu there).'**
  String residuIncluded(Object count, Object scans);

  /// No description provided for @scanWord.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{scan} other{scans}}'**
  String scanWord(num count);

  /// No description provided for @weekSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} scans this week. {days}'**
  String weekSemantics(Object count, Object days);

  /// No description provided for @quizAccNoData.
  ///
  /// In en, this message translates to:
  /// **'Quiz accuracy: no data'**
  String get quizAccNoData;

  /// No description provided for @quizAccSemantics.
  ///
  /// In en, this message translates to:
  /// **'Quiz accuracy {acc} percent over the last {count} scans with questions'**
  String quizAccSemantics(Object acc, Object count);

  /// No description provided for @quizAccDelta.
  ///
  /// In en, this message translates to:
  /// **', {dir} {count} points'**
  String quizAccDelta(Object dir, Object count);

  /// No description provided for @deltaUp.
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get deltaUp;

  /// No description provided for @deltaDown.
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get deltaDown;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'no data'**
  String get noData;

  /// No description provided for @medalUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get medalUnlocked;

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your progress'**
  String get homeLoading;

  /// No description provided for @homeGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing your tree…'**
  String get homeGrowing;

  /// No description provided for @fact1.
  ///
  /// In en, this message translates to:
  /// **'Plastics under 1,0 g/cm³ float in water. Recycling plants use that to separate them.'**
  String get fact1;

  /// No description provided for @fact2.
  ///
  /// In en, this message translates to:
  /// **'Batteries are B3 waste: their metals can leak into soil and water, so they need a special drop-off.'**
  String get fact2;

  /// No description provided for @fact3.
  ///
  /// In en, this message translates to:
  /// **'Fruit peels and food scraps can turn into compost in a few weeks.'**
  String get fact3;

  /// No description provided for @fact4.
  ///
  /// In en, this message translates to:
  /// **'Rinsing a bottle before recycling keeps the rest of the bin clean.'**
  String get fact4;

  /// No description provided for @fact5.
  ///
  /// In en, this message translates to:
  /// **'Aluminium cans can be recycled again and again without losing quality.'**
  String get fact5;

  /// Short Monday, Wednesday, Friday, comma-separated, max 3 letters each.
  ///
  /// In en, this message translates to:
  /// **'Mon,Wed,Fri'**
  String get heatmapDayLabels;

  /// Two-letter weekday initials Sunday..Saturday, comma-separated.
  ///
  /// In en, this message translates to:
  /// **'Su,Mo,Tu,We,Th,Fr,Sa'**
  String get calendarWeekdays;

  /// No description provided for @activityScansHint.
  ///
  /// In en, this message translates to:
  /// **'Use Month to browse days'**
  String get activityScansHint;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @searchAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAll;

  /// No description provided for @searchLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get searchLessons;

  /// No description provided for @searchLessonsHeader.
  ///
  /// In en, this message translates to:
  /// **'LESSONS'**
  String get searchLessonsHeader;

  /// No description provided for @searchSims.
  ///
  /// In en, this message translates to:
  /// **'Simulations'**
  String get searchSims;

  /// No description provided for @searchSimsHeader.
  ///
  /// In en, this message translates to:
  /// **'SIMULATIONS'**
  String get searchSimsHeader;

  /// No description provided for @searchQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get searchQuiz;

  /// No description provided for @searchQuizHeader.
  ///
  /// In en, this message translates to:
  /// **'QUIZ'**
  String get searchQuizHeader;

  /// No description provided for @searchScans.
  ///
  /// In en, this message translates to:
  /// **'Scans'**
  String get searchScans;

  /// No description provided for @searchScansHeader.
  ///
  /// In en, this message translates to:
  /// **'YOUR SCANS'**
  String get searchScansHeader;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search lessons, simulations, scans'**
  String get searchHint;

  /// No description provided for @resultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String resultCount(num count);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @searchIn.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get searchIn;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”.'**
  String noResultsFor(Object query);

  /// No description provided for @notifNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications right now.'**
  String get notifNone;

  /// No description provided for @notifEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Learning reminders, quiz review updates, and progress alerts will appear here.'**
  String get notifEmptyHint;

  /// No description provided for @notifDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notifications'**
  String get notifDismiss;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifClose.
  ///
  /// In en, this message translates to:
  /// **'Close notifications'**
  String get notifClose;

  /// No description provided for @notifSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learning updates and reminders from ELIO.'**
  String get notifSubtitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifMarkAllRead;

  /// No description provided for @notifClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get notifClearAll;

  /// No description provided for @notifDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notifDone;

  /// No description provided for @notifOpenLearning.
  ///
  /// In en, this message translates to:
  /// **'Open Learning'**
  String get notifOpenLearning;

  /// No description provided for @notifOpenConfig.
  ///
  /// In en, this message translates to:
  /// **'Open Config'**
  String get notifOpenConfig;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeMinutesAgo(Object n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeHoursAgo(Object n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeDaysAgo(Object n);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}w ago'**
  String timeWeeksAgo(Object n);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}mo ago'**
  String timeMonthsAgo(Object n);

  /// No description provided for @timeYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}y ago'**
  String timeYearsAgo(Object n);

  /// No description provided for @questScan3.
  ///
  /// In en, this message translates to:
  /// **'Scan 3 items today'**
  String get questScan3;

  /// No description provided for @questFinishQuiz.
  ///
  /// In en, this message translates to:
  /// **'Finish a scan quiz'**
  String get questFinishQuiz;

  /// No description provided for @questSortB3.
  ///
  /// In en, this message translates to:
  /// **'Sort one B3 item safely'**
  String get questSortB3;

  /// No description provided for @levelEcoStarter.
  ///
  /// In en, this message translates to:
  /// **'Eco Starter'**
  String get levelEcoStarter;

  /// No description provided for @levelWasteSpotter.
  ///
  /// In en, this message translates to:
  /// **'Waste Spotter'**
  String get levelWasteSpotter;

  /// No description provided for @levelBinExpert.
  ///
  /// In en, this message translates to:
  /// **'Bin Expert'**
  String get levelBinExpert;

  /// No description provided for @levelEcoSorter.
  ///
  /// In en, this message translates to:
  /// **'Eco Sorter'**
  String get levelEcoSorter;

  /// No description provided for @levelPlanetGuardian.
  ///
  /// In en, this message translates to:
  /// **'Planet Guardian'**
  String get levelPlanetGuardian;

  /// No description provided for @gradePerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect'**
  String get gradePerfect;

  /// No description provided for @gradeGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get gradeGreat;

  /// No description provided for @gradeGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get gradeGood;

  /// No description provided for @gradeKeepLearning.
  ///
  /// In en, this message translates to:
  /// **'Keep Learning'**
  String get gradeKeepLearning;

  /// No description provided for @gradeTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get gradeTryAgain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
