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
  /// **'{count} XP'**
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
  /// **'Put ELIOS and this phone on the same Wi-Fi or hotspot, then tap Connect now.'**
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
  /// **'Looking for ELIOS…'**
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
  /// **'Connection and video'**
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

  /// No description provided for @robotWifiQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join ELIOS to a hotspot or Wi-Fi'**
  String get robotWifiQrSubtitle;

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
  /// **'Connect ELIOS'**
  String get shellConnectElio;

  /// No description provided for @shellConnected.
  ///
  /// In en, this message translates to:
  /// **'ELIOS connected'**
  String get shellConnected;

  /// No description provided for @shellConnectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Robot connection is ready.'**
  String get shellConnectedMsg;

  /// No description provided for @shellDisconnected.
  ///
  /// In en, this message translates to:
  /// **'ELIOS disconnected'**
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
  /// **'Ready to learn with ELIOS?'**
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
  /// **'Start the Introduction to ELIOS module'**
  String get medalRoboticsDesc;

  /// No description provided for @medalRoboticsHint.
  ///
  /// In en, this message translates to:
  /// **'Start Intro to ELIOS'**
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
  /// **'Level {level}, {title}. {trophies} XP'**
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
  /// **'Earn your first XP: scan an item.'**
  String get homePlantFirst;

  /// No description provided for @homeTreeGrows.
  ///
  /// In en, this message translates to:
  /// **'Your tree grows as you earn XP.'**
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
  /// **'{title}, {state}. Reward {reward} XP'**
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
  /// **'Residu scans count toward Anorganik (the robot sorts residu there).'**
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
  /// **'Learning updates and reminders from ELIOS.'**
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

  /// No description provided for @cfgIpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an IP like 192.168.4.1'**
  String get cfgIpHint;

  /// No description provided for @cfgPortRange.
  ///
  /// In en, this message translates to:
  /// **'Port 1 to 65535'**
  String get cfgPortRange;

  /// No description provided for @cfgFoundAt.
  ///
  /// In en, this message translates to:
  /// **'Found ELIOS at {ip}'**
  String cfgFoundAt(Object ip);

  /// No description provided for @cfgNotFound.
  ///
  /// In en, this message translates to:
  /// **'ELIOS not found on this Wi-Fi'**
  String get cfgNotFound;

  /// No description provided for @cfgRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get cfgRetry;

  /// No description provided for @cfgCameraSource.
  ///
  /// In en, this message translates to:
  /// **'Camera source'**
  String get cfgCameraSource;

  /// No description provided for @cfgCameraSourceSub.
  ///
  /// In en, this message translates to:
  /// **'Which camera takes the scan photo'**
  String get cfgCameraSourceSub;

  /// No description provided for @cfgMaixDesc.
  ///
  /// In en, this message translates to:
  /// **'Robot camera over the ELIOS Wi-Fi'**
  String get cfgMaixDesc;

  /// No description provided for @cfgPhoneCamera.
  ///
  /// In en, this message translates to:
  /// **'Phone camera'**
  String get cfgPhoneCamera;

  /// No description provided for @cfgPhoneCameraDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan with this phone, no robot needed'**
  String get cfgPhoneCameraDesc;

  /// No description provided for @cfgQuizQuestions.
  ///
  /// In en, this message translates to:
  /// **'Quiz questions'**
  String get cfgQuizQuestions;

  /// No description provided for @cfgQuizQuestionsSub.
  ///
  /// In en, this message translates to:
  /// **'Where the scan quiz gets its questions'**
  String get cfgQuizQuestionsSub;

  /// No description provided for @cfgStartScan.
  ///
  /// In en, this message translates to:
  /// **'Start scan'**
  String get cfgStartScan;

  /// No description provided for @cfgConnectNow.
  ///
  /// In en, this message translates to:
  /// **'Connect now'**
  String get cfgConnectNow;

  /// No description provided for @cfgDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get cfgDisconnect;

  /// No description provided for @cfgConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get cfgConnecting;

  /// No description provided for @cfgCancelConnecting.
  ///
  /// In en, this message translates to:
  /// **'Cancel connecting'**
  String get cfgCancelConnecting;

  /// No description provided for @cfgConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cfgConnected;

  /// No description provided for @cfgTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get cfgTryAgain;

  /// No description provided for @cfgConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get cfgConnection;

  /// No description provided for @cfgWsAddress.
  ///
  /// In en, this message translates to:
  /// **'ELIOS WebSocket address'**
  String get cfgWsAddress;

  /// No description provided for @cfgPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get cfgPort;

  /// No description provided for @cfgSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get cfgSearching;

  /// No description provided for @cfgFindElio.
  ///
  /// In en, this message translates to:
  /// **'Find ELIOS'**
  String get cfgFindElio;

  /// No description provided for @cfgRobotNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Robot not used'**
  String get cfgRobotNotUsed;

  /// No description provided for @cfgConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {endpoint}'**
  String cfgConnectingTo(Object endpoint);

  /// No description provided for @cfgLastTryFailed.
  ///
  /// In en, this message translates to:
  /// **'Last try failed'**
  String get cfgLastTryFailed;

  /// No description provided for @cfgNotConnectedYet.
  ///
  /// In en, this message translates to:
  /// **'Not connected yet'**
  String get cfgNotConnectedYet;

  /// No description provided for @cfgNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get cfgNotUsed;

  /// No description provided for @cfgOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get cfgOnline;

  /// No description provided for @cfgConnectingShort.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get cfgConnectingShort;

  /// No description provided for @cfgOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get cfgOffline;

  /// No description provided for @cfgStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cfgStatus;

  /// No description provided for @cfgBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get cfgBattery;

  /// No description provided for @cfgNotReported.
  ///
  /// In en, this message translates to:
  /// **'not reported'**
  String get cfgNotReported;

  /// No description provided for @cfgCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cfgCamera;

  /// No description provided for @cfgPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get cfgPhone;

  /// No description provided for @cfgRobotModel.
  ///
  /// In en, this message translates to:
  /// **'ELIOS robot 3D model, drag to rotate'**
  String get cfgRobotModel;

  /// No description provided for @cfgQuestionBankDesc.
  ///
  /// In en, this message translates to:
  /// **'Checked questions, instant'**
  String get cfgQuestionBankDesc;

  /// No description provided for @cfgAiDesc.
  ///
  /// In en, this message translates to:
  /// **'New questions each scan, needs internet'**
  String get cfgAiDesc;

  /// No description provided for @cfgAiUnreachable.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is not reachable'**
  String get cfgAiUnreachable;

  /// No description provided for @setConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get setConnection;

  /// No description provided for @setAutoReconnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnect'**
  String get setAutoReconnect;

  /// No description provided for @setAutoReconnectSub.
  ///
  /// In en, this message translates to:
  /// **'Reconnect when ELIOS is available again'**
  String get setAutoReconnectSub;

  /// No description provided for @setVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get setVideo;

  /// No description provided for @setResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get setResolution;

  /// No description provided for @setResolutionSub.
  ///
  /// In en, this message translates to:
  /// **'Higher looks sharper but uses more Wi-Fi'**
  String get setResolutionSub;

  /// No description provided for @setShowFps.
  ///
  /// In en, this message translates to:
  /// **'Show FPS overlay'**
  String get setShowFps;

  /// No description provided for @setShowFpsSub.
  ///
  /// In en, this message translates to:
  /// **'Show stream speed while viewing'**
  String get setShowFpsSub;

  /// No description provided for @setSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get setSound;

  /// No description provided for @setSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get setSoundEffects;

  /// No description provided for @setSoundEffectsSub.
  ///
  /// In en, this message translates to:
  /// **'UI and robot feedback sounds'**
  String get setSoundEffectsSub;

  /// No description provided for @setMasterVolume.
  ///
  /// In en, this message translates to:
  /// **'Master volume'**
  String get setMasterVolume;

  /// No description provided for @setMasterVolumeValue.
  ///
  /// In en, this message translates to:
  /// **'Master volume {percent}%'**
  String setMasterVolumeValue(Object percent);

  /// No description provided for @setQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get setQuiz;

  /// No description provided for @setDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get setDifficulty;

  /// No description provided for @setEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get setEasy;

  /// No description provided for @setMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get setMedium;

  /// No description provided for @setHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get setHard;

  /// No description provided for @setEssay.
  ///
  /// In en, this message translates to:
  /// **'Essay questions'**
  String get setEssay;

  /// No description provided for @setEssaySub.
  ///
  /// In en, this message translates to:
  /// **'Written answers, graded by ELIOS AI'**
  String get setEssaySub;

  /// No description provided for @setTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get setTimer;

  /// No description provided for @setTimerSub.
  ///
  /// In en, this message translates to:
  /// **'Time for each question'**
  String get setTimerSub;

  /// No description provided for @setAllowSkip.
  ///
  /// In en, this message translates to:
  /// **'Allow skipping'**
  String get setAllowSkip;

  /// No description provided for @setAllowSkipSub.
  ///
  /// In en, this message translates to:
  /// **'Learners can skip a question'**
  String get setAllowSkipSub;

  /// No description provided for @qrIntro.
  ///
  /// In en, this message translates to:
  /// **'Turn on this phone\'s hotspot (2.4 GHz), or use your home Wi-Fi, and type its name and password. On the robot screen tap Wi-Fi setup, then hold this QR in front of the camera.'**
  String get qrIntro;

  /// No description provided for @qrSsid.
  ///
  /// In en, this message translates to:
  /// **'Hotspot name (SSID)'**
  String get qrSsid;

  /// No description provided for @qrPassword.
  ///
  /// In en, this message translates to:
  /// **'Hotspot password'**
  String get qrPassword;

  /// No description provided for @qrShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get qrShowPassword;

  /// No description provided for @qrHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get qrHidePassword;

  /// No description provided for @qrShow.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get qrShow;

  /// No description provided for @qrSemantics.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi QR code for {ssid}'**
  String qrSemantics(Object ssid);

  /// No description provided for @ctlWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get ctlWaiting;

  /// No description provided for @ctlOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get ctlOffline;

  /// No description provided for @ctlStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get ctlStopped;

  /// No description provided for @ctlForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get ctlForward;

  /// No description provided for @ctlBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get ctlBack;

  /// No description provided for @ctlLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get ctlLeft;

  /// No description provided for @ctlRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get ctlRight;

  /// No description provided for @ctlReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ctlReady;

  /// No description provided for @ctlHoming.
  ///
  /// In en, this message translates to:
  /// **'Homing'**
  String get ctlHoming;

  /// No description provided for @ctlExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get ctlExit;

  /// No description provided for @ctlDebugScan.
  ///
  /// In en, this message translates to:
  /// **'Debug Scan'**
  String get ctlDebugScan;

  /// No description provided for @ctlPushToDrive.
  ///
  /// In en, this message translates to:
  /// **'Push to drive · let go to stop'**
  String get ctlPushToDrive;

  /// No description provided for @ctlUnlocksOnConnect.
  ///
  /// In en, this message translates to:
  /// **'Unlocks when the robot connects'**
  String get ctlUnlocksOnConnect;

  /// No description provided for @ctlSpeedPwm.
  ///
  /// In en, this message translates to:
  /// **'SPEED (PWM)'**
  String get ctlSpeedPwm;

  /// No description provided for @ctlSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ctlSpeed;

  /// No description provided for @ctlPickUp.
  ///
  /// In en, this message translates to:
  /// **'PICK UP'**
  String get ctlPickUp;

  /// No description provided for @ctlRelease.
  ///
  /// In en, this message translates to:
  /// **'RELEASE'**
  String get ctlRelease;

  /// No description provided for @ctlGripperCaps.
  ///
  /// In en, this message translates to:
  /// **'GRIPPER'**
  String get ctlGripperCaps;

  /// No description provided for @ctlGripper.
  ///
  /// In en, this message translates to:
  /// **'Gripper'**
  String get ctlGripper;

  /// No description provided for @ctlHeight.
  ///
  /// In en, this message translates to:
  /// **'HEIGHT'**
  String get ctlHeight;

  /// No description provided for @ctlUpDown.
  ///
  /// In en, this message translates to:
  /// **'Up / Down'**
  String get ctlUpDown;

  /// No description provided for @ctlReach.
  ///
  /// In en, this message translates to:
  /// **'REACH'**
  String get ctlReach;

  /// No description provided for @ctlFwdBack.
  ///
  /// In en, this message translates to:
  /// **'Fwd / Back'**
  String get ctlFwdBack;

  /// No description provided for @ctlArmHint.
  ///
  /// In en, this message translates to:
  /// **'Slide up to lift, slide forward to reach. The arm only moves when the robot is not STOPPED.'**
  String get ctlArmHint;

  /// No description provided for @ctlArmLocked.
  ///
  /// In en, this message translates to:
  /// **'Arm controls unlock when the robot is connected. STOP always works.'**
  String get ctlArmLocked;

  /// No description provided for @ctlAiBusy.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is busy. Try LOCK again in a moment.'**
  String get ctlAiBusy;

  /// No description provided for @ctlNoItem.
  ///
  /// In en, this message translates to:
  /// **'No item found. Point the camera at one item and try again.'**
  String get ctlNoItem;

  /// No description provided for @ctlBaseLeft.
  ///
  /// In en, this message translates to:
  /// **'Base left'**
  String get ctlBaseLeft;

  /// No description provided for @ctlBaseRight.
  ///
  /// In en, this message translates to:
  /// **'Base right'**
  String get ctlBaseRight;

  /// No description provided for @ctlRobotControl.
  ///
  /// In en, this message translates to:
  /// **'Robot Control'**
  String get ctlRobotControl;

  /// No description provided for @ctlDrive.
  ///
  /// In en, this message translates to:
  /// **'DRIVE'**
  String get ctlDrive;

  /// No description provided for @ctlLiveScanPaused.
  ///
  /// In en, this message translates to:
  /// **'LIVE · scan paused'**
  String get ctlLiveScanPaused;

  /// No description provided for @ctlLiveFps.
  ///
  /// In en, this message translates to:
  /// **'LIVE · {fps} fps'**
  String ctlLiveFps(Object fps);

  /// No description provided for @ctlNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No video'**
  String get ctlNoVideo;

  /// No description provided for @ctlNoVideoCaps.
  ///
  /// In en, this message translates to:
  /// **'NO VIDEO'**
  String get ctlNoVideoCaps;

  /// No description provided for @ctlConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get ctlConnecting;

  /// No description provided for @ctlScanQuiz.
  ///
  /// In en, this message translates to:
  /// **'Scan quiz'**
  String get ctlScanQuiz;

  /// No description provided for @ctlVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ctlVoice;

  /// No description provided for @ctlWaitingFrames.
  ///
  /// In en, this message translates to:
  /// **'Connected. Waiting for camera frames...'**
  String get ctlWaitingFrames;

  /// No description provided for @ctlArm.
  ///
  /// In en, this message translates to:
  /// **'ARM'**
  String get ctlArm;

  /// No description provided for @ctlUnlock.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK'**
  String get ctlUnlock;

  /// No description provided for @ctlLock.
  ///
  /// In en, this message translates to:
  /// **'LOCK'**
  String get ctlLock;

  /// No description provided for @ctlScan.
  ///
  /// In en, this message translates to:
  /// **'SCAN'**
  String get ctlScan;

  /// No description provided for @ctlDisconnectRobot.
  ///
  /// In en, this message translates to:
  /// **'Disconnect robot'**
  String get ctlDisconnectRobot;

  /// No description provided for @ctlConnectRobot.
  ///
  /// In en, this message translates to:
  /// **'Connect robot'**
  String get ctlConnectRobot;

  /// No description provided for @ctlGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get ctlGuide;

  /// No description provided for @ctlStoppedPaused.
  ///
  /// In en, this message translates to:
  /// **'Robot stopped · scanning paused'**
  String get ctlStoppedPaused;

  /// No description provided for @ctlRobotOffline.
  ///
  /// In en, this message translates to:
  /// **'Robot offline'**
  String get ctlRobotOffline;

  /// No description provided for @ctlTurnOnRobot.
  ///
  /// In en, this message translates to:
  /// **'Turn on the robot and join the ELIOS Wi-Fi.'**
  String get ctlTurnOnRobot;

  /// No description provided for @ctlConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get ctlConnect;

  /// No description provided for @ctlEmergencyStop.
  ///
  /// In en, this message translates to:
  /// **'Emergency stop'**
  String get ctlEmergencyStop;

  /// No description provided for @ctlPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get ctlPower;

  /// No description provided for @ctlMaixConnected.
  ///
  /// In en, this message translates to:
  /// **'MaixCAM2 connected'**
  String get ctlMaixConnected;

  /// No description provided for @ctlDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get ctlDisconnected;

  /// No description provided for @ctlPickZone.
  ///
  /// In en, this message translates to:
  /// **'PICK ZONE'**
  String get ctlPickZone;

  /// No description provided for @ctlKeepTabletOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Turn the robot on and keep this tablet on the ELIOS Wi-Fi.'**
  String get ctlKeepTabletOnWifi;

  /// No description provided for @ctlRetryingIn.
  ///
  /// In en, this message translates to:
  /// **'Retrying in {s} s · attempt {attempt} of {max}'**
  String ctlRetryingIn(Object s, Object attempt, Object max);

  /// No description provided for @ctlAutoReconnectOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-reconnect is off'**
  String get ctlAutoReconnectOff;

  /// No description provided for @ctlStoppedRetrying.
  ///
  /// In en, this message translates to:
  /// **'Stopped retrying after {max} tries'**
  String ctlStoppedRetrying(Object max);

  /// No description provided for @ctlTryingAgain.
  ///
  /// In en, this message translates to:
  /// **'Trying again · attempt {attempt} of {max}'**
  String ctlTryingAgain(Object attempt, Object max);

  /// No description provided for @ctlLinkDropped.
  ///
  /// In en, this message translates to:
  /// **'The robot link dropped, so the robot stopped for safety.'**
  String get ctlLinkDropped;

  /// No description provided for @ctlOpenQuiz.
  ///
  /// In en, this message translates to:
  /// **'Open quiz'**
  String get ctlOpenQuiz;

  /// No description provided for @ctlMission.
  ///
  /// In en, this message translates to:
  /// **'MISSION'**
  String get ctlMission;

  /// No description provided for @ctlSortItems.
  ///
  /// In en, this message translates to:
  /// **'Sort {count} items this drive'**
  String ctlSortItems(Object count);

  /// No description provided for @ctlThisDrive.
  ///
  /// In en, this message translates to:
  /// **'THIS DRIVE'**
  String get ctlThisDrive;

  /// No description provided for @ctlElioSays.
  ///
  /// In en, this message translates to:
  /// **'ELIOS SAYS'**
  String get ctlElioSays;

  /// No description provided for @ctlMissionOf.
  ///
  /// In en, this message translates to:
  /// **'Mission {done} of {target}'**
  String ctlMissionOf(Object done, Object target);

  /// No description provided for @ctlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drive close, pick it up, sort it right!'**
  String get ctlSubtitle;

  /// No description provided for @ctlLinkLost.
  ///
  /// In en, this message translates to:
  /// **'link lost'**
  String get ctlLinkLost;

  /// No description provided for @ctlStopButton.
  ///
  /// In en, this message translates to:
  /// **'STOP button'**
  String get ctlStopButton;

  /// No description provided for @ctlRobotError.
  ///
  /// In en, this message translates to:
  /// **'robot error'**
  String get ctlRobotError;

  /// No description provided for @ctlRobotStoppedWhy.
  ///
  /// In en, this message translates to:
  /// **'Robot STOPPED · {why}'**
  String ctlRobotStoppedWhy(Object why);

  /// No description provided for @ctlHoldForHome.
  ///
  /// In en, this message translates to:
  /// **'Hold 1 second for HOME'**
  String get ctlHoldForHome;

  /// No description provided for @ctlRobotStoppedLong.
  ///
  /// In en, this message translates to:
  /// **'ROBOT STOPPED ({why}). Scanning stopped; an open quiz can still be answered.'**
  String ctlRobotStoppedLong(Object why);

  /// No description provided for @guideDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Drive the robot'**
  String get guideDriveTitle;

  /// No description provided for @guideDriveBody.
  ///
  /// In en, this message translates to:
  /// **'Push the green knob the way you want to go. Let go and the robot stops.'**
  String get guideDriveBody;

  /// No description provided for @guideStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Big red STOP'**
  String get guideStopTitle;

  /// No description provided for @guideStopBody.
  ///
  /// In en, this message translates to:
  /// **'Tap it any time something looks unsafe. Space or Esc work too.'**
  String get guideStopBody;

  /// No description provided for @guideGrabTitle.
  ///
  /// In en, this message translates to:
  /// **'Grab the item'**
  String get guideGrabTitle;

  /// No description provided for @guideGrabBody.
  ///
  /// In en, this message translates to:
  /// **'When the item is close, press PICK UP. RELEASE drops it. HOME parks the arm.'**
  String get guideGrabBody;

  /// No description provided for @guideQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Answer the quiz'**
  String get guideQuizTitle;

  /// No description provided for @guideQuizBody.
  ///
  /// In en, this message translates to:
  /// **'After each scan ELIOS AI asks a question. Tap here to open it and earn XP!'**
  String get guideQuizBody;

  /// No description provided for @guideStepOf.
  ///
  /// In en, this message translates to:
  /// **'STEP {step} OF {total}'**
  String guideStepOf(Object step, Object total);

  /// No description provided for @guideSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get guideSkip;

  /// No description provided for @guideNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get guideNext;

  /// No description provided for @guideIntro.
  ///
  /// In en, this message translates to:
  /// **'Drive to an item, grab it, sort it, then answer ELIOS AI to earn XP. Tap Guide any time to replay this.'**
  String get guideIntro;

  /// No description provided for @r2JoystickHint.
  ///
  /// In en, this message translates to:
  /// **'Joystick: slide to steer, let go to stop'**
  String get r2JoystickHint;

  /// No description provided for @r2SpeedValue.
  ///
  /// In en, this message translates to:
  /// **'Speed {value}'**
  String r2SpeedValue(Object value);

  /// No description provided for @r2RobotPrefix.
  ///
  /// In en, this message translates to:
  /// **'Robot '**
  String get r2RobotPrefix;

  /// No description provided for @dsAiOffline.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI offline · question bank'**
  String get dsAiOffline;

  /// No description provided for @dsAiReady.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI ready'**
  String get dsAiReady;

  /// No description provided for @dsBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get dsBack;

  /// No description provided for @dsLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get dsLive;

  /// No description provided for @dsNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera'**
  String get dsNoCamera;

  /// No description provided for @dsBankMode.
  ///
  /// In en, this message translates to:
  /// **'Bank mode'**
  String get dsBankMode;

  /// No description provided for @dsPutItem.
  ///
  /// In en, this message translates to:
  /// **'Put one item inside the white box, then tap Scan.'**
  String get dsPutItem;

  /// No description provided for @dsScanMakeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Scan and make quiz'**
  String get dsScanMakeQuiz;

  /// No description provided for @dsScanMakeQuizShort.
  ///
  /// In en, this message translates to:
  /// **'Scan & make quiz'**
  String get dsScanMakeQuizShort;

  /// No description provided for @dsTiming.
  ///
  /// In en, this message translates to:
  /// **'About 2–4 s · needs internet'**
  String get dsTiming;

  /// No description provided for @dsSwitchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get dsSwitchCamera;

  /// No description provided for @dsTestModeHint.
  ///
  /// In en, this message translates to:
  /// **'Test mode: quiz without the camera'**
  String get dsTestModeHint;

  /// No description provided for @dsTestMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode'**
  String get dsTestMode;

  /// No description provided for @histSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get histSavedLocal;

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get histTitle;

  /// No description provided for @histSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Quiz results & XP'**
  String get histSubtitleShort;

  /// No description provided for @histSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every item you scanned, with its quiz results and XP'**
  String get histSubtitle;

  /// No description provided for @histPickLeft.
  ///
  /// In en, this message translates to:
  /// **'Pick a scan on the left to see the quiz details.'**
  String get histPickLeft;

  /// No description provided for @histRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent scans'**
  String get histRecent;

  /// No description provided for @histSeedDebug.
  ///
  /// In en, this message translates to:
  /// **'Seed Sample Data (Debug)'**
  String get histSeedDebug;

  /// No description provided for @histRecyclable.
  ///
  /// In en, this message translates to:
  /// **'Recyclable'**
  String get histRecyclable;

  /// No description provided for @histOrganic.
  ///
  /// In en, this message translates to:
  /// **'Organic'**
  String get histOrganic;

  /// No description provided for @histScannedAt.
  ///
  /// In en, this message translates to:
  /// **'Scanned {time} · Photo and {count} questions saved locally'**
  String histScannedAt(Object time, Object count);

  /// No description provided for @histDiffPill.
  ///
  /// In en, this message translates to:
  /// **'{level} · {count}Q'**
  String histDiffPill(Object level, Object count);

  /// No description provided for @hist10Trophies.
  ///
  /// In en, this message translates to:
  /// **'10 XP per right answer'**
  String get hist10Trophies;

  /// No description provided for @histQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get histQuestions;

  /// No description provided for @histPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get histPending;

  /// No description provided for @histCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get histCorrect;

  /// No description provided for @histWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get histWrong;

  /// No description provided for @histYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'YOUR ANSWER'**
  String get histYourAnswer;

  /// No description provided for @histRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'RIGHT ANSWER'**
  String get histRightAnswer;

  /// No description provided for @histScore.
  ///
  /// In en, this message translates to:
  /// **'SCORE'**
  String get histScore;

  /// No description provided for @awaitingGrading.
  ///
  /// In en, this message translates to:
  /// **'Awaiting grading'**
  String get awaitingGrading;

  /// No description provided for @histEssayScore.
  ///
  /// In en, this message translates to:
  /// **'{score} / 10 · +{trophies} XP'**
  String histEssayScore(Object score, Object trophies);

  /// No description provided for @histHideExplanation.
  ///
  /// In en, this message translates to:
  /// **'Hide Explanation'**
  String get histHideExplanation;

  /// No description provided for @histShowExplanation.
  ///
  /// In en, this message translates to:
  /// **'Show Explanation'**
  String get histShowExplanation;

  /// No description provided for @histNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation was saved for this question.'**
  String get histNoExplanation;

  /// No description provided for @histEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Scan History Yet'**
  String get histEmptyTitle;

  /// No description provided for @histEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every item you scan and every quiz you finish will show up here.'**
  String get histEmptyBody;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email or username.'**
  String get authUserNotFound;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get authWrongPassword;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authTooMany;

  /// No description provided for @authNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get authNoInternet;

  /// No description provided for @authGoogleConfig.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not configured correctly. Check Android/iOS Firebase setup.'**
  String get authGoogleConfig;

  /// No description provided for @authOtherMethod.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered with another sign-in method.'**
  String get authOtherMethod;

  /// No description provided for @authGoogleLinked.
  ///
  /// In en, this message translates to:
  /// **'This Google account is already linked to another user.'**
  String get authGoogleLinked;

  /// No description provided for @authGoogleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Google credential is invalid. Check Firebase configuration.'**
  String get authGoogleInvalid;

  /// No description provided for @authGoogleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not enabled in Firebase Authentication.'**
  String get authGoogleDisabled;

  /// No description provided for @authGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authGeneric;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get authWelcomeBack;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed.'**
  String get authSignInFailed;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created!'**
  String get authAccountCreated;

  /// No description provided for @authCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Account creation failed.'**
  String get authCreateFailed;

  /// No description provided for @authNoIdToken.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In returned no idToken. Check Firebase platform config.'**
  String get authNoIdToken;

  /// No description provided for @authGoogleFailedCode.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed: {code}'**
  String authGoogleFailedCode(Object code);

  /// No description provided for @authGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Check debug logs.'**
  String get authGoogleFailed;

  /// No description provided for @authGuestEntered.
  ///
  /// In en, this message translates to:
  /// **'Entered guest mode.'**
  String get authGuestEntered;

  /// No description provided for @authGuestFailed.
  ///
  /// In en, this message translates to:
  /// **'Guest mode failed.'**
  String get authGuestFailed;

  /// No description provided for @authEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email first.'**
  String get authEmailFirst;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent to your email.'**
  String get authResetSent;

  /// No description provided for @authResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get authResetFailed;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authEmailOrUserRequired.
  ///
  /// In en, this message translates to:
  /// **'Email or username is required'**
  String get authEmailOrUserRequired;

  /// No description provided for @authValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authValidEmail;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authMin6.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get authMin6;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get authNameRequired;

  /// No description provided for @authMin2.
  ///
  /// In en, this message translates to:
  /// **'Min 2 characters'**
  String get authMin2;

  /// No description provided for @authForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgot;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeTitle;

  /// No description provided for @authJoin.
  ///
  /// In en, this message translates to:
  /// **'Join ELIOS to start sorting'**
  String get authJoin;

  /// No description provided for @authSignInSub.
  ///
  /// In en, this message translates to:
  /// **'Sign in to control ELIOS'**
  String get authSignInSub;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailOrUser.
  ///
  /// In en, this message translates to:
  /// **'Email / Username'**
  String get authEmailOrUser;

  /// No description provided for @authEmailOrUserHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com or username'**
  String get authEmailOrUserHint;

  /// No description provided for @authSendReset.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendReset;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullName;

  /// No description provided for @authFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get authFullNameHint;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogle;

  /// No description provided for @authGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get authGuest;

  /// No description provided for @authGuestNote.
  ///
  /// In en, this message translates to:
  /// **'Guest mode saves data locally only. Sign in to sync progress.'**
  String get authGuestNote;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get authPleaseWait;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get authOr;

  /// No description provided for @quizSrcBank.
  ///
  /// In en, this message translates to:
  /// **'MODULE QUESTION · QUESTION BANK'**
  String get quizSrcBank;

  /// No description provided for @quizSrcAi.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI QUESTION'**
  String get quizSrcAi;

  /// No description provided for @quizSrcFallback.
  ///
  /// In en, this message translates to:
  /// **'BACKUP QUESTION (ELIOS AI NOT CONNECTED)'**
  String get quizSrcFallback;

  /// No description provided for @quizSrcGeneric.
  ///
  /// In en, this message translates to:
  /// **'GENERAL QUESTION (ITEM NOT IN THE QUESTION BANK YET)'**
  String get quizSrcGeneric;

  /// No description provided for @quizPreparing.
  ///
  /// In en, this message translates to:
  /// **'Quiz, preparing the question'**
  String get quizPreparing;

  /// No description provided for @quizReady.
  ///
  /// In en, this message translates to:
  /// **'Quiz, question ready'**
  String get quizReady;

  /// No description provided for @quizWord.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quizWord;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan did not work'**
  String get scanFailed;

  /// No description provided for @wasteGeneric.
  ///
  /// In en, this message translates to:
  /// **'Waste'**
  String get wasteGeneric;

  /// No description provided for @trophiesEarned.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String trophiesEarned(Object count);

  /// No description provided for @trophiesTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} XP total'**
  String trophiesTotal(Object count);

  /// No description provided for @robotDropping.
  ///
  /// In en, this message translates to:
  /// **'The robot is dropping it in the bin...'**
  String get robotDropping;

  /// No description provided for @qzReadScan.
  ///
  /// In en, this message translates to:
  /// **'Read the scan'**
  String get qzReadScan;

  /// No description provided for @qzAiLooking.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is looking'**
  String get qzAiLooking;

  /// No description provided for @qzPickedTopic.
  ///
  /// In en, this message translates to:
  /// **'Picked a topic'**
  String get qzPickedTopic;

  /// No description provided for @qzAfterScan.
  ///
  /// In en, this message translates to:
  /// **'After the scan'**
  String get qzAfterScan;

  /// No description provided for @qzAiTopic.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI topic'**
  String get qzAiTopic;

  /// No description provided for @qzBankPool.
  ///
  /// In en, this message translates to:
  /// **'Bank pool · {pool}'**
  String qzBankPool(Object pool);

  /// No description provided for @qzWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing the question'**
  String get qzWriting;

  /// No description provided for @qzEssay.
  ///
  /// In en, this message translates to:
  /// **'essay'**
  String get qzEssay;

  /// No description provided for @qzMultipleChoice.
  ///
  /// In en, this message translates to:
  /// **'multiple choice'**
  String get qzMultipleChoice;

  /// No description provided for @qzQuestionOfLevel.
  ///
  /// In en, this message translates to:
  /// **'Question {n} of {total} · {level}'**
  String qzQuestionOfLevel(Object n, Object total, Object level);

  /// No description provided for @qzQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {n} of {total}'**
  String qzQuestionOf(Object n, Object total);

  /// No description provided for @qzScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {name}'**
  String qzScanned(Object name);

  /// No description provided for @qzReading.
  ///
  /// In en, this message translates to:
  /// **'reading…'**
  String get qzReading;

  /// No description provided for @qzAiReadingCaps.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI · READING THE SCAN'**
  String get qzAiReadingCaps;

  /// No description provided for @qzAiWritingCaps.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI · WRITING YOUR QUESTION'**
  String get qzAiWritingCaps;

  /// No description provided for @qzReadingScan.
  ///
  /// In en, this message translates to:
  /// **'Reading the scan…'**
  String get qzReadingScan;

  /// No description provided for @qzPreparingNext.
  ///
  /// In en, this message translates to:
  /// **'Preparing the next question…'**
  String get qzPreparingNext;

  /// No description provided for @qzAiOnline.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is writing it online. This usually takes 2–4 seconds.'**
  String get qzAiOnline;

  /// No description provided for @qzFromBank.
  ///
  /// In en, this message translates to:
  /// **'From the reviewed question bank. This takes a moment.'**
  String get qzFromBank;

  /// No description provided for @qzKeepDriving.
  ///
  /// In en, this message translates to:
  /// **'Keep driving. '**
  String get qzKeepDriving;

  /// No description provided for @qzMinimiseHint.
  ///
  /// In en, this message translates to:
  /// **'Minimise this and the Quiz button lights up when the question is ready.'**
  String get qzMinimiseHint;

  /// No description provided for @qzMcCaps.
  ///
  /// In en, this message translates to:
  /// **'MULTIPLE CHOICE · {level}'**
  String qzMcCaps(Object level);

  /// No description provided for @qzSkipFinish.
  ///
  /// In en, this message translates to:
  /// **'Skip and finish'**
  String get qzSkipFinish;

  /// No description provided for @qzSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get qzSkip;

  /// No description provided for @qzUpTo10.
  ///
  /// In en, this message translates to:
  /// **'Up to +10 XP for a full answer'**
  String get qzUpTo10;

  /// No description provided for @qz10Right.
  ///
  /// In en, this message translates to:
  /// **'+10 XP for a right answer'**
  String get qz10Right;

  /// No description provided for @qzEssayCaps.
  ///
  /// In en, this message translates to:
  /// **'ESSAY · {level} · MAX {words} WORDS'**
  String qzEssayCaps(Object level, Object words);

  /// No description provided for @qzGrading.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is grading your answer…'**
  String get qzGrading;

  /// No description provided for @qzTypeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer here…'**
  String get qzTypeAnswer;

  /// No description provided for @qzSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get qzSubmit;

  /// No description provided for @qzClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get qzClear;

  /// No description provided for @qzHazardTitle.
  ///
  /// In en, this message translates to:
  /// **'Possibly hazardous (B3): {name}'**
  String qzHazardTitle(Object name);

  /// No description provided for @scanHazardOverline.
  ///
  /// In en, this message translates to:
  /// **'Handle with care'**
  String get scanHazardOverline;

  /// No description provided for @scanHazardNote.
  ///
  /// In en, this message translates to:
  /// **'Don\'t take it apart or put it in a normal bin. Ask a staff member to handle it safely.'**
  String get scanHazardNote;

  /// No description provided for @scanHazardKeepLearning.
  ///
  /// In en, this message translates to:
  /// **'Keep learning about this item?'**
  String get scanHazardKeepLearning;

  /// No description provided for @qzContinueQuiz.
  ///
  /// In en, this message translates to:
  /// **'Continue quiz'**
  String get qzContinueQuiz;

  /// No description provided for @qzWhichBin.
  ///
  /// In en, this message translates to:
  /// **'Which bin is right?'**
  String get qzWhichBin;

  /// No description provided for @qzMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'The detector says {detector} ({detectorCategory}). ELIOS AI says {name} ({aiCategory}). Pick the right one.'**
  String qzMismatchBody(
    Object detector,
    Object detectorCategory,
    Object name,
    Object aiCategory,
  );

  /// No description provided for @qzUseAi.
  ///
  /// In en, this message translates to:
  /// **'Use ELIOS AI ({category})'**
  String qzUseAi(Object category);

  /// No description provided for @qzUseDetector.
  ///
  /// In en, this message translates to:
  /// **'Use detector ({category})'**
  String qzUseDetector(Object category);

  /// No description provided for @qzScanChip.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get qzScanChip;

  /// No description provided for @qzComplete.
  ///
  /// In en, this message translates to:
  /// **'Quiz complete'**
  String get qzComplete;

  /// No description provided for @qzBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get qzBack;

  /// No description provided for @qzListenExplanation.
  ///
  /// In en, this message translates to:
  /// **'Listen to explanation'**
  String get qzListenExplanation;

  /// No description provided for @qzFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish quiz'**
  String get qzFinish;

  /// No description provided for @qzNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get qzNextQuestion;

  /// No description provided for @qzEssayReview.
  ///
  /// In en, this message translates to:
  /// **'Essay review'**
  String get qzEssayReview;

  /// No description provided for @qzReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get qzReview;

  /// No description provided for @qzWaitingGrading.
  ///
  /// In en, this message translates to:
  /// **'Waiting for grading'**
  String get qzWaitingGrading;

  /// No description provided for @qzNotGradedYet.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI has not graded this answer yet. It is saved and graded later.'**
  String get qzNotGradedYet;

  /// No description provided for @qzScoreOf10.
  ///
  /// In en, this message translates to:
  /// **'Score {score} / 10'**
  String qzScoreOf10(Object score);

  /// No description provided for @qzCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get qzCorrect;

  /// No description provided for @qzYouChose.
  ///
  /// In en, this message translates to:
  /// **'You chose “{picked}”.'**
  String qzYouChose(Object picked);

  /// No description provided for @qzNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get qzNotQuite;

  /// No description provided for @qzGoodThinking.
  ///
  /// In en, this message translates to:
  /// **'Good thinking'**
  String get qzGoodThinking;

  /// No description provided for @qzTheCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'The correct answer'**
  String get qzTheCorrectAnswer;

  /// No description provided for @qzCheckedByAi.
  ///
  /// In en, this message translates to:
  /// **'Checked by ELIOS AI'**
  String get qzCheckedByAi;

  /// No description provided for @qzRightAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'The right answer is “{answer}”.'**
  String qzRightAnswerIs(Object answer);

  /// No description provided for @qzAnswerReview.
  ///
  /// In en, this message translates to:
  /// **'Answer review'**
  String get qzAnswerReview;

  /// No description provided for @qzDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed explanation'**
  String get qzDetailed;

  /// No description provided for @qzQuestionOfCaps.
  ///
  /// In en, this message translates to:
  /// **'QUESTION {n} OF {total} · {kind}'**
  String qzQuestionOfCaps(Object n, Object total, Object kind);

  /// No description provided for @qzEssayUpper.
  ///
  /// In en, this message translates to:
  /// **'ESSAY'**
  String get qzEssayUpper;

  /// No description provided for @qzQuestionCaps.
  ///
  /// In en, this message translates to:
  /// **'QUESTION'**
  String get qzQuestionCaps;

  /// No description provided for @qzCorrectAnswerCaps.
  ///
  /// In en, this message translates to:
  /// **'CORRECT ANSWER'**
  String get qzCorrectAnswerCaps;

  /// No description provided for @qzLoadingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Loading the explanation…'**
  String get qzLoadingExplanation;

  /// No description provided for @qzSavedNoTrophies.
  ///
  /// In en, this message translates to:
  /// **'Your answer is saved. ELIOS AI grades it when it is ready; no XP until then.'**
  String get qzSavedNoTrophies;

  /// No description provided for @qzFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get qzFeedback;

  /// No description provided for @qzWhyWrong.
  ///
  /// In en, this message translates to:
  /// **'Why your answer is not right'**
  String get qzWhyWrong;

  /// No description provided for @qzWhyRight.
  ///
  /// In en, this message translates to:
  /// **'Why the correct answer is right'**
  String get qzWhyRight;

  /// No description provided for @qzElioModule.
  ///
  /// In en, this message translates to:
  /// **'ELIOS module'**
  String get qzElioModule;

  /// No description provided for @qzScoringTable.
  ///
  /// In en, this message translates to:
  /// **'Table 1. Scoring breakdown'**
  String get qzScoringTable;

  /// No description provided for @qzCriteria.
  ///
  /// In en, this message translates to:
  /// **'CRITERIA'**
  String get qzCriteria;

  /// No description provided for @qzFeedbackCaps.
  ///
  /// In en, this message translates to:
  /// **'FEEDBACK'**
  String get qzFeedbackCaps;

  /// No description provided for @qzWhereGoes.
  ///
  /// In en, this message translates to:
  /// **'Table 1. Where {name} goes'**
  String qzWhereGoes(Object name);

  /// No description provided for @qzThisItem.
  ///
  /// In en, this message translates to:
  /// **'this item'**
  String get qzThisItem;

  /// No description provided for @qzBin.
  ///
  /// In en, this message translates to:
  /// **'BIN'**
  String get qzBin;

  /// No description provided for @qzExamples.
  ///
  /// In en, this message translates to:
  /// **'EXAMPLES'**
  String get qzExamples;

  /// No description provided for @qzAccepts.
  ///
  /// In en, this message translates to:
  /// **'ACCEPTS'**
  String get qzAccepts;

  /// No description provided for @qzOptionsTable.
  ///
  /// In en, this message translates to:
  /// **'Table 1. The answer options'**
  String get qzOptionsTable;

  /// No description provided for @qzOption.
  ///
  /// In en, this message translates to:
  /// **'OPTION'**
  String get qzOption;

  /// No description provided for @qzStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get qzStatus;

  /// No description provided for @qzCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get qzCorrectAnswer;

  /// No description provided for @qzYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get qzYourAnswer;

  /// No description provided for @qzAiGraded.
  ///
  /// In en, this message translates to:
  /// **'AI graded · check with your teacher'**
  String get qzAiGraded;

  /// No description provided for @qzReviewedBank.
  ///
  /// In en, this message translates to:
  /// **'Reviewed question bank'**
  String get qzReviewedBank;

  /// No description provided for @qzAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI generated · not reviewed'**
  String get qzAiGenerated;

  /// No description provided for @qzSugFullMark.
  ///
  /// In en, this message translates to:
  /// **'Show a full-mark answer'**
  String get qzSugFullMark;

  /// No description provided for @qzSugKeyTerms.
  ///
  /// In en, this message translates to:
  /// **'Explain key terms'**
  String get qzSugKeyTerms;

  /// No description provided for @qzSugHint.
  ///
  /// In en, this message translates to:
  /// **'Give me a hint'**
  String get qzSugHint;

  /// No description provided for @qzSugSimpler.
  ///
  /// In en, this message translates to:
  /// **'Say it simpler'**
  String get qzSugSimpler;

  /// No description provided for @qzCoach.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI coach'**
  String get qzCoach;

  /// No description provided for @qzSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get qzSent;

  /// No description provided for @qzPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get qzPlaying;

  /// No description provided for @qzAskScore.
  ///
  /// In en, this message translates to:
  /// **'Ask ELIOS AI about your score…'**
  String get qzAskScore;

  /// No description provided for @qzAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask ELIOS AI…'**
  String get qzAsk;

  /// No description provided for @qzSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get qzSend;

  /// No description provided for @qzListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get qzListen;

  /// No description provided for @qzCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get qzCopy;

  /// No description provided for @qzWhichItem.
  ///
  /// In en, this message translates to:
  /// **'Which item is this?'**
  String get qzWhichItem;

  /// No description provided for @qzNotThis.
  ///
  /// In en, this message translates to:
  /// **'Not this?'**
  String get qzNotThis;

  /// No description provided for @qzMinimise.
  ///
  /// In en, this message translates to:
  /// **'Minimise'**
  String get qzMinimise;

  /// No description provided for @qzMinimiseQuiz.
  ///
  /// In en, this message translates to:
  /// **'Minimise quiz'**
  String get qzMinimiseQuiz;

  /// No description provided for @qzCloseQuiz.
  ///
  /// In en, this message translates to:
  /// **'Close quiz'**
  String get qzCloseQuiz;

  /// No description provided for @qzReadToMe.
  ///
  /// In en, this message translates to:
  /// **'Read it to me'**
  String get qzReadToMe;

  /// No description provided for @qzExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get qzExplanation;

  /// No description provided for @ovEssayMax.
  ///
  /// In en, this message translates to:
  /// **'Essay · max 150 words'**
  String get ovEssayMax;

  /// No description provided for @ovPendingSub.
  ///
  /// In en, this message translates to:
  /// **'Answer saved. No score yet.'**
  String get ovPendingSub;

  /// No description provided for @ovEssayScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}/10 · +{score} XP'**
  String ovEssayScore(Object score);

  /// No description provided for @ovGood.
  ///
  /// In en, this message translates to:
  /// **'Good answer!'**
  String get ovGood;

  /// No description provided for @ovNeedsWork.
  ///
  /// In en, this message translates to:
  /// **'A few points need work.'**
  String get ovNeedsWork;

  /// No description provided for @ovRight.
  ///
  /// In en, this message translates to:
  /// **'Correct! +10 XP'**
  String get ovRight;

  /// No description provided for @ovWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite right'**
  String get ovWrong;

  /// No description provided for @ovRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'Right answer: {answer}'**
  String ovRightAnswer(Object answer);

  /// No description provided for @ovExplanationN.
  ///
  /// In en, this message translates to:
  /// **'Explanation for question {n}'**
  String ovExplanationN(Object n);

  /// No description provided for @ovNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation for this question yet.'**
  String get ovNoExplanation;

  /// No description provided for @ovCompareTable.
  ///
  /// In en, this message translates to:
  /// **'Waste category comparison'**
  String get ovCompareTable;

  /// No description provided for @ovReference.
  ///
  /// In en, this message translates to:
  /// **'Reference answer: {answer}'**
  String ovReference(Object answer);

  /// No description provided for @ovCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ovCategory;

  /// No description provided for @ovMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get ovMaterial;

  /// No description provided for @ovAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get ovAccepted;

  /// No description provided for @ovCriteria.
  ///
  /// In en, this message translates to:
  /// **'Criteria'**
  String get ovCriteria;

  /// No description provided for @ovMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get ovMax;

  /// No description provided for @ovAwarded.
  ///
  /// In en, this message translates to:
  /// **'Awarded'**
  String get ovAwarded;

  /// No description provided for @ovComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get ovComment;

  /// No description provided for @ovFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish quiz ✓'**
  String get ovFinish;

  /// No description provided for @ovNext.
  ///
  /// In en, this message translates to:
  /// **'Next question →'**
  String get ovNext;

  /// No description provided for @ovAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Correction Assistant'**
  String get ovAssistant;

  /// No description provided for @ovAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI...'**
  String get ovAskAi;

  /// No description provided for @ovVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ovVoice;

  /// No description provided for @lqTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get lqTitle;

  /// No description provided for @lqCompletedBest.
  ///
  /// In en, this message translates to:
  /// **' Completed with best score {score}%.'**
  String lqCompletedBest(Object score);

  /// No description provided for @lqBest.
  ///
  /// In en, this message translates to:
  /// **' Best score {score}%.'**
  String lqBest(Object score);

  /// No description provided for @lqUsedAttempt.
  ///
  /// In en, this message translates to:
  /// **'You have already used your one quiz attempt.{scoreText}'**
  String lqUsedAttempt(Object scoreText);

  /// No description provided for @lqOnceBody.
  ///
  /// In en, this message translates to:
  /// **'This quiz can only be attempted once. Once you start, you must finish it before leaving.'**
  String get lqOnceBody;

  /// No description provided for @lqFinishBody.
  ///
  /// In en, this message translates to:
  /// **'This quiz has only one attempt. Please finish all questions before leaving.'**
  String get lqFinishBody;

  /// No description provided for @lqLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading quiz questions'**
  String get lqLoading;

  /// No description provided for @lqLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Quiz questions could not be loaded.'**
  String get lqLoadFailed;

  /// No description provided for @lqCheckFirestore.
  ///
  /// In en, this message translates to:
  /// **'Check the Firestore connection and try again.'**
  String get lqCheckFirestore;

  /// No description provided for @lqBackToQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Back to Quizzes'**
  String get lqBackToQuizzes;

  /// No description provided for @lqNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Quiz questions are not available yet.'**
  String get lqNotAvailable;

  /// No description provided for @lqIntro.
  ///
  /// In en, this message translates to:
  /// **'Test your understanding of waste management and how ELIOS classifies materials. Each quiz has one attempt.'**
  String get lqIntro;

  /// No description provided for @lqSetsFailed.
  ///
  /// In en, this message translates to:
  /// **'Quiz sets could not be loaded.'**
  String get lqSetsFailed;

  /// No description provided for @lqNoPublished.
  ///
  /// In en, this message translates to:
  /// **'No published quizzes are available.'**
  String get lqNoPublished;

  /// No description provided for @lqCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get lqCompleted;

  /// No description provided for @lqAttemptUsed.
  ///
  /// In en, this message translates to:
  /// **'Attempt used'**
  String get lqAttemptUsed;

  /// No description provided for @lqBestScore.
  ///
  /// In en, this message translates to:
  /// **'best score {score}%'**
  String lqBestScore(Object score);

  /// No description provided for @lqReviewNew.
  ///
  /// In en, this message translates to:
  /// **'review for new attempts only'**
  String get lqReviewNew;

  /// No description provided for @lqQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String lqQuestions(Object count);

  /// No description provided for @lqOneAttempt.
  ///
  /// In en, this message translates to:
  /// **'one attempt'**
  String get lqOneAttempt;

  /// No description provided for @lqReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get lqReview;

  /// No description provided for @lqDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lqDone;

  /// No description provided for @lqUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get lqUsed;

  /// No description provided for @lqCounter.
  ///
  /// In en, this message translates to:
  /// **'Question {n} / {total}'**
  String lqCounter(Object n, Object total);

  /// No description provided for @lqCorrectExpl.
  ///
  /// In en, this message translates to:
  /// **'Correct: {explanation}'**
  String lqCorrectExpl(Object explanation);

  /// No description provided for @lqNotQuiteExpl.
  ///
  /// In en, this message translates to:
  /// **'Not quite: {explanation}'**
  String lqNotQuiteExpl(Object explanation);

  /// No description provided for @lqNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get lqNotQuite;

  /// No description provided for @lqViewResults.
  ///
  /// In en, this message translates to:
  /// **'View results'**
  String get lqViewResults;

  /// No description provided for @lqImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get lqImageUnavailable;

  /// No description provided for @lqScored.
  ///
  /// In en, this message translates to:
  /// **'You scored {score} out of {total}.'**
  String lqScored(Object score, Object total);

  /// No description provided for @lqBackLower.
  ///
  /// In en, this message translates to:
  /// **'Back to quizzes'**
  String get lqBackLower;

  /// No description provided for @lqReviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get lqReviewAnswers;

  /// No description provided for @rvTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz review'**
  String get rvTitle;

  /// No description provided for @rvScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get rvScore;

  /// No description provided for @rvPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get rvPercent;

  /// No description provided for @rvPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get rvPassed;

  /// No description provided for @rvQuestionN.
  ///
  /// In en, this message translates to:
  /// **'Question {n}'**
  String rvQuestionN(Object n);

  /// No description provided for @rvNotAnswered.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get rvNotAnswered;

  /// No description provided for @rvUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown answer'**
  String get rvUnknown;

  /// No description provided for @pqResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Physics Quiz Results'**
  String get pqResultsTitle;

  /// No description provided for @pqTitle.
  ///
  /// In en, this message translates to:
  /// **'Physics quiz'**
  String get pqTitle;

  /// No description provided for @pqCounter.
  ///
  /// In en, this message translates to:
  /// **'Question {n} / {total}'**
  String pqCounter(Object n, Object total);

  /// No description provided for @pqAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced physics'**
  String get pqAdvanced;

  /// No description provided for @pqWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get pqWrong;

  /// No description provided for @pqSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get pqSeeResults;

  /// No description provided for @pqNext.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get pqNext;

  /// No description provided for @pqDone.
  ///
  /// In en, this message translates to:
  /// **'Physics Quiz Complete'**
  String get pqDone;

  /// No description provided for @pqScore.
  ///
  /// In en, this message translates to:
  /// **'Your score: {score} / {total}'**
  String pqScore(Object score, Object total);

  /// No description provided for @pqBackMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to Menu'**
  String get pqBackMenu;

  /// No description provided for @tpNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Not used yet'**
  String get tpNotUsed;

  /// No description provided for @tpReady.
  ///
  /// In en, this message translates to:
  /// **'Ready ({model})'**
  String tpReady(Object model);

  /// No description provided for @tpOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected, bank mode'**
  String get tpOffline;

  /// No description provided for @lnWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Learn'**
  String get lnWelcome;

  /// No description provided for @lnWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Start with {bin}: {count} short lessons, then try the quiz.'**
  String lnWelcomeBody(Object bin, Object count);

  /// No description provided for @lnStartModule1.
  ///
  /// In en, this message translates to:
  /// **'Start module 1'**
  String get lnStartModule1;

  /// No description provided for @lnTestElio.
  ///
  /// In en, this message translates to:
  /// **'Test how ELIOS sorts waste.'**
  String get lnTestElio;

  /// No description provided for @lnQuizzesTest.
  ///
  /// In en, this message translates to:
  /// **'{count} quizzes. Test how ELIOS sorts waste.'**
  String lnQuizzesTest(Object count);

  /// No description provided for @lnTakeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take quiz'**
  String get lnTakeQuiz;

  /// No description provided for @lnYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your learning progress'**
  String get lnYourProgress;

  /// No description provided for @lnNoModulesStarted.
  ///
  /// In en, this message translates to:
  /// **'No modules started yet'**
  String get lnNoModulesStarted;

  /// No description provided for @lnModulesInProgress.
  ///
  /// In en, this message translates to:
  /// **'{started} of {total} modules in progress'**
  String lnModulesInProgress(Object started, Object total);

  /// No description provided for @lnOverall.
  ///
  /// In en, this message translates to:
  /// **'{percent}% overall completion'**
  String lnOverall(Object percent);

  /// No description provided for @lnCourseModules.
  ///
  /// In en, this message translates to:
  /// **'Course modules'**
  String get lnCourseModules;

  /// No description provided for @lnSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get lnSeeAll;

  /// No description provided for @lnContinueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get lnContinueLearning;

  /// No description provided for @lnAllLessons.
  ///
  /// In en, this message translates to:
  /// **'All lessons'**
  String get lnAllLessons;

  /// No description provided for @lnNothingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Nothing in progress yet. Lessons you open will wait for you here.'**
  String get lnNothingInProgress;

  /// No description provided for @lnWatchLearn.
  ///
  /// In en, this message translates to:
  /// **'Watch and learn'**
  String get lnWatchLearn;

  /// No description provided for @lnVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video} other{{count} videos}}'**
  String lnVideoCount(num count);

  /// No description provided for @lnVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get lnVideos;

  /// No description provided for @lnNoVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos published yet.'**
  String get lnNoVideos;

  /// No description provided for @lnPhysicsSims.
  ///
  /// In en, this message translates to:
  /// **'Physics simulations'**
  String get lnPhysicsSims;

  /// No description provided for @lnModuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 module} other{{count} modules}}'**
  String lnModuleCount(num count);

  /// No description provided for @lnSimTag.
  ///
  /// In en, this message translates to:
  /// **'Simulation · {tag}'**
  String lnSimTag(Object tag);

  /// No description provided for @lnGuides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get lnGuides;

  /// No description provided for @lnNoGuides.
  ///
  /// In en, this message translates to:
  /// **'No guides published yet.'**
  String get lnNoGuides;

  /// No description provided for @lnModuleN.
  ///
  /// In en, this message translates to:
  /// **'Module {n}'**
  String lnModuleN(Object n);

  /// No description provided for @lnGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get lnGuide;

  /// No description provided for @lnDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lnDone;

  /// No description provided for @lnNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get lnNew;

  /// No description provided for @lnLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Learning modules could not be loaded.'**
  String get lnLoadFailed;

  /// No description provided for @lnLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check the connection to ELIOS or the internet, then try again. Lessons you already opened still work offline.'**
  String get lnLoadFailedBody;

  /// No description provided for @lnOpenOffline.
  ///
  /// In en, this message translates to:
  /// **'Open offline lessons'**
  String get lnOpenOffline;

  /// No description provided for @lnNoModules.
  ///
  /// In en, this message translates to:
  /// **'No learning modules available yet.'**
  String get lnNoModules;

  /// No description provided for @lnNoModulesBody.
  ///
  /// In en, this message translates to:
  /// **'New lessons appear here as soon as they are published.'**
  String get lnNoModulesBody;

  /// No description provided for @lnNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get lnNothingHere;

  /// No description provided for @lnVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get lnVideo;

  /// No description provided for @lnSimulations.
  ///
  /// In en, this message translates to:
  /// **'Simulations'**
  String get lnSimulations;

  /// No description provided for @lnOfflineLessons.
  ///
  /// In en, this message translates to:
  /// **'Offline lessons'**
  String get lnOfflineLessons;

  /// No description provided for @lnLoadingOffline.
  ///
  /// In en, this message translates to:
  /// **'Loading offline lessons'**
  String get lnLoadingOffline;

  /// No description provided for @lnOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Guides you opened before work offline. Videos need the internet.'**
  String get lnOfflineNote;

  /// No description provided for @lnNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No lessons saved on this device yet.'**
  String get lnNoSaved;

  /// No description provided for @lnPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get lnPlayVideo;

  /// No description provided for @lnOpenGuide.
  ///
  /// In en, this message translates to:
  /// **'Open guide'**
  String get lnOpenGuide;

  /// No description provided for @lnContinueVideo.
  ///
  /// In en, this message translates to:
  /// **'Continue video · {pct}%'**
  String lnContinueVideo(Object pct);

  /// No description provided for @lnContinueGuide.
  ///
  /// In en, this message translates to:
  /// **'Continue guide · {pct}%'**
  String lnContinueGuide(Object pct);

  /// No description provided for @lnWatchAgain.
  ///
  /// In en, this message translates to:
  /// **'Watch again'**
  String get lnWatchAgain;

  /// No description provided for @lnReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get lnReadAgain;

  /// No description provided for @lnLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get lnLesson;

  /// No description provided for @lnDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get lnDuration;

  /// No description provided for @lnReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get lnReading;

  /// No description provided for @lnPositionOf.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total}'**
  String lnPositionOf(Object n, Object total);

  /// No description provided for @lnWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get lnWatched;

  /// No description provided for @lnRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get lnRead;

  /// No description provided for @lnAbout.
  ///
  /// In en, this message translates to:
  /// **'About this lesson'**
  String get lnAbout;

  /// No description provided for @lnGuidesTab.
  ///
  /// In en, this message translates to:
  /// **'{count} Guides'**
  String lnGuidesTab(Object count);

  /// No description provided for @lnVideosTab.
  ///
  /// In en, this message translates to:
  /// **'{count} Videos'**
  String lnVideosTab(Object count);

  /// No description provided for @lnQuizTab.
  ///
  /// In en, this message translates to:
  /// **'{count} Quiz'**
  String lnQuizTab(Object count);

  /// No description provided for @lnNoQuizModule.
  ///
  /// In en, this message translates to:
  /// **'No quiz for this module yet.'**
  String get lnNoQuizModule;

  /// No description provided for @lnNothingModule.
  ///
  /// In en, this message translates to:
  /// **'Nothing here for this module yet.'**
  String get lnNothingModule;

  /// No description provided for @lnThisLesson.
  ///
  /// In en, this message translates to:
  /// **'this lesson'**
  String get lnThisLesson;

  /// No description provided for @lnMyProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get lnMyProgress;

  /// No description provided for @lnNoProgress.
  ///
  /// In en, this message translates to:
  /// **'No progress yet.'**
  String get lnNoProgress;

  /// No description provided for @lnNoProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Open a lesson, a simulation or a quiz and your progress shows up here.'**
  String get lnNoProgressBody;

  /// No description provided for @lnInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get lnInProgress;

  /// No description provided for @lnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get lnCompleted;

  /// No description provided for @lnSimProgress.
  ///
  /// In en, this message translates to:
  /// **'Simulation progress'**
  String get lnSimProgress;

  /// No description provided for @lnSimsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} modules done'**
  String lnSimsDone(Object done, Object total);

  /// No description provided for @lnPercentDone.
  ///
  /// In en, this message translates to:
  /// **'{percent}% done'**
  String lnPercentDone(Object percent);

  /// No description provided for @lnAllComplete.
  ///
  /// In en, this message translates to:
  /// **'Every module is complete.'**
  String get lnAllComplete;

  /// No description provided for @lnNoneComplete.
  ///
  /// In en, this message translates to:
  /// **'No module completed yet.'**
  String get lnNoneComplete;

  /// No description provided for @lnMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String lnMinutes(Object count);

  /// No description provided for @lnLessonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 lesson} other{{count} lessons}}'**
  String lnLessonCount(num count);

  /// No description provided for @lnQuizHistory.
  ///
  /// In en, this message translates to:
  /// **'Quiz history'**
  String get lnQuizHistory;

  /// No description provided for @lnQuizHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Quizzes you finish are listed here with your best score.'**
  String get lnQuizHistoryHint;

  /// No description provided for @lnBinQuiz.
  ///
  /// In en, this message translates to:
  /// **'{bin} quiz'**
  String lnBinQuiz(Object bin);

  /// No description provided for @lnBest.
  ///
  /// In en, this message translates to:
  /// **'Best {score}%'**
  String lnBest(Object score);

  /// No description provided for @lnGuideCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 guide} other{{count} guides}}'**
  String lnGuideCount(num count);

  /// No description provided for @lnNoVideosModule.
  ///
  /// In en, this message translates to:
  /// **'No videos in this module yet.'**
  String get lnNoVideosModule;

  /// No description provided for @lnNoGuidesModule.
  ///
  /// In en, this message translates to:
  /// **'No guides in this module yet.'**
  String get lnNoGuidesModule;

  /// No description provided for @lnSimForModule.
  ///
  /// In en, this message translates to:
  /// **'Simulation for this module'**
  String get lnSimForModule;

  /// No description provided for @lnOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get lnOpen;

  /// No description provided for @lnNoQuizPublished.
  ///
  /// In en, this message translates to:
  /// **'No quiz published for this module yet.'**
  String get lnNoQuizPublished;

  /// No description provided for @lnLoadingGuide.
  ///
  /// In en, this message translates to:
  /// **'Loading guide'**
  String get lnLoadingGuide;

  /// No description provided for @lnCheckOpenAgain.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and open the guide again.'**
  String get lnCheckOpenAgain;

  /// No description provided for @lnPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get lnPrevPage;

  /// No description provided for @lnPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {n} of {total}'**
  String lnPageOf(Object n, Object total);

  /// No description provided for @lnPage.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String lnPage(Object n);

  /// No description provided for @lnNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get lnNextPage;

  /// No description provided for @lnVideoTag.
  ///
  /// In en, this message translates to:
  /// **'Video · {tag}'**
  String lnVideoTag(Object tag);

  /// No description provided for @lnGuidePart.
  ///
  /// In en, this message translates to:
  /// **'Guide · Part {n}'**
  String lnGuidePart(Object n);

  /// No description provided for @lnStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get lnStart;

  /// No description provided for @lnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get lnContinue;

  /// No description provided for @lnModuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Module {label}'**
  String lnModuleLabel(Object label);

  /// No description provided for @lnVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video {title}'**
  String lnVideoLabel(Object title);

  /// No description provided for @lnSimLabel.
  ///
  /// In en, this message translates to:
  /// **'Simulation {title}'**
  String lnSimLabel(Object title);

  /// No description provided for @lnLoadingModules.
  ///
  /// In en, this message translates to:
  /// **'Loading learning modules'**
  String get lnLoadingModules;

  /// No description provided for @lnLoadingLesson.
  ///
  /// In en, this message translates to:
  /// **'Loading lesson'**
  String get lnLoadingLesson;

  /// No description provided for @lnAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer {letter}: {label}'**
  String lnAnswerLabel(Object letter, Object label);

  /// No description provided for @lnCorrectSuffix.
  ///
  /// In en, this message translates to:
  /// **', correct'**
  String get lnCorrectSuffix;

  /// No description provided for @lnWrongSuffix.
  ///
  /// In en, this message translates to:
  /// **', wrong'**
  String get lnWrongSuffix;

  /// No description provided for @lnTabTheory.
  ///
  /// In en, this message translates to:
  /// **'Theory'**
  String get lnTabTheory;

  /// No description provided for @lnTabFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get lnTabFormula;

  /// No description provided for @lnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get lnStatus;

  /// No description provided for @lnBackToHub.
  ///
  /// In en, this message translates to:
  /// **'Back to learning hub'**
  String get lnBackToHub;

  /// No description provided for @openProfileMenu.
  ///
  /// In en, this message translates to:
  /// **'Open profile menu'**
  String get openProfileMenu;

  /// No description provided for @closeMenu.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get closeMenu;

  /// No description provided for @navigationMenu.
  ///
  /// In en, this message translates to:
  /// **'Navigation menu'**
  String get navigationMenu;

  /// No description provided for @dismissNotification.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notification'**
  String get dismissNotification;

  /// No description provided for @wqCannotCrop.
  ///
  /// In en, this message translates to:
  /// **'The item could not be cut out of the photo. Try scanning again.'**
  String get wqCannotCrop;

  /// No description provided for @wqNoCleanPhoto.
  ///
  /// In en, this message translates to:
  /// **'The original photo without annotations is not available yet. Update the camera firmware, then scan again.'**
  String get wqNoCleanPhoto;

  /// No description provided for @wqNotRecognised.
  ///
  /// In en, this message translates to:
  /// **'The item in the photo was not recognised yet.'**
  String get wqNotRecognised;

  /// No description provided for @wqPickFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick one answer first. After that you can ask anything about this question.'**
  String get wqPickFirst;

  /// No description provided for @wqWriteFirst.
  ///
  /// In en, this message translates to:
  /// **'Write your answer and send it. After it is graded you can ask more.'**
  String get wqWriteFirst;

  /// No description provided for @wqFallbackAi.
  ///
  /// In en, this message translates to:
  /// **'This is a backup question because the AI couldn\'t write one. {reason}'**
  String wqFallbackAi(Object reason);

  /// No description provided for @wqFallbackGeneric.
  ///
  /// In en, this message translates to:
  /// **'This is a general question because this item is not in the question bank yet.'**
  String get wqFallbackGeneric;

  /// No description provided for @wqBankNotice.
  ///
  /// In en, this message translates to:
  /// **'The AI is not connected, so this question is from the question bank. Check the internet.'**
  String get wqBankNotice;

  /// No description provided for @wqRight.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get wqRight;

  /// No description provided for @wqWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. The right answer: {answer}.'**
  String wqWrong(Object answer);

  /// No description provided for @wqEssayAnswer.
  ///
  /// In en, this message translates to:
  /// **'Essay answer'**
  String get wqEssayAnswer;

  /// No description provided for @wqSavedNotGraded.
  ///
  /// In en, this message translates to:
  /// **'Answer saved, but the AI couldn\'t grade it yet. {reason}'**
  String wqSavedNotGraded(Object reason);

  /// No description provided for @wqForFullMarks.
  ///
  /// In en, this message translates to:
  /// **'For full marks: {tip}'**
  String wqForFullMarks(Object tip);

  /// No description provided for @wqScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}/10.'**
  String wqScore(Object score);

  /// No description provided for @wqAnswerFirstMc.
  ///
  /// In en, this message translates to:
  /// **'Answer the question first. Once you pick an answer, I\'ll explain it and answer your questions about it.'**
  String get wqAnswerFirstMc;

  /// No description provided for @wqAnswerFirstEssay.
  ///
  /// In en, this message translates to:
  /// **'Send your essay answer first. Then I\'ll grade it and we can talk about it.'**
  String get wqAnswerFirstEssay;

  /// No description provided for @wqScanFirst.
  ///
  /// In en, this message translates to:
  /// **'Scan an item first to start the quiz, then we can talk.'**
  String get wqScanFirst;

  /// No description provided for @wqAiCannotAnswer.
  ///
  /// In en, this message translates to:
  /// **'The AI can\'t answer yet. {reason}'**
  String wqAiCannotAnswer(Object reason);

  /// No description provided for @wqCheckInternet.
  ///
  /// In en, this message translates to:
  /// **'Check the internet connection, then try again.'**
  String get wqCheckInternet;

  /// No description provided for @wqTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again.'**
  String get wqTryAgain;

  /// No description provided for @wqSkipped.
  ///
  /// In en, this message translates to:
  /// **'Question {n} skipped.'**
  String wqSkipped(Object n);

  /// No description provided for @wqSkippedCount.
  ///
  /// In en, this message translates to:
  /// **' {count} questions skipped.'**
  String wqSkippedCount(Object count);

  /// No description provided for @wqSessionDone.
  ///
  /// In en, this message translates to:
  /// **'Session done! Correct answers: {correct} of {total}.{skipped} Scan another item for new questions.'**
  String wqSessionDone(Object correct, Object total, Object skipped);

  /// No description provided for @wqQuestionReady.
  ///
  /// In en, this message translates to:
  /// **'Question ready'**
  String get wqQuestionReady;

  /// No description provided for @r1LinkLost.
  ///
  /// In en, this message translates to:
  /// **'The robot connection dropped. The robot stopped.'**
  String get r1LinkLost;

  /// No description provided for @r1NotConnected.
  ///
  /// In en, this message translates to:
  /// **'robot not connected'**
  String get r1NotConnected;

  /// No description provided for @r1Stopped.
  ///
  /// In en, this message translates to:
  /// **'Robot stopped ({reason}). Press \"Continue\" when it is safe.'**
  String r1Stopped(Object reason);

  /// No description provided for @r1Stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get r1Stop;

  /// No description provided for @r1Picking.
  ///
  /// In en, this message translates to:
  /// **'The robot is picking up the item'**
  String get r1Picking;

  /// No description provided for @r1NotIdentified.
  ///
  /// In en, this message translates to:
  /// **'The item could not be identified. Drive on.'**
  String get r1NotIdentified;

  /// No description provided for @r1NoConfirm.
  ///
  /// In en, this message translates to:
  /// **'No confirmation. The robot did not pick up the item.'**
  String get r1NoConfirm;

  /// No description provided for @r1Timeout.
  ///
  /// In en, this message translates to:
  /// **'Time is up. The robot did not pick up the item.'**
  String get r1Timeout;

  /// No description provided for @r1TooLong.
  ///
  /// In en, this message translates to:
  /// **'The robot took too long. The robot stopped.'**
  String get r1TooLong;

  /// No description provided for @r1Resuming.
  ///
  /// In en, this message translates to:
  /// **'The robot is carrying on'**
  String get r1Resuming;

  /// No description provided for @r1PickFailed.
  ///
  /// In en, this message translates to:
  /// **'The item was not picked up. The robot stopped.'**
  String get r1PickFailed;

  /// No description provided for @r1Done.
  ///
  /// In en, this message translates to:
  /// **'Done! The robot can drive again.'**
  String get r1Done;

  /// No description provided for @r1ConfirmFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm first'**
  String get r1ConfirmFirst;

  /// No description provided for @r1WhichBin.
  ///
  /// In en, this message translates to:
  /// **'Which bin does it go in?'**
  String get r1WhichBin;

  /// No description provided for @r1RobotChose.
  ///
  /// In en, this message translates to:
  /// **'The robot chose: {bin}'**
  String r1RobotChose(Object bin);

  /// No description provided for @r1PositionOk.
  ///
  /// In en, this message translates to:
  /// **'Is the position right?'**
  String get r1PositionOk;

  /// No description provided for @r1Forward.
  ///
  /// In en, this message translates to:
  /// **'Forward a little'**
  String get r1Forward;

  /// No description provided for @r1Back.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get r1Back;

  /// No description provided for @r1PressPick.
  ///
  /// In en, this message translates to:
  /// **'Press Pick up'**
  String get r1PressPick;

  /// No description provided for @r1Hand.
  ///
  /// In en, this message translates to:
  /// **'A hand! The robot is pausing.'**
  String get r1Hand;

  /// No description provided for @r1NoReply.
  ///
  /// In en, this message translates to:
  /// **'The robot did not reply ({cmd}: {reason}). The robot stopped.'**
  String r1NoReply(Object cmd, Object reason);

  /// No description provided for @h3Title.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get h3Title;

  /// No description provided for @h3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan results, quizzes & XP'**
  String get h3Subtitle;

  /// No description provided for @h3Back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get h3Back;

  /// No description provided for @h3All.
  ///
  /// In en, this message translates to:
  /// **'All scans'**
  String get h3All;

  /// No description provided for @h3CatB3.
  ///
  /// In en, this message translates to:
  /// **'B3'**
  String get h3CatB3;

  /// No description provided for @h3CatB3Long.
  ///
  /// In en, this message translates to:
  /// **'B3 · Hazardous'**
  String get h3CatB3Long;

  /// No description provided for @h3CatRecyclable.
  ///
  /// In en, this message translates to:
  /// **'Recyclable'**
  String get h3CatRecyclable;

  /// No description provided for @h3CatOrganic.
  ///
  /// In en, this message translates to:
  /// **'Organic'**
  String get h3CatOrganic;

  /// No description provided for @h3CatResidu.
  ///
  /// In en, this message translates to:
  /// **'Residual'**
  String get h3CatResidu;

  /// No description provided for @h3Easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get h3Easy;

  /// No description provided for @h3Medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get h3Medium;

  /// No description provided for @h3Hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get h3Hard;

  /// No description provided for @h3Today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get h3Today;

  /// No description provided for @h3Yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get h3Yesterday;

  /// No description provided for @h3LoadFailed.
  ///
  /// In en, this message translates to:
  /// **'History couldn\'t be loaded'**
  String get h3LoadFailed;

  /// No description provided for @h3RecentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent scans'**
  String get h3RecentScans;

  /// No description provided for @h3ScanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scan} other{{count} scans}}'**
  String h3ScanCount(int count);

  /// No description provided for @h3NoScansInCategory.
  ///
  /// In en, this message translates to:
  /// **'No scans in this category yet.'**
  String get h3NoScansInCategory;

  /// No description provided for @h3Trophies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} XP}}'**
  String h3Trophies(int count);

  /// No description provided for @h3ToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{count} XP to Level {level}'**
  String h3ToNextLevel(Object count, Object level);

  /// No description provided for @h3TopLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get h3TopLevel;

  /// No description provided for @h3SavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get h3SavedLocally;

  /// No description provided for @h3RowMeta.
  ///
  /// In en, this message translates to:
  /// **'{time} · {count, plural, =1{1 question} other{{count} questions}}'**
  String h3RowMeta(Object time, int count);

  /// No description provided for @h3DetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan detail'**
  String get h3DetailTitle;

  /// No description provided for @h3ExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get h3ExportPdf;

  /// No description provided for @h3DetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan detail couldn\'t be loaded'**
  String get h3DetailLoadFailed;

  /// No description provided for @h3DiffChip.
  ///
  /// In en, this message translates to:
  /// **'{level} · {count}Q'**
  String h3DiffChip(Object level, Object count);

  /// No description provided for @h3Questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get h3Questions;

  /// No description provided for @h3PdfFailed.
  ///
  /// In en, this message translates to:
  /// **'The PDF couldn\'t be exported. Try again.'**
  String get h3PdfFailed;

  /// No description provided for @h3Correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get h3Correct;

  /// No description provided for @h3Incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get h3Incorrect;

  /// No description provided for @h3AwaitingGrading.
  ///
  /// In en, this message translates to:
  /// **'Awaiting grading'**
  String get h3AwaitingGrading;

  /// No description provided for @h3EssayScore.
  ///
  /// In en, this message translates to:
  /// **'Score {score}/10'**
  String h3EssayScore(Object score);

  /// No description provided for @h3YourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get h3YourAnswer;

  /// No description provided for @h3CorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get h3CorrectAnswer;

  /// No description provided for @h3ReferenceAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reference answer'**
  String get h3ReferenceAnswer;

  /// No description provided for @h3SeeExplanation.
  ///
  /// In en, this message translates to:
  /// **'See explanation'**
  String get h3SeeExplanation;

  /// No description provided for @h3Listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get h3Listen;

  /// No description provided for @h3Pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get h3Pause;

  /// No description provided for @h3ReadingNow.
  ///
  /// In en, this message translates to:
  /// **'READING NOW'**
  String get h3ReadingNow;

  /// No description provided for @h3KeyIdea.
  ///
  /// In en, this message translates to:
  /// **'KEY IDEA'**
  String get h3KeyIdea;

  /// No description provided for @h3TryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get h3TryAgain;

  /// No description provided for @h3Translating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get h3Translating;

  /// No description provided for @h3Loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get h3Loading;

  /// No description provided for @h3EmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get h3EmptyTitle;

  /// No description provided for @h3EmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Scan an item with ELIOS and its quiz results and XP will show up here.'**
  String get h3EmptyBody;

  /// No description provided for @h3StartScan.
  ///
  /// In en, this message translates to:
  /// **'Start scanning'**
  String get h3StartScan;

  /// No description provided for @h3ExplanationTitle.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get h3ExplanationTitle;

  /// No description provided for @h3ExplanationMeta.
  ///
  /// In en, this message translates to:
  /// **'{item} · Q{index} of {total}'**
  String h3ExplanationMeta(Object item, Object index, Object total);

  /// No description provided for @h3WhyCorrect.
  ///
  /// In en, this message translates to:
  /// **'Why this is the right answer'**
  String get h3WhyCorrect;

  /// No description provided for @h3WhyWrong.
  ///
  /// In en, this message translates to:
  /// **'Why your answer isn\'t right'**
  String get h3WhyWrong;

  /// No description provided for @h3Feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get h3Feedback;

  /// No description provided for @h3HowTo.
  ///
  /// In en, this message translates to:
  /// **'How to do it'**
  String get h3HowTo;

  /// No description provided for @h3NextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get h3NextQuestion;

  /// No description provided for @h3ExplanationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The full explanation isn\'t available yet'**
  String get h3ExplanationUnavailable;

  /// No description provided for @h3PdfSaved.
  ///
  /// In en, this message translates to:
  /// **'PDF saved: {path}'**
  String h3PdfSaved(Object path);

  /// No description provided for @h3ExportQuestion.
  ///
  /// In en, this message translates to:
  /// **'Export this question'**
  String get h3ExportQuestion;

  /// No description provided for @h3ExportOnly.
  ///
  /// In en, this message translates to:
  /// **'Only Q{index} of {item} goes into the PDF.'**
  String h3ExportOnly(Object index, Object item);

  /// No description provided for @h3A4Pdf.
  ///
  /// In en, this message translates to:
  /// **'A4 · PDF'**
  String get h3A4Pdf;

  /// No description provided for @h3Include.
  ///
  /// In en, this message translates to:
  /// **'INCLUDE'**
  String get h3Include;

  /// No description provided for @h3IncAnswers.
  ///
  /// In en, this message translates to:
  /// **'Question and both answers'**
  String get h3IncAnswers;

  /// No description provided for @h3IncExplanation.
  ///
  /// In en, this message translates to:
  /// **'Full explanation and steps'**
  String get h3IncExplanation;

  /// No description provided for @h3IncPhoto.
  ///
  /// In en, this message translates to:
  /// **'Scan photo'**
  String get h3IncPhoto;

  /// No description provided for @h3IncNotes.
  ///
  /// In en, this message translates to:
  /// **'Space for my notes'**
  String get h3IncNotes;

  /// No description provided for @h3Share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get h3Share;

  /// No description provided for @h3SavePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get h3SavePdf;

  /// No description provided for @h3Saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get h3Saving;

  /// No description provided for @h3ShownInOriginal.
  ///
  /// In en, this message translates to:
  /// **'Shown in {language}, connect to translate'**
  String h3ShownInOriginal(Object language);

  /// No description provided for @h3KeyIdeaTitle.
  ///
  /// In en, this message translates to:
  /// **'Key idea'**
  String get h3KeyIdeaTitle;

  /// No description provided for @pdfQuestionHeader.
  ///
  /// In en, this message translates to:
  /// **'ELIOS | {item} | Q{index}'**
  String pdfQuestionHeader(Object item, Object index);

  /// No description provided for @pdfEssayScore.
  ///
  /// In en, this message translates to:
  /// **'Essay score'**
  String get pdfEssayScore;

  /// No description provided for @pdfReportTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS - Waste Quiz Report'**
  String get pdfReportTitle;

  /// No description provided for @pdfPageShort.
  ///
  /// In en, this message translates to:
  /// **'Page {page} / {total}'**
  String pdfPageShort(Object page, Object total);

  /// No description provided for @pdfFooter.
  ///
  /// In en, this message translates to:
  /// **'ELIOS Waste Sorting Education | Page {page} of {total} | Session ID: {id}'**
  String pdfFooter(Object page, Object total, Object id);

  /// No description provided for @pdfSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session information'**
  String get pdfSessionInfo;

  /// No description provided for @pdfPhoto.
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get pdfPhoto;

  /// No description provided for @pdfItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get pdfItem;

  /// No description provided for @pdfCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get pdfCategory;

  /// No description provided for @pdfDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date / time'**
  String get pdfDateTime;

  /// No description provided for @pdfDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get pdfDifficulty;

  /// No description provided for @pdfQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get pdfQuestionCount;

  /// No description provided for @pdfCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get pdfCorrect;

  /// No description provided for @pdfCorrectOf.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total}'**
  String pdfCorrectOf(Object correct, Object total);

  /// No description provided for @pdfTrophies.
  ///
  /// In en, this message translates to:
  /// **'XP earned'**
  String get pdfTrophies;

  /// No description provided for @pdfTrophyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} XP'**
  String pdfTrophyCount(Object count);

  /// No description provided for @pdfGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get pdfGrade;

  /// No description provided for @pdfQuestionLine.
  ///
  /// In en, this message translates to:
  /// **'Q{index}: {question}'**
  String pdfQuestionLine(Object index, Object question);

  /// No description provided for @pdfEssayLine.
  ///
  /// In en, this message translates to:
  /// **'{score} / 10 (+{trophies} XP)'**
  String pdfEssayLine(Object score, Object trophies);

  /// No description provided for @pdfNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation was saved for this question.'**
  String get pdfNoExplanation;

  /// No description provided for @pdfSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {title}'**
  String pdfSource(Object title);

  /// No description provided for @pdfBankTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS Question Bank'**
  String get pdfBankTitle;

  /// No description provided for @pdfSection.
  ///
  /// In en, this message translates to:
  /// **'section {section}'**
  String pdfSection(Object section);

  /// No description provided for @pdfPage.
  ///
  /// In en, this message translates to:
  /// **'p. {page}'**
  String pdfPage(Object page);

  /// No description provided for @pdfTableCategories.
  ///
  /// In en, this message translates to:
  /// **'Table 1. Waste category comparison'**
  String get pdfTableCategories;

  /// No description provided for @pdfTableScoring.
  ///
  /// In en, this message translates to:
  /// **'Table 1. Scoring breakdown'**
  String get pdfTableScoring;

  /// No description provided for @pdfColCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get pdfColCategory;

  /// No description provided for @pdfColMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get pdfColMaterial;

  /// No description provided for @pdfColAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get pdfColAccepted;

  /// No description provided for @pdfColCriterion.
  ///
  /// In en, this message translates to:
  /// **'Criterion'**
  String get pdfColCriterion;

  /// No description provided for @pdfColMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get pdfColMax;

  /// No description provided for @pdfColAwarded.
  ///
  /// In en, this message translates to:
  /// **'Awarded'**
  String get pdfColAwarded;

  /// No description provided for @pdfColComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get pdfColComment;

  /// No description provided for @a11yTrophies.
  ///
  /// In en, this message translates to:
  /// **'{count} XP'**
  String a11yTrophies(Object count);

  /// No description provided for @homeScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} · +{count} XP'**
  String homeScanSubtitle(Object date, Object count);

  /// No description provided for @a11yLabelValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String a11yLabelValue(Object label, Object value);

  /// No description provided for @a11yBinStat.
  ///
  /// In en, this message translates to:
  /// **'{bin} {count} scans, {percent}'**
  String a11yBinStat(Object bin, Object count, Object percent);

  /// No description provided for @a11yTopBin.
  ///
  /// In en, this message translates to:
  /// **', top bin'**
  String get a11yTopBin;

  /// No description provided for @homeScansUnit.
  ///
  /// In en, this message translates to:
  /// **' scans'**
  String get homeScansUnit;

  /// No description provided for @homeOpenHistory.
  ///
  /// In en, this message translates to:
  /// **'Open History'**
  String get homeOpenHistory;

  /// No description provided for @homeLatestScan.
  ///
  /// In en, this message translates to:
  /// **'Latest: {item} · {when}'**
  String homeLatestScan(String item, String when);

  /// No description provided for @homeMedalsOf.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} of {total}'**
  String homeMedalsOf(Object unlocked, Object total);

  /// No description provided for @a11yMedal.
  ///
  /// In en, this message translates to:
  /// **'{name}, {state}. {description}'**
  String a11yMedal(Object name, Object state, Object description);

  /// No description provided for @a11yUnlocked.
  ///
  /// In en, this message translates to:
  /// **'unlocked'**
  String get a11yUnlocked;

  /// No description provided for @a11yLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get a11yLocked;

  /// No description provided for @a11ySearchItem.
  ///
  /// In en, this message translates to:
  /// **'{title}, {subtitle}'**
  String a11ySearchItem(Object title, Object subtitle);

  /// No description provided for @learnQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String learnQuestionCount(int count);

  /// No description provided for @learnMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String learnMinutes(Object count);

  /// No description provided for @learnLessonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 lesson} other{{count} lessons}}'**
  String learnLessonCount(int count);

  /// No description provided for @a11yPercent.
  ///
  /// In en, this message translates to:
  /// **'{title}, {percent} percent'**
  String a11yPercent(Object title, Object percent);

  /// No description provided for @tipWaiting.
  ///
  /// In en, this message translates to:
  /// **'Hang on, I\'m looking for the robot! If it takes long, check the ELIOS Wi-Fi.'**
  String get tipWaiting;

  /// No description provided for @tipDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Uh-oh, I can\'t hear the robot. Walk closer to it or check that it\'s switched on.'**
  String get tipDisconnected;

  /// No description provided for @tipStopped.
  ///
  /// In en, this message translates to:
  /// **'The robot is STOPPED. Check the way is clear, then tap Continue.'**
  String get tipStopped;

  /// No description provided for @tipQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz time! Answer it, then we sort the item together.'**
  String get tipQuiz;

  /// No description provided for @tipDrive.
  ///
  /// In en, this message translates to:
  /// **'Drive around slowly and point my camera at an item to sort.'**
  String get tipDrive;

  /// No description provided for @tipPickZone.
  ///
  /// In en, this message translates to:
  /// **'Nice driving! The {item} is in the pick zone. Press PICK UP to grab it.'**
  String tipPickZone(Object item);

  /// No description provided for @tipLocked.
  ///
  /// In en, this message translates to:
  /// **'Got it! I locked on the {item}. Hold still while I look.'**
  String tipLocked(Object item);

  /// No description provided for @tipSeeItem.
  ///
  /// In en, this message translates to:
  /// **'I see a {item}. Drive closer, slowly.'**
  String tipSeeItem(Object item);

  /// No description provided for @ctlPlusTrophies.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String ctlPlusTrophies(Object count);

  /// No description provided for @guideReady.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready, Robot Pilot!'**
  String get guideReady;

  /// No description provided for @guideGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get guideGo;

  /// No description provided for @qzElapsed.
  ///
  /// In en, this message translates to:
  /// **'elapsed'**
  String get qzElapsed;

  /// No description provided for @qzWordCount.
  ///
  /// In en, this message translates to:
  /// **'{words} / {limit} words'**
  String qzWordCount(Object words, Object limit);

  /// No description provided for @wqCorrectOf.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String wqCorrectOf(Object correct, Object total);

  /// No description provided for @cfgCouldNotReach.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach ELIOS'**
  String get cfgCouldNotReach;

  /// No description provided for @cfgIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get cfgIpAddress;

  /// No description provided for @camMacFailed.
  ///
  /// In en, this message translates to:
  /// **'The Mac camera couldn\'t be opened ({error}).'**
  String camMacFailed(Object error);

  /// No description provided for @catExamplesOrganic.
  ///
  /// In en, this message translates to:
  /// **'Food scraps; Leftover cooked food; Coffee grounds and tea bags; Grass clippings and leaves; Eggshells'**
  String get catExamplesOrganic;

  /// No description provided for @catExamplesInorganic.
  ///
  /// In en, this message translates to:
  /// **'Plastic bottles and containers; Glass jars and bottles; Aluminium cans and foil; Paper and cardboard; Metal scraps'**
  String get catExamplesInorganic;

  /// No description provided for @catExamplesHazardous.
  ///
  /// In en, this message translates to:
  /// **'Batteries; Electronic waste; Fluorescent light bulbs; Paint and solvents; Pesticides and herbicides'**
  String get catExamplesHazardous;

  /// No description provided for @authNoUser.
  ///
  /// In en, this message translates to:
  /// **'No account found for that username.'**
  String get authNoUser;

  /// No description provided for @notifVideoDone.
  ///
  /// In en, this message translates to:
  /// **'Video completed'**
  String get notifVideoDone;

  /// No description provided for @notifVideoDoneMsg.
  ///
  /// In en, this message translates to:
  /// **'You completed a video lesson.'**
  String get notifVideoDoneMsg;

  /// No description provided for @notifGuideDone.
  ///
  /// In en, this message translates to:
  /// **'Guide completed'**
  String get notifGuideDone;

  /// No description provided for @notifGuideDoneMsg.
  ///
  /// In en, this message translates to:
  /// **'You completed a guide.'**
  String get notifGuideDoneMsg;

  /// No description provided for @notifQuizDone.
  ///
  /// In en, this message translates to:
  /// **'Quiz completed'**
  String get notifQuizDone;

  /// No description provided for @notifQuizDoneMsg.
  ///
  /// In en, this message translates to:
  /// **'Your quiz result has been saved.'**
  String get notifQuizDoneMsg;

  /// No description provided for @notifReview.
  ///
  /// In en, this message translates to:
  /// **'Quiz review available'**
  String get notifReview;

  /// No description provided for @notifReviewMsg.
  ///
  /// In en, this message translates to:
  /// **'You can now review your quiz answers.'**
  String get notifReviewMsg;

  /// No description provided for @notifSync.
  ///
  /// In en, this message translates to:
  /// **'Progress sync issue'**
  String get notifSync;

  /// No description provided for @notifSyncMsg.
  ///
  /// In en, this message translates to:
  /// **'Your progress could not be synced. Check your connection.'**
  String get notifSyncMsg;

  /// No description provided for @physDensityTag.
  ///
  /// In en, this message translates to:
  /// **'Module A · Environment'**
  String get physDensityTag;

  /// No description provided for @physDensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Waste Density'**
  String get physDensityTitle;

  /// No description provided for @physDensityDesc.
  ///
  /// In en, this message translates to:
  /// **'ELIOS sorts inorganic waste by density.'**
  String get physDensityDesc;

  /// No description provided for @physHeatTag.
  ///
  /// In en, this message translates to:
  /// **'Module B · Environment'**
  String get physHeatTag;

  /// No description provided for @physHeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Compost Heat & Thermodynamics'**
  String get physHeatTitle;

  /// No description provided for @physHeatDesc.
  ///
  /// In en, this message translates to:
  /// **'Microbes decomposing waste release heat over time.'**
  String get physHeatDesc;

  /// No description provided for @physTorqueTag.
  ///
  /// In en, this message translates to:
  /// **'Module C · Mechanics'**
  String get physTorqueTag;

  /// No description provided for @physTorqueTitle.
  ///
  /// In en, this message translates to:
  /// **'Robot Shoulder Torque'**
  String get physTorqueTitle;

  /// No description provided for @physTorqueDesc.
  ///
  /// In en, this message translates to:
  /// **'The ELIOS shoulder joint holds torque as the arm reaches out.'**
  String get physTorqueDesc;

  /// No description provided for @physWorkEnergyTag.
  ///
  /// In en, this message translates to:
  /// **'Module D · Mechanics'**
  String get physWorkEnergyTag;

  /// No description provided for @physWorkEnergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Work & Potential Energy'**
  String get physWorkEnergyTitle;

  /// No description provided for @physWorkEnergyDesc.
  ///
  /// In en, this message translates to:
  /// **'Lifting a load takes a measurable amount of work.'**
  String get physWorkEnergyDesc;

  /// No description provided for @physKinematicsTag.
  ///
  /// In en, this message translates to:
  /// **'Module E · Kinematics'**
  String get physKinematicsTag;

  /// No description provided for @physKinematicsTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS Speed'**
  String get physKinematicsTitle;

  /// No description provided for @physKinematicsDesc.
  ///
  /// In en, this message translates to:
  /// **'Uniform straight-line motion towards the waste pile.'**
  String get physKinematicsDesc;

  /// No description provided for @physPwmTag.
  ///
  /// In en, this message translates to:
  /// **'Module F · Electronics'**
  String get physPwmTag;

  /// No description provided for @physPwmTitle.
  ///
  /// In en, this message translates to:
  /// **'PWM & Motor Voltage'**
  String get physPwmTitle;

  /// No description provided for @physPwmDesc.
  ///
  /// In en, this message translates to:
  /// **'The duty cycle sets the average voltage of the wheel motors.'**
  String get physPwmDesc;

  /// No description provided for @physPowerTag.
  ///
  /// In en, this message translates to:
  /// **'Module G · Power'**
  String get physPowerTag;

  /// No description provided for @physPowerTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS Power & Battery'**
  String get physPowerTitle;

  /// No description provided for @physPowerDesc.
  ///
  /// In en, this message translates to:
  /// **'Managing how much power the robot parts use.'**
  String get physPowerDesc;

  /// No description provided for @physDeepDiveTag.
  ///
  /// In en, this message translates to:
  /// **'Deep-Dive · Waste Physics'**
  String get physDeepDiveTag;

  /// No description provided for @physDeepDiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Waste Deep-Dive Cards'**
  String get physDeepDiveTitle;

  /// No description provided for @physDeepDiveDesc.
  ///
  /// In en, this message translates to:
  /// **'A closer look: organic, inorganic and B3.'**
  String get physDeepDiveDesc;

  /// No description provided for @physQuizTag.
  ///
  /// In en, this message translates to:
  /// **'Evaluation'**
  String get physQuizTag;

  /// No description provided for @physQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Your Understanding (Quiz)'**
  String get physQuizTitle;

  /// No description provided for @physQuizDesc.
  ///
  /// In en, this message translates to:
  /// **'Test what you know about the physics behind the ELIOS robot.'**
  String get physQuizDesc;

  /// No description provided for @physLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get physLevelBeginner;

  /// No description provided for @physLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get physLevelIntermediate;

  /// No description provided for @physLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get physLevelAdvanced;

  /// No description provided for @physLevelAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get physLevelAllLevels;

  /// No description provided for @simDeepDive1.
  ///
  /// In en, this message translates to:
  /// **'Waste Deep-Dive'**
  String get simDeepDive1;

  /// No description provided for @simDeepDive2.
  ///
  /// In en, this message translates to:
  /// **'The Physics of Sorting Waste'**
  String get simDeepDive2;

  /// No description provided for @simDeepDive3.
  ///
  /// In en, this message translates to:
  /// **'Explore why each waste category is handled differently.'**
  String get simDeepDive3;

  /// No description provided for @simDeepDive4.
  ///
  /// In en, this message translates to:
  /// **'Pile Porosity'**
  String get simDeepDive4;

  /// No description provided for @simDeepDive5.
  ///
  /// In en, this message translates to:
  /// **'Low porosity (<25%). Air can hardly get in, which triggers anaerobic decomposition (methane).'**
  String get simDeepDive5;

  /// No description provided for @simDeepDive6.
  ///
  /// In en, this message translates to:
  /// **'Good porosity. Oxygen flows freely and aerobic composting works best.'**
  String get simDeepDive6;

  /// No description provided for @simDeepDive7.
  ///
  /// In en, this message translates to:
  /// **'Porosity is the percentage of empty space (filled with air) between the solid particles in a compost pile. High porosity = air can flow freely through the whole pile = the aerobic process (which needs oxygen) runs well. Low porosity = the pile is too dense = oxygen runs out quickly inside = anaerobic microbes take over.'**
  String get simDeepDive7;

  /// No description provided for @simDeepDive8.
  ///
  /// In en, this message translates to:
  /// **'Organic waste has no electrical (conductivity), optical (NIR reflectance) or hazardous chemical (volatility/reactivity) property that could be used as an automatic sorting signal. The only relevant physical variable is its own pore structure and moisture, because the goal is not to separate materials but to manage the biological breakdown itself.'**
  String get simDeepDive8;

  /// No description provided for @simDeepDive9.
  ///
  /// In en, this message translates to:
  /// **'ELIOS uses this principle in its spring-loaded gripper/pusher to test how hard or elastic an item is.'**
  String get simDeepDive9;

  /// No description provided for @simDeepDive10.
  ///
  /// In en, this message translates to:
  /// **'Compression (x)'**
  String get simDeepDive10;

  /// No description provided for @simDeepDive11.
  ///
  /// In en, this message translates to:
  /// **'⚠ Accuracy note: the peak wavelengths used in this simulation (e.g. PET ≈1660 nm, HDPE ≈1730 nm, PP ≈1410 nm) must be checked again against a valid industrial NIR sorting reference before release. Real NIR sensors measure absorbance peaks/valleys over ranges that can vary.'**
  String get simDeepDive11;

  /// No description provided for @simDeepDive12.
  ///
  /// In en, this message translates to:
  /// **'When metal moves through a changing magnetic field, eddy currents are induced inside it. They create an opposing magnetic field that pushes non-magnetic metals such as aluminium away from the magnet.'**
  String get simDeepDive12;

  /// No description provided for @simDeepDive13.
  ///
  /// In en, this message translates to:
  /// **'Inorganic materials (plastic, glass, metal) go through no biological process that needs managing (unlike organic waste), and most are not chemically reactive or hazardous (unlike B3). The most effective sorting signals are their stable physical properties: hardness (Hooke), optical identity (NIR) and magnetic/conductive behaviour (eddy currents).'**
  String get simDeepDive13;

  /// No description provided for @simDeepDive14.
  ///
  /// In en, this message translates to:
  /// **'The hotter a liquid or substance is, the more it tends to evaporate into a gas: this is vapour pressure. The Clausius-Clapeyron equation describes this non-linear (exponential) relationship.'**
  String get simDeepDive14;

  /// No description provided for @simDeepDive15.
  ///
  /// In en, this message translates to:
  /// **'⚠ Accuracy note: this simulation uses a qualitative, simplified approach, not a literal P–T curve with scientifically precise exponential constants. It only shows the trend (hotter = evaporates more easily = more dangerous).'**
  String get simDeepDive15;

  /// No description provided for @simDeepDive16.
  ///
  /// In en, this message translates to:
  /// **'Substance temperature'**
  String get simDeepDive16;

  /// No description provided for @simDeepDive17.
  ///
  /// In en, this message translates to:
  /// **'Incinerator temperature'**
  String get simDeepDive17;

  /// No description provided for @simDeepDive18.
  ///
  /// In en, this message translates to:
  /// **'Status: hazardous chemical bonds broken (safe)'**
  String get simDeepDive18;

  /// No description provided for @simDeepDive19.
  ///
  /// In en, this message translates to:
  /// **'Radiation intensity (I) drops exponentially as the shield thickness (x) increases.'**
  String get simDeepDive19;

  /// No description provided for @simDeepDive20.
  ///
  /// In en, this message translates to:
  /// **'⚠ Accuracy note: real attenuation coefficients depend strongly on the energy of the radiation particles (MeV) and on the specific shield material. The numbers below are illustrative and only show the relative order (gamma hardest, alpha easiest).'**
  String get simDeepDive20;

  /// No description provided for @simDeepDive21.
  ///
  /// In en, this message translates to:
  /// **'Alpha (α)'**
  String get simDeepDive21;

  /// No description provided for @simDeepDive22.
  ///
  /// In en, this message translates to:
  /// **'Shield thickness (x)'**
  String get simDeepDive22;

  /// No description provided for @simDeepDive23.
  ///
  /// In en, this message translates to:
  /// **'The key difference is not the physical material (B3 can be metal, liquid or any solid) but its hidden danger: chemical volatility, radioactivity or thermal reactivity that can harm people or the environment if it is handled like ordinary waste. So \"sorting\" here is not about separating materials but about safe containment and handling: shielding, controlled temperature and early identification before direct contact.'**
  String get simDeepDive23;

  /// No description provided for @simDensity1.
  ///
  /// In en, this message translates to:
  /// **'Density & Classification'**
  String get simDensity1;

  /// No description provided for @simDensity2.
  ///
  /// In en, this message translates to:
  /// **'MODULE A · LESSON'**
  String get simDensity2;

  /// No description provided for @simDensity3.
  ///
  /// In en, this message translates to:
  /// **'Items with different densities are sorted into the matching category.'**
  String get simDensity3;

  /// No description provided for @simDensity4.
  ///
  /// In en, this message translates to:
  /// **'DENSITY FORMULA'**
  String get simDensity4;

  /// No description provided for @simDensity5.
  ///
  /// In en, this message translates to:
  /// **'m = mass · V = volume'**
  String get simDensity5;

  /// No description provided for @simDensity6.
  ///
  /// In en, this message translates to:
  /// **'Move the sliders to see the item change'**
  String get simDensity6;

  /// No description provided for @simDensity7.
  ///
  /// In en, this message translates to:
  /// **'Mass (m)'**
  String get simDensity7;

  /// No description provided for @simDensity8.
  ///
  /// In en, this message translates to:
  /// **'CLASSIFICATION RESULT'**
  String get simDensity8;

  /// No description provided for @simDensity9.
  ///
  /// In en, this message translates to:
  /// **'Unknown material'**
  String get simDensity9;

  /// No description provided for @simDensity10.
  ///
  /// In en, this message translates to:
  /// **'Density outside the database range (not a known plastic, glass or metal).'**
  String get simDensity10;

  /// No description provided for @simDensity11.
  ///
  /// In en, this message translates to:
  /// **'Choose a bin:'**
  String get simDensity11;

  /// No description provided for @simDensity12.
  ///
  /// In en, this message translates to:
  /// **'Plastic'**
  String get simDensity12;

  /// No description provided for @simDensity13.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get simDensity13;

  /// No description provided for @simDensity14.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get simDensity14;

  /// No description provided for @simDensity15.
  ///
  /// In en, this message translates to:
  /// **'Module A — Density & Waste Classification'**
  String get simDensity15;

  /// No description provided for @simDensity16.
  ///
  /// In en, this message translates to:
  /// **'Density is a measure of how \"tightly packed\" matter is inside an object. Two objects can have the same size (volume) but very different weights, because their particles are packed differently. Iron feels heavy in your hand not because there is \"more\" iron, but because its atoms are packed more tightly per unit of space than, say, plastic.\n\nThis matters for ELIOS because density is one of the cheapest and fastest signals for guessing a material, far cheaper than, for example, analysing the infrared spectrum of every item.'**
  String get simDensity16;

  /// No description provided for @simDensity17.
  ///
  /// In en, this message translates to:
  /// **'ρ = m / V (density = mass / volume). Pure water has ρ = 1.0 g/cm³ as the reference point.'**
  String get simDensity17;

  /// No description provided for @simDensity18.
  ///
  /// In en, this message translates to:
  /// **'A common mistake swaps m and V into V/m, which changes the result drastically. Density is mass per volume.'**
  String get simDensity18;

  /// No description provided for @simDensity19.
  ///
  /// In en, this message translates to:
  /// **'Plastic (0.9 - 1.4 g/cm³)'**
  String get simDensity19;

  /// No description provided for @simDensity20.
  ///
  /// In en, this message translates to:
  /// **'Glass (2.4 - 2.6 g/cm³)'**
  String get simDensity20;

  /// No description provided for @simDensity21.
  ///
  /// In en, this message translates to:
  /// **'Metal (≥ 2.7 g/cm³)'**
  String get simDensity21;

  /// No description provided for @simDensity22.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get simDensity22;

  /// No description provided for @simHeat1.
  ///
  /// In en, this message translates to:
  /// **'Heat & Thermodynamics'**
  String get simHeat1;

  /// No description provided for @simHeat2.
  ///
  /// In en, this message translates to:
  /// **'MODULE B · LESSON'**
  String get simHeat2;

  /// No description provided for @simHeat3.
  ///
  /// In en, this message translates to:
  /// **'Heat & Composting Thermodynamics'**
  String get simHeat3;

  /// No description provided for @simHeat4.
  ///
  /// In en, this message translates to:
  /// **'HEAT FORMULA (Q)'**
  String get simHeat4;

  /// No description provided for @simHeat5.
  ///
  /// In en, this message translates to:
  /// **'m = mass · c = 4000 J/kg°C · ΔT = temperature change'**
  String get simHeat5;

  /// No description provided for @simHeat6.
  ///
  /// In en, this message translates to:
  /// **'Particles represent microbial activity'**
  String get simHeat6;

  /// No description provided for @simHeat7.
  ///
  /// In en, this message translates to:
  /// **'Temperature change (ΔT)'**
  String get simHeat7;

  /// No description provided for @simHeat8.
  ///
  /// In en, this message translates to:
  /// **'Porosity (cross-module)'**
  String get simHeat8;

  /// No description provided for @simHeat9.
  ///
  /// In en, this message translates to:
  /// **'PHASE RESULT'**
  String get simHeat9;

  /// No description provided for @simHeat10.
  ///
  /// In en, this message translates to:
  /// **'Thermophilic phase: heat-loving bacteria work best and pathogens start to die.'**
  String get simHeat10;

  /// No description provided for @simHeat11.
  ///
  /// In en, this message translates to:
  /// **'Module B — Heat & Composting Thermodynamics'**
  String get simHeat11;

  /// No description provided for @simHeat12.
  ///
  /// In en, this message translates to:
  /// **'When microorganisms in a compost pile break down organic waste, they release energy as heat: a biological exothermic process. The pile warms up not because of fire or electricity, but because of the metabolism of millions of bacteria and fungi breaking organic molecules apart.\n\nThis module models how much heat a mass of compost has to absorb or release for a given temperature change, and links it to the real biological phases of composting.'**
  String get simHeat12;

  /// No description provided for @simHeat13.
  ///
  /// In en, this message translates to:
  /// **'Mesophilic (< 55°C)'**
  String get simHeat13;

  /// No description provided for @simHeat14.
  ///
  /// In en, this message translates to:
  /// **'Thermophilic (55 - 60°C)'**
  String get simHeat14;

  /// No description provided for @simHeat15.
  ///
  /// In en, this message translates to:
  /// **'Too hot (> 60°C)'**
  String get simHeat15;

  /// No description provided for @simKinematics1.
  ///
  /// In en, this message translates to:
  /// **'Kinematics'**
  String get simKinematics1;

  /// No description provided for @simKinematics2.
  ///
  /// In en, this message translates to:
  /// **'MODULE E · LESSON'**
  String get simKinematics2;

  /// No description provided for @simKinematics3.
  ///
  /// In en, this message translates to:
  /// **'Kinematics (uniform & accelerated motion)'**
  String get simKinematics3;

  /// No description provided for @simKinematics4.
  ///
  /// In en, this message translates to:
  /// **'How long does ELIOS take to reach the target? Link distance, speed and time.'**
  String get simKinematics4;

  /// No description provided for @simKinematics5.
  ///
  /// In en, this message translates to:
  /// **'TIME FORMULA (uniform motion)'**
  String get simKinematics5;

  /// No description provided for @simKinematics6.
  ///
  /// In en, this message translates to:
  /// **'t = time · s = distance · v = constant speed'**
  String get simKinematics6;

  /// No description provided for @simKinematics7.
  ///
  /// In en, this message translates to:
  /// **'Target distance (s)'**
  String get simKinematics7;

  /// No description provided for @simKinematics8.
  ///
  /// In en, this message translates to:
  /// **'Speed (v)'**
  String get simKinematics8;

  /// No description provided for @simKinematics9.
  ///
  /// In en, this message translates to:
  /// **'PREDICTION'**
  String get simKinematics9;

  /// No description provided for @simKinematics10.
  ///
  /// In en, this message translates to:
  /// **'Estimated time of arrival (ETA)'**
  String get simKinematics10;

  /// No description provided for @simKinematics11.
  ///
  /// In en, this message translates to:
  /// **'Uniformly accelerated motion involves acceleration (a). In the real world ELIOS does not jump straight to full speed: the motor needs time (less than 1 second) to speed up from standstill to constant speed.\n\nFormula: s = v₀·t + ½·a·t²\n\nBecause ELIOS accelerates very quickly, the acceleration distance is tiny and is usually ignored for indoor navigation. But if an obstacle appears suddenly, the ELIOS emergency brake uses deceleration (negative acceleration) calculated with the same formula.'**
  String get simKinematics11;

  /// No description provided for @simKinematics12.
  ///
  /// In en, this message translates to:
  /// **'Module E — Kinematics'**
  String get simKinematics12;

  /// No description provided for @simKinematics13.
  ///
  /// In en, this message translates to:
  /// **'When ELIOS is sent to a waste collection point, its navigation system (Local Planner) has to know how far away it is and how long it will take to get there at a given speed. This is pure basic kinematics: the part of physics that studies motion without caring what causes it (force/mass).\n\nThis module models ELIOS moving in uniform straight-line motion.'**
  String get simKinematics13;

  /// No description provided for @simKinematics14.
  ///
  /// In en, this message translates to:
  /// **'Bonus, accelerated motion: in the real world the ELIOS motor needs time to accelerate (s = v₀·t + ½·a·t²). But because ELIOS accelerates very quickly, uniform motion is accurate enough to compute the ETA.'**
  String get simKinematics14;

  /// No description provided for @simKinematics15.
  ///
  /// In en, this message translates to:
  /// **'A common mistake when computing t is multiplying s and v (s·v) instead of dividing (s/v). The unit of s·v is m²/s, which makes no sense. Always check the final unit (m / (m/s) = s).'**
  String get simKinematics15;

  /// No description provided for @simDensityPainter1.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get simDensityPainter1;

  /// No description provided for @simDensityPainter2.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get simDensityPainter2;

  /// No description provided for @simTorquePainter1.
  ///
  /// In en, this message translates to:
  /// **'TORQUE'**
  String get simTorquePainter1;

  /// No description provided for @simPowerBudget1.
  ///
  /// In en, this message translates to:
  /// **'Power & Battery Budget'**
  String get simPowerBudget1;

  /// No description provided for @simPowerBudget2.
  ///
  /// In en, this message translates to:
  /// **'MODULE G · LESSON'**
  String get simPowerBudget2;

  /// No description provided for @simPowerBudget3.
  ///
  /// In en, this message translates to:
  /// **'POWER & ENERGY FORMULA'**
  String get simPowerBudget3;

  /// No description provided for @simPowerBudget4.
  ///
  /// In en, this message translates to:
  /// **'Scenario presets:'**
  String get simPowerBudget4;

  /// No description provided for @simPowerBudget5.
  ///
  /// In en, this message translates to:
  /// **'Usage time (t)'**
  String get simPowerBudget5;

  /// No description provided for @simPowerBudget6.
  ///
  /// In en, this message translates to:
  /// **'BATTERY LIFE PREDICTION'**
  String get simPowerBudget6;

  /// No description provided for @simPowerBudget7.
  ///
  /// In en, this message translates to:
  /// **'Module G — Power & Battery Budget'**
  String get simPowerBudget7;

  /// No description provided for @simPowerBudget8.
  ///
  /// In en, this message translates to:
  /// **'Every ELIOS part that is switched on (camera, drive motors, arm motor) draws power from the same battery. This module shows how to work out how long the battery lasts depending on which parts are active, a decision the ELIOS control system really makes in real time to save power.\n\nThe real power-saving behaviour of ELIOS follows this logic directly: the drive motors are switched off while sorting (the robot stands still), and the camera is switched off while moving when it is not analysing an object. Every watt that does not need to be on means extra seconds of operation before the battery needs recharging.'**
  String get simPowerBudget8;

  /// No description provided for @simPowerBudget9.
  ///
  /// In en, this message translates to:
  /// **'P = V · I (power = voltage × current). Here the power (P) of each part is already given.'**
  String get simPowerBudget9;

  /// No description provided for @simPowerBudget10.
  ///
  /// In en, this message translates to:
  /// **'E = P · t (energy = total power × time).'**
  String get simPowerBudget10;

  /// No description provided for @simPowerBudget11.
  ///
  /// In en, this message translates to:
  /// **'Total capacity = 50,000 joules. t_estimate = 50,000 / P_total.'**
  String get simPowerBudget11;

  /// No description provided for @simPowerBudget12.
  ///
  /// In en, this message translates to:
  /// **'Camera 10 W, drive motors 36 W, arm motor 18 W.'**
  String get simPowerBudget12;

  /// No description provided for @simPwm1.
  ///
  /// In en, this message translates to:
  /// **'PWM & Motor'**
  String get simPwm1;

  /// No description provided for @simPwm2.
  ///
  /// In en, this message translates to:
  /// **'MODULE F · LESSON'**
  String get simPwm2;

  /// No description provided for @simPwm3.
  ///
  /// In en, this message translates to:
  /// **'PWM & Effective Voltage'**
  String get simPwm3;

  /// No description provided for @simPwm4.
  ///
  /// In en, this message translates to:
  /// **'EFFECTIVE AVERAGE VOLTAGE'**
  String get simPwm4;

  /// No description provided for @simPwm5.
  ///
  /// In en, this message translates to:
  /// **'Square wave (PWM signal)'**
  String get simPwm5;

  /// No description provided for @simPwm6.
  ///
  /// In en, this message translates to:
  /// **'MOTOR VOLTAGE'**
  String get simPwm6;

  /// No description provided for @simPwm7.
  ///
  /// In en, this message translates to:
  /// **'Module F — PWM & Effective Motor Voltage'**
  String get simPwm7;

  /// No description provided for @simPwm8.
  ///
  /// In en, this message translates to:
  /// **'V_avg = D · V_max (effective average voltage = duty cycle × maximum voltage).'**
  String get simPwm8;

  /// No description provided for @simPwm9.
  ///
  /// In en, this message translates to:
  /// **'D (duty cycle) is the percentage of time the signal is \"on\" in one period.'**
  String get simPwm9;

  /// No description provided for @simPwm10.
  ///
  /// In en, this message translates to:
  /// **'Linear model limits (important): the RPM estimate in this simulation is a linear approximation. On a real motor, the link between duty cycle and actual RPM is not fully linear once the motor carries a torque load.'**
  String get simPwm10;

  /// No description provided for @simPwm11.
  ///
  /// In en, this message translates to:
  /// **'The claim \"lower average voltage = proportionally lower average current\" is ONLY TRUE FOR A PURELY RESISTIVE LOAD. In a motor (inductive + mechanical load) the current does not follow the voltage in a simple linear way.'**
  String get simPwm11;

  /// No description provided for @simTorque1.
  ///
  /// In en, this message translates to:
  /// **'Robot Shoulder Torque'**
  String get simTorque1;

  /// No description provided for @simTorque2.
  ///
  /// In en, this message translates to:
  /// **'MODULE C · MECHANICS'**
  String get simTorque2;

  /// No description provided for @simTorque3.
  ///
  /// In en, this message translates to:
  /// **'TORQUE FORMULA'**
  String get simTorque3;

  /// No description provided for @simTorque4.
  ///
  /// In en, this message translates to:
  /// **'r = arm length · F = load · θ = angle'**
  String get simTorque4;

  /// No description provided for @simTorque5.
  ///
  /// In en, this message translates to:
  /// **'Drag the arm handle to change r & θ'**
  String get simTorque5;

  /// No description provided for @simTorque6.
  ///
  /// In en, this message translates to:
  /// **'Arm length (r)'**
  String get simTorque6;

  /// No description provided for @simTorque7.
  ///
  /// In en, this message translates to:
  /// **'Load (F)'**
  String get simTorque7;

  /// No description provided for @simTorque8.
  ///
  /// In en, this message translates to:
  /// **'Angle (θ)'**
  String get simTorque8;

  /// No description provided for @simTorque9.
  ///
  /// In en, this message translates to:
  /// **'INSTANT TORQUE'**
  String get simTorque9;

  /// No description provided for @simTorque10.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGE'**
  String get simTorque10;

  /// No description provided for @simTorque11.
  ///
  /// In en, this message translates to:
  /// **'Lesson: torque (moment of force)'**
  String get simTorque11;

  /// No description provided for @simSimCanvasFrame1.
  ///
  /// In en, this message translates to:
  /// **'⚠ TIP-OVER RISK'**
  String get simSimCanvasFrame1;

  /// No description provided for @simSimulationPageScaffold1.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get simSimulationPageScaffold1;

  /// No description provided for @simWorkEnergy1.
  ///
  /// In en, this message translates to:
  /// **'Work & Energy'**
  String get simWorkEnergy1;

  /// No description provided for @simWorkEnergy2.
  ///
  /// In en, this message translates to:
  /// **'MODULE D · LESSON'**
  String get simWorkEnergy2;

  /// No description provided for @simWorkEnergy3.
  ///
  /// In en, this message translates to:
  /// **'Work & Potential Energy'**
  String get simWorkEnergy3;

  /// No description provided for @simWorkEnergy4.
  ///
  /// In en, this message translates to:
  /// **'Every lift turns battery energy into gravitational potential energy.'**
  String get simWorkEnergy4;

  /// No description provided for @simWorkEnergy5.
  ///
  /// In en, this message translates to:
  /// **'WORK FORMULA (W)'**
  String get simWorkEnergy5;

  /// No description provided for @simWorkEnergy6.
  ///
  /// In en, this message translates to:
  /// **'m = mass · g = 10 m/s² · h = height'**
  String get simWorkEnergy6;

  /// No description provided for @simWorkEnergy7.
  ///
  /// In en, this message translates to:
  /// **'Change the height and load to see the effect'**
  String get simWorkEnergy7;

  /// No description provided for @simWorkEnergy8.
  ///
  /// In en, this message translates to:
  /// **'Load mass (m)'**
  String get simWorkEnergy8;

  /// No description provided for @simWorkEnergy9.
  ///
  /// In en, this message translates to:
  /// **'Height (h)'**
  String get simWorkEnergy9;

  /// No description provided for @simWorkEnergy10.
  ///
  /// In en, this message translates to:
  /// **'RESULT'**
  String get simWorkEnergy10;

  /// No description provided for @simWorkEnergy11.
  ///
  /// In en, this message translates to:
  /// **'Module D — Work & Gravitational Potential Energy'**
  String get simWorkEnergy11;

  /// No description provided for @simWorkEnergy12.
  ///
  /// In en, this message translates to:
  /// **'Every time ELIOS lifts waste from the tray into a higher container, it does work against gravity. This work is stored as gravitational potential energy in the lifted item: energy that is \"ready to be released\" if the item is dropped again.\n\nThis is not just an abstract idea: every joule of work the ELIOS arm motor does comes from the battery, so this module directly explains why lifting heavy loads more often and higher = the ELIOS battery runs out faster.'**
  String get simWorkEnergy12;

  /// No description provided for @simDeepDive24.
  ///
  /// In en, this message translates to:
  /// **'• Fick\'s law (diffusion): the rate at which oxygen moves into the pile is proportional to the area of the pore paths and inversely proportional to the distance travelled; a dense pile = longer, narrower diffusion paths = oxygen gets in much more slowly.\n'**
  String get simDeepDive24;

  /// No description provided for @simDeepDive25.
  ///
  /// In en, this message translates to:
  /// **'• Heat conduction, Q/t = kAΔT/L: the heat microbes produce in the core of the pile travels outwards by conduction; a dense pile also slows this down, which raises the risk of overheating (see Module B).\n'**
  String get simDeepDive25;

  /// No description provided for @simDeepDive26.
  ///
  /// In en, this message translates to:
  /// **'• Jurin\'s law (capillarity): explains how moisture rises or stays between small particles, which affects how \"wet\" the pores remain over time.'**
  String get simDeepDive26;

  /// No description provided for @simDeepDive27.
  ///
  /// In en, this message translates to:
  /// **'Each type of plastic absorbs and reflects near-infrared light at its own characteristic wavelengths, forming a kind of \"optical fingerprint\".'**
  String get simDeepDive27;

  /// No description provided for @simDeepDive28.
  ///
  /// In en, this message translates to:
  /// **'Incinerating hazardous materials needs much higher temperatures than burning ordinary waste, to break the chemical bonds of toxic molecules (for example persistent organic compounds). The 1000°C threshold here illustrates the thermal decomposition point.'**
  String get simDeepDive28;

  /// No description provided for @simDeepDive29.
  ///
  /// In en, this message translates to:
  /// **'Status: bonds still intact (hazardous)'**
  String get simDeepDive29;

  /// No description provided for @simDensity23.
  ///
  /// In en, this message translates to:
  /// **'Ranges: plastic (0.9–1.4), glass (2.4–2.6), metal (≥ 2.7).'**
  String get simDensity23;

  /// No description provided for @simDensity24.
  ///
  /// In en, this message translates to:
  /// **'Plastics with ρ < 1.0 (HDPE, PP) float in water. Plastics with ρ > 1.0 (PET, PVC) sink. This is a real flotation sorting technique used in industry!'**
  String get simDensity24;

  /// No description provided for @simHeat16.
  ///
  /// In en, this message translates to:
  /// **'Heat from microbial activity changes the temperature of the compost pile. Watch its phase.'**
  String get simHeat16;

  /// No description provided for @simHeat17.
  ///
  /// In en, this message translates to:
  /// **'Warning: anaerobic, methane risk. Low porosity (<25%) and high temperature (>55°C).'**
  String get simHeat17;

  /// No description provided for @simHeat18.
  ///
  /// In en, this message translates to:
  /// **'Overheated: too hot! Microbial activity slows down.'**
  String get simHeat18;

  /// No description provided for @simHeat19.
  ///
  /// In en, this message translates to:
  /// **'Q = m · c · ΔT (heat = mass × specific heat × temperature change).'**
  String get simHeat19;

  /// No description provided for @simHeat20.
  ///
  /// In en, this message translates to:
  /// **'Mesophilic phase (< 55°C): medium-temperature bacteria start breaking down simple sugars and proteins.'**
  String get simHeat20;

  /// No description provided for @simHeat21.
  ///
  /// In en, this message translates to:
  /// **'Thermophilic phase (55–60°C): heat-loving bacteria dominate; this phase kills pathogens and weed seeds.'**
  String get simHeat21;

  /// No description provided for @simHeat22.
  ///
  /// In en, this message translates to:
  /// **'Overheated (> 60°C): microbial activity slows or stops; turn the pile to release heat.'**
  String get simHeat22;

  /// No description provided for @simHeat23.
  ///
  /// In en, this message translates to:
  /// **'Link with porosity: when porosity is < 25% AND the temperature is > 55°C, the pile can turn anaerobic (no oxygen left). Anaerobic microbes take over and produce methane (CH₄), a dangerous gas.'**
  String get simHeat23;

  /// No description provided for @simKinematics16.
  ///
  /// In en, this message translates to:
  /// **'Uniform straight-line motion'**
  String get simKinematics16;

  /// No description provided for @simKinematics17.
  ///
  /// In en, this message translates to:
  /// **'Uniform motion: constant speed (v), no acceleration (a = 0).'**
  String get simKinematics17;

  /// No description provided for @simKinematics18.
  ///
  /// In en, this message translates to:
  /// **'v = s / t, so t = s / v (time = distance divided by speed).'**
  String get simKinematics18;

  /// No description provided for @simPowerBudget13.
  ///
  /// In en, this message translates to:
  /// **'How long does the battery last? It depends on which parts are switched on.'**
  String get simPowerBudget13;

  /// No description provided for @simPowerBudget14.
  ///
  /// In en, this message translates to:
  /// **'If P_total = 0, the runtime is mathematically infinite (∞).'**
  String get simPowerBudget14;

  /// No description provided for @simPwm12.
  ///
  /// In en, this message translates to:
  /// **'Control the ELIOS motor speed without wasting energy as heat in a resistor.'**
  String get simPwm12;

  /// No description provided for @simPwm13.
  ///
  /// In en, this message translates to:
  /// **'The DC motors in ELIOS (for example the wheel or arm motors) are not always given full voltage all the time. To control motor speed without wasting energy as heat, ELIOS uses PWM (pulse width modulation): it switches the full voltage on and off very quickly (hundreds to thousands of times per second) and sets what share of each cycle the voltage is on.\n\nThe old way to control motor speed was a resistive voltage divider (resistor/potentiometer) that lowers the voltage directly. The problem is that the extra energy is wasted as heat in the resistor: energy is lost and parts get hot.\n\nPWM never really \"lowers\" the voltage: it only switches the full voltage on and off very fast. Because the motor has mechanical inertia and coil inductance that smooth this on/off \"twitching\" into steady motion, the result feels like a lower voltage, but without wasting energy as resistive heat; only much smaller switching losses.'**
  String get simPwm13;

  /// No description provided for @simPwm14.
  ///
  /// In en, this message translates to:
  /// **'A 60% duty cycle means fully on 60% of the time and off for the other 40%. The average is 7.2 V of the 12 V maximum.'**
  String get simPwm14;

  /// No description provided for @simTorque12.
  ///
  /// In en, this message translates to:
  /// **'When ELIOS reaches out its arm, the shoulder joint holds more torque.'**
  String get simTorque12;

  /// No description provided for @simTorque13.
  ///
  /// In en, this message translates to:
  /// **'Torque above 8 N·m: the robot could tip over!'**
  String get simTorque13;

  /// No description provided for @simTorque14.
  ///
  /// In en, this message translates to:
  /// **'θ = 90°: maximum torque, the arm is perpendicular to the force.'**
  String get simTorque14;

  /// No description provided for @simTorque15.
  ///
  /// In en, this message translates to:
  /// **'θ = 0° or 180°: zero torque, the force is parallel to the arm.'**
  String get simTorque15;

  /// No description provided for @simTorque16.
  ///
  /// In en, this message translates to:
  /// **'Large r: more torque, but the robot is harder to keep stable.'**
  String get simTorque16;

  /// No description provided for @simWorkEnergy13.
  ///
  /// In en, this message translates to:
  /// **'W = E_p = m · g · h (work = potential energy = mass × gravity × height).'**
  String get simWorkEnergy13;

  /// No description provided for @simWorkEnergy14.
  ///
  /// In en, this message translates to:
  /// **'g (gravity) is rounded to 10 m/s² to keep the maths simple.'**
  String get simWorkEnergy14;

  /// No description provided for @simPwmMotorGets.
  ///
  /// In en, this message translates to:
  /// **'The motor gets the equivalent of {volts} V'**
  String simPwmMotorGets(Object volts);

  /// No description provided for @simDensityMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material: {name}'**
  String simDensityMaterial(Object name);

  /// No description provided for @simPowerLegend.
  ///
  /// In en, this message translates to:
  /// **'P_total = {watts} W · t = time (seconds)'**
  String simPowerLegend(Object watts);

  /// No description provided for @simPowerEstimate.
  ///
  /// In en, this message translates to:
  /// **'t_estimate = 50000 J / {watts} W = {runtime}'**
  String simPowerEstimate(Object watts, Object runtime);

  /// No description provided for @simPowerLasts.
  ///
  /// In en, this message translates to:
  /// **'Lasts {runtime}'**
  String simPowerLasts(Object runtime);

  /// No description provided for @simWorkBatteryLeft.
  ///
  /// In en, this message translates to:
  /// **'Battery left: {percent}%'**
  String simWorkBatteryLeft(Object percent);

  /// No description provided for @simTorqueMotorStatus.
  ///
  /// In en, this message translates to:
  /// **'Motor: {status} · safe limit 8 N·m'**
  String simTorqueMotorStatus(Object status);

  /// No description provided for @simTorqueSafe.
  ///
  /// In en, this message translates to:
  /// **'SAFE'**
  String get simTorqueSafe;

  /// No description provided for @simTorqueWarning.
  ///
  /// In en, this message translates to:
  /// **'CAUTION'**
  String get simTorqueWarning;

  /// No description provided for @simTorqueCritical.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL'**
  String get simTorqueCritical;

  /// No description provided for @simTorqueChallenge.
  ///
  /// In en, this message translates to:
  /// **'Find the heaviest load ELIOS can lift when r = {r} m and θ = 90° with a torque limit of 8 N·m.\nAnswer: F = τ/(r·sinθ) = 8 / {r} = 16 N'**
  String simTorqueChallenge(Object r);

  /// No description provided for @simTorqueBody.
  ///
  /// In en, this message translates to:
  /// **'Torque (τ) measures how effectively a force turns an object around a pivot. Torque depends on the moment arm and on the angle between the arm and the direction of the force.'**
  String get simTorqueBody;

  /// No description provided for @simKinArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival time = {distance} / {speed} = {time} seconds'**
  String simKinArrival(Object distance, Object speed, Object time);

  /// No description provided for @simHeatFinal.
  ///
  /// In en, this message translates to:
  /// **'Final temperature = 25°C + {delta}°C = {result}°C'**
  String simHeatFinal(Object delta, Object result);

  /// No description provided for @physQDensity.
  ///
  /// In en, this message translates to:
  /// **'A sample of inorganic waste has a mass of {m} g and a volume of {v} cm³. What is its density?'**
  String physQDensity(Object m, Object v);

  /// No description provided for @physQHeat.
  ///
  /// In en, this message translates to:
  /// **'A compost pile with a mass of {m} kg warms up by {dt} °C. If the specific heat (c) of compost is {c} J/kg°C, how much heat (Q) did the microbes produce?'**
  String physQHeat(Object m, Object dt, Object c);

  /// No description provided for @physQTorque.
  ///
  /// In en, this message translates to:
  /// **'The robot arm reaches out {r} m and lifts a load with a force of {f} N at an angle of {theta}° to the arm. How large is the torque at the shoulder joint?'**
  String physQTorque(Object r, Object f, Object theta);

  /// No description provided for @physQWork.
  ///
  /// In en, this message translates to:
  /// **'ELIOS lifts a {m} kg load to a height of {h} m. How much work does it do against gravity (g = 10 m/s²)?'**
  String physQWork(Object m, Object h);

  /// No description provided for @physQSpeed.
  ///
  /// In en, this message translates to:
  /// **'ELIOS drives {s} metres in a straight line in {t} seconds towards the target. What is its average speed?'**
  String physQSpeed(Object s, Object t);

  /// No description provided for @physQPwm.
  ///
  /// In en, this message translates to:
  /// **'A PWM signal sets the motor voltage with a duty cycle (D) of {d}%. If the maximum battery voltage is {vmax} V, what is the average motor voltage?'**
  String physQPwm(Object d, Object vmax);

  /// No description provided for @physQPower.
  ///
  /// In en, this message translates to:
  /// **'A subsystem draws {i} A from a {v} V battery. How much power does it use?'**
  String physQPower(Object i, Object v);

  /// No description provided for @simDensityLoad.
  ///
  /// In en, this message translates to:
  /// **'A typical organic load for ELIOS is {kg} kg. Because organic waste is much denser than plastic, lifting the same volume of organic waste takes more energy (see Module D).'**
  String simDensityLoad(Object kg);

  /// No description provided for @simWorkOrganic.
  ///
  /// In en, this message translates to:
  /// **'Organic waste tends to have more mass per volume than plastic. For a typical organic load of {kg} kg, lifting it to the same height as light plastic takes much more work.'**
  String simWorkOrganic(Object kg);

  /// No description provided for @simWorkBattery.
  ///
  /// In en, this message translates to:
  /// **'The ELIOS battery capacity used in this simulation is {joules} joules. % left = 100 - (W / {joules}) × 100.'**
  String simWorkBattery(Object joules);

  /// No description provided for @aiNotReady.
  ///
  /// In en, this message translates to:
  /// **'The AI couldn\'t read the photo yet. Check the internet, then try again.'**
  String get aiNotReady;

  /// No description provided for @aiNotRecognised.
  ///
  /// In en, this message translates to:
  /// **'The item in the photo was not recognised yet. Move the camera closer, make sure it is bright, then scan again.'**
  String get aiNotRecognised;

  /// No description provided for @essaySavedPending.
  ///
  /// In en, this message translates to:
  /// **'Answer saved. Waiting for grading because the AI is not available yet.'**
  String get essaySavedPending;

  /// No description provided for @essayScoreLine.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}/10.'**
  String essayScoreLine(Object score);

  /// No description provided for @quizSkippedAnswer.
  ///
  /// In en, this message translates to:
  /// **'(skipped)'**
  String get quizSkippedAnswer;

  /// No description provided for @quizTimeUpAnswer.
  ///
  /// In en, this message translates to:
  /// **'(time\'s up)'**
  String get quizTimeUpAnswer;

  /// No description provided for @wqTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up for question {n}.'**
  String wqTimeUp(int n);

  /// No description provided for @qzTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} seconds left'**
  String qzTimeLeft(int n);

  /// No description provided for @h3YourTrophies.
  ///
  /// In en, this message translates to:
  /// **'Your XP'**
  String get h3YourTrophies;

  /// No description provided for @h3TrophyUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{XP}}'**
  String h3TrophyUnit(int count);

  /// No description provided for @h3StatTrophies.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get h3StatTrophies;

  /// No description provided for @h3StatScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get h3StatScanned;

  /// No description provided for @h3QuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {index} of {total}'**
  String h3QuestionOf(int index, int total);

  /// No description provided for @h3HeroRight.
  ///
  /// In en, this message translates to:
  /// **'Nice one!'**
  String get h3HeroRight;

  /// No description provided for @h3HeroRightBody.
  ///
  /// In en, this message translates to:
  /// **'You got it right. Here\'s why it works.'**
  String get h3HeroRightBody;

  /// No description provided for @h3HeroWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite!'**
  String get h3HeroWrong;

  /// No description provided for @h3HeroWrongBody.
  ///
  /// In en, this message translates to:
  /// **'Good try. Let\'s find out why.'**
  String get h3HeroWrongBody;

  /// No description provided for @h3PlusTrophies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{+{count} XP}}'**
  String h3PlusTrophies(int count);

  /// No description provided for @h3TheQuestion.
  ///
  /// In en, this message translates to:
  /// **'The question'**
  String get h3TheQuestion;

  /// No description provided for @h3LearnWhy.
  ///
  /// In en, this message translates to:
  /// **'Let\'s learn why'**
  String get h3LearnWhy;

  /// No description provided for @h3Mission.
  ///
  /// In en, this message translates to:
  /// **'Your mission'**
  String get h3Mission;

  /// No description provided for @h3MissionSteps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step to sort it right} other{{count} steps to sort it right}}'**
  String h3MissionSteps(int count);

  /// No description provided for @h3MissionDone.
  ///
  /// In en, this message translates to:
  /// **'Mission complete: you know how to sort it right.'**
  String get h3MissionDone;

  /// No description provided for @h3SeeResults.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get h3SeeResults;

  /// No description provided for @h3CardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{item}, {category}, {correct} of {total} correct, +{trophies} XP'**
  String h3CardSemantics(
    String item,
    String category,
    int correct,
    int total,
    int trophies,
  );

  /// No description provided for @h3OpenPhoto.
  ///
  /// In en, this message translates to:
  /// **'View photo full screen'**
  String get h3OpenPhoto;

  /// No description provided for @h3Close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get h3Close;

  /// No description provided for @h3SharePhoto.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get h3SharePhoto;

  /// No description provided for @h3PinchHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom · double-tap to reset'**
  String get h3PinchHint;

  /// No description provided for @h3ViewerMeta.
  ///
  /// In en, this message translates to:
  /// **'Scanned {when} · {category}'**
  String h3ViewerMeta(String when, String category);

  /// No description provided for @h3ScanPhoto.
  ///
  /// In en, this message translates to:
  /// **'Scan photo of {item}'**
  String h3ScanPhoto(String item);

  /// No description provided for @historySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing history…'**
  String get historySyncing;

  /// No description provided for @historySynced.
  ///
  /// In en, this message translates to:
  /// **'History synced'**
  String get historySynced;

  /// No description provided for @historyLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device · sync pending'**
  String get historyLocalOnly;

  /// No description provided for @historySyncRetry.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get historySyncRetry;

  /// No description provided for @historyImport.
  ///
  /// In en, this message translates to:
  /// **'Import previous device history'**
  String get historyImport;

  /// No description provided for @historyImportBody.
  ///
  /// In en, this message translates to:
  /// **'These older scans have no account owner. Import them into your current account? The original device history will be kept.'**
  String get historyImportBody;

  /// No description provided for @historyImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import previous history. The original files are kept.'**
  String get historyImportFailed;

  /// No description provided for @dailyGuidesTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Guide'**
  String get dailyGuidesTitle;

  /// No description provided for @dailyGuidesDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore the physics behind environmental news.'**
  String get dailyGuidesDescription;

  /// No description provided for @dailyGuidesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh guides'**
  String get dailyGuidesRefresh;

  /// No description provided for @dailyGuidesOffline.
  ///
  /// In en, this message translates to:
  /// **'Showing saved guides. Connect to check for new issues.'**
  String get dailyGuidesOffline;

  /// No description provided for @dailyGuidesEmpty.
  ///
  /// In en, this message translates to:
  /// **'The first daily guide is on its way.'**
  String get dailyGuidesEmpty;

  /// No description provided for @dailyGuidesLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest issue'**
  String get dailyGuidesLatest;

  /// No description provided for @dailyGuidesArchive.
  ///
  /// In en, this message translates to:
  /// **'Previous issues'**
  String get dailyGuidesArchive;

  /// No description provided for @g4AiLooksFor.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI will look for'**
  String get g4AiLooksFor;

  /// No description provided for @g4All.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get g4All;

  /// No description provided for @g4AllStopsDone.
  ///
  /// In en, this message translates to:
  /// **'All 3 stops done'**
  String get g4AllStopsDone;

  /// No description provided for @g4AlmostBody.
  ///
  /// In en, this message translates to:
  /// **'No XP yet. You can try as many times as you like.'**
  String get g4AlmostBody;

  /// No description provided for @g4AlmostTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost! Try one more time'**
  String get g4AlmostTitle;

  /// No description provided for @g4Archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get g4Archive;

  /// No description provided for @g4ArchiveLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}, {date}, {stops} of 3 stops, {xp} XP'**
  String g4ArchiveLabel(Object title, Object date, Object stops, Object xp);

  /// No description provided for @g4AskTeacher.
  ///
  /// In en, this message translates to:
  /// **'Ask teacher to review'**
  String get g4AskTeacher;

  /// No description provided for @g4AskTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'Think the check is wrong? Ask your teacher to review it. They see the AI reason, not your photos.'**
  String get g4AskTeacherHint;

  /// No description provided for @g4BackToResult.
  ///
  /// In en, this message translates to:
  /// **'Back to result'**
  String get g4BackToResult;

  /// No description provided for @g4BadgeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Badge unlocked'**
  String get g4BadgeUnlocked;

  /// No description provided for @g4Cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get g4Cancel;

  /// No description provided for @g4Check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get g4Check;

  /// No description provided for @g4CheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get g4CheckAgain;

  /// No description provided for @g4ContinueGuide.
  ///
  /// In en, this message translates to:
  /// **'Continue guide'**
  String get g4ContinueGuide;

  /// No description provided for @g4ContinueStop.
  ///
  /// In en, this message translates to:
  /// **'Continue · Stop {n}'**
  String g4ContinueStop(Object n);

  /// No description provided for @g4CopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get g4CopyLink;

  /// No description provided for @g4DayFuture.
  ///
  /// In en, this message translates to:
  /// **'coming up'**
  String get g4DayFuture;

  /// No description provided for @g4DayMissed.
  ///
  /// In en, this message translates to:
  /// **'missed'**
  String get g4DayMissed;

  /// No description provided for @g4DayRead.
  ///
  /// In en, this message translates to:
  /// **'read'**
  String get g4DayRead;

  /// No description provided for @g4DayToday.
  ///
  /// In en, this message translates to:
  /// **'today, not read yet'**
  String get g4DayToday;

  /// No description provided for @g4DidYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get g4DidYouKnow;

  /// No description provided for @g4EmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A new physics story arrives every morning around 06:00. Pull down to check again.'**
  String get g4EmptyBody;

  /// No description provided for @g4EmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The first guide is on its way'**
  String get g4EmptyTitle;

  /// No description provided for @g4FeedError.
  ///
  /// In en, this message translates to:
  /// **'Guides couldn\'t load'**
  String get g4FeedError;

  /// No description provided for @g4FeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Physics behind real news'**
  String get g4FeedSubtitle;

  /// No description provided for @g4FinishStop2.
  ///
  /// In en, this message translates to:
  /// **'Finish Stop 2 to unlock'**
  String get g4FinishStop2;

  /// No description provided for @g4FollowApp.
  ///
  /// In en, this message translates to:
  /// **'Same as the app'**
  String get g4FollowApp;

  /// No description provided for @g4FrameN.
  ///
  /// In en, this message translates to:
  /// **'Frame {n}'**
  String g4FrameN(Object n);

  /// No description provided for @g4GuideArchive.
  ///
  /// In en, this message translates to:
  /// **'Guide archive'**
  String get g4GuideArchive;

  /// No description provided for @g4GuideLanguage.
  ///
  /// In en, this message translates to:
  /// **'Guide language'**
  String get g4GuideLanguage;

  /// No description provided for @g4GuideXp.
  ///
  /// In en, this message translates to:
  /// **'guide XP'**
  String get g4GuideXp;

  /// No description provided for @g4Import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get g4Import;

  /// No description provided for @g4ImportBody.
  ///
  /// In en, this message translates to:
  /// **'This phone has {xp} guide XP from a guest session.'**
  String g4ImportBody(Object xp);

  /// No description provided for @g4ImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add the guest\'s guide progress ({xp} XP, stops and streak days) to this account? Nothing is merged without your OK.'**
  String g4ImportConfirm(Object xp);

  /// No description provided for @g4ImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import now. Try again when you\'re online.'**
  String get g4ImportFailed;

  /// No description provided for @g4ImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import guest guide progress'**
  String get g4ImportTitle;

  /// No description provided for @g4IssueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 issue} other{{count} issues}}'**
  String g4IssueCount(int count);

  /// No description provided for @g4IssueN.
  ///
  /// In en, this message translates to:
  /// **'Issue #{n}'**
  String g4IssueN(Object n);

  /// No description provided for @g4LabApproved.
  ///
  /// In en, this message translates to:
  /// **'Lab approved'**
  String get g4LabApproved;

  /// No description provided for @g4LabApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Lab approved by ELIOS AI'**
  String get g4LabApprovedBy;

  /// No description provided for @g4LabBusy.
  ///
  /// In en, this message translates to:
  /// **'The lab check is busy. Your photos stayed on your phone; try again in a minute.'**
  String get g4LabBusy;

  /// No description provided for @g4LabChecking.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is checking your photos…'**
  String get g4LabChecking;

  /// No description provided for @g4LabLimit.
  ///
  /// In en, this message translates to:
  /// **'That\'s 5 lab checks for this guide today. Try again tomorrow.'**
  String get g4LabLimit;

  /// No description provided for @g4LabMeta.
  ///
  /// In en, this message translates to:
  /// **'About 10 minutes · +{xp} XP · badge'**
  String g4LabMeta(Object xp);

  /// No description provided for @g4LabOffline.
  ///
  /// In en, this message translates to:
  /// **'The lab check needs internet. Connect and try again; nothing was sent.'**
  String get g4LabOffline;

  /// No description provided for @g4LabResult.
  ///
  /// In en, this message translates to:
  /// **'Mini lab result'**
  String get g4LabResult;

  /// No description provided for @g4LangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get g4LangEn;

  /// No description provided for @g4LangId.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get g4LangId;

  /// No description provided for @g4LangMissing.
  ///
  /// In en, this message translates to:
  /// **'This issue isn\'t in your language yet, so it\'s shown in the other one.'**
  String get g4LangMissing;

  /// No description provided for @g4LangPill.
  ///
  /// In en, this message translates to:
  /// **'EN · ID'**
  String get g4LangPill;

  /// No description provided for @g4Listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get g4Listen;

  /// No description provided for @g4MiniLab.
  ///
  /// In en, this message translates to:
  /// **'Mini lab'**
  String get g4MiniLab;

  /// No description provided for @g4Missing.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get g4Missing;

  /// No description provided for @g4New.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get g4New;

  /// No description provided for @g4NewGuide.
  ///
  /// In en, this message translates to:
  /// **'New guide'**
  String get g4NewGuide;

  /// No description provided for @g4NextCard.
  ///
  /// In en, this message translates to:
  /// **'Next card'**
  String get g4NextCard;

  /// No description provided for @g4NotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get g4NotNow;

  /// No description provided for @g4NotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get g4NotQuite;

  /// No description provided for @g4OfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline. Showing saved guides. Connect to check for new issues.'**
  String get g4OfflineBanner;

  /// No description provided for @g4Ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get g4Ok;

  /// No description provided for @g4Pass.
  ///
  /// In en, this message translates to:
  /// **'seen'**
  String get g4Pass;

  /// No description provided for @g4Pdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get g4Pdf;

  /// No description provided for @g4PdfMeta.
  ///
  /// In en, this message translates to:
  /// **'{pages}-page PDF · {language} · saved for offline'**
  String g4PdfMeta(Object pages, Object language);

  /// No description provided for @g4PhotoCredit.
  ///
  /// In en, this message translates to:
  /// **'Photo credit'**
  String get g4PhotoCredit;

  /// No description provided for @g4PhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Take 3 photos: the start, the middle and the end of your experiment.'**
  String get g4PhotoHint;

  /// No description provided for @g4PhotosTaken.
  ///
  /// In en, this message translates to:
  /// **'{n} of 3 photos'**
  String g4PhotosTaken(Object n);

  /// No description provided for @g4PlusXp.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String g4PlusXp(Object xp);

  /// No description provided for @g4PrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'ELIOS checks 8 still photos from your clip, then deletes them. Only the result is saved.'**
  String get g4PrivacyNote;

  /// No description provided for @g4QuestMap.
  ///
  /// In en, this message translates to:
  /// **'Your quest map'**
  String get g4QuestMap;

  /// No description provided for @g4QuickQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quick quiz'**
  String get g4QuickQuiz;

  /// No description provided for @g4QuizAlmost.
  ///
  /// In en, this message translates to:
  /// **'2 correct answers pass. Try the quiz again with new questions.'**
  String get g4QuizAlmost;

  /// No description provided for @g4QuizNice.
  ///
  /// In en, this message translates to:
  /// **'Nice work!'**
  String get g4QuizNice;

  /// No description provided for @g4QuizParkedHint.
  ///
  /// In en, this message translates to:
  /// **'Answered cards stay on the left. Tap Q1–Q3 on the result to look again.'**
  String get g4QuizParkedHint;

  /// No description provided for @g4QuizPassed.
  ///
  /// In en, this message translates to:
  /// **'Quiz passed'**
  String get g4QuizPassed;

  /// No description provided for @g4QuizResultHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Q1–Q3 to flip back to any answer.'**
  String get g4QuizResultHint;

  /// No description provided for @g4QuizUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The quiz couldn\'t load'**
  String get g4QuizUnavailable;

  /// No description provided for @g4ReadAgain.
  ///
  /// In en, this message translates to:
  /// **'Read the guide again'**
  String get g4ReadAgain;

  /// No description provided for @g4ReadFullGuide.
  ///
  /// In en, this message translates to:
  /// **'Read the full guide'**
  String get g4ReadFullGuide;

  /// No description provided for @g4ReadPage.
  ///
  /// In en, this message translates to:
  /// **'Read page {page}'**
  String g4ReadPage(Object page);

  /// No description provided for @g4Record.
  ///
  /// In en, this message translates to:
  /// **'Record 15–30 s'**
  String get g4Record;

  /// No description provided for @g4RecordHint.
  ///
  /// In en, this message translates to:
  /// **'Film only your hands and the experiment. Stop after {min} s; recording ends at 30 s.'**
  String g4RecordHint(Object min);

  /// No description provided for @g4RecordingSeconds.
  ///
  /// In en, this message translates to:
  /// **'Recording {s} / {max} s'**
  String g4RecordingSeconds(Object s, Object max);

  /// No description provided for @g4Retake.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get g4Retake;

  /// No description provided for @g4Retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get g4Retry;

  /// No description provided for @g4ReviewBody.
  ///
  /// In en, this message translates to:
  /// **'These are the only pictures that will be sent. Nothing leaves your phone until you tap Send.'**
  String get g4ReviewBody;

  /// No description provided for @g4ReviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Look at question {n} again'**
  String g4ReviewQuestion(Object n);

  /// No description provided for @g4ReviewSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to your teacher.'**
  String get g4ReviewSent;

  /// No description provided for @g4ReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'{n} photos ready'**
  String g4ReviewTitle(Object n);

  /// No description provided for @g4SafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Film only your hands and the experiment'**
  String get g4SafetyTitle;

  /// No description provided for @g4SavedAccount.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account'**
  String get g4SavedAccount;

  /// No description provided for @g4SavedPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. It syncs when you\'re online.'**
  String get g4SavedPhone;

  /// No description provided for @g4Saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get g4Saving;

  /// No description provided for @g4ScoreOf.
  ///
  /// In en, this message translates to:
  /// **'{score} of {total} correct'**
  String g4ScoreOf(Object score, Object total);

  /// No description provided for @g4SeeResult.
  ///
  /// In en, this message translates to:
  /// **'See result'**
  String get g4SeeResult;

  /// No description provided for @g4Send.
  ///
  /// In en, this message translates to:
  /// **'Send to ELIOS AI'**
  String get g4Send;

  /// No description provided for @g4Sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get g4Sources;

  /// No description provided for @g4SourcesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source} other{{count} sources}}'**
  String g4SourcesCount(int count);

  /// No description provided for @g4StartGuide.
  ///
  /// In en, this message translates to:
  /// **'Start guide'**
  String get g4StartGuide;

  /// No description provided for @g4StartLab.
  ///
  /// In en, this message translates to:
  /// **'Start mini lab'**
  String get g4StartLab;

  /// No description provided for @g4StopDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get g4StopDone;

  /// No description provided for @g4StopLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get g4StopLocked;

  /// No description provided for @g4StopMission.
  ///
  /// In en, this message translates to:
  /// **'Your mission'**
  String get g4StopMission;

  /// No description provided for @g4StopMissionSub.
  ///
  /// In en, this message translates to:
  /// **'Stop 3 · Your mission'**
  String get g4StopMissionSub;

  /// No description provided for @g4StopN.
  ///
  /// In en, this message translates to:
  /// **'Stop {n}'**
  String g4StopN(Object n);

  /// No description provided for @g4StopOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get g4StopOpen;

  /// No description provided for @g4StopPage.
  ///
  /// In en, this message translates to:
  /// **'STOP {n} · P.{page}'**
  String g4StopPage(Object n, Object page);

  /// No description provided for @g4StopPhysics.
  ///
  /// In en, this message translates to:
  /// **'The physics'**
  String get g4StopPhysics;

  /// No description provided for @g4StopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get g4StopRecording;

  /// No description provided for @g4StopStory.
  ///
  /// In en, this message translates to:
  /// **'The story'**
  String get g4StopStory;

  /// No description provided for @g4StopsDoneNext.
  ///
  /// In en, this message translates to:
  /// **'{done} of 3 stops done · Next: {next}'**
  String g4StopsDoneNext(Object done, Object next);

  /// No description provided for @g4StopsOf.
  ///
  /// In en, this message translates to:
  /// **'{done}/3 stops'**
  String g4StopsOf(Object done);

  /// No description provided for @g4StreakHint.
  ///
  /// In en, this message translates to:
  /// **'Read today\'s guide to earn XP and clovers'**
  String get g4StreakHint;

  /// No description provided for @g4WeekReading.
  ///
  /// In en, this message translates to:
  /// **'Your reading this week'**
  String get g4WeekReading;

  /// No description provided for @g4TakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get g4TakePhoto;

  /// No description provided for @g4TeacherBody.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI wasn\'t sure, so your teacher will look at the result. No photos are kept.'**
  String get g4TeacherBody;

  /// No description provided for @g4TeacherNote.
  ///
  /// In en, this message translates to:
  /// **'Your teacher can see this result and change it. Photos were deleted after the check.'**
  String get g4TeacherNote;

  /// No description provided for @g4TeacherTitle.
  ///
  /// In en, this message translates to:
  /// **'Your teacher will check this'**
  String get g4TeacherTitle;

  /// No description provided for @g4ThreePhotos.
  ///
  /// In en, this message translates to:
  /// **'Take 3 photos instead'**
  String get g4ThreePhotos;

  /// No description provided for @g4TodayDate.
  ///
  /// In en, this message translates to:
  /// **'TODAY · {date}'**
  String g4TodayDate(Object date);

  /// No description provided for @g4TodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s guide: {title}, {done} of 3 stops done'**
  String g4TodayLabel(Object title, Object done);

  /// No description provided for @g4TodaysGuide.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S GUIDE'**
  String get g4TodaysGuide;

  /// No description provided for @g4TodaysGuideIssue.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S GUIDE · #{n}'**
  String g4TodaysGuideIssue(Object n);

  /// No description provided for @g4TopicAir.
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get g4TopicAir;

  /// No description provided for @g4TopicEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get g4TopicEnergy;

  /// No description provided for @g4TopicHeat.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get g4TopicHeat;

  /// No description provided for @g4TopicOther.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get g4TopicOther;

  /// No description provided for @g4TopicStorm.
  ///
  /// In en, this message translates to:
  /// **'Storm'**
  String get g4TopicStorm;

  /// No description provided for @g4TopicWaste.
  ///
  /// In en, this message translates to:
  /// **'Waste'**
  String get g4TopicWaste;

  /// No description provided for @g4TopicWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get g4TopicWater;

  /// No description provided for @g4TryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get g4TryAgain;

  /// No description provided for @g4TryQuizAgain.
  ///
  /// In en, this message translates to:
  /// **'Try the quiz again'**
  String get g4TryQuizAgain;

  /// No description provided for @g4WeekLetters.
  ///
  /// In en, this message translates to:
  /// **'M,T,W,T,F,S,S'**
  String get g4WeekLetters;

  /// No description provided for @g4WhatAiSaw.
  ///
  /// In en, this message translates to:
  /// **'What ELIOS AI saw'**
  String get g4WhatAiSaw;

  /// No description provided for @g4WhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get g4WhatToDo;

  /// No description provided for @g4XpDone.
  ///
  /// In en, this message translates to:
  /// **'✓ {xp} XP'**
  String g4XpDone(Object xp);

  /// No description provided for @g4XpOf.
  ///
  /// In en, this message translates to:
  /// **'{xp} / {total} XP'**
  String g4XpOf(Object xp, Object total);

  /// No description provided for @g4YourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question: {q}'**
  String g4YourQuestion(Object q);

  /// No description provided for @g4FeedTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS Guides'**
  String get g4FeedTitle;

  /// No description provided for @lnShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Learn shortcuts'**
  String get lnShortcuts;

  /// No description provided for @lnJumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Jump back in'**
  String get lnJumpBackIn;

  /// No description provided for @lnExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get lnExplore;

  /// No description provided for @lnExploreSub.
  ///
  /// In en, this message translates to:
  /// **'{lessons} lessons across {modules} modules'**
  String lnExploreSub(int lessons, int modules);

  /// No description provided for @lnModules.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get lnModules;

  /// No description provided for @lnPdfGuides.
  ///
  /// In en, this message translates to:
  /// **'PDF guides'**
  String get lnPdfGuides;

  /// No description provided for @lnPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get lnPractice;

  /// No description provided for @lnYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get lnYou;

  /// No description provided for @lnQuizShort.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get lnQuizShort;

  /// No description provided for @lnMiniLab.
  ///
  /// In en, this message translates to:
  /// **'Mini lab'**
  String get lnMiniLab;

  /// No description provided for @lnTodaysLab.
  ///
  /// In en, this message translates to:
  /// **'Today\'s experiment'**
  String get lnTodaysLab;

  /// No description provided for @lnArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get lnArchive;

  /// No description provided for @lnProgressShort.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get lnProgressShort;

  /// No description provided for @lnStartHere.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get lnStartHere;

  /// No description provided for @lnQuizCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quiz} other{{count} quizzes}}'**
  String lnQuizCount(num count);

  /// No description provided for @lnTotalXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP total'**
  String lnTotalXp(int xp);

  /// No description provided for @lnGuideStops.
  ///
  /// In en, this message translates to:
  /// **'#{issue} · {done} of 3 stops'**
  String lnGuideStops(String issue, int done);

  /// No description provided for @lnPctDone.
  ///
  /// In en, this message translates to:
  /// **'{pct}%'**
  String lnPctDone(int pct);

  /// No description provided for @lnTodaysGuide.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Guide'**
  String get lnTodaysGuide;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan, opens the scan hub'**
  String get navScanHint;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @scanHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick how you want to scan today'**
  String get scanHubSubtitle;

  /// No description provided for @scanPhoneOverline.
  ///
  /// In en, this message translates to:
  /// **'With your phone'**
  String get scanPhoneOverline;

  /// No description provided for @scanPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan & quiz'**
  String get scanPhoneTitle;

  /// No description provided for @scanPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at an item. ELIOS names it and makes a quiz for you.'**
  String get scanPhoneBody;

  /// No description provided for @scanOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get scanOpenCamera;

  /// No description provided for @scanRobotOverline.
  ///
  /// In en, this message translates to:
  /// **'With a robot'**
  String get scanRobotOverline;

  /// No description provided for @scanRobotTitle.
  ///
  /// In en, this message translates to:
  /// **'Robot scan'**
  String get scanRobotTitle;

  /// No description provided for @scanRobotBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a vehicle. ELIOS is ready; the drone is coming soon.'**
  String get scanRobotBody;

  /// No description provided for @scanSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle'**
  String get scanSelectVehicle;

  /// No description provided for @vehicleEliosDesc.
  ///
  /// In en, this message translates to:
  /// **'Ground robot · camera MaixCAM2'**
  String get vehicleEliosDesc;

  /// No description provided for @vehicleDrone.
  ///
  /// In en, this message translates to:
  /// **'Drone'**
  String get vehicleDrone;

  /// No description provided for @vehicleComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get vehicleComingSoon;

  /// No description provided for @vehicleReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get vehicleReady;

  /// No description provided for @vehicleMaixNote.
  ///
  /// In en, this message translates to:
  /// **'Robots use the MaixCAM2 camera automatically'**
  String get vehicleMaixNote;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS setup'**
  String get setupTitle;

  /// No description provided for @profileTapPicture.
  ///
  /// In en, this message translates to:
  /// **'Tap your picture for account options'**
  String get profileTapPicture;

  /// No description provided for @profileSynced.
  ///
  /// In en, this message translates to:
  /// **'Google account · history synced'**
  String get profileSynced;

  /// No description provided for @profileGuestChip.
  ///
  /// In en, this message translates to:
  /// **'Guest · history saved on this phone only'**
  String get profileGuestChip;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileDarkModeSub.
  ///
  /// In en, this message translates to:
  /// **'Switch the whole app to the dark theme'**
  String get profileDarkModeSub;

  /// No description provided for @profileLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'App text and voice'**
  String get profileLanguageSub;

  /// No description provided for @profileQuestionSource.
  ///
  /// In en, this message translates to:
  /// **'Question source'**
  String get profileQuestionSource;

  /// No description provided for @profileQuestionSourceSub.
  ///
  /// In en, this message translates to:
  /// **'Where the scan quiz gets its questions'**
  String get profileQuestionSourceSub;

  /// No description provided for @profileAccountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account options'**
  String get profileAccountMenu;

  /// No description provided for @profileSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get profileSwitchAccount;

  /// No description provided for @vehicleUse.
  ///
  /// In en, this message translates to:
  /// **'Use {name}'**
  String vehicleUse(String name);

  /// No description provided for @profileNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get profileNotSignedIn;

  /// No description provided for @profileGuestTap.
  ///
  /// In en, this message translates to:
  /// **'Tap the picture to sign in or switch account'**
  String get profileGuestTap;

  /// No description provided for @homeLvShort.
  ///
  /// In en, this message translates to:
  /// **'Lv {n}'**
  String homeLvShort(int n);

  /// No description provided for @homeToNextLong.
  ///
  /// In en, this message translates to:
  /// **'{count} XP to Level {level} · your tree grows as you earn XP'**
  String homeToNextLong(int count, int level);

  /// No description provided for @homeRobotOverline.
  ///
  /// In en, this message translates to:
  /// **'ELIOS robot'**
  String get homeRobotOverline;

  /// No description provided for @homeStillConnected.
  ///
  /// In en, this message translates to:
  /// **'Still connected'**
  String get homeStillConnected;

  /// No description provided for @homeResumeControl.
  ///
  /// In en, this message translates to:
  /// **'Resume robot control'**
  String get homeResumeControl;

  /// No description provided for @lnClovers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clover} other{{count} clovers}}'**
  String lnClovers(int count);

  /// No description provided for @lnGuideRewards.
  ///
  /// In en, this message translates to:
  /// **'{clovers} · {xp} XP from Daily Guides'**
  String lnGuideRewards(int xp, String clovers);

  /// No description provided for @lnCloversOf.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {possible} clovers'**
  String lnCloversOf(int earned, int possible);

  /// No description provided for @wqSavedNoQuiz.
  ///
  /// In en, this message translates to:
  /// **'Saved to History. The quiz is off for robot scans.'**
  String get wqSavedNoQuiz;

  /// No description provided for @setupQuizAfterScan.
  ///
  /// In en, this message translates to:
  /// **'Quiz after each scan'**
  String get setupQuizAfterScan;

  /// No description provided for @setupCameraAuto.
  ///
  /// In en, this message translates to:
  /// **'Camera: MaixCAM2'**
  String get setupCameraAuto;

  /// No description provided for @setupAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get setupAutomatic;

  /// No description provided for @setupOpenControl.
  ///
  /// In en, this message translates to:
  /// **'Open control'**
  String get setupOpenControl;

  /// No description provided for @setupVideoStream.
  ///
  /// In en, this message translates to:
  /// **'Video stream'**
  String get setupVideoStream;

  /// No description provided for @vehicleChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get vehicleChange;

  /// No description provided for @scanHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold steady · one item in the frame'**
  String get scanHoldSteady;

  /// No description provided for @scanTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo and identify'**
  String get scanTakePhoto;

  /// No description provided for @scanAiQuiz.
  ///
  /// In en, this message translates to:
  /// **'AI quiz'**
  String get scanAiQuiz;

  /// No description provided for @contributeTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to contribute'**
  String get contributeTitle;

  /// No description provided for @contributePickBin.
  ///
  /// In en, this message translates to:
  /// **'Which bin are you using?'**
  String get contributePickBin;

  /// No description provided for @contributeDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop the item into the bin while recording.'**
  String get contributeDrop;

  /// No description provided for @contributeKeepLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep the bin label in view so we can check it.'**
  String get contributeKeepLabel;

  /// No description provided for @contributeChecking.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI is checking your video…'**
  String get contributeChecking;

  /// No description provided for @contributeStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get contributeStart;

  /// No description provided for @contributeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get contributeStop;

  /// No description provided for @contributeNice.
  ///
  /// In en, this message translates to:
  /// **'Nice sorting!'**
  String get contributeNice;

  /// No description provided for @contributeNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get contributeNotQuite;

  /// No description provided for @contributeNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check'**
  String get contributeNotChecked;

  /// No description provided for @contributeNoItem.
  ///
  /// In en, this message translates to:
  /// **'ELIOS AI couldn\'t see an item. Try again closer, with good light.'**
  String get contributeNoItem;

  /// No description provided for @contributeWentInto.
  ///
  /// In en, this message translates to:
  /// **'{item} went into the {bin} bin.'**
  String contributeWentInto(String item, String bin);

  /// No description provided for @contributeBelongs.
  ///
  /// In en, this message translates to:
  /// **'{item} belongs in the {bin} bin. Try again!'**
  String contributeBelongs(String item, String bin);

  /// No description provided for @contributeTrophies.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String contributeTrophies(int count);

  /// No description provided for @contributeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to History as a contribution'**
  String get contributeSaved;

  /// No description provided for @contributeAgain.
  ///
  /// In en, this message translates to:
  /// **'Contribute again'**
  String get contributeAgain;

  /// No description provided for @scanContributeOverline.
  ///
  /// In en, this message translates to:
  /// **'Earn XP'**
  String get scanContributeOverline;

  /// No description provided for @scanContributeBody.
  ///
  /// In en, this message translates to:
  /// **'Film yourself putting waste in the right bin. Keep the bin label in view.'**
  String get scanContributeBody;

  /// No description provided for @contributeRec.
  ///
  /// In en, this message translates to:
  /// **'REC {time}'**
  String contributeRec(String time);

  /// No description provided for @histSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'Scans, quizzes and contributions'**
  String get histSubtitle3;

  /// No description provided for @histSeeTimeline.
  ///
  /// In en, this message translates to:
  /// **'See timeline'**
  String get histSeeTimeline;

  /// No description provided for @histByDevice.
  ///
  /// In en, this message translates to:
  /// **'By device'**
  String get histByDevice;

  /// No description provided for @histByDeviceSub.
  ///
  /// In en, this message translates to:
  /// **'Open a device to see its own timeline'**
  String get histByDeviceSub;

  /// No description provided for @histToReview.
  ///
  /// In en, this message translates to:
  /// **'Questions to review'**
  String get histToReview;

  /// No description provided for @histReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get histReview;

  /// No description provided for @histQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz {correct}/{total}'**
  String histQuiz(int correct, int total);

  /// No description provided for @histScanOnly.
  ///
  /// In en, this message translates to:
  /// **'Scan only'**
  String get histScanOnly;

  /// No description provided for @histContribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get histContribution;

  /// No description provided for @histPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get histPhone;

  /// No description provided for @histNoScansYet.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get histNoScansYet;

  /// No description provided for @histTimeline.
  ///
  /// In en, this message translates to:
  /// **'Scan timeline'**
  String get histTimeline;

  /// No description provided for @histTimelineSub.
  ///
  /// In en, this message translates to:
  /// **'Recent scans by device'**
  String get histTimelineSub;

  /// No description provided for @histPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get histPhoneTitle;

  /// No description provided for @histEliosTitle.
  ///
  /// In en, this message translates to:
  /// **'ELIOS robot'**
  String get histEliosTitle;

  /// No description provided for @histDeviceScans.
  ///
  /// In en, this message translates to:
  /// **'{count} scans · camera {camera}'**
  String histDeviceScans(int count, String camera);

  /// No description provided for @histPhoneCamera.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get histPhoneCamera;

  /// No description provided for @histNoDevice.
  ///
  /// In en, this message translates to:
  /// **'Scans saved before this update have no device; they are under All.'**
  String get histNoDevice;

  /// No description provided for @histAllScans.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get histAllScans;

  /// No description provided for @h3TrophiesWord.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get h3TrophiesWord;

  /// No description provided for @celebrateTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get celebrateTap;

  /// No description provided for @celebrateLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level {level}!'**
  String celebrateLevelUp(int level);

  /// No description provided for @celebrateMedal.
  ///
  /// In en, this message translates to:
  /// **'Medal unlocked'**
  String get celebrateMedal;

  /// No description provided for @lnArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'From the archive'**
  String get lnArchiveTitle;

  /// No description provided for @lnArchiveSub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your last guide · swipe the photos} other{Your last {count} guides · swipe the photos}}'**
  String lnArchiveSub(int count);

  /// No description provided for @lnArchivePulled.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get lnArchivePulled;

  /// No description provided for @lnArchivePhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}. Tap to pull out, swipe for the next guide'**
  String lnArchivePhotoLabel(String title);

  /// No description provided for @lnArchiveXp.
  ///
  /// In en, this message translates to:
  /// **'{xp}/{total} XP'**
  String lnArchiveXp(int xp, int total);

  /// No description provided for @lnArchiveXpDone.
  ///
  /// In en, this message translates to:
  /// **'✓ {total} XP'**
  String lnArchiveXpDone(int total);

  /// No description provided for @lnArchiveStops.
  ///
  /// In en, this message translates to:
  /// **'{done}/3 stops'**
  String lnArchiveStops(int done);

  /// No description provided for @lnRailSub.
  ///
  /// In en, this message translates to:
  /// **'{lead} · {count} in {module}'**
  String lnRailSub(String lead, int count, String module);

  /// No description provided for @lnRailVideosLead.
  ///
  /// In en, this message translates to:
  /// **'Watch and learn'**
  String get lnRailVideosLead;

  /// No description provided for @lnRailGuidesLead.
  ///
  /// In en, this message translates to:
  /// **'Read in a minute'**
  String get lnRailGuidesLead;

  /// No description provided for @lnRailQuizLead.
  ///
  /// In en, this message translates to:
  /// **'Check what you know'**
  String get lnRailQuizLead;

  /// No description provided for @lnRailSims.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Try it yourself · 1 lab} other{Try it yourself · {count} labs}}'**
  String lnRailSims(int count);

  /// No description provided for @lnSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get lnSimulation;

  /// No description provided for @lnQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get lnQuizzes;

  /// No description provided for @lnBestShort.
  ///
  /// In en, this message translates to:
  /// **'best {score}%'**
  String lnBestShort(int score);

  /// No description provided for @lnContinueLessonN.
  ///
  /// In en, this message translates to:
  /// **'Continue lesson {n}'**
  String lnContinueLessonN(int n);

  /// No description provided for @lnStartLessonN.
  ///
  /// In en, this message translates to:
  /// **'Start lesson {n}'**
  String lnStartLessonN(int n);

  /// No description provided for @lnWhatGoesIn.
  ///
  /// In en, this message translates to:
  /// **'{module, select, organic{What goes in the green bin} inorganic{What goes in the yellow bin} hazardous{What goes in the red bin} other{What goes in this bin}}'**
  String lnWhatGoesIn(String module);

  /// No description provided for @lnLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lnLessons;

  /// No description provided for @lnModuleProgressDone.
  ///
  /// In en, this message translates to:
  /// **'Module progress · {done} of {total} done'**
  String lnModuleProgressDone(int done, int total);

  /// No description provided for @lnPartN.
  ///
  /// In en, this message translates to:
  /// **'Part {n}'**
  String lnPartN(int n);

  /// No description provided for @lnPctWatched.
  ///
  /// In en, this message translates to:
  /// **'{pct}% watched'**
  String lnPctWatched(int pct);

  /// No description provided for @lnLessonNofM.
  ///
  /// In en, this message translates to:
  /// **'Lesson {n} of {total}'**
  String lnLessonNofM(int n, int total);

  /// No description provided for @lnPlaying.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get lnPlaying;

  /// No description provided for @lnCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get lnCheckAnswer;

  /// No description provided for @lnPickToContinue.
  ///
  /// In en, this message translates to:
  /// **'Pick an answer to continue.'**
  String get lnPickToContinue;

  /// No description provided for @setupWsOverWifi.
  ///
  /// In en, this message translates to:
  /// **'ELIOS WebSocket address over the robot Wi-Fi'**
  String get setupWsOverWifi;

  /// No description provided for @setupJoinWifi.
  ///
  /// In en, this message translates to:
  /// **'Join the ELIOS Wi-Fi'**
  String get setupJoinWifi;

  /// No description provided for @setupJoinWifiBody.
  ///
  /// In en, this message translates to:
  /// **'Scan the Wi-Fi QR on the robot so this phone joins its network.'**
  String get setupJoinWifiBody;

  /// No description provided for @setupShowWifiQr.
  ///
  /// In en, this message translates to:
  /// **'Show robot Wi-Fi QR'**
  String get setupShowWifiQr;

  /// No description provided for @setupFoundAt.
  ///
  /// In en, this message translates to:
  /// **'Found at {ip}'**
  String setupFoundAt(String ip);

  /// No description provided for @setupSearch.
  ///
  /// In en, this message translates to:
  /// **'Search for ELIOS'**
  String get setupSearch;

  /// No description provided for @setupSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get setupSearchAgain;

  /// No description provided for @setupConnectStep.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get setupConnectStep;

  /// No description provided for @setupSaveDefault.
  ///
  /// In en, this message translates to:
  /// **'Save as default address'**
  String get setupSaveDefault;

  /// No description provided for @setupSavedDefault.
  ///
  /// In en, this message translates to:
  /// **'Saved as default address'**
  String get setupSavedDefault;

  /// No description provided for @setupStepState.
  ///
  /// In en, this message translates to:
  /// **'Step {n}, {state}'**
  String setupStepState(int n, String state);

  /// No description provided for @setupStepDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get setupStepDone;

  /// No description provided for @setupStepNow.
  ///
  /// In en, this message translates to:
  /// **'current step'**
  String get setupStepNow;

  /// No description provided for @setupStepTodo.
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get setupStepTodo;

  /// No description provided for @setupStepProblem.
  ///
  /// In en, this message translates to:
  /// **'needs attention'**
  String get setupStepProblem;

  /// No description provided for @histEcoLevel.
  ///
  /// In en, this message translates to:
  /// **'YOUR ECO LEVEL'**
  String get histEcoLevel;

  /// No description provided for @histSyncedShort.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get histSyncedShort;

  /// No description provided for @histSyncingShort.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get histSyncingShort;

  /// No description provided for @histNotSyncedShort.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get histNotSyncedShort;

  /// No description provided for @scanResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan result'**
  String get scanResultTitle;

  /// No description provided for @scanIdentified.
  ///
  /// In en, this message translates to:
  /// **'Identified'**
  String get scanIdentified;

  /// No description provided for @scanIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Identifying…'**
  String get scanIdentifying;

  /// No description provided for @scanBinRecyclable.
  ///
  /// In en, this message translates to:
  /// **'Recyclable bin (Anorganik)'**
  String get scanBinRecyclable;

  /// No description provided for @scanBinOrganic.
  ///
  /// In en, this message translates to:
  /// **'Organic bin (Organik)'**
  String get scanBinOrganic;

  /// No description provided for @scanBinB3.
  ///
  /// In en, this message translates to:
  /// **'Hazardous bin (B3)'**
  String get scanBinB3;

  /// No description provided for @scanBinResidu.
  ///
  /// In en, this message translates to:
  /// **'Residual bin (Residu)'**
  String get scanBinResidu;

  /// No description provided for @scanQuizReady.
  ///
  /// In en, this message translates to:
  /// **'Your quiz is ready'**
  String get scanQuizReady;

  /// No description provided for @scanQuizWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing your quiz…'**
  String get scanQuizWriting;

  /// No description provided for @scanQuizQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String scanQuizQuestions(int count);

  /// No description provided for @scanRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get scanRetake;

  /// No description provided for @scanStartQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start quiz'**
  String get scanStartQuiz;

  /// No description provided for @scanSkipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Skip question'**
  String get scanSkipQuestion;

  /// No description provided for @scanJustNowPhone.
  ///
  /// In en, this message translates to:
  /// **'Just now · Phone'**
  String get scanJustNowPhone;

  /// No description provided for @scanGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get scanGallery;

  /// No description provided for @scanZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom {zoom}'**
  String scanZoom(Object zoom);

  /// No description provided for @scanJustNowRobot.
  ///
  /// In en, this message translates to:
  /// **'Just now · Robot camera'**
  String get scanJustNowRobot;

  /// No description provided for @scanSubmitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get scanSubmitAnswer;

  /// No description provided for @scanEssay.
  ///
  /// In en, this message translates to:
  /// **'Essay'**
  String get scanEssay;

  /// No description provided for @scanFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get scanFlash;

  /// No description provided for @scanWhyWorks.
  ///
  /// In en, this message translates to:
  /// **'Why it works this way'**
  String get scanWhyWorks;

  /// No description provided for @scanBinFits.
  ///
  /// In en, this message translates to:
  /// **'Where each bin fits the scanned item'**
  String get scanBinFits;

  /// No description provided for @scanAskCoach.
  ///
  /// In en, this message translates to:
  /// **'Ask ELIOS AI coach'**
  String get scanAskCoach;

  /// No description provided for @scanAskCoachSub.
  ///
  /// In en, this message translates to:
  /// **'Ask why, get a hint, hear it aloud'**
  String get scanAskCoachSub;

  /// No description provided for @scanBinYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get scanBinYes;

  /// No description provided for @scanBinNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get scanBinNo;

  /// No description provided for @binCheckChip.
  ///
  /// In en, this message translates to:
  /// **'Bin check · before the quiz'**
  String get binCheckChip;

  /// No description provided for @binCheckOverline.
  ///
  /// In en, this message translates to:
  /// **'BIN CHECK · {item}'**
  String binCheckOverline(Object item);

  /// No description provided for @binCheckQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where will this waste go? Pick the right bin.'**
  String get binCheckQuestion;

  /// No description provided for @binOrganik.
  ///
  /// In en, this message translates to:
  /// **'Organik bin'**
  String get binOrganik;

  /// No description provided for @binAnorganik.
  ///
  /// In en, this message translates to:
  /// **'Anorganik bin'**
  String get binAnorganik;

  /// No description provided for @binB3.
  ///
  /// In en, this message translates to:
  /// **'B3 (hazardous) bin'**
  String get binB3;

  /// No description provided for @binOops.
  ///
  /// In en, this message translates to:
  /// **'Oops! Not the {bin} bin'**
  String binOops(Object bin);

  /// No description provided for @binNice.
  ///
  /// In en, this message translates to:
  /// **'Nice sorting! {bin} it is'**
  String binNice(Object bin);

  /// No description provided for @binWhyOrganic.
  ///
  /// In en, this message translates to:
  /// **'{item} is food or plant waste, so it rots. It goes in the Organik bin to become compost.'**
  String binWhyOrganic(Object item);

  /// No description provided for @binWhyAnorganik.
  ///
  /// In en, this message translates to:
  /// **'{item} doesn\'t rot. It goes in the Anorganik bin so it can be recycled.'**
  String binWhyAnorganik(Object item);

  /// No description provided for @binWhyB3.
  ///
  /// In en, this message translates to:
  /// **'{item} can hold harmful materials. It goes in the B3 bin so it is handled safely.'**
  String binWhyB3(Object item);

  /// No description provided for @binQuizNext.
  ///
  /// In en, this message translates to:
  /// **'Your quiz is next'**
  String get binQuizNext;

  /// No description provided for @binGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get binGotIt;

  /// No description provided for @qzMute.
  ///
  /// In en, this message translates to:
  /// **'Mute voice and sounds'**
  String get qzMute;

  /// No description provided for @qzUnmute.
  ///
  /// In en, this message translates to:
  /// **'Turn voice and sounds on'**
  String get qzUnmute;

  /// No description provided for @quizLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the quiz?'**
  String get quizLeaveTitle;

  /// No description provided for @quizLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be lost.'**
  String get quizLeaveBody;

  /// No description provided for @quizLeaveKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get quizLeaveKeep;

  /// No description provided for @quizLeaveLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get quizLeaveLeave;

  /// No description provided for @qzExplanationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Explanation not available yet'**
  String get qzExplanationUnavailable;

  /// No description provided for @h3HeroAlmost.
  ///
  /// In en, this message translates to:
  /// **'Almost there!'**
  String get h3HeroAlmost;

  /// No description provided for @h3HeroPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get h3HeroPerfect;

  /// No description provided for @h3HeroEssayWrongBody.
  ///
  /// In en, this message translates to:
  /// **'Score {score}/10. Let\'s find out why.'**
  String h3HeroEssayWrongBody(Object score);

  /// No description provided for @h3HeroEssayAlmostBody.
  ///
  /// In en, this message translates to:
  /// **'Score {score}/10. A little more for full marks.'**
  String h3HeroEssayAlmostBody(Object score);

  /// No description provided for @h3HeroEssayPerfectBody.
  ///
  /// In en, this message translates to:
  /// **'Score 10/10. Your answer is complete.'**
  String get h3HeroEssayPerfectBody;

  /// No description provided for @essayNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get essayNotQuite;

  /// No description provided for @essayPartly.
  ///
  /// In en, this message translates to:
  /// **'Partly right'**
  String get essayPartly;

  /// No description provided for @essayRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get essayRight;

  /// No description provided for @essayCheckedBy.
  ///
  /// In en, this message translates to:
  /// **'Checked by ELIOS AI · essay'**
  String get essayCheckedBy;

  /// No description provided for @essayScoreOf.
  ///
  /// In en, this message translates to:
  /// **'{score} / 10'**
  String essayScoreOf(Object score);

  /// No description provided for @essayBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Score breakdown'**
  String get essayBreakdown;

  /// No description provided for @rubricAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get rubricAccuracy;

  /// No description provided for @rubricKeyTerms.
  ///
  /// In en, this message translates to:
  /// **'Key terms'**
  String get rubricKeyTerms;

  /// No description provided for @rubricCompleteness.
  ///
  /// In en, this message translates to:
  /// **'Completeness'**
  String get rubricCompleteness;

  /// No description provided for @rubricClarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get rubricClarity;

  /// No description provided for @essayAiNote.
  ///
  /// In en, this message translates to:
  /// **'Scores are made automatically by ELIOS AI and can be wrong. Not sure? Ask your teacher.'**
  String get essayAiNote;

  /// No description provided for @essayYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer · {verdict}'**
  String essayYourAnswer(Object verdict);

  /// No description provided for @essayRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'The right answer'**
  String get essayRightAnswer;

  /// No description provided for @essaySkipped.
  ///
  /// In en, this message translates to:
  /// **'You skipped this question'**
  String get essaySkipped;

  /// No description provided for @essayFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback on your answer'**
  String get essayFeedbackTitle;

  /// No description provided for @essayWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why it is so'**
  String get essayWhyTitle;

  /// No description provided for @essayWhyRightTitle.
  ///
  /// In en, this message translates to:
  /// **'Why your answer is right'**
  String get essayWhyRightTitle;

  /// No description provided for @essayTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips for full marks'**
  String get essayTipsTitle;

  /// No description provided for @essayTipsSub.
  ///
  /// In en, this message translates to:
  /// **'{count} steps to write an essay answer'**
  String essayTipsSub(Object count);

  /// No description provided for @essayTipsDone.
  ///
  /// In en, this message translates to:
  /// **'Combine them into 2–3 sentences for 10/10.'**
  String get essayTipsDone;

  /// No description provided for @pdfReportHead.
  ///
  /// In en, this message translates to:
  /// **'Waste quiz report'**
  String get pdfReportHead;

  /// No description provided for @pdfExportedLabel.
  ///
  /// In en, this message translates to:
  /// **'EXPORTED'**
  String get pdfExportedLabel;

  /// No description provided for @pdfScanResult.
  ///
  /// In en, this message translates to:
  /// **'{category} · scan result'**
  String pdfScanResult(Object category);

  /// No description provided for @pdfCoverMeta.
  ///
  /// In en, this message translates to:
  /// **'{count} questions · {level} level · {mc} multiple choice, {essay} essay'**
  String pdfCoverMeta(Object count, Object level, Object mc, Object essay);

  /// No description provided for @pdfRingLabel.
  ///
  /// In en, this message translates to:
  /// **'CORRECT'**
  String get pdfRingLabel;

  /// No description provided for @pdfHeadNone.
  ///
  /// In en, this message translates to:
  /// **'Try again, you can do it!'**
  String get pdfHeadNone;

  /// No description provided for @pdfHeadSome.
  ///
  /// In en, this message translates to:
  /// **'Good start, keep going!'**
  String get pdfHeadSome;

  /// No description provided for @pdfHeadAll.
  ///
  /// In en, this message translates to:
  /// **'Perfect, all correct!'**
  String get pdfHeadAll;

  /// No description provided for @pdfSubNone.
  ///
  /// In en, this message translates to:
  /// **'{count} new things are ready for you to learn from this quiz.'**
  String pdfSubNone(Object count);

  /// No description provided for @pdfSubSome.
  ///
  /// In en, this message translates to:
  /// **'{count} more to review, then you have it all.'**
  String pdfSubSome(Object count);

  /// No description provided for @pdfSubAll.
  ///
  /// In en, this message translates to:
  /// **'You understand how to sort this waste.'**
  String get pdfSubAll;

  /// No description provided for @pdfXpChip.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP · max. +{max} XP'**
  String pdfXpChip(Object xp, Object max);

  /// No description provided for @pdfPhotoCaption.
  ///
  /// In en, this message translates to:
  /// **'ELIOS scan photo · {time}'**
  String pdfPhotoCaption(Object time);

  /// No description provided for @pdfStamp.
  ///
  /// In en, this message translates to:
  /// **'GRADE: {grade}'**
  String pdfStamp(Object grade);

  /// No description provided for @pdfStampRetry.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get pdfStampRetry;

  /// No description provided for @pdfStampGood.
  ///
  /// In en, this message translates to:
  /// **'GOOD'**
  String get pdfStampGood;

  /// No description provided for @pdfStampPerfect.
  ///
  /// In en, this message translates to:
  /// **'PERFECT'**
  String get pdfStampPerfect;

  /// No description provided for @pdfNeedReview.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String pdfNeedReview(Object count);

  /// No description provided for @pdfAllRight.
  ///
  /// In en, this message translates to:
  /// **'All correct'**
  String get pdfAllRight;

  /// No description provided for @pdfXpRule.
  ///
  /// In en, this message translates to:
  /// **'Right answer = +10'**
  String get pdfXpRule;

  /// No description provided for @pdfDifficultyShort.
  ///
  /// In en, this message translates to:
  /// **'DIFFICULTY'**
  String get pdfDifficultyShort;

  /// No description provided for @pdfQuestionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String pdfQuestionsCount(Object count);

  /// No description provided for @pdfBinGreen.
  ///
  /// In en, this message translates to:
  /// **'Green bin'**
  String get pdfBinGreen;

  /// No description provided for @pdfBinYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow bin'**
  String get pdfBinYellow;

  /// No description provided for @pdfBinRed.
  ///
  /// In en, this message translates to:
  /// **'Red bin'**
  String get pdfBinRed;

  /// No description provided for @pdfBinGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey bin'**
  String get pdfBinGrey;

  /// No description provided for @pdfMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Question map'**
  String get pdfMapTitle;

  /// No description provided for @pdfMapHint.
  ///
  /// In en, this message translates to:
  /// **'open the page for the full explanation'**
  String get pdfMapHint;

  /// No description provided for @pdfTypeMc.
  ///
  /// In en, this message translates to:
  /// **'MULTIPLE CHOICE'**
  String get pdfTypeMc;

  /// No description provided for @pdfTypeEssay.
  ///
  /// In en, this message translates to:
  /// **'ESSAY'**
  String get pdfTypeEssay;

  /// No description provided for @pdfMapPage.
  ///
  /// In en, this message translates to:
  /// **'{type} · P. {page}'**
  String pdfMapPage(Object type, Object page);

  /// No description provided for @pdfYourAnswerLine.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String pdfYourAnswerLine(Object answer);

  /// No description provided for @pdfChipWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get pdfChipWrong;

  /// No description provided for @pdfChipSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get pdfChipSkipped;

  /// No description provided for @pdfTipLabel.
  ///
  /// In en, this message translates to:
  /// **'TIPS FROM ELIOS'**
  String get pdfTipLabel;

  /// No description provided for @pdfTipIdeas.
  ///
  /// In en, this message translates to:
  /// **'Focus on {count} ideas: {ideas} Read the explanations, then retake the quiz.'**
  String pdfTipIdeas(Object count, Object ideas);

  /// No description provided for @pdfTipGeneric.
  ///
  /// In en, this message translates to:
  /// **'Read each explanation, then retake the quiz to earn more XP.'**
  String get pdfTipGeneric;

  /// No description provided for @pdfFooterBrand.
  ///
  /// In en, this message translates to:
  /// **'ELIOS · Waste Sorting Education'**
  String get pdfFooterBrand;

  /// No description provided for @pdfSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID · {id}'**
  String pdfSessionId(Object id);

  /// No description provided for @pdfQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'QUESTION {index} OF {total}'**
  String pdfQuestionOf(Object index, Object total);

  /// No description provided for @pdfQuestionType.
  ///
  /// In en, this message translates to:
  /// **'QUESTION {index} · {type}'**
  String pdfQuestionType(Object index, Object type);

  /// No description provided for @pdfStickerXp.
  ///
  /// In en, this message translates to:
  /// **'{label} · +{xp} XP'**
  String pdfStickerXp(Object label, Object xp);

  /// No description provided for @pdfYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'YOUR ANSWER'**
  String get pdfYourAnswer;

  /// No description provided for @pdfRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'RIGHT ANSWER'**
  String get pdfRightAnswer;

  /// No description provided for @pdfModelAnswer.
  ///
  /// In en, this message translates to:
  /// **'MODEL ANSWER'**
  String get pdfModelAnswer;

  /// No description provided for @pdfYourRight.
  ///
  /// In en, this message translates to:
  /// **'YOUR ANSWER · CORRECT'**
  String get pdfYourRight;

  /// No description provided for @pdfFeedbackLabel.
  ///
  /// In en, this message translates to:
  /// **'FEEDBACK ON YOUR ANSWER'**
  String get pdfFeedbackLabel;

  /// No description provided for @pdfEssayScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'ESSAY SCORE'**
  String get pdfEssayScoreLabel;

  /// No description provided for @pdfGradedBy.
  ///
  /// In en, this message translates to:
  /// **'Graded by ELIOS AI · check with your teacher'**
  String get pdfGradedBy;

  /// No description provided for @pdfNoExplTitle.
  ///
  /// In en, this message translates to:
  /// **'Explanation not saved yet'**
  String get pdfNoExplTitle;

  /// No description provided for @pdfNoExplHint.
  ///
  /// In en, this message translates to:
  /// **'Open this question in the ELIOS app and tap \"Ask ELIOS AI\" to see the full explanation.'**
  String get pdfNoExplHint;

  /// No description provided for @pdfMyNotes.
  ///
  /// In en, this message translates to:
  /// **'My notes'**
  String get pdfMyNotes;

  /// No description provided for @pdfMyNotesHint.
  ///
  /// In en, this message translates to:
  /// **'write in your own words'**
  String get pdfMyNotesHint;

  /// No description provided for @pdfStepsDone.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get pdfStepsDone;

  /// No description provided for @pdfContinued.
  ///
  /// In en, this message translates to:
  /// **'{item} · question {index} (continued)'**
  String pdfContinued(Object item, Object index);

  /// No description provided for @pdfSingleExport.
  ///
  /// In en, this message translates to:
  /// **'{item} · 1-question export'**
  String pdfSingleExport(Object item);

  /// No description provided for @pdfNotesOver.
  ///
  /// In en, this message translates to:
  /// **'QUESTION {index} · NOTES'**
  String pdfNotesOver(Object index);

  /// No description provided for @pdfNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes space'**
  String get pdfNotesTitle;

  /// No description provided for @pdfNotesIntro.
  ///
  /// In en, this message translates to:
  /// **'Go over it in your own way. Finish every part, then ask your teacher or parent to sign.'**
  String get pdfNotesIntro;

  /// No description provided for @pdfN1.
  ///
  /// In en, this message translates to:
  /// **'1 · EXPLAIN AGAIN'**
  String get pdfN1;

  /// No description provided for @pdfN1Prompt.
  ///
  /// In en, this message translates to:
  /// **'In your own words: {question}'**
  String pdfN1Prompt(Object question);

  /// No description provided for @pdfN1Idea.
  ///
  /// In en, this message translates to:
  /// **'Use this idea: {idea}'**
  String pdfN1Idea(Object idea);

  /// No description provided for @pdfN2.
  ///
  /// In en, this message translates to:
  /// **'2 · DRAW & COMPARE'**
  String get pdfN2;

  /// No description provided for @pdfN2Prompt.
  ///
  /// In en, this message translates to:
  /// **'Draw what happens in this idea: {idea}'**
  String pdfN2Prompt(Object idea);

  /// No description provided for @pdfN2Generic.
  ///
  /// In en, this message translates to:
  /// **'Draw what this question describes.'**
  String get pdfN2Generic;

  /// No description provided for @pdfN3.
  ///
  /// In en, this message translates to:
  /// **'3 · CHECK MY UNDERSTANDING'**
  String get pdfN3;

  /// No description provided for @pdfCheckIdea.
  ///
  /// In en, this message translates to:
  /// **'I can explain: {idea}'**
  String pdfCheckIdea(Object idea);

  /// No description provided for @pdfCheckWrong.
  ///
  /// In en, this message translates to:
  /// **'I know why my answer was not quite right.'**
  String get pdfCheckWrong;

  /// No description provided for @pdfCheckRight.
  ///
  /// In en, this message translates to:
  /// **'I can explain why my answer is right.'**
  String get pdfCheckRight;

  /// No description provided for @pdfCheckTry.
  ///
  /// In en, this message translates to:
  /// **'I have tried it at home with: {item}.'**
  String pdfCheckTry(Object item);

  /// No description provided for @pdfN4.
  ///
  /// In en, this message translates to:
  /// **'4 · CHALLENGE'**
  String get pdfN4;

  /// No description provided for @pdfChallenge.
  ///
  /// In en, this message translates to:
  /// **'Retake the \"{item}\" quiz in ELIOS and earn +10 XP for this question.'**
  String pdfChallenge(Object item);

  /// No description provided for @pdfN5.
  ///
  /// In en, this message translates to:
  /// **'5 · MY QUESTION FOR THE TEACHER'**
  String get pdfN5;

  /// No description provided for @pdfSign.
  ///
  /// In en, this message translates to:
  /// **'Teacher / parent signature'**
  String get pdfSign;

  /// No description provided for @pdfDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pdfDate;

  /// No description provided for @pdfSticker.
  ///
  /// In en, this message translates to:
  /// **'Stick a sticker'**
  String get pdfSticker;

  /// No description provided for @pdfThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'PDF theme'**
  String get pdfThemeLabel;

  /// No description provided for @pdfThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get pdfThemeLight;

  /// No description provided for @pdfThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get pdfThemeDark;

  /// No description provided for @pdfReportExport.
  ///
  /// In en, this message translates to:
  /// **'Export quiz report'**
  String get pdfReportExport;

  /// No description provided for @pdfReportSub.
  ///
  /// In en, this message translates to:
  /// **'{item} · {count} questions'**
  String pdfReportSub(Object item, Object count);

  /// No description provided for @advButton.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advButton;

  /// No description provided for @advTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advTitle;

  /// No description provided for @advTeacherMode.
  ///
  /// In en, this message translates to:
  /// **'Teacher mode · robot calibration & settings'**
  String get advTeacherMode;

  /// No description provided for @advSave.
  ///
  /// In en, this message translates to:
  /// **'Save to robot'**
  String get advSave;

  /// No description provided for @advSavedSent.
  ///
  /// In en, this message translates to:
  /// **'Saved and sent to the robot'**
  String get advSavedSent;

  /// No description provided for @advSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Connect the robot to send it.'**
  String get advSavedLocal;

  /// No description provided for @advDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get advDiscardTitle;

  /// No description provided for @advDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes are not saved yet.'**
  String get advDiscardBody;

  /// No description provided for @advDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get advDiscard;

  /// No description provided for @advKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get advKeepEditing;

  /// No description provided for @advConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get advConnected;

  /// No description provided for @advOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get advOffline;

  /// No description provided for @advSecAxes.
  ///
  /// In en, this message translates to:
  /// **'Arm axes'**
  String get advSecAxes;

  /// No description provided for @advSecGripper.
  ///
  /// In en, this message translates to:
  /// **'Gripper'**
  String get advSecGripper;

  /// No description provided for @advSecDrive.
  ///
  /// In en, this message translates to:
  /// **'Drive & joystick'**
  String get advSecDrive;

  /// No description provided for @advSecLink.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get advSecLink;

  /// No description provided for @advSecSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get advSecSafety;

  /// No description provided for @advSecBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get advSecBackup;

  /// No description provided for @advAxesSub.
  ///
  /// In en, this message translates to:
  /// **'Match the real arm to the home pose in the simulator. INV reverses a servo.'**
  String get advAxesSub;

  /// No description provided for @advColAxis.
  ///
  /// In en, this message translates to:
  /// **'AXIS'**
  String get advColAxis;

  /// No description provided for @advColTrim.
  ///
  /// In en, this message translates to:
  /// **'OFFSET (TRIM)'**
  String get advColTrim;

  /// No description provided for @advColInv.
  ///
  /// In en, this message translates to:
  /// **'INV'**
  String get advColInv;

  /// No description provided for @advColHome.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get advColHome;

  /// No description provided for @advColRange.
  ///
  /// In en, this message translates to:
  /// **'RANGE'**
  String get advColRange;

  /// No description provided for @advColSpeed.
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get advColSpeed;

  /// No description provided for @advAxisBase.
  ///
  /// In en, this message translates to:
  /// **'Base (J1)'**
  String get advAxisBase;

  /// No description provided for @advAxisArmA.
  ///
  /// In en, this message translates to:
  /// **'Arm A (J2)'**
  String get advAxisArmA;

  /// No description provided for @advAxisArmB.
  ///
  /// In en, this message translates to:
  /// **'Arm B (J3)'**
  String get advAxisArmB;

  /// No description provided for @advAxisPitch.
  ///
  /// In en, this message translates to:
  /// **'Wrist pitch (J4)'**
  String get advAxisPitch;

  /// No description provided for @advAxisYaw.
  ///
  /// In en, this message translates to:
  /// **'Wrist yaw (J5)'**
  String get advAxisYaw;

  /// No description provided for @advAxesTip.
  ///
  /// In en, this message translates to:
  /// **'Offset up to ±15°. Need more? Move the servo horn one tooth (≈14°). Power the robot on with the base at 90°.'**
  String get advAxesTip;

  /// No description provided for @advTips.
  ///
  /// In en, this message translates to:
  /// **'TIPS'**
  String get advTips;

  /// No description provided for @advImportant.
  ///
  /// In en, this message translates to:
  /// **'IMPORTANT'**
  String get advImportant;

  /// No description provided for @advDanger.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get advDanger;

  /// No description provided for @advGripSub.
  ///
  /// In en, this message translates to:
  /// **'Where the gripper closes. Open stays at 180°.'**
  String get advGripSub;

  /// No description provided for @advGripOffset.
  ///
  /// In en, this message translates to:
  /// **'Closed offset'**
  String get advGripOffset;

  /// No description provided for @advGripOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Up to ±15°. Only the closed position moves.'**
  String get advGripOffsetHint;

  /// No description provided for @advGripInv.
  ///
  /// In en, this message translates to:
  /// **'Reverse open/close (INV)'**
  String get advGripInv;

  /// No description provided for @advGripInvHint.
  ///
  /// In en, this message translates to:
  /// **'PICK UP and RELEASE keep their meaning.'**
  String get advGripInvHint;

  /// No description provided for @advGripMap.
  ///
  /// In en, this message translates to:
  /// **'APP WIDTH → SERVO'**
  String get advGripMap;

  /// No description provided for @advGripOpen.
  ///
  /// In en, this message translates to:
  /// **'0 % (release)'**
  String get advGripOpen;

  /// No description provided for @advGripClosed.
  ///
  /// In en, this message translates to:
  /// **'100 % (pick up)'**
  String get advGripClosed;

  /// No description provided for @advGripTip.
  ///
  /// In en, this message translates to:
  /// **'The gripper squeezes too hard or the servo hums? Lower the closed offset.'**
  String get advGripTip;

  /// No description provided for @advDriveSub.
  ///
  /// In en, this message translates to:
  /// **'Starting values (0231). Test with the wheels lifted first.'**
  String get advDriveSub;

  /// No description provided for @advCapResponse.
  ///
  /// In en, this message translates to:
  /// **'JOYSTICK RESPONSE'**
  String get advCapResponse;

  /// No description provided for @advCapSmooth.
  ///
  /// In en, this message translates to:
  /// **'SMOOTHING'**
  String get advCapSmooth;

  /// No description provided for @advCapBase.
  ///
  /// In en, this message translates to:
  /// **'ARM BASE'**
  String get advCapBase;

  /// No description provided for @advDeadzone.
  ///
  /// In en, this message translates to:
  /// **'Dead zone'**
  String get advDeadzone;

  /// No description provided for @advDeadzoneHint.
  ///
  /// In en, this message translates to:
  /// **'Raise it if the robot creeps at rest.'**
  String get advDeadzoneHint;

  /// No description provided for @advCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve (quadratic)'**
  String get advCurve;

  /// No description provided for @advCurveHint.
  ///
  /// In en, this message translates to:
  /// **'Higher: a light push is slower.'**
  String get advCurveHint;

  /// No description provided for @advTurnGain.
  ///
  /// In en, this message translates to:
  /// **'Turn gain'**
  String get advTurnGain;

  /// No description provided for @advTurnGainHint.
  ///
  /// In en, this message translates to:
  /// **'Turning speed on the spot.'**
  String get advTurnGainHint;

  /// No description provided for @advSlewUp.
  ///
  /// In en, this message translates to:
  /// **'Speed up'**
  String get advSlewUp;

  /// No description provided for @advSlewUpHint.
  ///
  /// In en, this message translates to:
  /// **'How quickly the robot gets going.'**
  String get advSlewUpHint;

  /// No description provided for @advSlewDown.
  ///
  /// In en, this message translates to:
  /// **'Slow down'**
  String get advSlewDown;

  /// No description provided for @advSlewDownHint.
  ///
  /// In en, this message translates to:
  /// **'How quickly it stops.'**
  String get advSlewDownHint;

  /// No description provided for @advMinOutput.
  ///
  /// In en, this message translates to:
  /// **'Minimum output (P0)'**
  String get advMinOutput;

  /// No description provided for @advMinOutputHint.
  ///
  /// In en, this message translates to:
  /// **'Smallest value that turns the wheels on the floor.'**
  String get advMinOutputHint;

  /// No description provided for @advBaseRate.
  ///
  /// In en, this message translates to:
  /// **'Base max speed'**
  String get advBaseRate;

  /// No description provided for @advBaseRateHint.
  ///
  /// In en, this message translates to:
  /// **'Firmware limit 40°/s.'**
  String get advBaseRateHint;

  /// No description provided for @advBaseLimit.
  ///
  /// In en, this message translates to:
  /// **'Base limit'**
  String get advBaseLimit;

  /// No description provided for @advBaseLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Past ±90° the arm can hit the tank.'**
  String get advBaseLimitHint;

  /// No description provided for @advFlipTurn.
  ///
  /// In en, this message translates to:
  /// **'Reverse turning'**
  String get advFlipTurn;

  /// No description provided for @advFlipTurnHint.
  ///
  /// In en, this message translates to:
  /// **'If the robot turns the wrong way.'**
  String get advFlipTurnHint;

  /// No description provided for @advFlipBase.
  ///
  /// In en, this message translates to:
  /// **'Reverse base'**
  String get advFlipBase;

  /// No description provided for @advFlipBaseHint.
  ///
  /// In en, this message translates to:
  /// **'If BASIS turns the wrong way.'**
  String get advFlipBaseHint;

  /// No description provided for @advLinkSub.
  ///
  /// In en, this message translates to:
  /// **'App → Wi-Fi → MaixCAM2. The arm and wheel boards sit behind the MaixCAM2.'**
  String get advLinkSub;

  /// No description provided for @advAddress.
  ///
  /// In en, this message translates to:
  /// **'MaixCAM2 address'**
  String get advAddress;

  /// No description provided for @advLinkStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get advLinkStatus;

  /// No description provided for @advLinkTip.
  ///
  /// In en, this message translates to:
  /// **'ESP32 health and firmware versions will show here once the MaixCAM2 forwards them.'**
  String get advLinkTip;

  /// No description provided for @advSafetySub.
  ///
  /// In en, this message translates to:
  /// **'Built-in limits that protect the robot and students.'**
  String get advSafetySub;

  /// No description provided for @advReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get advReadOnly;

  /// No description provided for @advArmTimeout.
  ///
  /// In en, this message translates to:
  /// **'One arm move, max'**
  String get advArmTimeout;

  /// No description provided for @advSortCap.
  ///
  /// In en, this message translates to:
  /// **'One sort, max'**
  String get advSortCap;

  /// No description provided for @advHeartbeat.
  ///
  /// In en, this message translates to:
  /// **'App heartbeat'**
  String get advHeartbeat;

  /// No description provided for @advNudge.
  ///
  /// In en, this message translates to:
  /// **'Slow approach, max'**
  String get advNudge;

  /// No description provided for @advStopRepeat.
  ///
  /// In en, this message translates to:
  /// **'STOP repeated'**
  String get advStopRepeat;

  /// No description provided for @advHandPause.
  ///
  /// In en, this message translates to:
  /// **'Arm pauses when a hand is in view'**
  String get advHandPause;

  /// No description provided for @advSafetyTip.
  ///
  /// In en, this message translates to:
  /// **'Locking the drive is not an emergency stop. The red STOP always works and can\'t be turned off here.'**
  String get advSafetyTip;

  /// No description provided for @advBackupSub.
  ///
  /// In en, this message translates to:
  /// **'Copy the settings to another phone, or start again.'**
  String get advBackupSub;

  /// No description provided for @advExport.
  ///
  /// In en, this message translates to:
  /// **'Copy settings'**
  String get advExport;

  /// No description provided for @advImport.
  ///
  /// In en, this message translates to:
  /// **'Paste settings'**
  String get advImport;

  /// No description provided for @advCopied.
  ///
  /// In en, this message translates to:
  /// **'Settings copied'**
  String get advCopied;

  /// No description provided for @advImported.
  ///
  /// In en, this message translates to:
  /// **'Settings pasted. Save to keep them.'**
  String get advImported;

  /// No description provided for @advImportFailed.
  ///
  /// In en, this message translates to:
  /// **'No valid settings on the clipboard.'**
  String get advImportFailed;

  /// No description provided for @advChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change teacher PIN'**
  String get advChangePin;

  /// No description provided for @advReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get advReset;

  /// No description provided for @advResetBody.
  ///
  /// In en, this message translates to:
  /// **'Put every robot setting back to its default. Scan history stays.'**
  String get advResetBody;

  /// No description provided for @advResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset all robot settings?'**
  String get advResetConfirm;

  /// No description provided for @advPinCreate.
  ///
  /// In en, this message translates to:
  /// **'Set a teacher PIN'**
  String get advPinCreate;

  /// No description provided for @advPinCreateBody.
  ///
  /// In en, this message translates to:
  /// **'4 digits. Students can\'t open these settings without it.'**
  String get advPinCreateBody;

  /// No description provided for @advPinEnter.
  ///
  /// In en, this message translates to:
  /// **'Teacher PIN'**
  String get advPinEnter;

  /// No description provided for @advPinWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get advPinWrong;

  /// No description provided for @advPinOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get advPinOpen;

  /// No description provided for @advPinSave.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get advPinSave;

  /// No description provided for @advCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get advCancel;
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
