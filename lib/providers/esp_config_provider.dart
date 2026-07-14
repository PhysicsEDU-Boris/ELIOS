import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/config_model.dart';
import '../services/config_service.dart';

final espConfigProvider =
    AsyncNotifierProvider<EspConfigNotifier, EspConfig>(EspConfigNotifier.new);

class EspConfigNotifier extends AsyncNotifier<EspConfig> {
  ConfigService get _service => ConfigService();

  @override
  Future<EspConfig> build() => _service.loadConfig();

  /// Persist a full config replacement and update state optimistically.
  Future<void> save(EspConfig config) async {
    await _service.saveConfig(config);
    state = AsyncData(config);
  }

  /// Convenience: patch just the fields that changed, keeping the rest.
  Future<void> patch(EspConfig Function(EspConfig current) transform) async {
    final current = state.valueOrNull ?? const EspConfig();
    await save(transform(current));
  }

  Future<void> clear() async {
    await _service.clearConfig();
    state = const AsyncData(EspConfig());
  }
}
