import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider global para acceso síncrono a SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

/// Provider que gestiona el Modo Personas Mayores de forma reactiva con Riverpod.
class ElderlyModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('elderly_mode_enabled') ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('elderly_mode_enabled', value);
  }
}

final elderlyModeProvider = NotifierProvider<ElderlyModeNotifier, bool>(() {
  return ElderlyModeNotifier();
});
