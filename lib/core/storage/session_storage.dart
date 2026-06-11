import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage seguro para JWT e identidad del usuario.
///
/// Usa FlutterSecureStorage (Keystore en Android, Keychain en iOS) en lugar
/// de SharedPreferences para que el token NO sea legible mediante un backup
/// ADB o desde otra app con permisos elevados.
///
/// Hace una **migración one-shot** desde SharedPreferences la primera vez
/// que se ejecuta tras la actualización: copia los valores antiguos al
/// secure storage y los borra del SP. Idempotente — vuelve a llamarlo a
/// cada arranque y no hace nada si ya migró.
class SessionStorage {
  // En FSS >= 10 EncryptedSharedPreferences está deprecated (Jetpack Security
  // se discontinuó). El propio plugin migra los datos a un cipher custom en
  // el primer acceso, así que basta con instanciar sin opciones.
  static const _storage = FlutterSecureStorage();

  // Claves nuevas (en FSS)
  static const _kToken    = 'session_jwt_token';
  static const _kEmail    = 'session_user_email';
  static const _kUserId   = 'session_user_id';
  static const _kExpiry   = 'session_token_expiry';

  // Flag de migración (vive en SharedPreferences, no es sensible)
  static const _kMigratedSp = 'session_migrated_from_sp_v1';

  // Claves antiguas en SharedPreferences (preFSS). Se borran al migrar.
  static const _legacyToken  = 'jwt_token';
  static const _legacyEmail  = 'user_email';
  static const _legacyUserId = 'user_id';
  static const _legacyExpiry = 'token_expiry';

  /// Migra la sesión desde SharedPreferences a FSS si aún no se ha hecho.
  /// Llamar UNA VEZ desde `main()` antes de leer el token.
  ///
  /// Aprovecha también para borrar la `biometric_password` legacy que en
  /// versiones anteriores se persistía en FSS — el nuevo flujo biométrico
  /// no la necesita y mantenerla expuesta es lo que arregla el punto P5
  /// de la auditoría.
  static Future<void> migrateFromSharedPreferencesIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (prefs.getBool(_kMigratedSp) == true) return;

    final legacyToken = prefs.getString(_legacyToken);
    if (legacyToken != null) {
      await _storage.write(key: _kToken, value: legacyToken);

      final email = prefs.getString(_legacyEmail);
      if (email != null) await _storage.write(key: _kEmail, value: email);

      final userId = prefs.getInt(_legacyUserId);
      if (userId != null) {
        await _storage.write(key: _kUserId, value: userId.toString());
      }

      final expiry = prefs.getInt(_legacyExpiry);
      if (expiry != null) {
        await _storage.write(key: _kExpiry, value: expiry.toString());
      }
    }

    // Borrar las claves antiguas del SP — el token y el email no deben
    // quedar accesibles sin cifrar después de migrar.
    await prefs.remove(_legacyToken);
    await prefs.remove(_legacyEmail);
    await prefs.remove(_legacyUserId);
    await prefs.remove(_legacyExpiry);

    // Borrar la contraseña biométrica heredada (auth_service.dart la guardaba
    // en FSS para "saltar OTP" — ya no la usamos).
    await _storage.delete(key: 'biometric_password');

    await prefs.setBool(_kMigratedSp, true);
  }

  static Future<String?> getToken() => _storage.read(key: _kToken);

  static Future<String?> getEmail() => _storage.read(key: _kEmail);

  static Future<int?> getUserId() async {
    final v = await _storage.read(key: _kUserId);
    return v == null ? null : int.tryParse(v);
  }

  /// Epoch en segundos (campo `exp` del JWT).
  static Future<int?> getExpiry() async {
    final v = await _storage.read(key: _kExpiry);
    return v == null ? null : int.tryParse(v);
  }

  static Future<void> saveSession({
    required String token,
    required String email,
    required int userId,
    int? expiryEpoch,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kUserId, value: userId.toString());
    if (expiryEpoch != null) {
      await _storage.write(key: _kExpiry, value: expiryEpoch.toString());
    } else {
      await _storage.delete(key: _kExpiry);
    }
  }

  static Future<void> updateEmail(String email) =>
      _storage.write(key: _kEmail, value: email);

  static Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kExpiry);
  }
}
