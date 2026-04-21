import 'package:alzitrans/domain/ports/outbound/secrets_port.dart';

class InMemorySecrets implements SecretsPort {
  final Map<String, String> _store = {};
  Map<String, String> get snapshot => Map.unmodifiable(_store);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final k in keys) {
      _store.remove(k);
    }
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}
