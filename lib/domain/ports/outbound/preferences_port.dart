/// Puerto de persistencia clave-valor no segura (preferencias de usuario,
/// flags, ids, último estado conocido…).
///
/// La implementación por defecto (`SharedPrefsAdapter`) usa el plugin
/// `shared_preferences`, pero el dominio no lo sabe ni le importa.
///
/// En tests se sustituye por `InMemoryPreferences` para conseguir 100 % de
/// determinismo sin necesidad de inicializar Flutter.
abstract interface class PreferencesPort {
  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);

  Future<int?> readInt(String key);
  Future<void> writeInt(String key, int value);

  Future<bool?> readBool(String key);
  Future<void> writeBool(String key, bool value);

  Future<void> remove(String key);

  /// Borra todas las claves del dominio Auth (token, email, id, premium…).
  /// Útil en logout y en respuestas 401.
  Future<void> removeAll(Iterable<String> keys);
}
