# `lib/` Inventory

## Folder Tree
```
lib
lib/Screens
lib/Screens/config_screen.dart
lib/Screens/control_screen.dart
lib/Screens/home_screen.dart
lib/Screens/home_shell.dart
lib/Screens/login_screen.dart
lib/Screens/splash_screen.dart
lib/Screens/tabs
lib/Screens/tabs/elearning
lib/Screens/tabs/elearning/guides_page.dart
lib/Screens/tabs/elearning/quiz
lib/Screens/tabs/elearning/quiz/physics_quiz_page.dart
lib/Screens/tabs/elearning/quiz_page.dart
lib/Screens/tabs/elearning/quiz_review_page.dart
lib/Screens/tabs/elearning/simulations
lib/Screens/tabs/elearning/simulations/deep_dive_simulation_page.dart
lib/Screens/tabs/elearning/simulations/density_simulation_page.dart
lib/Screens/tabs/elearning/simulations/heat_simulation_page.dart
lib/Screens/tabs/elearning/simulations/kinematics_simulation_page.dart
lib/Screens/tabs/elearning/simulations/painters
lib/Screens/tabs/elearning/simulations/painters/b3_painters.dart
lib/Screens/tabs/elearning/simulations/painters/density_painter.dart
lib/Screens/tabs/elearning/simulations/painters/heat_painter.dart
lib/Screens/tabs/elearning/simulations/painters/inorganic_painters.dart
lib/Screens/tabs/elearning/simulations/painters/kinematics_painter.dart
lib/Screens/tabs/elearning/simulations/painters/pwm_painter.dart
lib/Screens/tabs/elearning/simulations/painters/torque_painter.dart
lib/Screens/tabs/elearning/simulations/painters/work_energy_painter.dart
lib/Screens/tabs/elearning/simulations/power_budget_simulation_page.dart
lib/Screens/tabs/elearning/simulations/pwm_simulation_page.dart
lib/Screens/tabs/elearning/simulations/simulations_page.dart
lib/Screens/tabs/elearning/simulations/torque_simulation_page.dart
lib/Screens/tabs/elearning/simulations/widgets
lib/Screens/tabs/elearning/simulations/widgets/calc_box.dart
lib/Screens/tabs/elearning/simulations/widgets/collapsible_section.dart
lib/Screens/tabs/elearning/simulations/widgets/deep_explain_card.dart
lib/Screens/tabs/elearning/simulations/widgets/formula_box.dart
lib/Screens/tabs/elearning/simulations/widgets/labeled_slider.dart
lib/Screens/tabs/elearning/simulations/widgets/meta_chip.dart
lib/Screens/tabs/elearning/simulations/widgets/sim_canvas_frame.dart
lib/Screens/tabs/elearning/simulations/widgets/sim_module_header.dart
lib/Screens/tabs/elearning/simulations/widgets/simulation_page_scaffold.dart
lib/Screens/tabs/elearning/simulations/widgets/threshold_banner.dart
lib/Screens/tabs/elearning/simulations/work_energy_simulation_page.dart
lib/Screens/tabs/elearning/video_lessons_page.dart
lib/Screens/tabs/elearning_tab.dart
lib/firebase_options_loader.dart
lib/main.dart
lib/models
lib/models/app_notification.dart
lib/models/config_model.dart
lib/models/elearning_module.dart
lib/models/guide_lesson.dart
lib/models/http_response_model.dart
lib/models/learning_progress.dart
lib/models/physics_module.dart
lib/models/physics_progress.dart
lib/models/quiz_question.dart
lib/models/quiz_set.dart
lib/models/video_lesson.dart
lib/models/waste_category.dart
lib/physics
lib/physics/deep_dive
lib/physics/deep_dive/hooke_spring_state.dart
lib/physics/deep_dive/incinerator_state.dart
lib/physics/deep_dive/nir_reflectance_state.dart
lib/physics/deep_dive/radiation_shielding_state.dart
lib/physics/deep_dive/vapor_pressure_state.dart
lib/physics/density
lib/physics/density/density_notifier.dart
lib/physics/density/density_state.dart
lib/physics/heat
lib/physics/heat/heat_notifier.dart
lib/physics/heat/heat_state.dart
lib/physics/kinematics
lib/physics/kinematics/kinematics_notifier.dart
lib/physics/kinematics/kinematics_state.dart
lib/physics/power
lib/physics/power_budget
lib/physics/power_budget/power_budget_notifier.dart
lib/physics/power_budget/power_budget_state.dart
lib/physics/pwm
lib/physics/pwm/pwm_notifier.dart
lib/physics/pwm/pwm_state.dart
lib/physics/quiz
lib/physics/quiz/physics_quiz_state.dart
lib/physics/shared
lib/physics/shared/porosity_notifier.dart
lib/physics/shared/porosity_state.dart
lib/physics/shared_constants.dart
lib/physics/torque
lib/physics/torque/torque_notifier.dart
lib/physics/torque/torque_state.dart
lib/physics/waste_deep_dive
lib/physics/work_energy
lib/physics/work_energy/work_energy_notifier.dart
lib/physics/work_energy/work_energy_state.dart
lib/providers
lib/providers/app_notification_provider.dart
lib/providers/app_preferences_provider.dart
lib/providers/auth_provider.dart
lib/providers/esp_config_provider.dart
lib/providers/learning_progress_provider.dart
lib/providers/navigation_provider.dart
lib/providers/physics_progress_provider.dart
lib/providers/robot_provider.dart
lib/providers/udp_discovery_provider.dart
lib/providers/wifi_provisioning_provider.dart
lib/services
lib/services/auth_service.dart
lib/services/config_service.dart
lib/services/elearning_content_service.dart
lib/services/progress_service.dart
lib/services/websocket_service.dart
lib/theme
lib/theme/elio_learning_colors.dart
lib/utils
lib/utils/system_ui.dart
lib/widgets
lib/widgets/app_notification_banner.dart
lib/widgets/elio_colors.dart
lib/widgets/elio_learning_app_bar.dart
lib/widgets/hotspot_trap_wrapper.dart
lib/widgets/segmentation_overlay_painter.dart
```

## lib/Screens/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/Screens/config_screen.dart` | ConfigScreen, _ConfigScreenState, _GlassCard, _RobotConnectionPanel, _BatteryStatusChip, _FloatingStatusChip, _ElioConfigModelViewer, _ElioConfigModelViewerState, _ConfigSettingsSheet, _SettingsSectionCard, _SettingsDivider, _SettingsSwitchRow, _SettingsDropdownRow, _SettingsSliderRow, _FieldLabel, _DotSeparator | UI screen for config | package:elio/models/config_model.dart<br>package:elio/providers/udp_discovery_provider.dart<br>package:elio/providers/wifi_provisioning_provider.dart<br>package:elio/services/websocket_service.dart<br>../providers/app_preferences_provider.dart<br>../providers/esp_config_provider.dart<br>../providers/robot_provider.dart<br>../utils/system_ui.dart<br>control_screen.dart |
| `lib/Screens/control_screen.dart` | ControlScreen, _ControlScreenState, _ExitControlButton, _VerticalControlSlider, _LandscapeDriveControls, _DpadButton, _LandscapeCameraPanel, _CameraDiagnosticsBadge, _CameraFallback, _LandscapeActionButtons, _LandscapeSpeedPanel | UI screen for control | ../models/config_model.dart<br>../providers/esp_config_provider.dart<br>../providers/robot_provider.dart<br>../services/websocket_service.dart<br>../widgets/segmentation_overlay_painter.dart |
| `lib/Screens/home_screen.dart` | HomeScreen, _Dashboard, _TopBar, _HeroCard, _ElioRobot3DViewer, _ElioRobot3DViewerState, _RotatingRobotStage, _RotatingRobotStageState, _RobotEye, _HeroStat, _ProgressWarning, _ContinueLearningCard, _ProgressGrid, _ProgressCard, _InsightCard, _SectionHeader, _AchievementList, _AchievementCard, _RecentActivityList, _UnfinishedLearningTile, _CompletedLearningTile, _QuizHistoryTile, _NotificationTile, _NotificationsEmptyState, _ProgressSheetEmptyMessage, _QuickActions, _QuickActionCard, _GuestBanner, _LearningContentInventory, _DashboardData, _Achievement, _ContinueLearningItem, _CompletedLearningItem, _HomeActivity, _LearningActivityType | UI screen for home | ../models/app_notification.dart<br>../models/guide_lesson.dart<br>../models/learning_progress.dart<br>../models/video_lesson.dart<br>../models/waste_category.dart<br>../providers/app_notification_provider.dart<br>../providers/auth_provider.dart<br>../providers/learning_progress_provider.dart<br>../providers/navigation_provider.dart<br>../services/elearning_content_service.dart<br>../widgets/elio_colors.dart<br>tabs/elearning/quiz_review_page.dart |
| `lib/Screens/home_shell.dart` | HomeShell, _HomeShellState, PlaceholderScreen | Home shell implementation | ../utils/system_ui.dart<br>../models/app_notification.dart<br>../providers/app_notification_provider.dart<br>../providers/navigation_provider.dart<br>../providers/robot_provider.dart<br>../widgets/app_notification_banner.dart<br>login_screen.dart<br>home_screen.dart<br>tabs/elearning_tab.dart<br>config_screen.dart<br>control_screen.dart |
| `lib/Screens/login_screen.dart` | LoginScreen, _LoginScreenState, credential | UI screen for login | package:elio/providers/auth_provider.dart<br>home_shell.dart |
| `lib/Screens/splash_screen.dart` | SplashScreen, _SplashScreenState | UI screen for splash | login_screen.dart<br>home_shell.dart |
| `lib/Screens/tabs/elearning/guides_page.dart` | GuidesPage, GuidesContent, _GuidesContentState, _FilterBanner, _GuideModuleCard, _GuideLessonTile, _GuideCover, _GuidePdfPage, _GuidePdfPageState, _GuideMessage | UI screen for guides | ../../../models/guide_lesson.dart<br>../../../providers/learning_progress_provider.dart<br>../../../services/elearning_content_service.dart<br>../../../widgets/elio_learning_app_bar.dart |
| `lib/Screens/tabs/elearning/quiz/physics_quiz_page.dart` | PhysicsQuizPage, _PhysicsQuestionView, _PhysicsQuestionViewState, _AnswerOption, _QuizResult, _DifficultyChip | UI screen for physics quiz | ../../../../../physics/quiz/physics_quiz_state.dart<br>../../../../widgets/elio_learning_app_bar.dart<br>../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/quiz_page.dart` | QuizPage, QuizContent, _QuizContentState, _FilterBanner, _QuizSetGrid, _QuizSetCard, _QuizQuestionView, _QuizQuestionImage, _QuizImageFrame, _QuizImageUnavailable, _AnswerOption, _QuizResult, _DifficultyChip, _CenteredMessage | UI screen for quiz | ../../../models/quiz_question.dart<br>../../../models/quiz_set.dart<br>../../../models/learning_progress.dart<br>../../../providers/learning_progress_provider.dart<br>../../../services/elearning_content_service.dart<br>../../../widgets/elio_learning_app_bar.dart<br>quiz_review_page.dart |
| `lib/Screens/tabs/elearning/quiz_review_page.dart` | QuizReviewPage, _QuizReviewHeader, _QuizReviewMetric, _QuizReviewAnswerCard, _QuizReviewAnswerLine | UI screen for quiz review | ../../../models/learning_progress.dart<br>../../../widgets/elio_learning_app_bar.dart |
| `lib/Screens/tabs/elearning/simulations/deep_dive_simulation_page.dart` | DeepDiveSimulationPage, _DeepDiveSimulationPageState, _OrganicDeepDiveContent, _InorganicDeepDiveContent, _InorganicDeepDiveContentState, _B3DeepDiveContent | UI screen for deep dive simulation | ../../../../../physics/shared/porosity_notifier.dart<br>../../../../../physics/deep_dive/hooke_spring_state.dart<br>../../../../../physics/deep_dive/nir_reflectance_state.dart<br>../../../../../physics/deep_dive/vapor_pressure_state.dart<br>../../../../../physics/deep_dive/incinerator_state.dart<br>../../../../../physics/deep_dive/radiation_shielding_state.dart<br>../../../../../theme/elio_learning_colors.dart<br>widgets/sim_module_header.dart<br>widgets/labeled_slider.dart<br>widgets/simulation_page_scaffold.dart<br>painters/inorganic_painters.dart<br>painters/b3_painters.dart |
| `lib/Screens/tabs/elearning/simulations/density_simulation_page.dart` | DensitySimulationPage, _DensitySimulationPageState, _DensityCanvas, _BinWidget, _BinWidgetState | UI screen for density simulation | ../../../../../physics/shared_constants.dart<br>../../../../../physics/density/density_state.dart<br>../../../../../physics/density/density_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/density_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/threshold_banner.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/heat_simulation_page.dart` | HeatSimulationPage, _HeatSimulationPageState, _HeatCanvas, _HeatCanvasState | UI screen for heat simulation | ../../../../../physics/heat/heat_state.dart<br>../../../../../physics/heat/heat_notifier.dart<br>../../../../../physics/shared/porosity_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/heat_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/threshold_banner.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/kinematics_simulation_page.dart` | KinematicsSimulationPage, _KinematicsSimulationPageState | UI screen for kinematics simulation | ../../../../../physics/kinematics/kinematics_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/kinematics_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/painters/b3_painters.dart` | VaporPressurePainter, IncineratorPainter, RadiationPainter | B3 painters implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/painters/density_painter.dart` | DensityPainter | Density painter implementation | - |
| `lib/Screens/tabs/elearning/simulations/painters/heat_painter.dart` | Particle, HeatCompostPainter, ThermometerPainter | Heat painter implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/painters/inorganic_painters.dart` | HookeSpringPainter, NirCurvePainter, EddyCurrentPainter | Inorganic painters implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/painters/kinematics_painter.dart` | KinematicsPainter | Kinematics painter implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/painters/pwm_painter.dart` | PwmWavePainter, PwmWheelPainter | Pwm painter implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/painters/torque_painter.dart` | TorquePainter | Torque painter implementation | ../../../../../physics/torque/torque_state.dart |
| `lib/Screens/tabs/elearning/simulations/painters/work_energy_painter.dart` | WorkEnergyPainter | Work energy painter implementation | ../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/power_budget_simulation_page.dart` | PowerBudgetSimulationPage | UI screen for power budget simulation | ../../../../../physics/power_budget/power_budget_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/pwm_simulation_page.dart` | PwmSimulationPage, _PwmSimulationPageState | UI screen for pwm simulation | ../../../../../physics/pwm/pwm_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/pwm_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/simulations_page.dart` | SimulationsPage, SimulationsContent, _SimulationCard, _StatusBadge, _PhysicsProgressOverviewCard | UI screen for simulations | ../../../../models/physics_module.dart<br>../../../../widgets/elio_learning_app_bar.dart<br>../../../../theme/elio_learning_colors.dart<br>torque_simulation_page.dart<br>density_simulation_page.dart<br>heat_simulation_page.dart<br>work_energy_simulation_page.dart<br>kinematics_simulation_page.dart<br>pwm_simulation_page.dart<br>power_budget_simulation_page.dart<br>deep_dive_simulation_page.dart<br>../quiz/physics_quiz_page.dart<br>widgets/meta_chip.dart<br>../../../../providers/physics_progress_provider.dart<br>../../../../models/physics_progress.dart |
| `lib/Screens/tabs/elearning/simulations/torque_simulation_page.dart` | TorqueSimulationPage, _TorqueSimulationPageState, _TorqueCanvas | UI screen for torque simulation | ../../../../../physics/torque/torque_state.dart<br>../../../../../physics/torque/torque_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/torque_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/threshold_banner.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/calc_box.dart` | CalcBox | Calc box implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/collapsible_section.dart` | CollapsibleSection, _CollapsibleSectionState | Collapsible section implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/deep_explain_card.dart` | DeepExplainCard | Deep explain card implementation | ../../../../../../theme/elio_learning_colors.dart<br>collapsible_section.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/formula_box.dart` | FormulaBox | Formula box implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/labeled_slider.dart` | LabeledSlider | Labeled slider implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/meta_chip.dart` | MetaChip | Meta chip implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/sim_canvas_frame.dart` | SimCanvasFrame, _SimNote, _RiskBadge | Sim canvas frame implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/sim_module_header.dart` | SimModuleHeader | Sim module header implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/simulation_page_scaffold.dart` | SimulationPageScaffold | UI screen for simulation scaffold | ../../../../../../theme/elio_learning_colors.dart<br>../../../../../widgets/elio_learning_app_bar.dart<br>collapsible_section.dart |
| `lib/Screens/tabs/elearning/simulations/widgets/threshold_banner.dart` | ThresholdBanner | Threshold banner implementation | ../../../../../../theme/elio_learning_colors.dart |
| `lib/Screens/tabs/elearning/simulations/work_energy_simulation_page.dart` | WorkEnergySimulationPage, _WorkEnergyCanvas | UI screen for work energy simulation | ../../../../../physics/shared_constants.dart<br>../../../../../physics/work_energy/work_energy_state.dart<br>../../../../../physics/work_energy/work_energy_notifier.dart<br>../../../../../theme/elio_learning_colors.dart<br>painters/work_energy_painter.dart<br>widgets/sim_module_header.dart<br>widgets/formula_box.dart<br>widgets/sim_canvas_frame.dart<br>widgets/labeled_slider.dart<br>widgets/calc_box.dart<br>widgets/deep_explain_card.dart<br>widgets/simulation_page_scaffold.dart |
| `lib/Screens/tabs/elearning/video_lessons_page.dart` | VideoLessonsPage, VideoLessonsContent, _VideoLessonsContentState, _FilterBanner, _FeaturedVideoCard, _VideoLessonCard, _YoutubeVideoPage, _YoutubeVideoPageState, _VideoBadge, _VideoMessage | UI screen for video lessons | ../../../models/video_lesson.dart<br>../../../providers/learning_progress_provider.dart<br>../../../services/elearning_content_service.dart<br>../../../widgets/elio_learning_app_bar.dart |
| `lib/Screens/tabs/elearning_tab.dart` | ElearningTab, _ElearningTabState, _LearningNotificationTile, _LearningNotificationsEmptyState, _AllCategoriesContent, _LearningHeader, _LearningFilterChips, _LearningFilterChipsState, _ProgressOverviewCard, _CourseModulesSection, _ModulesMessage, _CourseModuleCard, _LearningPathSheet, _LearningPathButton, _ModuleArtwork, _BlurredCircle, _LevelChip, _InfoChip, _ModuleMetadata, LearningSection | Elearning tab implementation | ../../models/elearning_module.dart<br>../../models/app_notification.dart<br>../../models/learning_progress.dart<br>../../models/waste_category.dart<br>../../providers/app_notification_provider.dart<br>../../providers/learning_progress_provider.dart<br>../../providers/navigation_provider.dart<br>../../services/elearning_content_service.dart<br>../../widgets/elio_learning_app_bar.dart<br>elearning/guides_page.dart<br>elearning/quiz_page.dart<br>elearning/video_lessons_page.dart<br>elearning/simulations/simulations_page.dart |

## lib/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/firebase_options_loader.dart` | - | Firebase options loader implementation | - |
| `lib/main.dart` | ElioApp, _AuthGate | Main implementation | firebase_options_loader.dart<br>utils/system_ui.dart<br>Screens/home_shell.dart<br>Screens/login_screen.dart |

## lib/models/

**FLAG**: This folder has >8 files sitting flat and is a reorganization candidate.

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/models/app_notification.dart` | AppNotification, AppNotificationType | Data structure for app notification | - |
| `lib/models/config_model.dart` | EspConfig | Data structure for config | - |
| `lib/models/elearning_module.dart` | ElearningModule | Data structure for elearning module | - |
| `lib/models/guide_lesson.dart` | GuideLesson | Data structure for guide lesson | - |
| `lib/models/http_response_model.dart` | HttpResponseModel | Data structure for http response | - |
| `lib/models/learning_progress.dart` | CategoryProgress, QuizReviewAnswer, QuizReview, LearningProgress | Data structure for learning progress | - |
| `lib/models/physics_module.dart` | PhysicsModule, PhysicsModuleId | Data structure for physics module | - |
| `lib/models/physics_progress.dart` | PhysicsProgress | Data structure for physics progress | - |
| `lib/models/quiz_question.dart` | QuizQuestion | Data structure for quiz question | - |
| `lib/models/quiz_set.dart` | QuizSet | Data structure for quiz set | - |
| `lib/models/video_lesson.dart` | VideoLesson | Data structure for video lesson | - |
| `lib/models/waste_category.dart` | WasteCategory, QuizQuestion | Data structure for waste category | - |

## lib/physics/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/physics/deep_dive/hooke_spring_state.dart` | HookeSpringState, HookeSpringNotifier, hookeSpringProvider | Hooke spring state implementation | - |
| `lib/physics/deep_dive/incinerator_state.dart` | IncineratorState, IncineratorNotifier, incineratorProvider | Incinerator state implementation | - |
| `lib/physics/deep_dive/nir_reflectance_state.dart` | NirReflectanceState, NirReflectanceNotifier, PlasticType, nirReflectanceProvider | Nir reflectance state implementation | - |
| `lib/physics/deep_dive/radiation_shielding_state.dart` | RadiationShieldingState, RadiationShieldingNotifier, RadiationType, radiationShieldingProvider | Radiation shielding state implementation | - |
| `lib/physics/deep_dive/vapor_pressure_state.dart` | VaporPressureState, VaporPressureNotifier, vaporPressureProvider | Vapor pressure state implementation | - |
| `lib/physics/density/density_notifier.dart` | DensityNotifier, densityProvider | Density notifier implementation | density_state.dart |
| `lib/physics/density/density_state.dart` | DensityState, WasteCategory | Density state implementation | - |
| `lib/physics/heat/heat_notifier.dart` | HeatNotifier, heatProvider | Heat notifier implementation | heat_state.dart |
| `lib/physics/heat/heat_state.dart` | HeatState, CompostPhase | Heat state implementation | - |
| `lib/physics/kinematics/kinematics_notifier.dart` | KinematicsNotifier, kinematicsProvider | Kinematics notifier implementation | kinematics_state.dart |
| `lib/physics/kinematics/kinematics_state.dart` | KinematicsState | Kinematics state implementation | - |
| `lib/physics/power_budget/power_budget_notifier.dart` | PowerBudgetNotifier, powerBudgetProvider | Power budget notifier implementation | power_budget_state.dart |
| `lib/physics/power_budget/power_budget_state.dart` | PowerBudgetState | Power budget state implementation | ../shared_constants.dart |
| `lib/physics/pwm/pwm_notifier.dart` | PwmNotifier, pwmProvider | Pwm notifier implementation | pwm_state.dart |
| `lib/physics/pwm/pwm_state.dart` | PwmState | Pwm state implementation | - |
| `lib/physics/quiz/physics_quiz_state.dart` | PhysicsQuizQuestion, PhysicsQuizState, PhysicsQuizNotifier, QuizResult, physicsQuizProvider | Physics quiz state implementation | - |
| `lib/physics/shared/porosity_notifier.dart` | PorosityNotifier, porosityProvider | Porosity notifier implementation | porosity_state.dart |
| `lib/physics/shared/porosity_state.dart` | PorosityState | Porosity state implementation | - |
| `lib/physics/shared_constants.dart` | - | Shared constants implementation | - |
| `lib/physics/torque/torque_notifier.dart` | TorqueNotifier, torqueProvider | Torque notifier implementation | torque_state.dart |
| `lib/physics/torque/torque_state.dart` | TorqueState, MotorStatus | Torque state implementation | - |
| `lib/physics/work_energy/work_energy_notifier.dart` | WorkEnergyNotifier, workEnergyProvider | Work energy notifier implementation | work_energy_state.dart |
| `lib/physics/work_energy/work_energy_state.dart` | WorkEnergyState | Work energy state implementation | ../shared_constants.dart |

## lib/providers/

**FLAG**: This folder has >8 files sitting flat and is a reorganization candidate.

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/providers/app_notification_provider.dart` | AppNotificationNotifier, appNotificationProvider, unreadNotificationCountProvider, latestBannerNotificationProvider | State management for app notification | ../models/app_notification.dart |
| `lib/providers/app_preferences_provider.dart` | AppPreferences, AppPreferencesNotifier, appPreferencesProvider | State management for app preferences | - |
| `lib/providers/auth_provider.dart` | authStateProvider, currentUserProvider, isGuestProvider | State management for auth | - |
| `lib/providers/esp_config_provider.dart` | EspConfigNotifier, espConfigProvider | State management for esp config | ../models/config_model.dart<br>../services/config_service.dart |
| `lib/providers/learning_progress_provider.dart` | LearningProgressNotifier, progressServiceProvider, learningProgressProvider, progressSyncWarningProvider | State management for learning progress | ../models/app_notification.dart<br>../models/learning_progress.dart<br>../services/progress_service.dart<br>app_notification_provider.dart<br>auth_provider.dart |
| `lib/providers/navigation_provider.dart` | LearningResumeIntent, LearningResumeType, navigationIndexProvider, learningResumeIntentProvider | State management for navigation | - |
| `lib/providers/physics_progress_provider.dart` | PhysicsProgressNotifier, progressServiceProvider, physicsProgressProvider | State management for physics progress | ../models/physics_progress.dart<br>../services/progress_service.dart<br>auth_provider.dart |
| `lib/providers/robot_provider.dart` | RobotState, RobotControlNotifier, robotConnectionProvider, robotFrameProvider, robotStatusProvider, robotControlProvider, resolutionAckProvider | State management for robot | ../services/websocket_service.dart |
| `lib/providers/udp_discovery_provider.dart` | UdpDiscoveryNotifier, udpDiscoveryProvider | State management for udp discovery | - |
| `lib/providers/wifi_provisioning_provider.dart` | wifiSsidProvider | State management for wifi provisioning | - |

## lib/services/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/services/auth_service.dart` | - | Business logic/API for auth | - |
| `lib/services/config_service.dart` | ConfigService | Business logic/API for config | ../models/config_model.dart |
| `lib/services/elearning_content_service.dart` | ElearningContentService | Business logic/API for elearning content | ../models/elearning_module.dart<br>../models/guide_lesson.dart<br>../models/quiz_question.dart<br>../models/quiz_set.dart<br>../models/video_lesson.dart |
| `lib/services/progress_service.dart` | ProgressService | Business logic/API for progress | ../models/learning_progress.dart<br>../models/physics_progress.dart |
| `lib/services/websocket_service.dart` | WebSocketService, Detection | Business logic/API for websocket | - |

## lib/theme/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/theme/elio_learning_colors.dart` | - | Elio learning colors implementation | - |

## lib/utils/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/utils/system_ui.dart` | - | System ui implementation | - |

## lib/widgets/

| File | Exports | Purpose | Depends on |
|---|---|---|---|
| `lib/widgets/app_notification_banner.dart` | AppNotificationBannerHost, _AppNotificationBannerHostState, _AppNotificationBanner | App notification banner implementation | ../models/app_notification.dart<br>../providers/app_notification_provider.dart |
| `lib/widgets/elio_colors.dart` | - | Elio colors implementation | - |
| `lib/widgets/elio_learning_app_bar.dart` | ElioLearningAppBar | Elio learning app bar implementation | - |
| `lib/widgets/hotspot_trap_wrapper.dart` | HotspotTrapWrapper, connectivityStreamProvider | Hotspot trap wrapper implementation | - |
| `lib/widgets/segmentation_overlay_painter.dart` | SegmentationOverlayPainter, _CoverTransform | Segmentation overlay painter implementation | ../services/websocket_service.dart |

