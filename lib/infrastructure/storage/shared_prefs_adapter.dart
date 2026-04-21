import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/outbound/preferences_port.dart';

/// Adaptador del puerto [PreferencesPort] basado en `shared_preferences`.
///
/// La instancia de `SharedPreferences` se inyecta para que en producción se
/// consiga una sola vez en `main()` y en tests podamos saltarnos el plugin
/// usando `SharedPreferences.setMockInitialValues(...)`.
class SharedPrefsAdapter implements PreferencesPort {
  final SharedPreferences _prefs;
  const SharedPrefsAdapter(this._prefs);

  @override
  Future<String?> readString(String key) async => _prefs.getString(key);

  @override
  Future<void> writeString(String key, String value) async =>
      _prefs.setString(key, value);

  @override
  Future<int?> readInt(String key) async => _prefs.getInt(key);

  @override
  Future<void> writeInt(String key, int value) async =>
      _prefs.setInt(key, value);

  @override
  Future<bool?> readBool(String key) async => _prefs.getBool(key);

  @override
  Future<void> writeBool(String key, bool value) async =>
      _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) async => _prefs.remove(key);

  @override
  Future<void> removeAll(Iterable<String> keys) async {
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
