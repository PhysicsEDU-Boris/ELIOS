import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlasticType { pet, hdpe, pp }

class NirReflectanceState {
  final PlasticType selectedPlastic;

  const NirReflectanceState({this.selectedPlastic = PlasticType.pet});
  
  // ⚠ CATATAN AKURASI: Angka panjang gelombang puncak ini (PET ≈1660nm, 
  // HDPE ≈1730nm, PP ≈1410nm) yang dipakai dalam simulasi ini HARUS DIVERIFIKASI 
  // ULANG terhadap referensi sorting NIR industri yang valid sebelum dirilis. 
  // Sensor NIR sungguhan mengukur puncak/lembah absorbansi pada rentang 
  // tertentu yang bisa bervariasi.
  double get peakWavelengthNm {
    switch (selectedPlastic) {
      case PlasticType.pet: return 1660.0;
      case PlasticType.hdpe: return 1730.0;
      case PlasticType.pp: return 1410.0;
    }
  }

  String get plasticName {
    switch (selectedPlastic) {
      case PlasticType.pet: return 'PET';
      case PlasticType.hdpe: return 'HDPE';
      case PlasticType.pp: return 'PP';
    }
  }

  NirReflectanceState copyWith({PlasticType? selectedPlastic}) {
    return NirReflectanceState(
      selectedPlastic: selectedPlastic ?? this.selectedPlastic,
    );
  }
}

class NirReflectanceNotifier extends Notifier<NirReflectanceState> {
  @override
  NirReflectanceState build() => const NirReflectanceState();

  void setPlastic(PlasticType p) {
    state = state.copyWith(selectedPlastic: p);
  }
}

final nirReflectanceProvider = NotifierProvider<NirReflectanceNotifier, NirReflectanceState>(NirReflectanceNotifier.new);
