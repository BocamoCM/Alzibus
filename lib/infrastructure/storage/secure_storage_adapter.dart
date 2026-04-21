import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/ports/outbound/secrets_port.dart';

/// Adaptador del puerto [SecretsPort] basado en `flutter_secure_storage`.
class SecureStorageAdapter implements SecretsPort {
  final FlutterSecureStorage _storage;

  const SecureStorageAdapter([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final k in keys) {
      await _storage.delete(key: k);
    }
  }
}
