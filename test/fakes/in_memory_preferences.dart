import 'package:alzitrans/domain/ports/outbound/preferences_port.dart';

/// Implementación en memoria de [PreferencesPort] para tests.
class InMemoryPreferences implements PreferencesPort {
  final Map<String, Object> _store = {};

  Map<String, Object> get snapshot => Map.unmodifiable(_store);

  @override
  Future<bool?> readBool(String key) async => _store[key] as bool?;

  @override
  Future<int?> readInt(String key) async => _store[key] as int?;

  @override
  Future<String?> readString(String key) async => _store[key] as String?;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> removeAll(Iterable<String> keys) async {
    for (final k in keys) {
      _store.remove(k);
    }
  }

  @override
  Future<void> writeBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> writeInt(String key, int value) async => _store[key] = value;

  @override
  Future<void> writeString(String key, String value) async =>
      _store[key] = value;
}
