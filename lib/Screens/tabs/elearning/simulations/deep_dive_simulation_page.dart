import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/shared/porosity_notifier.dart';
import '../../../../../physics/deep_dive/hooke_spring_state.dart';
import '../../../../../physics/deep_dive/nir_reflectance_state.dart';
import '../../../../../physics/deep_dive/vapor_pressure_state.dart';
import '../../../../../physics/deep_dive/incinerator_state.dart';
import '../../../../../physics/deep_dive/radiation_shielding_state.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/simulation_page_scaffold.dart';
import 'painters/inorganic_painters.dart';
import 'painters/b3_painters.dart';

class DeepDiveSimulationPage extends ConsumerStatefulWidget {
  const DeepDiveSimulationPage({super.key});

  @override
  ConsumerState<DeepDiveSimulationPage> createState() => _DeepDiveSimulationPageState();
}

class _DeepDiveSimulationPageState extends ConsumerState<DeepDiveSimulationPage> {
  bool _organicExpanded = false;
  bool _inorganicExpanded = false;
  bool _b3Expanded = false;

  @override
  Widget build(BuildContext context) {
    return SimulationPageScaffold(
      module: PhysicsModuleId.deepDive,
      appBarTitle: 'Deep-Dive Sampah',
      header: const SimModuleHeader(
        tag: 'WASTE PHYSICS · DEEP-DIVE',
        title: 'Fisika Pemilahan Sampah',
        subtitle: 'Eksplorasi alasan di balik perbedaan penanganan tiap kategori sampah.',
      ),
      simulationContent: [
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _organicExpanded ? Color(0xFF10B981) : context.elio.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        backgroundColor: context.elio.surface,
                        collapsedBackgroundColor: context.elio.surface,
                        initiallyExpanded: false,
                        title: Text('Kartu Organik — Porositas & Aliran Oksigen', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                        iconColor: const Color(0xFF10B981),
                        collapsedIconColor: context.elio.textSecondary,
                        onExpansionChanged: (v) => setState(() => _organicExpanded = v),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: const _OrganicDeepDiveContent(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Inorganic Card
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _inorganicExpanded ? Color(0xFF3B82F6) : context.elio.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        backgroundColor: context.elio.surface,
                        collapsedBackgroundColor: context.elio.surface,
                        initiallyExpanded: false,
                        title: Text('Kartu Inorganik — Hooke, NIR, & Eddy Current', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                        iconColor: const Color(0xFF3B82F6),
                        collapsedIconColor: context.elio.textSecondary,
                        onExpansionChanged: (v) => setState(() => _inorganicExpanded = v),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: const _InorganicDeepDiveContent(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // B3 Card
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _b3Expanded ? Color(0xFFEF4444) : context.elio.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        backgroundColor: context.elio.surface,
                        collapsedBackgroundColor: context.elio.surface,
                        initiallyExpanded: false,
                        title: Text('Kartu B3 — Tekanan Uap, Insinerator, Radiasi', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                        iconColor: const Color(0xFFEF4444),
                        collapsedIconColor: context.elio.textSecondary,
                        onExpansionChanged: (v) => setState(() => _b3Expanded = v),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: const _B3DeepDiveContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
      ],
    );
  }
}

class _OrganicDeepDiveContent extends ConsumerWidget {
  const _OrganicDeepDiveContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porosityState = ref.watch(porosityProvider);
    final notifier = ref.read(porosityProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Slider
        LabeledSlider(
          label: 'Porositas Tumpukan',
          valueLabel: '${porosityState.porosityPercent.toStringAsFixed(0)}%',
          value: porosityState.porosityPercent,
          min: 10.0,
          max: 80.0,
          onChanged: notifier.setPorosity,
        ),
        const SizedBox(height: 16),

        // Indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: porosityState.isAnaerobic ? context.elio.errorText.withValues(alpha: 0.1) : context.elio.primaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: porosityState.isAnaerobic ? context.elio.errorText : context.elio.primaryText),
          ),
          child: Row(
            children: [
              Icon(
                porosityState.isAnaerobic ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: porosityState.isAnaerobic ? context.elio.errorText : context.elio.primaryText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  porosityState.isAnaerobic
                      ? 'Porositas rendah (<25%). Udara sulit masuk, memicu dekomposisi anaerobik (metana).'
                      : 'Porositas baik. Oksigen mengalir bebas, proses aerobik optimal.',
                  style: TextStyle(
                    color: porosityState.isAnaerobic ? context.elio.errorText : context.elio.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Physics details
        Text('Konsep Inti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Porositas adalah persentase ruang kosong (berisi udara) di antara partikel padat dalam tumpukan kompos. Porositas tinggi = udara bisa mengalir bebas ke seluruh tumpukan = proses aerobik (butuh oksigen) berjalan sehat. Porositas rendah = tumpukan terlalu padat = oksigen cepat habis di bagian dalam = mikroba anaerobik mengambil alih.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        
        Text('Fisika Kunci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          '• Hukum Fick (difusi) — laju perpindahan oksigen ke dalam tumpukan sebanding dengan luas jalur pori dan berbanding terbalik dengan jarak tempuh; tumpukan padat = jalur difusi lebih panjang dan sempit = laju oksigen masuk melambat drastis.\n'
          '• Konduksi kalor, Q/t = kAΔT/L — panas yang dihasilkan mikroba di inti tumpukan merambat keluar lewat konduksi; tumpukan padat menghambat pelepasan ini juga, memperparah risiko overheating (lihat Modul B).\n'
          '• Hukum Jurin (kapilaritas) — menjelaskan bagaimana kelembapan naik atau tertahan di antara partikel kecil, memengaruhi seberapa "basah" pori-pori tetap dari waktu ke waktu.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),

        // Why can't it be sorted like inorganic/B3?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: context.elio.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Text('Mengapa perlakuan berbeda?', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Sampah organik tidak punya sifat listrik (konduktivitas), optik (reflektansi NIR), atau kimia berbahaya (volatilitas/reaktivitas) yang bisa dijadikan sinyal pemilahan otomatis — satu-satunya variabel fisik yang relevan justru adalah struktur pori dan kelembapannya sendiri, karena tujuan pemrosesannya bukan memisahkan jenis material, tapi mengelola proses biologis penguraian itu sendiri.',
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InorganicDeepDiveContent extends ConsumerStatefulWidget {
  const _InorganicDeepDiveContent();

  @override
  ConsumerState<_InorganicDeepDiveContent> createState() => _InorganicDeepDiveContentState();
}

class _InorganicDeepDiveContentState extends ConsumerState<_InorganicDeepDiveContent> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _animationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _animationValue = (elapsed.inMilliseconds % 2000) / 2000.0;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hookeState = ref.watch(hookeSpringProvider);
    final hookeNotifier = ref.read(hookeSpringProvider.notifier);
    
    final nirState = ref.watch(nirReflectanceProvider);
    final nirNotifier = ref.read(nirReflectanceProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. Uji Kekerasan (Pegas Hooke)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Prinsip ini dipakai ELIO pada mekanisme penjepit/pendorong berpegas untuk menguji kekerasan/elastisitas benda.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: HookeSpringPainter(compressionCm: hookeState.compressionCm)),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: 'Pemampatan (x)',
          valueLabel: '${hookeState.compressionCm.toStringAsFixed(1)} cm',
          value: hookeState.compressionCm,
          min: 2.0,
          max: 20.0,
          onChanged: hookeNotifier.setCompression,
        ),
        const SizedBox(height: 8),
        Text('Gaya Reaksi (F = k·x): ${hookeState.forceN.toStringAsFixed(1)} N (k=50 N/m)', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.primaryText)),
        const Divider(height: 32),
        
        Text('2. Reflektansi Near-Infrared (NIR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Setiap jenis plastik menyerap dan memantulkan cahaya inframerah-dekat pada panjang gelombang karakteristik yang berbeda, membentuk semacam "sidik jari optik."',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.elio.secondaryText.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: context.elio.secondaryText)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, color: context.elio.secondaryText, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠ Catatan Akurasi: Angka panjang gelombang puncak (mis. PET ≈1660nm, HDPE ≈1730nm, PP ≈1410nm) yang dipakai dalam simulasi ini harus diverifikasi ulang terhadap referensi sorting NIR industri yang valid sebelum dirilis ke pengguna. Sensor NIR sungguhan mengukur puncak/lembah absorbansi pada rentang tertentu yang bisa bervariasi.',
                  style: TextStyle(color: context.elio.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: PlasticType.values.map((type) {
            final isSelected = nirState.selectedPlastic == type;
            final label = type == PlasticType.pet ? 'PET' : (type == PlasticType.hdpe ? 'HDPE' : 'PP');
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (v) => nirNotifier.setPlastic(type),
              selectedColor: context.elio.primaryText.withValues(alpha: 0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: NirCurvePainter(peakNm: nirState.peakWavelengthNm)),
        ),
        const SizedBox(height: 8),
        Text('Puncak Spektrum: ≈${nirState.peakWavelengthNm.toStringAsFixed(0)} nm', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.primaryText)),
        const Divider(height: 32),
        
        Text('3. Arus Eddy (Logam Non-Feromagnetik)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Ketika logam bergerak melalui medan magnet yang berubah, arus pusar (eddy current) terinduksi di dalam logam tersebut, menciptakan medan magnet lawan yang menolak logam non-magnetik seperti aluminium menjauh dari sumber magnet.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: EddyCurrentPainter(animationValue: _animationValue)),
        ),
        const SizedBox(height: 24),

        // Why can't it be sorted like organic/B3?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: context.elio.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Text('Mengapa perlakuan berbeda?', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Material inorganik (plastik, kaca, logam) tidak mengalami proses biologis apa pun yang perlu dikelola (beda dengan organik), dan sebagian besar tidak reaktif secara kimiawi/berbahaya (beda dengan B3) — sinyal pemilahan yang paling efektif justru sifat fisiknya yang stabil: kekerasan (Hooke), identitas optik (NIR), dan sifat magnetik/konduktif (arus eddy).',
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _B3DeepDiveContent extends ConsumerWidget {
  const _B3DeepDiveContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaporState = ref.watch(vaporPressureProvider);
    final vaporNotifier = ref.read(vaporPressureProvider.notifier);
    
    final incinState = ref.watch(incineratorProvider);
    final incinNotifier = ref.read(incineratorProvider.notifier);
    
    final radState = ref.watch(radiationShieldingProvider);
    final radNotifier = ref.read(radiationShieldingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. Tekanan Uap (Vapor Pressure)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Semakin tinggi suhu suatu cairan/zat, semakin besar kecenderungannya menguap menjadi gas — inilah tekanan uap. Persamaan Clausius-Clapeyron menjelaskan hubungan non-linear (eksponensial) ini.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.elio.secondaryText.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: context.elio.secondaryText)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, color: context.elio.secondaryText, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠ Catatan Akurasi: Simulasi ini memakai pendekatan kualitatif/simplifikasi, bukan kurva P–T literal dengan konstanta eksponensial yang presisi secara ilmiah. Tujuannya semata menunjukkan tren (semakin panas = semakin mudah menguap = semakin berbahaya).',
                  style: TextStyle(color: context.elio.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: VaporPressurePainter(temperatureC: vaporState.temperatureC, relativePressure: vaporState.relativePressure)),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: 'Suhu Zat',
          valueLabel: '${vaporState.temperatureC.toStringAsFixed(1)} °C',
          value: vaporState.temperatureC,
          min: 0.0,
          max: 100.0,
          onChanged: vaporNotifier.setTemperature,
        ),
        const SizedBox(height: 8),
        Text('Relative Vapor Pressure: ${vaporState.relativePressure.toStringAsFixed(4)} (Arbiter)', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.errorText)),
        const Divider(height: 32),
        
        Text('2. Insinerator (Penghancuran Ikatan Kimia)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Insinerasi bahan berbahaya membutuhkan suhu jauh lebih tinggi dibanding pembakaran sampah biasa untuk memutus ikatan kimia molekul beracun (misalnya senyawa organik persisten). Ambang 1000°C di sini adalah ilustrasi titik dekomposisi termal.',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: IncineratorPainter(temperatureC: incinState.temperatureC, isDestroyed: incinState.bondsDestroyed)),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: 'Suhu Insinerator',
          valueLabel: '${incinState.temperatureC.toStringAsFixed(0)} °C',
          value: incinState.temperatureC,
          min: 200.0,
          max: 1200.0,
          onChanged: incinNotifier.setTemperature,
        ),
        const SizedBox(height: 8),
        Text(
          incinState.bondsDestroyed ? 'Status: Ikatan Kimia Berbahaya Terurai (Aman)' : 'Status: Ikatan Masih Utuh (Berbahaya)',
          style: TextStyle(fontWeight: FontWeight.bold, color: incinState.bondsDestroyed ? context.elio.primaryText : context.elio.errorText),
        ),
        const Divider(height: 32),
        
        Text('3. Perisai Radiasi (Radiation Shielding)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.elio.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Intensitas radiasi (I) berkurang secara eksponensial seiring bertambahnya ketebalan perisai (x).',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.elio.secondaryText.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: context.elio.secondaryText)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, color: context.elio.secondaryText, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠ Catatan Akurasi: Koefisien atenuasi sungguhan sangat bergantung pada energi partikel radiasi (MeV) dan jenis material perisai spesifik. Angka di bawah adalah nilai ilustratif untuk menunjukkan urutan relatif (gamma paling sulit, alfa paling mudah).',
                  style: TextStyle(color: context.elio.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: RadiationType.values.map((type) {
            final isSelected = radState.selectedType == type;
            final label = type == RadiationType.alpha ? 'Alfa (α)' : (type == RadiationType.beta ? 'Beta (β)' : 'Gamma (γ)');
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (v) => radNotifier.setType(type),
              selectedColor: context.elio.primaryText.withValues(alpha: 0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(color: context.elio.surface, border: Border.all(color: context.elio.borderSubtle), borderRadius: BorderRadius.circular(8)),
          child: CustomPaint(painter: RadiationPainter(thicknessCm: radState.thicknessCm, transmittedPercent: radState.transmittedIntensityPercent)),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: 'Ketebalan Perisai (x)',
          valueLabel: '${radState.thicknessCm.toStringAsFixed(1)} cm',
          value: radState.thicknessCm,
          min: 0.0,
          max: 20.0,
          onChanged: radNotifier.setThickness,
        ),
        const SizedBox(height: 24),

        // Why can't it be sorted like organic/inorganic?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: context.elio.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Text('Mengapa perlakuan berbeda?', style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Perbedaan mendasarnya bukan pada jenis material fisiknya (B3 bisa berupa logam, cairan, atau padatan apa saja), tapi pada tingkat bahaya laten-nya — volatilitas kimia, radioaktivitas, atau reaktivitas termal yang bisa mencederai manusia atau lingkungan kalau ditangani seperti sampah biasa. Karena itu metode "pemilahan"-nya bukan soal memisahkan jenis material, melainkan soal penahanan dan penanganan aman (containment) — perisai, suhu kontrol, dan identifikasi dini sebelum bersentuhan langsung.',
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
