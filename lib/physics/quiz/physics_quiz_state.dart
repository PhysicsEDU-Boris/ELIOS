import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum QuizResult { unanswered, correct, wrong }

class PhysicsQuizQuestion {
  final String moduleId;
  final Map<String, num> Function(Random) randomize;
  final String Function(Map<String, num>) prompt;
  final List<String> Function(Map<String, num>) options;
  final int correctIndex;
  final String Function(Map<String, num>) workedSolution;

  const PhysicsQuizQuestion({
    required this.moduleId,
    required this.randomize,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.workedSolution,
  });
}

// Helper to format numbers nicely
String _fmt(num value) => value.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');

final List<PhysicsQuizQuestion> physicsQuizQuestions = [
  // 1. Density (Module A)
  PhysicsQuizQuestion(
    moduleId: 'density',
    correctIndex: 1, // Option B
    randomize: (r) => {
      'm': 100 + r.nextInt(1900), // 100 - 2000 g
      'V': 100 + r.nextInt(900),  // 100 - 1000 cm3
    },
    prompt: (d) => 'Sebuah sampel sampah inorganik memiliki massa ${_fmt(d['m']!)} g dan volume ${_fmt(d['V']!)} cm³. Berapa massa jenis (densitas) sampah tersebut?',
    options: (d) {
      final m = d['m']!;
      final v = d['V']!;
      return [
        '${_fmt(v / m)} g/cm³', // Distractor: V/m (swapped)
        '${_fmt(m / v)} g/cm³', // Correct
        '${_fmt(m * v)} g/cm³', // Distractor: m*v
        '${_fmt(m + v)} g/cm³', // Distractor: m+v
      ];
    },
    workedSolution: (d) => 'ρ = m / V\nρ = ${_fmt(d['m']!)} / ${_fmt(d['V']!)} = ${_fmt(d['m']! / d['V']!)} g/cm³',
  ),
  
  // 2. Heat (Module B)
  PhysicsQuizQuestion(
    moduleId: 'heat',
    correctIndex: 0, // Option A
    randomize: (r) => {
      'm': 1 + r.nextInt(10), // 1 - 10 kg
      'c': 4000, // J/kgC
      'dT': 10 + r.nextInt(40), // 10 - 50 C
    },
    prompt: (d) => 'Tumpukan kompos bermassa ${_fmt(d['m']!)} kg mengalami kenaikan suhu sebesar ${_fmt(d['dT']!)} °C. Jika kalor jenis (c) kompos adalah ${_fmt(d['c']!)} J/kg°C, berapa total kalor (Q) yang dihasilkan mikroba?',
    options: (d) {
      final m = d['m']!;
      final c = d['c']!;
      final dt = d['dT']!;
      return [
        '${_fmt(m * c * dt)} J', // Correct
        '${_fmt(m + dt)} J',     // Distractor: m + ΔT
        '${_fmt(m * dt)} J',     // Distractor: missing c (m * ΔT)
        '${_fmt(m * c / dt)} J', // Distractor: m * c / ΔT
      ];
    },
    workedSolution: (d) => 'Q = m · c · ΔT\nQ = ${_fmt(d['m']!)} · ${_fmt(d['c']!)} · ${_fmt(d['dT']!)} = ${_fmt(d['m']! * d['c']! * d['dT']!)} J',
  ),

  // 3. Torque (Module C)
  PhysicsQuizQuestion(
    moduleId: 'torque',
    correctIndex: 2, // Option C
    randomize: (r) {
      final angles = [30.0, 45.0, 60.0];
      return {
        'r': 0.1 + (r.nextInt(5) / 10.0), // 0.1 - 0.5 m
        'F': 5 + r.nextInt(15), // 5 - 20 N
        'theta': angles[r.nextInt(angles.length)], // degrees
      };
    },
    prompt: (d) => 'Lengan robot memanjang sejauh ${_fmt(d['r']!)} m dan mengangkat beban dengan gaya ${_fmt(d['F']!)} N pada sudut ${_fmt(d['theta']!)}° terhadap lengan. Berapa besar torsi pada sendi bahu?',
    options: (d) {
      final r = d['r']!;
      final f = d['F']!;
      final thetaRad = d['theta']! * (pi / 180.0);
      final sinTheta = sin(thetaRad);
      return [
        '${_fmt(r * f)} N·m',         // Distractor: r*F (forgot sin)
        '${_fmt(f * sinTheta)} N·m',  // Distractor: F*sin (forgot r)
        '${_fmt(r * f * sinTheta)} N·m', // Correct
        '${_fmt(r + f)} N·m',         // Distractor: r+F
      ];
    },
    workedSolution: (d) => 'τ = r · F · sin(θ)\nτ = ${_fmt(d['r']!)} · ${_fmt(d['F']!)} · sin(${_fmt(d['theta']!)}°) = ${_fmt(d['r']! * d['F']! * sin(d['theta']! * pi / 180.0))} N·m',
  ),

  // 4. WorkEnergy (Module D)
  PhysicsQuizQuestion(
    moduleId: 'workEnergy',
    correctIndex: 3, // Option D
    randomize: (r) => {
      'm': 1 + r.nextInt(5), // 1 - 5 kg
      'g': 10, // m/s2
      'h': 0.2 + (r.nextInt(14) / 10.0), // 0.2 - 1.5 m
    },
    prompt: (d) => 'ELIO mengangkat beban ${_fmt(d['m']!)} kg setinggi ${_fmt(d['h']!)} m. Berapa usaha yang dilakukan melawan gravitasi (g = 10 m/s²)?',
    options: (d) {
      final m = d['m']!;
      final g = d['g']!;
      final h = d['h']!;
      return [
        '${_fmt(m * h)} J', // Distractor: m*h (forgot g)
        '${_fmt(m / h)} J', // Distractor: m/h
        '${_fmt(g * h)} J', // Distractor: g*h (forgot m)
        '${_fmt(m * g * h)} J', // Correct
      ];
    },
    workedSolution: (d) => 'W = m · g · h\nW = ${_fmt(d['m']!)} · 10 · ${_fmt(d['h']!)} = ${_fmt(d['m']! * 10 * d['h']!)} J',
  ),

  // 5. Kinematics (Module E)
  PhysicsQuizQuestion(
    moduleId: 'kinematics',
    correctIndex: 0, // Option A
    randomize: (r) => {
      's': 5 + r.nextInt(45), // 5 - 50 m
      't': 2 + r.nextInt(9), // 2 - 10 s
    },
    prompt: (d) => 'ELIO bergerak lurus sejauh ${_fmt(d['s']!)} meter dalam waktu ${_fmt(d['t']!)} detik menuju target. Berapa kecepatan rata-ratanya?',
    options: (d) {
      final s = d['s']!;
      final t = d['t']!;
      return [
        '${_fmt(s / t)} m/s', // Correct
        '${_fmt(s * t)} m/s', // Distractor: s*t
        '${_fmt(t / s)} m/s', // Distractor: t/s
        '${_fmt(s + t)} m/s', // Distractor: s+t
      ];
    },
    workedSolution: (d) => 'v = s / t\nv = ${_fmt(d['s']!)} / ${_fmt(d['t']!)} = ${_fmt(d['s']! / d['t']!)} m/s',
  ),

  // 6. PWM (Module F)
  PhysicsQuizQuestion(
    moduleId: 'pwm',
    correctIndex: 1, // Option B
    randomize: (r) => {
      'D': 10 + r.nextInt(81), // 10 - 90 %
      'Vmax': 12, // V
    },
    prompt: (d) => 'Sinyal PWM mengatur tegangan motor dengan Duty Cycle (D) sebesar ${_fmt(d['D']!)}%. Jika tegangan maksimal baterai adalah ${_fmt(d['Vmax']!)} V, berapa tegangan rata-rata motor?',
    options: (d) {
      final dPct = d['D']! / 100.0;
      final vmax = d['Vmax']!;
      return [
        '${_fmt(vmax - d['D']!)} V', // Distractor: Vmax - D (unit confusion)
        '${_fmt(dPct * vmax)} V',    // Correct
        '${_fmt(vmax / dPct)} V',    // Distractor: Vmax / D
        '${_fmt(d['D']! / vmax)} V', // Distractor: D / Vmax
      ];
    },
    workedSolution: (d) => 'V_avg = (D / 100) · V_max\nV_avg = ${_fmt(d['D']!)}% · 12 = ${_fmt((d['D']! / 100.0) * 12)} V',
  ),

  // 7. Power (Module G)
  PhysicsQuizQuestion(
    moduleId: 'power',
    correctIndex: 3, // Option D
    randomize: (r) => {
      'V': 12, // V
      'I': 1 + r.nextInt(5), // 1 - 5 A
    },
    prompt: (d) => 'Sebuah subsistem menarik arus sebesar ${_fmt(d['I']!)} A dari baterai ${_fmt(d['V']!)} V. Berapa daya yang dikonsumsi?',
    options: (d) {
      final v = d['V']!;
      final i = d['I']!;
      return [
        '${_fmt(v + i)} W', // Distractor: V + I
        '${_fmt(v / i)} W', // Distractor: V / I
        '${_fmt(i / v)} W', // Distractor: I / V
        '${_fmt(v * i)} W', // Correct
      ];
    },
    workedSolution: (d) => 'P = V · I\nP = 12 · ${_fmt(d['I']!)} = ${_fmt(12 * d['I']!)} W',
  ),
];

class PhysicsQuizState {
  final Map<String, Map<String, num>> currentData;
  final Map<String, QuizResult> results;
  
  const PhysicsQuizState({
    required this.currentData,
    required this.results,
  });
  
  int get score => results.values.where((r) => r == QuizResult.correct).length;
  int get total => physicsQuizQuestions.length; // 7

  PhysicsQuizState copyWith({
    Map<String, Map<String, num>>? currentData,
    Map<String, QuizResult>? results,
  }) {
    return PhysicsQuizState(
      currentData: currentData ?? this.currentData,
      results: results ?? this.results,
    );
  }
}

class PhysicsQuizNotifier extends Notifier<PhysicsQuizState> {
  @override
  PhysicsQuizState build() {
    return _generateInitialState();
  }

  PhysicsQuizState _generateInitialState() {
    final rand = Random();
    final data = <String, Map<String, num>>{};
    final results = <String, QuizResult>{};
    
    for (final q in physicsQuizQuestions) {
      data[q.moduleId] = q.randomize(rand);
      results[q.moduleId] = QuizResult.unanswered;
    }
    
    return PhysicsQuizState(currentData: data, results: results);
  }

  void answer(String moduleId, int selectedIndex) {
    final q = physicsQuizQuestions.firstWhere((q) => q.moduleId == moduleId);
    final isCorrect = selectedIndex == q.correctIndex;
    
    final newResults = Map<String, QuizResult>.from(state.results);
    newResults[moduleId] = isCorrect ? QuizResult.correct : QuizResult.wrong;
    
    state = state.copyWith(results: newResults);
  }

  void resetQuestion(String moduleId) {
    final rand = Random();
    final q = physicsQuizQuestions.firstWhere((q) => q.moduleId == moduleId);
    
    final newData = Map<String, Map<String, num>>.from(state.currentData);
    newData[moduleId] = q.randomize(rand);
    
    final newResults = Map<String, QuizResult>.from(state.results);
    newResults[moduleId] = QuizResult.unanswered;
    
    state = state.copyWith(currentData: newData, results: newResults);
  }

  void resetAll() {
    final newResults = <String, QuizResult>{};
    for (final key in state.results.keys) {
      newResults[key] = QuizResult.unanswered;
    }
    state = state.copyWith(results: newResults);
  }

  void randomizeAll() {
    state = _generateInitialState();
  }
}

final physicsQuizProvider = NotifierProvider<PhysicsQuizNotifier, PhysicsQuizState>(PhysicsQuizNotifier.new);
