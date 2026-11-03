/// R1 orchestration constants, all in one place (decisions 0021, 0023).
/// Values marked "proposed" were set in R1; the reason is in 0023.
library;

/// The student picks a bin within this time, else the robot reveals anyway (0021).
const binTimeout = Duration(seconds: 15);

/// Time per object question, from when it shows (or from its slot start if it never shows) (0021).
const questionTimeout = Duration(seconds: 20);

/// Object questions asked while the arm sorts (0021).
const objectQuestionCount = 2;

/// Ground distance band (cm, from the floor point below the lens) the arm can pick from.
/// Provisional until the camera is calibrated (0021 amendment a).
const pickBandMinCm = 20.0;
const pickBandMaxCm = 28.0;

/// Proposed: a MaixCAM2 reply over the local WiFi takes well under 1 s; 2 s
/// also covers an inference frame (~0.5 s) delaying the reply.
const ackTimeout = Duration(seconds: 2);

/// Proposed: the AI's image identify takes 7-9 s to its first token (HANDOFF);
/// 45 s leaves room for a slow full answer without hanging forever.
const identifyTimeout = Duration(seconds: 45);

/// Proposed: the B3 / mismatch confirmation card waits for a person.
const confirmTimeout = Duration(seconds: 30);

/// Proposed: how long the revealed bin stays on screen before positioning.
const revealDuration = Duration(seconds: 4);

/// Proposed: POSITION plus READY ("Ambil"): nudging a few cm at low speed and
/// pressing a button takes well under a minute.
const positionTimeout = Duration(seconds: 60);

/// Proposed: one arm command, from its ack to motion_done. The longest joint
/// travel (180 deg) takes 3 s at the 60 deg/s firmware limit; a PICK has about
/// four such segments (approach, descend, grip, lift), so 15 s.
const armTimeout = Duration(seconds: 15);

/// Proposed: after the arm's last motion the servos and the camera (on J1)
/// still settle; ~7 analysed frames at ~5 fps, the same as the stabilizer's
/// 1.5 s re-arm time.
const armSettle = Duration(milliseconds: 1500);

/// Proposed: after PICK's motion_done, the object must have left its floor
/// spot within this time (it is checked on every frame).
const pickVerifyTimeout = Duration(seconds: 2);

/// The floor spot must look empty this long to count as "left" (the
/// stabilizer's dropout tolerance).
const objectGoneFor = Duration(milliseconds: 600);

/// A hand must be out of view this long before a paused arm continues.
const handClearFor = Duration(seconds: 1);

/// Proposed: SORTING to RESUME, whatever happens (three arm commands of up to
/// 15 s each, two 20 s questions, hand pauses): 120 s.
const waitCap = Duration(seconds: 120);

/// Proposed: wheel PWM cap while driving is unlocked for nudges in POSITION
/// (the control screen's default speed is 75).
const nudgeMaxPwm = 40;

/// Proposed: where the arm and gripper show in the image at the home pose,
/// as fractions of the frame (left, top, right, bottom). Measure on the robot.
// ponytail: one fixed rectangle at J1 home; derive it from the arm pose if boxes near the arm still leak through.
const armRegion = (0.0, 0.35, 0.15, 0.65);

/// A Human_Hand box at this score or more pauses the arm (the live scan's presence score).
const handScore = 0.5;
