import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider global para acceso síncrono a SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

/// Provider que gestiona el Modo de Alta Visibilidad de forma reactiva con Riverpod.
class HighVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // Probamos con la nueva clave, si no existe usamos la antigua para compatibilidad
    return prefs.getBool('high_visibility_enabled') ?? 
           prefs.getBool('elderly_mode_enabled') ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('high_visibility_enabled', value);
  }
}

final highVisibilityProvider = NotifierProvider<HighVisibilityNotifier, bool>(() {
  return HighVisibilityNotifier();
});
