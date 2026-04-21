import '../../domain/exceptions/app_failure.dart';
import '../../domain/ports/outbound/biometric_credentials_storage.dart';
import '../../domain/ports/outbound/secrets_port.dart';
import '../../domain/shared/result.dart';
import '../../domain/value_objects/email.dart';
import '../../domain/value_objects/password.dart';

/// Implementación de [BiometricCredentialsStorage] basada en [SecretsPort].
/// Mantiene las claves del legacy `auth_service.dart`:
///   `biometric_email`, `biometric_password`, `biometric_enabled`.
class BiometricCredentialsStorageImpl implements BiometricCredentialsStorage {
  final SecretsPort _secrets;
  const BiometricCredentialsStorageImpl(this._secrets);

  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled = 'biometric_enabled';

  @override
  Future<bool> isEnabled() async {
    final enabled = await _secrets.read(_keyEnabled);
    return enabled == 'true';
  }

  @override
  Future<Result<BiometricCredentials?, StorageFailure>> read() async {
    try {
      final email = await _secrets.read(_keyEmail);
      final password = await _secrets.read(_keyPassword);
      if (email == null || password == null) return const Ok(null);

      final emailVo = Email.tryParse(email);
      final passVo = Password.tryParse(password);
      if (emailVo case Err()) return const Ok(null);
      if (passVo case Err()) return const Ok(null);
      return Ok(BiometricCredentials(
        email: emailVo.unwrap(),
        password: passVo.unwrap(),
      ));
    } catch (e, s) {
      return Err(StorageReadFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, StorageFailure>> save(BiometricCredentials credentials) async {
    try {
      await _secrets.write(_keyEmail, credentials.email.value);
      await _secrets.write(_keyPassword, credentials.password.value);
      await _secrets.write(_keyEnabled, 'true');
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }

  @override
  Future<Result<void, StorageFailure>> clear() async {
    try {
      await _secrets.deleteAll([_keyEmail, _keyPassword, _keyEnabled]);
      return const Ok(null);
    } catch (e, s) {
      return Err(StorageWriteFailure(cause: e, stackTrace: s));
    }
  }
}
