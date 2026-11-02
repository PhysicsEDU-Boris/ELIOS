import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/pwm/pwm_notifier.dart';
import 'painters/pwm_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class PwmSimulationPage extends ConsumerStatefulWidget {
  const PwmSimulationPage({super.key});

  @override
  ConsumerState<PwmSimulationPage> createState() => _PwmSimulationPageState();
}

class _PwmSimulationPageState extends ConsumerState<PwmSimulationPage> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  double _wheelAngle = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0) return;

    final state = ref.read(pwmProvider);
    
    setState(() {
      _time += dt;
      // Convert RPM to radians per second: (RPM / 60) * 2π
      final rps = state.approxRpm / 60.0;
      final radsPerSec = rps * 2 * 3.14159;
      _wheelAngle += radsPerSec * dt;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pwmProvider);
    final notifier = ref.read(pwmProvider.notifier);

    return SimulationPageScaffold(
      module: PhysicsModuleId.pwm,
      appBarTitle: 'PWM & Motor',
      header: const SimModuleHeader(
        tag: 'MODUL F · MATERI',
        title: 'PWM & Tegangan Efektif',
        subtitle: 'Atur kecepatan motor ELIO tanpa membuang energi panas lewat resistor.',
      ),
      formulaBox: FormulaBox(
        title: 'TEGANGAN RATA-RATA EFEKTIF',
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'V_avg = D · V_max = '),
            TextSpan(
              text: '${state.averageVoltage.toStringAsFixed(1)} V',
              style: TextStyle(color: context.elio.secondaryText),
            ),
          ],
        ),
        subtitle: 'D = Duty Cycle · V_max = 12.0V',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  
                  SimCanvasFrame(
                    noteText: 'Gelombang Kotak (Sinyal PWM)',
                    canvas: AspectRatio(
                      aspectRatio: 340 / 100,
                      child: CustomPaint(
                        painter: PwmWavePainter(
                          dutyPercent: state.dutyPercent,
                          time: _time,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Wheel and RPM Readout
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.elio.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.elio.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: PwmWheelPainter(angle: _wheelAngle),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kecepatan Motor (RPM)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.elio.textSecondary)),
                              const SizedBox(height: 4),
                              Text('${state.approxRpm.toStringAsFixed(0)} RPM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.elio.primaryText)),
                              const SizedBox(height: 4),
                              // REQUIRED LABEL: DO NOT REMOVE
                              Text('Perkiraan (aproksimasi linear)', style: TextStyle(fontSize: 10, color: context.elio.secondaryText, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Sliders
                  LabeledSlider(
                    label: 'Duty Cycle (D)',
                    valueLabel: '${state.dutyPercent.toStringAsFixed(0)}%',
                    value: state.dutyPercent,
                    min: 0.0,
                    max: 100.0,
                    onChanged: (v) => notifier.setDuty(v),
                  ),
                  const SizedBox(height: 16),

                  CalcBox(
                    headerTitle: 'TEGANGAN MOTOR',
                    formulaExpression: 'V_avg = ${(state.dutyPercent / 100.0).toStringAsFixed(2)} × 12.0 = ${state.averageVoltage.toStringAsFixed(1)} Volt',
                    statusIcon: Icons.bolt_rounded,
                    statusColor: context.elio.primaryText,
                    statusText: 'Motor menerima setara ${state.averageVoltage.toStringAsFixed(1)}V',
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Modul F — PWM & Tegangan Efektif Motor',
                    bodyText: 'Motor DC pada ELIO (misalnya motor roda atau motor lengan) tidak selalu diberi tegangan penuh terus-menerus. Untuk mengatur kecepatan motor tanpa membuang energi sebagai panas, ELIO memakai teknik PWM (Pulse Width Modulation) — menyalakan dan mematikan tegangan penuh secara sangat cepat (ratusan hingga ribuan kali per detik), dan mengatur berapa lama proporsi waktu tegangan itu menyala dalam satu siklus.\n\nCara lama mengatur kecepatan motor adalah memakai pembagi tegangan resistif (resistor/potensiometer) untuk menurunkan tegangan secara langsung. Masalahnya, kelebihan energi pada metode ini dibuang sebagai panas di resistor — energi terbuang percuma dan komponen jadi panas.\n\nPWM tidak pernah benar-benar "menurunkan" tegangan — ia hanya menyalakan-mematikan tegangan penuh dengan sangat cepat. Karena motor punya inersia mekanis dan induktansi kumparan yang meredam "kedutan" on/off ini menjadi gerakan halus, hasil akhirnya terasa seperti tegangan lebih rendah, tapi tanpa membuang energi sebagai panas resistif — hanya rugi-rugi sambungan (switching loss) yang jauh lebih kecil.',
                    bulletPoints: [
                      'V_avg = D · V_max (Tegangan efektif rata-rata = Duty Cycle × Tegangan Maksimum).',
                      'D (Duty Cycle) adalah persentase waktu sinyal dalam kondisi "menyala" dalam satu periode.',
                      'Duty cycle 60% berarti menyala penuh 60% waktu dan mati 40% sisanya. Rata-ratanya 7.2V dari 12V maksimal.',
                      'Batasan Model Linear (Penting): Perkiraan RPM pada simulasi ini adalah pendekatan linear. Pada motor nyata, hubungan duty cycle dan RPM aktual tidak sepenuhnya linear begitu motor dibebani torsi.',
                      'Klaim "penurunan tegangan rata-rata = penurunan arus rata-rata secara proporsional" HANYA BENAR KALAU BEBAN MURNI RESISTIF. Pada motor (beban induktif + mekanis), penurunan arus tidak mengikuti penurunan tegangan secara linear sederhana.'
                    ],
                  ),
    );
  }
}
