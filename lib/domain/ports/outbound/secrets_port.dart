/// Puerto de persistencia segura (Keychain en iOS, EncryptedSharedPreferences
/// en Android). Se usa para credenciales que respaldan el login biométrico.
///
/// Nunca debe usarse para tokens de sesión normales — esos van por
/// [PreferencesPort] porque su ciclo de vida es corto y se invalidan en logout.
abstract interface class SecretsPort {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll(Iterable<String> keys);
}
