import '../../domain/entities/session.dart';
import '../../domain/entities/user.dart';
import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/preferences_port.dart';
import '../../domain/ports/outbound/session_storage.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/jwt_token.dart';

/// Implementación de [SessionStorage] sobre [PreferencesPort].
///
/// Mantiene COMPATIBILIDAD con las claves usadas por el código actual
/// (`auth_service.dart`, `auth_provider.dart`, `api_client.dart`) para que
/// los componentes legacy sigan funcionando durante la migración:
///
///   `jwt_token`     → token JWT en claro
///   `user_email`    → email del usuario
///   `user_id`       → id numérico
///   `is_premium`    → bool
///   `token_expiry`  → epoch en segundos (compatibilidad)
class SessionStorageImpl implements SessionStorage {
  final PreferencesPort _prefs;
  const SessionStorageImpl(this._prefs);

  static const String keyToken = 'jwt_token';
  static const String keyEmail = 'user_email';
  static const String keyUserId = 'user_id';
  static const String keyIsPremium = 'is_premium';
  static const String keyTokenExpiry = 'token_expiry';

  /// Claves adicionales que se borran al limpiar sesión (parches del legacy).
  static const List<String> _allKeys = [
    keyToken,
    keyEmail,
    keyUserId,
    keyIsPremium,
    keyTokenExpiry,
    'pending_trip',
  ];

  @override
  Future<Result<Session?, StorageFailure>> read() async {
    try {
      final raw = await _prefs.readString(keyToken);
      if (raw == null) return const Ok(null);

      final tokenResult = JwtToken.tryParse(raw);
      if (tokenResult case Err()) {
        // JWT corrupto → tratamos como sin sesión.
        await clear();
        return const Ok(null);
      }
      final email = await _prefs.readString(keyEmail);
      final id = await _prefs.readInt(keyUserId);
      final isPremium = await _prefs.readBool(keyIsPremium) ?? false;
      if (email == null || id == null) return const Ok(null);

      final emailVo = Email.tryParse(email);
      if (emailVo case Err()) return const Ok(null);

      return Ok(Session(
        user: User(id: id, email: emailVo.unwrap(), isPremium: isPremium),
        token: tokenResult.unwrap(),
      ));
    } catch (e, s) {
      return Err(StorageReadFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, StorageFailure>> save(Session session) async {
    try {
      await _prefs.writeString(keyToken, session.token.raw);
      await _prefs.writeString(keyEmail, session.user.email.value);
      await _prefs.writeInt(keyUserId, session.user.id);
      await _prefs.writeBool(keyIsPremium, session.user.isPremium);
      final exp = session.token.expiresAt;
      if (exp != null) {
        await _prefs.writeInt(
          keyTokenExpiry,
          exp.millisecondsSinceEpoch ~/ 1000,
        );
      }
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, StorageFailure>> clear() async {
    try {
      await _prefs.removeAll(_allKeys);
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }
}
